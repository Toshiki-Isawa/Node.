import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type UserPlan = "seed" | "archive" | "conservatory";

export const PLAN_STORAGE_LIMIT_BYTES: Record<UserPlan, number> = {
  seed: 3 * 1024 * 1024 * 1024,
  archive: 50 * 1024 * 1024 * 1024,
  conservatory: 500 * 1024 * 1024 * 1024,
};

const VALID_PLANS = new Set<UserPlan>(["seed", "archive", "conservatory"]);

export function normalizePlan(raw: string | null | undefined): UserPlan {
  if (!raw || !VALID_PLANS.has(raw as UserPlan)) return "seed";
  return raw as UserPlan;
}

export async function getUserPlan(
  supabase: SupabaseClient,
  userId: string,
): Promise<UserPlan> {
  const { data, error } = await supabase.rpc("get_user_plan", {
    p_user_id: userId,
  });

  if (error) {
    console.error("getUserPlan failed:", error);
    return "seed";
  }

  return normalizePlan(data as string);
}

export async function getStorageUsageBytes(
  supabase: SupabaseClient,
  userId: string,
): Promise<number> {
  const { data, error } = await supabase.rpc("get_storage_usage_bytes", {
    p_user_id: userId,
  });

  if (error) {
    console.error("getStorageUsageBytes failed:", error);
    return 0;
  }

  return Number(data ?? 0);
}

export function getStorageLimitBytes(plan: UserPlan): number {
  return PLAN_STORAGE_LIMIT_BYTES[plan];
}

export function wouldExceedPlanLimit(
  plan: UserPlan,
  usedBytes: number,
  incomingBytes: number,
): boolean {
  return usedBytes + incomingBytes > getStorageLimitBytes(plan);
}

export async function registerStorageObject(
  supabase: SupabaseClient,
  params: {
    userId: string;
    observationId: string;
    objectKey: string;
    byteSize: number;
    contentType: string;
  },
): Promise<void> {
  const { error } = await supabase.from("storage_objects").upsert(
    {
      user_id: params.userId,
      observation_id: params.observationId,
      object_key: params.objectKey,
      byte_size: params.byteSize,
      content_type: params.contentType,
    },
    { onConflict: "object_key" },
  );

  if (error) {
    throw error;
  }
}
