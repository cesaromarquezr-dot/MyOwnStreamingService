import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-search-index-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

async function createEmbedding(text: string): Promise<number[]> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) throw new Error("Embedding provider is not configured");
  const response = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "text-embedding-3-small", input: text, dimensions: 384 }),
  });
  if (!response.ok) throw new Error("Embedding provider request failed");
  const payload = await response.json();
  const vector = payload?.data?.[0]?.embedding;
  if (!Array.isArray(vector) || vector.length !== 384) {
    throw new Error("Embedding provider returned an unexpected vector size");
  }
  return vector;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await req.json();
    const action = body?.action ?? "query";
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey) return json({ error: "Supabase is not configured" }, 503);

    if (action === "query") {
      const authorization = req.headers.get("Authorization") ?? "";
      if (!authorization.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);
      const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: { "apikey": anonKey, "Authorization": authorization },
      });
      if (!userResponse.ok) return json({ error: "Invalid session" }, 401);
      const text = typeof body?.text === "string" ? body.text.trim() : "";
      if (!text || text.length > 500) return json({ error: "Invalid search text" }, 400);
      return json({
        embedding: await createEmbedding(text),
        model: "text-embedding-3-small:384",
      });
    }

    if (action === "index") {
      const expected = Deno.env.get("SEARCH_INDEX_SECRET");
      const supplied = req.headers.get("x-search-index-secret");
      if (!expected || !supplied || supplied !== expected || !serviceRoleKey) {
        return json({ error: "Catalog indexing is not authorized" }, 403);
      }
      const id = typeof body?.id === "string" ? body.id.trim() : "";
      if (!id || id.length > 512) return json({ error: "A catalog id is required" }, 400);
      const lookup = await fetch(
        `${supabaseUrl}/rest/v1/external_media_catalog?id=eq.${encodeURIComponent(id)}&select=id,title,original_title,description,genres,themes,moods,tags,subtitle_languages,audio_languages`,
        { headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}` } },
      );
      if (!lookup.ok) return json({ error: "Unable to load catalog metadata" }, 502);
      const rows = await lookup.json();
      if (!Array.isArray(rows) || rows.length === 0) return json({ error: "Catalog item not found" }, 404);
      const row = rows[0];
      const text = [
        row.title, row.original_title, row.description,
        ...(row.genres ?? []), ...(row.themes ?? []), ...(row.moods ?? []),
        ...(row.tags ?? []), ...(row.subtitle_languages ?? []), ...(row.audio_languages ?? []),
      ].filter((value) => typeof value === "string" && value.trim()).join(" | ").slice(0, 12000);
      const embedding = await createEmbedding(text);
      const update = await fetch(
        `${supabaseUrl}/rest/v1/external_media_catalog?id=eq.${encodeURIComponent(id)}`,
        {
          method: "PATCH",
          headers: {
            "apikey": serviceRoleKey,
            "Authorization": `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
          },
          body: JSON.stringify({
            embedding: `[${embedding.join(",")}]`,
            embedding_model: "text-embedding-3-small:384",
            embedding_updated_at: new Date().toISOString(),
          }),
        },
      );
      if (!update.ok) return json({ error: "Unable to update catalog embedding" }, 502);
      await fetch(`${supabaseUrl}/rest/v1/media_search_embedding_queue?catalog_id=eq.${encodeURIComponent(id)}`, {
        method: "DELETE",
        headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}` },
      });
      return json({ id, indexed: true, model: "text-embedding-3-small:384" });
    }

    if (action === "index_next") {
      const expected = Deno.env.get("SEARCH_INDEX_SECRET");
      const supplied = req.headers.get("x-search-index-secret");
      if (!expected || !supplied || supplied !== expected || !serviceRoleKey) {
        return json({ error: "Catalog indexing is not authorized" }, 403);
      }
      const batchSize = Math.max(1, Math.min(Number(body?.limit ?? 10) || 10, 25));
      const dueBefore = encodeURIComponent(new Date().toISOString());
      const queueResponse = await fetch(
        `${supabaseUrl}/rest/v1/media_search_embedding_queue?select=catalog_id,attempts&queued_at=lte.${dueBefore}&attempts=lt.10&order=queued_at.asc&limit=${batchSize}`,
        { headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}` } },
      );
      if (!queueResponse.ok) return json({ error: "Unable to load embedding queue" }, 502);
      const queued = await queueResponse.json();
      if (!Array.isArray(queued) || queued.length === 0) return json({ indexed: 0, remaining: 0 });

      let indexed = 0;
      let failed = 0;
      for (const entry of queued) {
        const id = typeof entry?.catalog_id === "string" ? entry.catalog_id : "";
        if (!id) continue;
        try {
          const lookup = await fetch(
            `${supabaseUrl}/rest/v1/external_media_catalog?id=eq.${encodeURIComponent(id)}&select=id,title,original_title,description,genres,themes,moods,tags,subtitle_languages,audio_languages`,
            { headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}` } },
          );
          if (!lookup.ok) throw new Error("Unable to read catalog row");
          const rows = await lookup.json();
          if (!Array.isArray(rows) || rows.length === 0) {
            await fetch(`${supabaseUrl}/rest/v1/media_search_embedding_queue?catalog_id=eq.${encodeURIComponent(id)}`, {
              method: "DELETE", headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}` },
            });
            continue;
          }
          const row = rows[0];
          const document = [row.title, row.original_title, row.description,
            ...(row.genres ?? []), ...(row.themes ?? []), ...(row.moods ?? []),
            ...(row.tags ?? []), ...(row.subtitle_languages ?? []),
            ...(row.audio_languages ?? [])]
            .filter((value) => typeof value === "string" && value.trim())
            .join(" | ").slice(0, 12000);
          const embedding = await createEmbedding(document);
          const update = await fetch(
            `${supabaseUrl}/rest/v1/external_media_catalog?id=eq.${encodeURIComponent(id)}`,
            {
              method: "PATCH",
              headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}`, "Content-Type": "application/json", "Prefer": "return=minimal" },
              body: JSON.stringify({ embedding: `[${embedding.join(",")}]`, embedding_model: "text-embedding-3-small:384", embedding_updated_at: new Date().toISOString() }),
            },
          );
          if (!update.ok) throw new Error("Unable to update catalog embedding");
          await fetch(`${supabaseUrl}/rest/v1/media_search_embedding_queue?catalog_id=eq.${encodeURIComponent(id)}`, {
            method: "DELETE", headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}` },
          });
          indexed++;
        } catch (_error) {
          failed++;
          await fetch(`${supabaseUrl}/rest/v1/media_search_embedding_queue?catalog_id=eq.${encodeURIComponent(id)}`, {
            method: "PATCH",
            headers: { "apikey": serviceRoleKey, "Authorization": `Bearer ${serviceRoleKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({
              attempts: Number(entry.attempts ?? 0) + 1,
              queued_at: new Date(Date.now() + Math.min(
                60 * 60 * 1000,
                30_000 * (2 ** Math.min(Number(entry.attempts ?? 0), 7)),
              )).toISOString(),
              last_error: "embedding refresh failed",
            }),
          });
        }
      }
      return json({ indexed, failed, processed: queued.length });
    }

    return json({ error: "Unsupported action" }, 400);
  } catch (_error) {
    // Do not return provider exception details, authorization values, or secrets.
    return json({ error: "Hybrid search embedding request failed" }, 502);
  }
});
