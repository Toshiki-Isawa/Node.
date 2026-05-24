import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
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

    const accountId = Deno.env.get("R2_ACCOUNT_ID") ?? "";
    const bucket = Deno.env.get("R2_BUCKET") ?? "node-observations";
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") ?? "";
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "";
    const publicBase = Deno.env.get("R2_PUBLIC_BASE_URL") ?? "";

    const objectKey = `observations/${user.id}/${observationId}.jpg`;

    // Placeholder presigned URL generation — replace with AWS SigV4 for R2 in production.
    const uploadURL = publicBase
      ? `${publicBase.replace(/\/$/, "")}/${objectKey}?presign=placeholder`
      : `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${objectKey}`;

    if (!accountId || !accessKeyId || !secretAccessKey) {
      console.warn("R2 credentials not configured — returning stub presign response");
    }

    return new Response(
      JSON.stringify({ uploadURL, objectKey }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
