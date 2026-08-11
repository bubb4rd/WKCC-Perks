/**
 * APNs HTTP/2 sender for WKCC Perks push notifications.
 * Secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY, APNS_PRODUCTION
 */

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type PushPayload = {
  title: string;
  body: string;
  kind: string;
  relatedEntityId?: string | null;
};

function supabaseAdmin(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new Error("Supabase service role is not configured.");
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "\n")
    .replace(/\s+/g, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

let cachedJwt: { token: string; expiresAtMs: number } | null = null;

async function apnsProviderToken(): Promise<string | null> {
  const keyId = Deno.env.get("APNS_KEY_ID")?.trim() ?? "";
  const teamId = Deno.env.get("APNS_TEAM_ID")?.trim() ?? "";
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY")?.trim() ?? "";
  if (!keyId || !teamId || !privateKeyPem) {
    console.warn("APNs secrets not configured; skipping push.");
    return null;
  }

  const nowSec = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresAtMs > Date.now() + 60_000) {
    return cachedJwt.token;
  }

  const header = base64UrlEncode(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64UrlEncode(JSON.stringify({ iss: teamId, iat: nowSec }));
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );

  // WebCrypto returns IEEE P1363 (r||s); APNs expects that form for ES256 JWTs.
  const token = `${signingInput}.${base64UrlEncode(signature)}`;
  cachedJwt = { token, expiresAtMs: (nowSec + 3500) * 1000 };
  return token;
}

function apnsHost(): string {
  const production = (Deno.env.get("APNS_PRODUCTION") ?? "false")
    .trim()
    .toLowerCase();
  return production === "true" || production === "1"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

function bundleId(): string {
  return Deno.env.get("APNS_BUNDLE_ID")?.trim() ||
    "WKCC.Wilmette-Kenilworth-Perks";
}

async function sendToToken(
  deviceToken: string,
  payload: PushPayload,
  providerToken: string,
): Promise<"ok" | "gone" | "error"> {
  const body = {
    aps: {
      alert: {
        title: payload.title,
        body: payload.body,
      },
      sound: "default",
    },
    kind: payload.kind,
    relatedEntityId: payload.relatedEntityId ?? null,
  };

  try {
    const response = await fetch(
      `${apnsHost()}/3/device/${deviceToken}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${providerToken}`,
          "apns-topic": bundleId(),
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      },
    );

    if (response.ok) return "ok";

    const status = response.status;
    let reason = "";
    try {
      const json = await response.json() as { reason?: string };
      reason = json.reason ?? "";
    } catch {
      // ignore
    }
    console.error(`APNs push failed (${status}): ${reason || response.statusText}`);

    if (
      status === 410 ||
      reason === "BadDeviceToken" ||
      reason === "Unregistered" ||
      reason === "ExpiredToken"
    ) {
      return "gone";
    }
    return "error";
  } catch (error) {
    console.error("APNs request error:", error);
    return "error";
  }
}

async function deleteToken(token: string) {
  const supabase = supabaseAdmin();
  await supabase.from("device_push_tokens").delete().eq("token", token);
}

/** Send alert pushes to the given device tokens; prune invalid tokens. */
export async function sendPushToTokens(
  tokens: string[],
  payload: PushPayload,
): Promise<void> {
  const unique = [...new Set(tokens.filter((t) => t && t.length > 0))];
  if (unique.length === 0) return;

  const providerToken = await apnsProviderToken();
  if (!providerToken) return;

  const results = await Promise.allSettled(
    unique.map(async (token) => {
      const result = await sendToToken(token, payload, providerToken);
      if (result === "gone") await deleteToken(token);
    }),
  );
  for (const r of results) {
    if (r.status === "rejected") {
      console.error("Push send rejected:", r.reason);
    }
  }
}

export async function tokensForMemberIds(
  memberIds: string[],
): Promise<string[]> {
  if (memberIds.length === 0) return [];
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("device_push_tokens")
    .select("token")
    .in("member_id", memberIds);
  if (error) {
    console.error("tokensForMemberIds:", error.message);
    return [];
  }
  return (data ?? []).map((r) => String(r.token));
}

export async function allMemberTokensExcept(
  excludeMemberId?: string | null,
): Promise<string[]> {
  const supabase = supabaseAdmin();
  let query = supabase.from("device_push_tokens").select("token, member_id");
  if (excludeMemberId) {
    query = query.neq("member_id", excludeMemberId);
  }
  const { data, error } = await query;
  if (error) {
    console.error("allMemberTokensExcept:", error.message);
    return [];
  }
  return (data ?? []).map((r) => String(r.token));
}

export async function adminMemberIds(): Promise<string[]> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("app_profiles")
    .select("cm_id")
    .eq("is_chamber_admin", true)
    .not("cm_id", "is", null);
  if (error) {
    console.error("adminMemberIds:", error.message);
    return [];
  }
  return (data ?? [])
    .map((r) => r.cm_id)
    .filter((id): id is number => typeof id === "number" && Number.isFinite(id))
    .map((id) => String(id));
}

/** Fire-and-forget wrapper so push never blocks the API response path. */
export function emitPush(work: () => Promise<void>): void {
  work().catch((error) => {
    console.error("emitPush failed:", error);
  });
}

export async function notifyAdminsOfSubmission(params: {
  submissionId: string;
  submitterName: string;
  title: string;
}): Promise<void> {
  const adminIds = await adminMemberIds();
  const tokens = await tokensForMemberIds(adminIds);
  await sendPushToTokens(tokens, {
    title: "New promotion submission",
    body: `${params.submitterName} submitted “${params.title}”.`,
    kind: "newPromotionSubmission",
    relatedEntityId: params.submissionId,
  });
}

export async function notifySubmitterApproved(params: {
  submitterMemberId: string;
  title: string;
  submissionId: string;
}): Promise<void> {
  const tokens = await tokensForMemberIds([params.submitterMemberId]);
  await sendPushToTokens(tokens, {
    title: "Promotion approved",
    body: `“${params.title}” is now live for chamber members.`,
    kind: "promotionApproved",
    relatedEntityId: params.submissionId,
  });
}

export async function notifySubmitterRejected(params: {
  submitterMemberId: string;
  title: string;
  submissionId: string;
  notes?: string | null;
}): Promise<void> {
  const notes = params.notes?.trim();
  const body = notes && notes.length <= 120
    ? `“${params.title}” was not approved. ${notes}`
    : `“${params.title}” was not approved.`;
  const tokens = await tokensForMemberIds([params.submitterMemberId]);
  await sendPushToTokens(tokens, {
    title: "Promotion not approved",
    body,
    kind: "promotionRejected",
    relatedEntityId: params.submissionId,
  });
}

export async function notifyMembersNewPromotion(params: {
  title: string;
  businessName: string;
  dealId: string;
  excludeMemberId?: string | null;
}): Promise<void> {
  const tokens = await allMemberTokensExcept(params.excludeMemberId);
  await sendPushToTokens(tokens, {
    title: "New promotion",
    body: `${params.businessName}: ${params.title}`,
    kind: "newPromotion",
    relatedEntityId: params.dealId,
  });
}
