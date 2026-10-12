"""Signed, read-only streaming gateway for MyOwnStreamingService + TrueNAS.

The backend creates HMAC-SHA256 URLs. This service resolves IDs through the
private `server_media.relative_media_key` field and never accepts filesystem
paths from clients.
"""
import asyncio
import hashlib
import hmac
import mimetypes
import re
import os
import shutil
import time
from pathlib import Path
from typing import Iterator

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
import httpx
from supabase import Client, create_client

SUPABASE_URL = os.environ["SUPABASE_URL"].strip()
SUPABASE_SERVICE_ROLE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"].strip()
SIGNING_SECRET = os.environ["MEDIA_AGENT_SHARED_SECRET"].encode("utf-8")
MEDIA_ROOT = Path(os.environ.get("MEDIA_ROOT", "/media")).resolve()
MAX_URL_LIFETIME_SECONDS = 600
BACKEND_HEARTBEAT_URL = os.environ.get("BACKEND_HEARTBEAT_URL", "").strip()
SERVER_ID = os.environ.get("SERVER_ID", "").strip()
AGENT_ID = os.environ.get("AGENT_ID", "truenas-media-agent").strip()
NAS_NAME = os.environ.get("NAS_NAME", "TrueNAS").strip()

if len(SIGNING_SECRET) < 32:
    raise RuntimeError("MEDIA_AGENT_SHARED_SECRET must be at least 32 characters")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
app = FastAPI(title="MyOwnStreamingService TrueNAS Media Agent")
_heartbeat_task: asyncio.Task | None = None


async def heartbeat_loop() -> None:
    if not BACKEND_HEARTBEAT_URL or not SERVER_ID:
        # Playback can be tested independently, but the existing backend's
        # owner checks require this heartbeat configuration for app playback.
        return
    async with httpx.AsyncClient(timeout=10.0) as client:
        while True:
            try:
                usage = shutil.disk_usage(MEDIA_ROOT)
                response = await client.post(
                    BACKEND_HEARTBEAT_URL,
                    headers={"X-Media-Agent-Secret": SIGNING_SECRET.decode("utf-8")},
                    json={
                        "serverId": SERVER_ID,
                        "agentId": AGENT_ID,
                        "nasName": NAS_NAME,
                        "storageStatus": "available" if MEDIA_ROOT.is_dir() else "offline",
                        "totalBytes": usage.total,
                        "freeBytes": usage.free,
                    },
                )
                response.raise_for_status()
            except Exception:
                # Keep serving locally; the backend status will remain stale/offline
                # until a subsequent heartbeat succeeds. Never log credentials.
                pass
            await asyncio.sleep(30)


@app.on_event("startup")
async def start_heartbeat() -> None:
    global _heartbeat_task
    _heartbeat_task = asyncio.create_task(heartbeat_loop())


@app.on_event("shutdown")
async def stop_heartbeat() -> None:
    global _heartbeat_task
    if _heartbeat_task is not None:
        _heartbeat_task.cancel()
        try:
            await _heartbeat_task
        except asyncio.CancelledError:
            pass


def verify_signature(server_id: str, media_id: str, exp: int, signature: str) -> None:
    now = int(time.time())
    if exp < now or exp > now + MAX_URL_LIFETIME_SECONDS:
        raise HTTPException(status_code=403, detail="Playback URL expired or invalid")
    payload = f"{server_id}\n{media_id}\n{exp}".encode("utf-8")
    expected = hmac.new(SIGNING_SECRET, payload, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature.lower()):
        raise HTTPException(status_code=403, detail="Invalid playback signature")


def resolve_media_key(server_id: str, media_id: str) -> str:
    if not re.fullmatch(r"[0-9a-fA-F-]{36}", server_id):
        raise HTTPException(status_code=400, detail="Invalid server identifier")
    # First support the server-local identifier used by server_media.
    result = (
        supabase.table("server_media")
        .select("relative_media_key")
        .eq("server_id", server_id)
        .eq("server_media_id", media_id)
        .limit(1)
        .execute()
    )
    rows = result.data or []

    # Also support a canonical media_catalog UUID passed by a client.
    if not rows and re.fullmatch(r"[0-9a-fA-F-]{36}", media_id):
        result = (
            supabase.table("server_media")
            .select("relative_media_key")
            .eq("server_id", server_id)
            .eq("media_catalog_id", media_id)
            .limit(1)
            .execute()
        )
        rows = result.data or []

    if not rows or not rows[0].get("relative_media_key"):
        raise HTTPException(status_code=404, detail="Media is not indexed on this server")
    return str(rows[0]["relative_media_key"])


def resolve_file(storage_key: str) -> Path:
    # Resolve symlinks too; media files must remain inside the mounted root.
    candidate = (MEDIA_ROOT / storage_key).resolve()
    if not candidate.is_relative_to(MEDIA_ROOT):
        raise HTTPException(status_code=403, detail="Invalid storage key")
    if not candidate.is_file():
        raise HTTPException(status_code=404, detail="Media file is unavailable")
    return candidate


def parse_range(value: str | None, size: int) -> tuple[int, int, int]:
    if size <= 0:
        raise HTTPException(status_code=404, detail="Empty media file")
    if not value:
        return 0, size - 1, 200
    if not value.startswith("bytes=") or "," in value:
        raise HTTPException(416, "Only one byte range is supported", headers={"Content-Range": f"bytes */{size}"})
    try:
        left, right = value[6:].split("-", 1)
        if left:
            start = int(left)
            end = int(right) if right else size - 1
        else:
            suffix = int(right)
            if suffix <= 0:
                raise ValueError
            start = max(0, size - suffix)
            end = size - 1
        if start < 0 or start >= size or end < start:
            raise ValueError
        return start, min(end, size - 1), 206
    except ValueError:
        raise HTTPException(416, "Invalid byte range", headers={"Content-Range": f"bytes */{size}"})


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "truenas-media-agent"}


@app.api_route("/stream", methods=["GET", "HEAD"])
def stream(
    request: Request,
    server_id: str = Query(min_length=1, max_length=128),
    media_id: str = Query(min_length=1, max_length=256),
    exp: int = Query(),
    sig: str = Query(min_length=64, max_length=64),
):
    verify_signature(server_id, media_id, exp, sig)
    storage_key = resolve_media_key(server_id, media_id)
    path = resolve_file(storage_key)
    size = path.stat().st_size
    start, end, status_code = parse_range(request.headers.get("range"), size)
    length = end - start + 1
    content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(length),
        "Content-Disposition": "inline",
        "Cache-Control": "private, no-store",
        "X-Content-Type-Options": "nosniff",
    }
    if status_code == 206:
        headers["Content-Range"] = f"bytes {start}-{end}/{size}"

    if request.method == "HEAD":
        return StreamingResponse(iter(()), status_code=status_code, media_type=content_type, headers=headers)

    def chunks() -> Iterator[bytes]:
        with path.open("rb") as source:
            source.seek(start)
            remaining = length
            while remaining > 0:
                chunk = source.read(min(1024 * 1024, remaining))
                if not chunk:
                    break
                remaining -= len(chunk)
                yield chunk

    return StreamingResponse(chunks(), status_code=status_code, media_type=content_type, headers=headers)
