import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getUserPlan, normalizePlan } from "../_shared/storage.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUBSCRIPTION_PRODUCT_IDS = new Set([
  "app.node.archive.monthly",
  "app.node.conservatory.monthly",
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
    const productId = body.product_id as string;
    const transactionId = body.transaction_id as string;
    const originalTransactionId = body.original_transaction_id as string;
    const expiresAt = body.expires_at as string | null | undefined;
    const environment = (body.environment as string) ?? "production";

    if (!productId || !SUBSCRIPTION_PRODUCT_IDS.has(productId)) {
      return new Response(JSON.stringify({ error: "Invalid product_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!transactionId || !originalTransactionId) {
      return new Response(JSON.stringify({ error: "Missing transaction fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const serviceSupabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const parsedExpiresAt = expiresAt ? new Date(expiresAt) : null;
    const isActive = !parsedExpiresAt || parsedExpiresAt.getTime() > Date.now();

    const { error: entitlementError } = await serviceSupabase
      .from("subscription_entitlements")
      .upsert(
        {
          user_id: user.id,
          product_id: productId,
          transaction_id: transactionId,
          original_transaction_id: originalTransactionId,
          expires_at: parsedExpiresAt?.toISOString() ?? null,
          environment,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "transaction_id" },
      );

    if (entitlementError) {
      throw entitlementError;
    }

    const resolvedPlan = isActive
      ? await getUserPlan(serviceSupabase, user.id)
      : "seed";

    const { error: profileError } = await serviceSupabase
      .from("user_profiles")
      .upsert(
        {
          user_id: user.id,
          plan: resolvedPlan,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );

    if (profileError) {
      throw profileError;
    }

    return new Response(
      JSON.stringify({ plan: resolvedPlan, active: isActive }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("sync-premium failed:", error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
