import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { loadR2Config, presignGetObject } from "../_shared/r2.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const DEFAULT_EXPIRES_IN = 3600;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const observationId = body.observation_id as string;

    if (!observationId || !UUID_RE.test(observationId)) {
      return new Response(JSON.stringify({ error: "Invalid observation_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: observation, error: observationError } = await supabase
      .from("observations")
      .select("id, image_url")
      .eq("id", observationId)
      .maybeSingle();

    if (observationError || !observation) {
      return new Response(JSON.stringify({ error: "Observation not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const objectKey = observation.image_url as string | null;
    if (!objectKey) {
      return new Response(JSON.stringify({ error: "Image not available" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: storageObject, error: storageError } = await supabase
      .from("storage_objects")
      .select("object_key")
      .eq("observation_id", observationId)
      .eq("user_id", user.id)
      .eq("object_key", objectKey)
      .maybeSingle();

    if (storageError || !storageObject) {
      return new Response(JSON.stringify({ error: "Storage object not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const r2Config = loadR2Config();
    if (!r2Config) {
      return new Response(
        JSON.stringify({ error: "R2 is not configured on the server" }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const downloadURL = await presignGetObject(r2Config, objectKey, DEFAULT_EXPIRES_IN);

    return new Response(
      JSON.stringify({
        downloadURL,
        objectKey,
        expiresIn: DEFAULT_EXPIRES_IN,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("r2-presign-download failed:", error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
