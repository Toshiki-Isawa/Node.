import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { loadR2Config, presignPutObject, publicObjectUrl } from "../_shared/r2.ts";
import {
  getStorageLimitBytes,
  getStorageUsageBytes,
  getUserPlan,
  wouldExceedPlanLimit,
} from "../_shared/storage.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const ALLOWED_CONTENT_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

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
    const contentType = (body.content_type as string) ?? "image/jpeg";
    const byteSize = Number(body.byte_size ?? 0);

    if (!observationId || !UUID_RE.test(observationId)) {
      return new Response(JSON.stringify({ error: "Invalid observation_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
      return new Response(JSON.stringify({ error: "Unsupported content_type" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!Number.isFinite(byteSize) || byteSize <= 0) {
      return new Response(JSON.stringify({ error: "Invalid byte_size" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const serviceSupabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const plan = await getUserPlan(serviceSupabase, user.id);
    const usedBytes = await getStorageUsageBytes(serviceSupabase, user.id);

    if (wouldExceedPlanLimit(plan, usedBytes, byteSize)) {
      return new Response(
        JSON.stringify({
          error: "storage_limit_exceeded",
          used_bytes: usedBytes,
          limit_bytes: getStorageLimitBytes(plan),
          plan,
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
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

    const extension = contentType === "image/png"
      ? "png"
      : contentType.includes("heic") || contentType.includes("heif")
      ? "heic"
      : "jpg";
    const objectKey = `observations/${user.id}/${observationId}.${extension}`;
    const uploadURL = await presignPutObject(r2Config, objectKey, contentType);
    const publicURL = publicObjectUrl(r2Config, objectKey);

    return new Response(
      JSON.stringify({
        uploadURL,
        objectKey,
        ...(publicURL ? { publicURL } : {}),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("r2-presign-upload failed:", error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
