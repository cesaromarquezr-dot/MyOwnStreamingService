import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Supabase verifies the caller JWT before this function when verify_jwt is enabled.
  const { text, source = "auto", target } = await req.json();
  if (typeof text !== "string" || !text.trim() || text.length > 12000 ||
      typeof target !== "string" || !/^[a-z]{2}(-[A-Z]{2})?$/.test(target)) {
    return new Response(JSON.stringify({ error: "Invalid translation request" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Configure TRANSLATE_API_URL and TRANSLATE_API_KEY as Supabase function secrets.
  // Use a self-hosted LibreTranslate instance on your TrueNAS or a trusted provider.
  const endpoint = Deno.env.get("TRANSLATE_API_URL");
  if (!endpoint) {
    return new Response(JSON.stringify({ error: "Translation provider is not configured" }), {
      status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const providerResponse = await fetch(`${endpoint.replace(/\/$/, "")}/translate`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(Deno.env.get("TRANSLATE_API_KEY")
        ? { "X-API-Key": Deno.env.get("TRANSLATE_API_KEY")! }
        : {}),
    },
    body: JSON.stringify({ q: text, source, target: target.split("-")[0], format: "text" }),
  });
  if (!providerResponse.ok) {
    return new Response(JSON.stringify({ error: "Translation provider failed" }), {
      status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const result = await providerResponse.json();
  if (typeof result.translatedText !== "string") {
    return new Response(JSON.stringify({ error: "Invalid provider response" }), {
      status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  return new Response(JSON.stringify({ translatedText: result.translatedText }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
