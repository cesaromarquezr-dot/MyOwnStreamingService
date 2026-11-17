import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const openAiKey = Deno.env.get("OPENAI_API_KEY");
    const authorization = req.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !openAiKey) {
      return json({ error: "Voice search provider is not configured" }, 503);
    }
    if (!authorization.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { "apikey": anonKey, "Authorization": authorization },
    });
    if (!userResponse.ok) return json({ error: "Invalid session" }, 401);

    const body = await req.json();
    const encoded = typeof body?.audioBase64 === "string" ? body.audioBase64 : "";
    const mimeType = typeof body?.mimeType === "string" ? body.mimeType : "audio/mp4";
    if (!encoded || encoded.length > 7_000_000 || !/^audio\//.test(mimeType)) {
      return json({ error: "Invalid audio sample" }, 400);
    }
    const bytes = Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0));
    if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) {
      return json({ error: "Audio sample exceeds the 5 MB limit" }, 400);
    }

    const extension = mimeType.includes("webm") ? "webm" : mimeType.includes("wav") ? "wav" : "m4a";
    const form = new FormData();
    form.append("file", new File([bytes], `voice-search.${extension}`, { type: mimeType }));
    form.append("model", "whisper-1");
    form.append("response_format", "json");
    const result = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${openAiKey}` },
      body: form,
    });
    if (!result.ok) return json({ error: "Speech transcription provider failed" }, 502);
    const payload = await result.json();
    const text = typeof payload?.text === "string" ? payload.text.trim() : "";
    if (!text) return json({ error: "No speech was recognized" }, 422);
    return json({ text });
  } catch (_error) {
    // Avoid disclosing provider responses, tokens, or secrets to clients.
    return json({ error: "Voice search request failed" }, 502);
  }
});
