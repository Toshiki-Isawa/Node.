import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface TimelapseRequest {
  plant_id?: string;
  observation_ids?: string[];
  job_id?: string;
}

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
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: TimelapseRequest = await req.json();

    if (body.job_id) {
      const { data, error } = await supabase
        .from("timelapse_jobs")
        .select("*")
        .eq("id", body.job_id)
        .eq("user_id", user.id)
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({
          id: data.id,
          status: data.status,
          outputURL: data.output_url,
          error: data.error,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const plantId = body.plant_id;
    const observationIds = (body.observation_ids ?? []).slice(0, 60);

    if (!plantId || observationIds.length < 2) {
      return new Response(JSON.stringify({ error: "At least 2 observations required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: job, error: insertError } = await supabase
      .from("timelapse_jobs")
      .insert({
        user_id: user.id,
        plant_id: plantId,
        observation_ids: observationIds,
        status: "processing",
      })
      .select()
      .single();

    if (insertError) throw insertError;

    // FFmpeg generation runs in a background worker in production.
    // Closed Beta stub: mark completed with placeholder output after processing flag.
    const outputURL = Deno.env.get("TIMELAPSE_STUB_URL") ?? null;

    await supabase
      .from("timelapse_jobs")
      .update({
        status: outputURL ? "completed" : "processing",
        output_url: outputURL,
        updated_at: new Date().toISOString(),
      })
      .eq("id", job.id);

    return new Response(
      JSON.stringify({ jobId: job.id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
