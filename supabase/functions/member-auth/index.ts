import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { normalizeCategory } from "../_shared/categories.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ACTIVE_STATUS = "2";
const CODE_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const REQUEST_CODE_WINDOW_MINUTES = 15;
const REQUEST_CODE_MAX_PER_WINDOW = 5;
const ACCESS_TOKEN_TTL_SECONDS = 60 * 60; // 1 hour
const REFRESH_TOKEN_TTL_DAYS = 30;

type ChamberMemberRow = {
  cm_id: number;
  name: string;
  display_name: string;
  email: string | null;
  status: string;
  level: string | null;
  membership_type?: string | null;
  membership_established: string | null;
  drop_date: string | null;
  slug: string | null;
  display_flags: string;
  logo_url: string | null;
  category?: string | null;
  short_description?: string | null;
  website_url?: string | null;
  phone?: string | null;
  address?: string | null;
  address_public?: boolean | null;
  companymate_key?: string | null;
  raw?: Record<string, unknown> | null;
};

const MEMBER_COLUMNS =
  "cm_id, name, display_name, email, status, level, membership_type, membership_established, drop_date, slug, display_flags, logo_url";

const PROFILE_COLUMNS =
  "category, short_description, website_url, phone, address, address_public";

/** Includes `raw` for lat/long when listing business directory entries. */
const BUSINESS_COLUMNS = `${MEMBER_COLUMNS}, ${PROFILE_COLUMNS}, raw`;

const MAX_LOGO_BYTES = 2 * 1024 * 1024;
const ALLOWED_LOGO_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const MAX_SHORT_DESCRIPTION = 280;
const MAX_ADDRESS = 200;
const MAX_PHONE = 40;
const MAX_WEBSITE = 300;
const RATE_LIMIT_LOGO_MAX = 10;
const RATE_LIMIT_LOGO_WINDOW_MIN = 60;

type AppProfileRow = {
  email: string;
  cm_id: number | null;
  is_chamber_admin: boolean;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function isEligible(member: ChamberMemberRow): boolean {
  if (!member.email) return false;
  if (member.status !== ACTIVE_STATUS) return false;
  if ((member.display_flags ?? "").includes("DisableLogin")) return false;
  return true;
}

function supabaseAdmin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new Error("Supabase service role is not configured.");
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function randomDigits(length: number): string {
  let out = "";
  while (out.length < length) {
    const bytes = crypto.getRandomValues(new Uint8Array(length * 2));
    for (const b of bytes) {
      // Reject values >= 250 to avoid modulo bias (250 = 25 * 10).
      if (b >= 250) continue;
      out += (b % 10).toString();
      if (out.length >= length) break;
    }
  }
  return out;
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function base64UrlEncode(data: ArrayBuffer | Uint8Array | string): string {
  const bytes =
    typeof data === "string"
      ? new TextEncoder().encode(data)
      : data instanceof Uint8Array
      ? data
      : new Uint8Array(data);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlDecode(input: string): Uint8Array {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  const binary = atob(padded + pad);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

async function signAccessToken(payload: Record<string, unknown>): Promise<string> {
  const secret = Deno.env.get("AUTH_JWT_SECRET") ?? "";
  if (!secret) throw new Error("AUTH_JWT_SECRET is not configured.");

  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const data = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(data),
  );
  return `${data}.${base64UrlEncode(signature)}`;
}

async function verifyAccessToken(
  token: string,
): Promise<Record<string, unknown> | null> {
  const secret = Deno.env.get("AUTH_JWT_SECRET") ?? "";
  if (!secret) return null;

  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [encodedHeader, encodedPayload, encodedSig] = parts;
  const data = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    base64UrlDecode(encodedSig),
    new TextEncoder().encode(data),
  );
  if (!valid) return null;

  try {
    const payload = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(encodedPayload)),
    ) as Record<string, unknown>;
    const exp = typeof payload.exp === "number" ? payload.exp : 0;
    if (exp * 1000 < Date.now()) return null;
    return payload;
  } catch {
    return null;
  }
}

function deriveNames(member: ChamberMemberRow): { firstName: string; lastName: string } {
  const display = (member.display_name || member.name || "").trim();
  if (display.includes(" ")) {
    const parts = display.split(/\s+/);
    return { firstName: parts[0], lastName: parts.slice(1).join(" ") };
  }
  if (member.email?.includes("@")) {
    const local = member.email.split("@")[0] ?? "Member";
    const cleaned = local.replace(/[._-]+/g, " ").trim();
    const parts = cleaned.split(/\s+/).filter(Boolean);
    if (parts.length >= 2) {
      return { firstName: capitalize(parts[0]), lastName: capitalize(parts.slice(1).join(" ")) };
    }
    return { firstName: capitalize(parts[0] || "Member"), lastName: display || "Member" };
  }
  return { firstName: display || "Member", lastName: "" };
}

function capitalize(value: string): string {
  if (!value) return value;
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function mapMembershipTier(raw: string | null | undefined): string {
  const value = (raw ?? "").trim();
  if (!value) return "Basic";
  const lower = value.toLowerCase();
  if (lower === "not-for-profit" || lower === "nonprofit" || lower === "non-profit") {
    return "Non-Profit";
  }
  const allowed = new Set([
    "Basic",
    "Silver",
    "Gold",
    "Platinum",
    "Municipality",
    "Chamber of Commerce",
    "Non-Profit",
  ]);
  return allowed.has(value) ? value : "Basic";
}

async function memberHasPassword(email: string): Promise<boolean> {
  if (!email) return false;
  const supabase = supabaseAdmin();
  const { count, error } = await supabase
    .from("login_passwords")
    .select("email", { count: "exact", head: true })
    .eq("email", normalizeEmail(email));
  if (error) throw error;
  return (count ?? 0) > 0;
}

async function mapMember(
  member: ChamberMemberRow,
  profile: AppProfileRow | null,
) {
  const { firstName, lastName } = deriveNames(member);
  const isActive = member.status === ACTIVE_STATUS;
  const isAdmin = profile?.is_chamber_admin === true;
  const hasPassword = await memberHasPassword(member.email ?? "");

  return {
    id: String(member.cm_id),
    firstName,
    lastName,
    email: member.email ?? "",
    phone: null,
    address: null,
    membershipTier: mapMembershipTier(member.membership_type),
    membershipStatus: isActive ? "active" : "inactive",
    companyId: String(member.cm_id),
    companyName: member.name,
    companyLogoURL: member.logo_url ?? null,
    memberSince: member.membership_established,
    hasPassword,
    entitlements: isActive
      ? {
        canViewDeals: true,
        canSaveDeals: true,
        canRedeemDeals: true,
        isChamberAdmin: isAdmin,
      }
      : {
        canViewDeals: false,
        canSaveDeals: false,
        canRedeemDeals: false,
        isChamberAdmin: false,
      },
  };
}

function mapDealSummary(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    title: row.title,
    businessId: row.business_id,
    businessName: row.business_name,
    shortDescription: row.short_description ?? "",
    category: row.category,
    expirationDate: row.end_date ?? null,
    isFeatured: Boolean(row.is_featured),
    membersOnly: Boolean(row.members_only),
  };
}

function parseCoordinate(
  raw: Record<string, unknown> | null | undefined,
  key: string,
): number | null {
  if (!raw) return null;
  const value = raw[key];
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function mapBusiness(
  member: ChamberMemberRow,
  activeDeals: ReturnType<typeof mapDealSummary>[] = [],
  options: { includePrivateAddress?: boolean } = {},
) {
  const raw = member.raw ?? null;
  const category = normalizeCategory(member.category) ?? "Other";
  const shortDescription =
    typeof member.short_description === "string" ? member.short_description : "";
  const websiteURL =
    typeof member.website_url === "string" && member.website_url.trim()
      ? member.website_url.trim()
      : null;
  const phone =
    typeof member.phone === "string" && member.phone.trim()
      ? member.phone.trim()
      : null;
  const storedAddress =
    typeof member.address === "string" && member.address.trim()
      ? member.address.trim()
      : null;
  const addressPublic = member.address_public !== false;
  const address = (options.includePrivateAddress || addressPublic)
    ? storedAddress
    : null;

  return {
    id: String(member.cm_id),
    name: member.display_name || member.name,
    category,
    shortDescription,
    fullDescription: null,
    logoURL: member.logo_url ?? null,
    websiteURL,
    phone,
    address,
    addressPublic,
    email: member.email ?? null,
    latitude: parseCoordinate(raw, "Latitude"),
    longitude: parseCoordinate(raw, "Longitude"),
    memberSince: member.membership_established,
    isChamberPartner: true,
    activeDeals,
    redemptionNotes: null,
  };
}

function normalizeOptionalText(value: unknown, maxLen: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLen);
}

function normalizeWebsite(value: unknown): string | null {
  const trimmed = normalizeOptionalText(value, MAX_WEBSITE);
  if (!trimmed) return null;
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `https://${trimmed}`;
}

function decodeBase64Payload(input: string): Uint8Array {
  const trimmed = input.replace(/^data:[^;]+;base64,/, "").replace(/\s/g, "");
  const binary = atob(trimmed);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function logoExtension(contentType: string): string {
  switch (contentType) {
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    default:
      return "jpg";
  }
}

function sniffImageContentType(bytes: Uint8Array): string | null {
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return "image/jpeg";
  }
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return "image/png";
  }
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return "image/webp";
  }
  return null;
}

async function assertRateLimit(
  bucket: string,
  subject: string,
  max: number,
  windowMinutes: number,
): Promise<void> {
  const supabase = supabaseAdmin();
  const since = new Date(Date.now() - windowMinutes * 60_000).toISOString();
  const { count, error } = await supabase
    .from("edge_rate_limits")
    .select("*", { count: "exact", head: true })
    .eq("bucket", bucket)
    .eq("subject", subject)
    .gte("created_at", since);
  if (error) throw error;
  if ((count ?? 0) >= max) {
    throw Object.assign(
      new Error("Too many requests. Please try again later."),
      { status: 429 },
    );
  }
  const { error: insertError } = await supabase.from("edge_rate_limits").insert({
    bucket,
    subject,
  });
  if (insertError) throw insertError;
}

async function requireSessionMember(req: Request): Promise<{
  email: string;
  member: ChamberMemberRow;
  profile: AppProfileRow | null;
}> {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) {
    throw Object.assign(new Error("Missing bearer token."), { status: 401 });
  }

  const payload = await verifyAccessToken(token);
  if (!payload || payload.typ !== "access" || typeof payload.email !== "string") {
    throw Object.assign(new Error("Session expired."), { status: 401 });
  }

  const email = normalizeEmail(payload.email);
  const member = await findEligibleMember(email);
  if (!member) {
    throw Object.assign(new Error("Your membership is not currently active."), {
      status: 403,
    });
  }

  const profile = await getProfile(email);
  return { email, member, profile };
}

async function findEligibleMember(email: string): Promise<ChamberMemberRow | null> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("chamber_members")
    .select(MEMBER_COLUMNS)
    .eq("email", email)
    .eq("status", ACTIVE_STATUS)
    .order("cm_id", { ascending: true });

  if (error) throw error;
  const rows = (data ?? []) as ChamberMemberRow[];
  const eligible = rows.filter(isEligible);
  return eligible[0] ?? null;
}

async function getProfile(email: string): Promise<AppProfileRow | null> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("app_profiles")
    .select("email, cm_id, is_chamber_admin")
    .eq("email", email)
    .maybeSingle();
  if (error) throw error;
  return (data as AppProfileRow | null) ?? null;
}

async function upsertProfile(email: string, cmId: number): Promise<AppProfileRow> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("app_profiles")
    .upsert(
      {
        email,
        cm_id: cmId,
        last_login_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "email" },
    )
    .select("email, cm_id, is_chamber_admin")
    .single();
  if (error) throw error;
  return data as AppProfileRow;
}

async function sendLoginEmail(email: string, code: string): Promise<void> {
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("AUTH_EMAIL_FROM") ?? "WKCC Perks <onboarding@resend.dev>";

  if (!resendKey) {
    console.log(`[member-auth] OTP for ${email}: ${code}`);
    return;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: "Your WKCC Perks sign-in code",
      text:
        `Your Wilmette/Kenilworth Chamber Perks sign-in code is ${code}.\n\n` +
        `This code expires in ${CODE_TTL_MINUTES} minutes. If you did not request it, you can ignore this email.`,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to send email: ${body}`);
  }
}

async function issueSession(member: ChamberMemberRow, profile: AppProfileRow) {
  const email = normalizeEmail(member.email ?? "");
  const now = Math.floor(Date.now() / 1000);
  const accessToken = await signAccessToken({
    sub: String(member.cm_id),
    email,
    cm_id: member.cm_id,
    typ: "access",
    iat: now,
    exp: now + ACCESS_TOKEN_TTL_SECONDS,
  });

  const refreshToken = randomToken();
  const refreshHash = await sha256Hex(refreshToken);
  const expiresAt = new Date(
    Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();

  const supabase = supabaseAdmin();
  const { error } = await supabase.from("app_sessions").insert({
    email,
    cm_id: member.cm_id,
    refresh_token_hash: refreshHash,
    expires_at: expiresAt,
  });
  if (error) throw error;

  return {
    accessToken,
    refreshToken,
    expiresAt: new Date((now + ACCESS_TOKEN_TTL_SECONDS) * 1000).toISOString(),
    member: await mapMember(member, profile),
  };
}

async function handleRequestCode(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null) as { email?: string } | null;
  const email = typeof body?.email === "string" ? normalizeEmail(body.email) : "";

  // Always return generic success to avoid email enumeration.
  const generic = {
    ok: true,
    message: "If that email is eligible, a sign-in code has been sent.",
  };

  if (!email || !email.includes("@")) {
    return jsonResponse(generic);
  }

  const member = await findEligibleMember(email);
  if (!member) {
    return jsonResponse(generic);
  }

  const supabase = supabaseAdmin();
  const windowStart = new Date(
    Date.now() - REQUEST_CODE_WINDOW_MINUTES * 60 * 1000,
  ).toISOString();
  const { count, error: countError } = await supabase
    .from("login_codes")
    .select("id", { count: "exact", head: true })
    .eq("email", email)
    .gte("created_at", windowStart);
  if (countError) throw countError;
  if ((count ?? 0) >= REQUEST_CODE_MAX_PER_WINDOW) {
    console.warn(
      `[member-auth] request-code rate limited for ${email}: ${count} in ${REQUEST_CODE_WINDOW_MINUTES}m`,
    );
    return jsonResponse(generic);
  }

  const code = randomDigits(6);
  const codeHash = await sha256Hex(`${email}:${code}`);
  const expiresAt = new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000)
    .toISOString();

  // Invalidate prior unused codes for this email.
  await supabase
    .from("login_codes")
    .update({ consumed_at: new Date().toISOString() })
    .eq("email", email)
    .is("consumed_at", null);

  const { error } = await supabase.from("login_codes").insert({
    email,
    code_hash: codeHash,
    expires_at: expiresAt,
  });
  if (error) throw error;

  await sendLoginEmail(email, code);

  const debug = Deno.env.get("AUTH_DEBUG_RETURN_CODE") === "true";
  return jsonResponse(debug ? { ...generic, debugCode: code } : generic);
}

async function handleVerifyCode(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null) as {
    email?: string;
    code?: string;
  } | null;
  const email = typeof body?.email === "string" ? normalizeEmail(body.email) : "";
  const code = typeof body?.code === "string" ? body.code.trim() : "";

  if (!email || !code) {
    return jsonResponse({ error: "email and code are required." }, 400);
  }

  const supabase = supabaseAdmin();
  const { data: codeRows, error: codeError } = await supabase
    .from("login_codes")
    .select("id, email, code_hash, expires_at, attempts, consumed_at")
    .eq("email", email)
    .is("consumed_at", null)
    .order("created_at", { ascending: false })
    .limit(1);

  if (codeError) throw codeError;
  const row = codeRows?.[0];
  if (!row) {
    return jsonResponse({ error: "Invalid or expired code." }, 401);
  }

  if (row.attempts >= MAX_ATTEMPTS) {
    return jsonResponse({ error: "Too many attempts. Request a new code." }, 429);
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    return jsonResponse({ error: "Invalid or expired code." }, 401);
  }

  const expectedHash = await sha256Hex(`${email}:${code}`);
  if (expectedHash !== row.code_hash) {
    await supabase
      .from("login_codes")
      .update({ attempts: row.attempts + 1 })
      .eq("id", row.id);
    return jsonResponse({ error: "Invalid or expired code." }, 401);
  }

  const member = await findEligibleMember(email);
  if (!member) {
    return jsonResponse({ error: "Your membership is not currently active." }, 403);
  }

  await supabase
    .from("login_codes")
    .update({ consumed_at: new Date().toISOString() })
    .eq("id", row.id);

  const existingProfile = await getProfile(email);
  const isFirstLink = existingProfile == null;
  const profile = await upsertProfile(email, member.cm_id);
  const session = await issueSession(member, profile);
  return jsonResponse({ ...session, isFirstLink });
}

async function handleSignInPassword(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null) as {
    email?: string;
    password?: string;
  } | null;
  const email = typeof body?.email === "string" ? normalizeEmail(body.email) : "";
  const password = typeof body?.password === "string" ? body.password : "";

  if (!email || !password) {
    return jsonResponse({ error: "email and password are required." }, 400);
  }

  const supabase = supabaseAdmin();
  const windowStart = new Date(Date.now() - REQUEST_CODE_WINDOW_MINUTES * 60 * 1000)
    .toISOString();
  const { count, error: countError } = await supabase
    .from("edge_rate_limits")
    .select("*", { count: "exact", head: true })
    .eq("bucket", "password-sign-in")
    .eq("subject", email)
    .gte("created_at", windowStart);
  if (countError) throw countError;
  if ((count ?? 0) >= REQUEST_CODE_MAX_PER_WINDOW) {
    return jsonResponse(
      { error: "Too many attempts. Please try again later." },
      429,
    );
  }

  const { data: passwordOk, error: verifyError } = await supabase.rpc(
    "verify_login_password",
    { p_email: email, p_password: password },
  );
  if (verifyError) throw verifyError;

  if (passwordOk !== true) {
    const { error: insertError } = await supabase.from("edge_rate_limits").insert({
      bucket: "password-sign-in",
      subject: email,
    });
    if (insertError) throw insertError;
    return jsonResponse(
      { error: "That email or password is incorrect." },
      401,
    );
  }

  const member = await findEligibleMember(email);
  if (!member) {
    return jsonResponse(
      { error: "Your membership is not currently active." },
      403,
    );
  }

  const existingProfile = await getProfile(email);
  const isFirstLink = existingProfile == null;
  const profile = await upsertProfile(email, member.cm_id);
  const session = await issueSession(member, profile);
  return jsonResponse({ ...session, isFirstLink });
}

async function handleSetPassword(req: Request): Promise<Response> {
  let session;
  try {
    session = await requireSessionMember(req);
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  const body = await req.json().catch(() => null) as { password?: string } | null;
  const password = typeof body?.password === "string" ? body.password : "";

  if (password.length < 8) {
    return jsonResponse(
      { error: "Password must be at least 8 characters." },
      400,
    );
  }

  try {
    await assertRateLimit(
      "set-password",
      session.email,
      REQUEST_CODE_MAX_PER_WINDOW,
      REQUEST_CODE_WINDOW_MINUTES,
    );
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  const supabase = supabaseAdmin();
  const { error } = await supabase.rpc("set_login_password", {
    p_email: session.email,
    p_password: password,
  });
  if (error) throw error;

  return jsonResponse({ ok: true });
}

async function handleRefresh(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null) as { refreshToken?: string } | null;
  const refreshToken = typeof body?.refreshToken === "string"
    ? body.refreshToken
    : "";
  if (!refreshToken) {
    return jsonResponse({ error: "refreshToken is required." }, 400);
  }

  const refreshHash = await sha256Hex(refreshToken);
  const supabase = supabaseAdmin();
  const { data: sessionRow, error } = await supabase
    .from("app_sessions")
    .select("id, email, cm_id, expires_at, revoked_at")
    .eq("refresh_token_hash", refreshHash)
    .maybeSingle();

  if (error) throw error;
  if (!sessionRow || sessionRow.revoked_at) {
    return jsonResponse({ error: "Session expired." }, 401);
  }
  if (new Date(sessionRow.expires_at).getTime() < Date.now()) {
    return jsonResponse({ error: "Session expired." }, 401);
  }

  const email = normalizeEmail(sessionRow.email);
  const member = await findEligibleMember(email);
  if (!member) {
    await supabase
      .from("app_sessions")
      .update({ revoked_at: new Date().toISOString() })
      .eq("id", sessionRow.id);
    return jsonResponse({ error: "Your membership is not currently active." }, 403);
  }

  // Rotate refresh token.
  await supabase
    .from("app_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("id", sessionRow.id);

  const profile = await upsertProfile(email, member.cm_id);
  const session = await issueSession(member, profile);
  return jsonResponse(session);
}

async function handleLogout(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null) as { refreshToken?: string } | null;
  const refreshToken = typeof body?.refreshToken === "string"
    ? body.refreshToken.trim()
    : "";

  // Idempotent: missing/invalid token still clears the client session.
  if (!refreshToken) {
    return jsonResponse({ ok: true });
  }

  const refreshHash = await sha256Hex(refreshToken);
  const supabase = supabaseAdmin();
  const { data: sessionRow, error } = await supabase
    .from("app_sessions")
    .select("id, email")
    .eq("refresh_token_hash", refreshHash)
    .maybeSingle();
  if (error) throw error;

  if (sessionRow?.email) {
    const now = new Date().toISOString();
    await supabase
      .from("app_sessions")
      .update({ revoked_at: now })
      .eq("email", normalizeEmail(sessionRow.email))
      .is("revoked_at", null);
  }

  return jsonResponse({ ok: true });
}

async function handleMe(req: Request): Promise<Response> {
  try {
    const { member, profile } = await requireSessionMember(req);
    return jsonResponse({ member: await mapMember(member, profile) });
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }
}

async function handleCompanyLogo(req: Request): Promise<Response> {
  let session;
  try {
    session = await requireSessionMember(req);
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  try {
    await assertRateLimit(
      "company-logo",
      String(session.member.cm_id),
      RATE_LIMIT_LOGO_MAX,
      RATE_LIMIT_LOGO_WINDOW_MIN,
    );
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  const body = await req.json().catch(() => null) as {
    imageBase64?: string;
    contentType?: string;
  } | null;

  const imageBase64 = typeof body?.imageBase64 === "string" ? body.imageBase64 : "";
  const declaredType = typeof body?.contentType === "string"
    ? body.contentType.toLowerCase().trim()
    : "image/jpeg";

  if (!imageBase64) {
    return jsonResponse({ error: "imageBase64 is required." }, 400);
  }
  if (!ALLOWED_LOGO_TYPES.has(declaredType)) {
    return jsonResponse(
      { error: "contentType must be image/jpeg, image/png, or image/webp." },
      400,
    );
  }

  let bytes: Uint8Array;
  try {
    bytes = decodeBase64Payload(imageBase64);
  } catch {
    return jsonResponse({ error: "Invalid imageBase64 payload." }, 400);
  }

  if (bytes.byteLength === 0 || bytes.byteLength > MAX_LOGO_BYTES) {
    return jsonResponse(
      { error: "Image must be between 1 byte and 2MB." },
      400,
    );
  }

  const sniffedType = sniffImageContentType(bytes);
  if (!sniffedType || sniffedType !== declaredType) {
    return jsonResponse(
      { error: "Image bytes do not match the declared contentType." },
      400,
    );
  }

  const supabase = supabaseAdmin();
  const ext = logoExtension(sniffedType);
  const path = `${session.member.cm_id}/logo.${ext}`;

  const blob = new Blob([bytes], { type: sniffedType });
  const { error: uploadError } = await supabase.storage
    .from("business-logos")
    .upload(path, blob, {
      contentType: sniffedType,
      upsert: true,
      cacheControl: "3600",
    });
  if (uploadError) throw uploadError;

  const { data: publicData } = supabase.storage
    .from("business-logos")
    .getPublicUrl(path);
  const logoURL = `${publicData.publicUrl}?t=${Date.now()}`;

  const { data: updated, error: updateError } = await supabase
    .from("chamber_members")
    .update({
      logo_url: logoURL,
      logo_source: "member_upload",
      logo_skip_key: null,
      logo_skip_reason: null,
    })
    .eq("cm_id", session.member.cm_id)
    .select(MEMBER_COLUMNS)
    .single();
  if (updateError) throw updateError;

  return jsonResponse({
    member: await mapMember(updated as ChamberMemberRow, session.profile),
  });
}

async function handleCompanyProfile(req: Request): Promise<Response> {
  let session;
  try {
    session = await requireSessionMember(req);
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  const body = await req.json().catch(() => null) as {
    category?: string;
    shortDescription?: string;
    websiteURL?: string | null;
    phone?: string | null;
    address?: string | null;
    addressPublic?: boolean;
  } | null;

  if (!body || typeof body !== "object") {
    return jsonResponse({ error: "Invalid profile payload." }, 400);
  }

  const category = normalizeCategory(body.category);
  if (!category) {
    return jsonResponse({ error: "Invalid category." }, 400);
  }

  const shortDescription = normalizeOptionalText(
    body.shortDescription,
    MAX_SHORT_DESCRIPTION,
  ) ?? "";
  const websiteURL = normalizeWebsite(body.websiteURL);
  const phone = normalizeOptionalText(body.phone, MAX_PHONE);
  const address = normalizeOptionalText(body.address, MAX_ADDRESS);
  const addressPublic = body.addressPublic !== false;

  const supabase = supabaseAdmin();
  const { data: current, error: currentError } = await supabase
    .from("chamber_members")
    .select("category, category_source")
    .eq("cm_id", session.member.cm_id)
    .single();
  if (currentError) throw currentError;

  // The form always posts a category, so only claim it for the member when they
  // actually changed it; otherwise a phone-number edit would lock in a synced
  // category. "Other" never replaces a Chambermate-synced category: older app
  // builds can't display the newer labels and post "Other" back unchanged.
  const storedCategory = normalizeCategory(current.category) ?? "Other";
  const categoryUpdate: Record<string, string> = {};
  if (
    category !== storedCategory &&
    !(category === "Other" && current.category_source === "chambermate")
  ) {
    categoryUpdate.category = category;
    categoryUpdate.category_source = "member";
  }

  const { data: updated, error } = await supabase
    .from("chamber_members")
    .update({
      ...categoryUpdate,
      short_description: shortDescription || null,
      website_url: websiteURL,
      phone,
      address,
      address_public: addressPublic,
    })
    .eq("cm_id", session.member.cm_id)
    .select(BUSINESS_COLUMNS)
    .single();
  if (error) throw error;

  return jsonResponse(
    mapBusiness(updated as ChamberMemberRow, [], { includePrivateAddress: true }),
  );
}

async function handleBusinesses(req: Request): Promise<Response> {
  try {
    await requireSessionMember(req);
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  const supabase = supabaseAdmin();
  const { data: members, error: membersError } = await supabase
    .from("chamber_members")
    .select(BUSINESS_COLUMNS)
    .eq("status", ACTIVE_STATUS)
    .order("display_name", { ascending: true });
  if (membersError) throw membersError;

  const rows = (members ?? []) as ChamberMemberRow[];
  const businessIds = rows.map((row) => String(row.cm_id));

  const dealsByBusiness = new Map<string, ReturnType<typeof mapDealSummary>[]>();
  if (businessIds.length > 0) {
    const { data: deals, error: dealsError } = await supabase
      .from("deals")
      .select(
        "id, title, business_id, business_name, short_description, category, end_date, is_featured, members_only, archived_at",
      )
      .is("archived_at", null)
      .in("business_id", businessIds);
    if (dealsError) throw dealsError;

    for (const deal of deals ?? []) {
      const mapped = mapDealSummary(deal as Record<string, unknown>);
      const key = String(mapped.businessId);
      const list = dealsByBusiness.get(key) ?? [];
      list.push(mapped);
      dealsByBusiness.set(key, list);
    }
  }

  const businesses = rows.map((row) =>
    mapBusiness(row, dealsByBusiness.get(String(row.cm_id)) ?? [])
  );
  return jsonResponse(businesses);
}

async function handleBusiness(req: Request, businessId: string): Promise<Response> {
  let session;
  try {
    session = await requireSessionMember(req);
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, status);
  }

  const cmId = Number(businessId);
  if (!Number.isFinite(cmId)) {
    return jsonResponse({ error: "Business not found." }, 404);
  }

  const supabase = supabaseAdmin();
  const { data: member, error } = await supabase
    .from("chamber_members")
    .select(BUSINESS_COLUMNS)
    .eq("cm_id", cmId)
    .eq("status", ACTIVE_STATUS)
    .maybeSingle();
  if (error) throw error;
  if (!member) {
    return jsonResponse({ error: "Business not found." }, 404);
  }

  const { data: deals, error: dealsError } = await supabase
    .from("deals")
    .select(
      "id, title, business_id, business_name, short_description, category, end_date, is_featured, members_only, archived_at",
    )
    .is("archived_at", null)
    .eq("business_id", String(cmId));
  if (dealsError) throw dealsError;

  const isOwner = session.member.cm_id === cmId;
  return jsonResponse(
    mapBusiness(
      member as ChamberMemberRow,
      (deals ?? []).map((deal) => mapDealSummary(deal as Record<string, unknown>)),
      { includePrivateAddress: isOwner },
    ),
  );
}

type ChambermateCompany = {
  companyKey: string;
  companyName?: string;
  email?: string | null;
  phone?: { number?: string | null } | null;
  initialMembershipDate?: string | null;
  [key: string]: unknown;
};

type ChambermateBusinessCategory = {
  systemFieldOptionKey?: string | null;
  label?: string | null;
};

type ChambermateMembership = {
  companyKey: string;
  company: ChambermateCompany;
  /** Only populated when requested with includeBusinessCategories=true. */
  businessCategories?: ChambermateBusinessCategory[] | null;
  [key: string]: unknown;
};

/**
 * Chambermate's public WebPresence directory only ever returns *current*
 * members (no dropped/prospective history, no admin-only fields) -- see the
 * chambermaster_to_chambermate_migration project memory. Everyone it returns
 * is treated as active; anyone previously linked via `companymate_key` who
 * stops appearing here is flipped out of ACTIVE_STATUS below.
 */
async function handleSyncMembers(req: Request): Promise<Response> {
  const syncSecret = Deno.env.get("MEMBER_SYNC_SECRET") ?? "";
  const provided = req.headers.get("x-sync-secret") ?? "";
  if (!syncSecret || provided !== syncSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const apiKey = Deno.env.get("CHAMBERMATE_API_KEY") ?? "";
  if (!apiKey) {
    return jsonResponse(
      { error: "Chambermate API is not configured on the server." },
      503,
    );
  }
  const baseURL = (
    Deno.env.get("CHAMBERMATE_BASE_URL") ?? "https://api.chambermate.com/core/biz"
  ).replace(/\/+$/, "");

  const response = await fetch(
    `${baseURL}/webPresence/searchMembershipDirectory?apiKey=${
      encodeURIComponent(apiKey)
    }&rowCount=2000&includeBusinessCategories=true`,
    { headers: { Accept: "application/json" } },
  );

  if (!response.ok) {
    const text = await response.text();
    return jsonResponse(
      { error: `Chambermate sync failed: ${response.status} ${text}` },
      502,
    );
  }

  const payload = await response.json();
  if (payload?.status !== true) {
    return jsonResponse(
      {
        error: `Chambermate sync failed: ${
          payload?.message ?? payload?.error ?? "unknown error"
        }`,
      },
      502,
    );
  }

  const memberships: ChambermateMembership[] =
    Array.isArray(payload?.data?.memberships) ? payload.data.memberships : [];

  const byKey = new Map<string, ChambermateMembership>();
  for (const membership of memberships) {
    const key = membership.companyKey ?? membership.company?.companyKey;
    if (typeof key === "string" && key) byKey.set(key, membership);
  }
  const keys = [...byKey.keys()];

  const supabase = supabaseAdmin();

  // Companies already linked to a cm_id (from the one-time migration backfill,
  // or a previous run of this sync) keep that same cm_id.
  const cmIdByKey = new Map<string, number>();
  if (keys.length > 0) {
    const { data: existingRows, error: existingError } = await supabase
      .from("chamber_members")
      .select("cm_id, companymate_key")
      .in("companymate_key", keys);
    if (existingError) throw existingError;
    for (const row of existingRows ?? []) {
      if (row.companymate_key) cmIdByKey.set(row.companymate_key, row.cm_id);
    }
  }

  // Brand-new companies (never in ChamberMaster, or still awaiting manual
  // crosswalk review) get fresh cm_id values from the reserved companymate band.
  const newKeys = keys.filter((key) => !cmIdByKey.has(key));
  if (newKeys.length > 0) {
    const { data: idRows, error: idError } = await supabase.rpc(
      "next_companymate_cm_ids",
      { n: newKeys.length },
    );
    if (idError) throw idError;
    const newIds = (idRows ?? []) as number[];
    if (newIds.length !== newKeys.length) {
      throw new Error(
        "Failed to reserve cm_id values for new Chambermate companies.",
      );
    }
    newKeys.forEach((key, i) => cmIdByKey.set(key, newIds[i]));
  }

  const syncedAt = new Date().toISOString();
  const rows = [...byKey.entries()].map(([key, membership]) => {
    const company = membership.company ?? ({} as ChambermateCompany);
    const cmId = cmIdByKey.get(key)!;
    const email =
      typeof company.email === "string" && company.email.trim()
        ? company.email.trim().toLowerCase()
        : null;
    const name = String(company.companyName ?? `Member ${cmId}`);
    return {
      cm_id: cmId,
      name,
      display_name: name,
      email,
      status: ACTIVE_STATUS,
      level: null,
      membership_established: company.initialMembershipDate ?? null,
      drop_date: null,
      slug: null,
      display_flags: "",
      companymate_key: key,
      raw: membership as unknown as Record<string, unknown>,
      synced_at: syncedAt,
    };
  });

  if (rows.length > 0) {
    const { error: upsertError } = await supabase
      .from("chamber_members")
      .upsert(rows, { onConflict: "cm_id" });
    if (upsertError) throw upsertError;
  }

  // Anyone previously linked via companymate_key who no longer shows up in this
  // pull has dropped out of Chambermate's current-members list -- cut off their
  // entitlements. Skipped entirely if Chambermate returned nothing, so a
  // transient empty response can't wipe out everyone's access. Never touches
  // rows with no companymate_key (legacy ChamberMaster-only members awaiting
  // manual crosswalk review, or the -1 App Review test account).
  if (rows.length > 0) {
    const stillCurrentIds = rows.map((row) => row.cm_id);
    const { error: dropError } = await supabase
      .from("chamber_members")
      .update({ status: "dropped", synced_at: syncedAt })
      .not("companymate_key", "is", null)
      .eq("status", ACTIVE_STATUS)
      .not("cm_id", "in", `(${stillCurrentIds.join(",")})`);
    if (dropError) throw dropError;
  }

  return jsonResponse({ ok: true, upserted: rows.length });
}

type ChambermatePost = {
  postKey?: string;
  title?: string;
  postHtml?: { html?: string | null } | null;
  companyName?: string | null;
  avatarStorageKey?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  [key: string]: unknown;
};

/** Flattens a Chambermate rich-text post body to plain text with paragraph breaks. */
function postHtmlToText(html: string): string {
  return html
    .replace(/<\s*br\s*\/?>/gi, "\n")
    .replace(/<\/(p|li|div|h[1-6])>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&amp;/gi, "&")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Post dates are UTC but come without a zone suffix ("2026-12-01T06:00:00"). */
function postDateToISO(value?: string | null): string | null {
  if (!value) return null;
  const iso = /(z|[+-]\d{2}:?\d{2})$/i.test(value) ? value : `${value}Z`;
  const time = Date.parse(iso);
  return Number.isNaN(time) ? null : new Date(time).toISOString();
}

function normalizeCompanyName(name: string): string {
  return name.toLowerCase().replace(/&/g, "and").replace(/[^a-z0-9]+/g, "");
}

/**
 * Mirrors the Chambermate "Hot Deals" board (public getPostsInfo feed, no API
 * key needed) into `hot_deals`. Read-only in the app: rows are replaced on every
 * run and posts that left the board are deleted. Posts carry only a company
 * name, so business_id is filled by exact normalized-name match against current
 * members; unmatched posts still sync (business_id null) and are reported.
 */
async function handleSyncHotDeals(req: Request): Promise<Response> {
  const syncSecret = Deno.env.get("MEMBER_SYNC_SECRET") ?? "";
  const provided = req.headers.get("x-sync-secret") ?? "";
  if (!syncSecret || provided !== syncSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const baseURL = (
    Deno.env.get("CHAMBERMATE_BASE_URL") ?? "https://api.chambermate.com/core/biz"
  ).replace(/\/+$/, "");
  const params = new URLSearchParams({
    websiteShorthand: Deno.env.get("CHAMBERMATE_WEBSITE_SHORTHAND") ??
      "wilmettekenilworth",
    websiteDomain: Deno.env.get("CHAMBERMATE_WEBSITE_DOMAIN") ??
      "www.wilmettekenilworth.com",
    boardId: Deno.env.get("CHAMBERMATE_HOT_DEALS_BOARD_ID") ?? "1652",
  });

  const response = await fetch(
    `${baseURL}/webPresence/getPostsInfo?${params}`,
    { headers: { Accept: "application/json" } },
  );
  if (!response.ok) {
    const text = await response.text();
    return jsonResponse(
      { error: `Hot deals sync failed: ${response.status} ${text}` },
      502,
    );
  }

  const payload = await response.json();
  if (payload?.status !== true || !Array.isArray(payload?.data?.posts)) {
    return jsonResponse(
      {
        error: `Hot deals sync failed: ${
          payload?.error?.errorMessage ?? payload?.message ?? "unexpected response"
        }`,
      },
      502,
    );
  }
  const posts = payload.data.posts as ChambermatePost[];

  const supabase = supabaseAdmin();
  const { data: members, error: membersError } = await supabase
    .from("chamber_members")
    .select("cm_id, name, display_name")
    .eq("status", ACTIVE_STATUS);
  if (membersError) throw membersError;

  const cmIdByName = new Map<string, number>();
  for (const member of members ?? []) {
    for (const name of [member.name, member.display_name]) {
      if (typeof name !== "string" || !name) continue;
      const key = normalizeCompanyName(name);
      if (key && !cmIdByName.has(key)) cmIdByName.set(key, member.cm_id);
    }
  }

  const syncedAt = new Date().toISOString();
  const unmatched: string[] = [];
  const rows = posts
    .filter((post) => typeof post.postKey === "string" && post.postKey)
    .map((post) => {
      const companyName = String(post.companyName ?? "").trim();
      const cmId = cmIdByName.get(normalizeCompanyName(companyName));
      if (cmId === undefined) unmatched.push(companyName || String(post.postKey));
      return {
        post_key: post.postKey as string,
        title: String(post.title ?? "").trim(),
        body: postHtmlToText(String(post.postHtml?.html ?? "")),
        company_name: companyName,
        business_id: cmId === undefined ? null : String(cmId),
        avatar_storage_key: post.avatarStorageKey ?? null,
        start_date: postDateToISO(post.startDate),
        end_date: postDateToISO(post.endDate),
        raw: post as unknown as Record<string, unknown>,
        synced_at: syncedAt,
      };
    });

  if (rows.length > 0) {
    const { error: upsertError } = await supabase
      .from("hot_deals")
      .upsert(rows, { onConflict: "post_key" });
    if (upsertError) throw upsertError;
  }

  // The feed parsed cleanly, so an empty board is real: drop anything that left it.
  const keep = rows.map((row) => `"${row.post_key}"`);
  const stale = supabase.from("hot_deals").delete();
  const { error: deleteError } = keep.length > 0
    ? await stale.not("post_key", "in", `(${keep.join(",")})`)
    : await stale.neq("post_key", "");
  if (deleteError) throw deleteError;

  return jsonResponse({
    ok: true,
    upserted: rows.length,
    matched: rows.length - unmatched.length,
    unmatched,
  });
}

const LOGO_SYNC_DEFAULT_LIMIT = 25;
const LOGO_SYNC_MAX_LIMIT = 50;
const LOGO_SYNC_TIMEOUT_MS = 15_000;

/**
 * Copies member logos from Chambermate into our `business-logos` bucket.
 * Chambermate only exposes an `avatarStorageKey`; the public avatarDirectView
 * endpoint 302s to a ~2 minute presigned S3 URL, so we copy rather than link.
 *
 * Body: { dryRun?: boolean (default TRUE), limit?: number }. A dry run
 * downloads and validates each candidate but writes nothing. Never touches
 * `member_upload` logos or legacy logos; only fills empty ones or refreshes a
 * logo previously imported from Chambermate whose avatar key has changed.
 */
async function handleSyncLogos(req: Request): Promise<Response> {
  const syncSecret = Deno.env.get("MEMBER_SYNC_SECRET") ?? "";
  const provided = req.headers.get("x-sync-secret") ?? "";
  if (!syncSecret || provided !== syncSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const body = await req.json().catch(() => null) as {
    dryRun?: boolean;
    limit?: number;
  } | null;
  const dryRun = body?.dryRun !== false;
  const limit = Math.min(
    Math.max(Math.floor(Number(body?.limit)) || LOGO_SYNC_DEFAULT_LIMIT, 1),
    LOGO_SYNC_MAX_LIMIT,
  );

  const coreURL = (
    Deno.env.get("CHAMBERMATE_CORE_URL") ?? "https://api.chambermate.com/core"
  ).replace(/\/+$/, "");

  const supabase = supabaseAdmin();
  const { data: rows, error } = await supabase
    .from("chamber_members")
    .select(
      "cm_id, name, companymate_key, logo_url, logo_source, chambermate_avatar_key, logo_skip_key, raw",
    )
    .eq("status", ACTIVE_STATUS)
    .not("companymate_key", "is", null);
  if (error) throw error;

  type Candidate = { cm_id: number; name: string; companyKey: string; avatarKey: string };
  const candidates: Candidate[] = [];
  let noAvatar = 0;
  let alreadySkipped = 0;
  for (const row of rows ?? []) {
    const avatarKey = String(
      (row.raw as { company?: { avatarStorageKey?: string } } | null)?.company
        ?.avatarStorageKey ?? "",
    ).trim();
    if (!avatarKey) {
      noAvatar++;
      continue;
    }
    // Already rejected this exact avatar (too large / wrong type); wait for a new one.
    if (row.logo_skip_key === avatarKey) {
      alreadySkipped++;
      continue;
    }
    const hasLogo = typeof row.logo_url === "string" && row.logo_url.trim() !== "";
    const refresh = row.logo_source === "chambermate" &&
      row.chambermate_avatar_key !== avatarKey;
    if (!hasLogo || refresh) {
      candidates.push({
        cm_id: row.cm_id,
        name: row.name,
        companyKey: row.companymate_key as string,
        avatarKey,
      });
    }
  }

  const batch = candidates.slice(0, limit);
  const results: Array<Record<string, unknown>> = [];
  let copied = 0;
  let failed = 0;
  let skipped = 0;

  const recordSkip = async (c: Candidate, reason: string) => {
    skipped++;
    results.push({ cm_id: c.cm_id, name: c.name, outcome: "skipped", reason });
    if (dryRun) return;
    const { error: skipError } = await supabase
      .from("chamber_members")
      .update({ logo_skip_key: c.avatarKey, logo_skip_reason: reason })
      .eq("cm_id", c.cm_id);
    if (skipError) throw skipError;
  };

  for (const c of batch) {
    try {
      const avatarURL = new URL(`${coreURL}/shared/query/avatarDirectView`);
      avatarURL.searchParams.set("entityKey", c.companyKey);
      avatarURL.searchParams.set("entityName", "Company");
      avatarURL.searchParams.set("avatarStorageKey", c.avatarKey);
      avatarURL.searchParams.set("noFallback", "true");

      const redirect = await fetch(avatarURL, {
        redirect: "manual",
        signal: AbortSignal.timeout(LOGO_SYNC_TIMEOUT_MS),
      });
      const location = redirect.headers.get("location");
      if (redirect.status < 300 || redirect.status > 399 || !location) {
        throw new Error(`avatar lookup returned ${redirect.status}`);
      }
      const imageURL = new URL(location, avatarURL);
      if (
        imageURL.protocol !== "https:" ||
        !imageURL.hostname.endsWith(".amazonaws.com")
      ) {
        throw new Error("unexpected avatar redirect host");
      }

      const imageResponse = await fetch(imageURL, {
        signal: AbortSignal.timeout(LOGO_SYNC_TIMEOUT_MS),
      });
      if (!imageResponse.ok) {
        throw new Error(`image download returned ${imageResponse.status}`);
      }
      const bytes = new Uint8Array(await imageResponse.arrayBuffer());
      if (bytes.byteLength === 0 || bytes.byteLength > MAX_LOGO_BYTES) {
        await recordSkip(
          c,
          `size ${bytes.byteLength} bytes outside 1..${MAX_LOGO_BYTES}`,
        );
        continue;
      }
      const type = sniffImageContentType(bytes);
      if (!type || !ALLOWED_LOGO_TYPES.has(type)) {
        await recordSkip(c, "unsupported image type");
        continue;
      }

      if (dryRun) {
        results.push({
          cm_id: c.cm_id,
          name: c.name,
          outcome: "would_copy",
          type,
          bytes: bytes.byteLength,
        });
        continue;
      }

      const path = `${c.cm_id}/logo.${logoExtension(type)}`;
      const { error: uploadError } = await supabase.storage
        .from("business-logos")
        .upload(path, new Blob([bytes], { type }), {
          contentType: type,
          upsert: true,
          cacheControl: "3600",
        });
      if (uploadError) throw uploadError;

      const { data: publicData } = supabase.storage
        .from("business-logos")
        .getPublicUrl(path);
      const { error: updateError } = await supabase
        .from("chamber_members")
        .update({
          logo_url: `${publicData.publicUrl}?t=${Date.now()}`,
          logo_source: "chambermate",
          chambermate_avatar_key: c.avatarKey,
          logo_skip_key: null,
          logo_skip_reason: null,
          logo_synced_at: new Date().toISOString(),
        })
        .eq("cm_id", c.cm_id);
      if (updateError) throw updateError;

      copied++;
      results.push({ cm_id: c.cm_id, name: c.name, outcome: "copied", type });
    } catch (e) {
      failed++;
      results.push({
        cm_id: c.cm_id,
        name: c.name,
        outcome: "failed",
        reason: e instanceof Error ? e.message : "unknown error",
      });
    }
  }

  return jsonResponse({
    ok: true,
    dryRun,
    candidates: candidates.length,
    processed: batch.length,
    noAvatar,
    alreadySkipped,
    copied,
    skipped,
    failed,
    results,
  });
}

/**
 * Sets each business's category from the Chambermate business categories that
 * sync-members stored in `raw` (our categories are Chambermate's labels, so no
 * mapping). When a business has several, the first Chambermate lists wins.
 *
 * Body: { dryRun?: boolean (default TRUE) }. Never touches categories a member
 * picked in the app (`category_source = 'member'`); refreshes a category
 * previously synced from Chambermate only when its Chambermate categories
 * change. Businesses Chambermate has no category for are left alone.
 */
async function handleSyncCategories(req: Request): Promise<Response> {
  const syncSecret = Deno.env.get("MEMBER_SYNC_SECRET") ?? "";
  const provided = req.headers.get("x-sync-secret") ?? "";
  if (!syncSecret || provided !== syncSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const body = await req.json().catch(() => null) as { dryRun?: boolean } | null;
  const dryRun = body?.dryRun !== false;

  const supabase = supabaseAdmin();
  const { data: rows, error } = await supabase
    .from("chamber_members")
    .select("cm_id, name, category, category_source, chambermate_category_key, raw")
    .eq("status", ACTIVE_STATUS)
    .not("companymate_key", "is", null);
  if (error) throw error;

  const results: Array<Record<string, unknown>> = [];
  const unknownLabels: Record<string, number> = {};
  let noCategories = 0;
  let protectedMember = 0;
  let unchanged = 0;
  let updated = 0;

  for (const row of rows ?? []) {
    const categories = (row.raw as ChambermateMembership | null)?.businessCategories ?? [];
    if (categories.length === 0) {
      noCategories++;
      continue;
    }

    const categoryKey = categories
      .map((c) => String(c.systemFieldOptionKey ?? c.label ?? ""))
      .sort()
      .join(",");
    let category: string | null = null;
    for (const c of categories) {
      const normalized = normalizeCategory(c.label);
      if (normalized) {
        category ??= normalized;
      } else {
        const label = String(c.label ?? "(no label)");
        unknownLabels[label] = (unknownLabels[label] ?? 0) + 1;
      }
    }
    if (!category) continue;

    if (row.category_source === "member") {
      protectedMember++;
      continue;
    }
    if (
      row.category_source === "chambermate" &&
      row.chambermate_category_key === categoryKey
    ) {
      unchanged++;
      continue;
    }

    results.push({
      cm_id: row.cm_id,
      name: row.name,
      outcome: dryRun ? "would_set" : "set",
      from: row.category ?? null,
      to: category,
    });
    if (dryRun) continue;

    const { error: updateError } = await supabase
      .from("chamber_members")
      .update({
        category,
        category_source: "chambermate",
        chambermate_category_key: categoryKey,
        category_synced_at: new Date().toISOString(),
      })
      .eq("cm_id", row.cm_id);
    if (updateError) throw updateError;
    updated++;
  }

  return jsonResponse({
    ok: true,
    dryRun,
    total: rows?.length ?? 0,
    changes: results.length,
    updated,
    unchanged,
    protectedMember,
    noCategories,
    unknownLabels,
    results,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const route = url.pathname.split("/").filter(Boolean).at(-1) ?? "";

  try {
    if (route === "request-code" && req.method === "POST") {
      return await handleRequestCode(req);
    }
    if (route === "verify-code" && req.method === "POST") {
      return await handleVerifyCode(req);
    }
    if (route === "sign-in-password" && req.method === "POST") {
      return await handleSignInPassword(req);
    }
    if (route === "set-password" && req.method === "POST") {
      return await handleSetPassword(req);
    }
    if (route === "refresh" && req.method === "POST") {
      return await handleRefresh(req);
    }
    if (route === "logout" && req.method === "POST") {
      return await handleLogout(req);
    }
    if (route === "me" && req.method === "GET") {
      return await handleMe(req);
    }
    if (route === "company-logo" && req.method === "POST") {
      return await handleCompanyLogo(req);
    }
    if (route === "company-profile" && req.method === "POST") {
      return await handleCompanyProfile(req);
    }
    if (route === "businesses" && req.method === "GET") {
      return await handleBusinesses(req);
    }
    if (route === "business" && req.method === "GET") {
      const businessId = url.searchParams.get("id") ?? "";
      return await handleBusiness(req, businessId);
    }
    if (route === "sync-members" && req.method === "POST") {
      return await handleSyncMembers(req);
    }
    if (route === "sync-hot-deals" && req.method === "POST") {
      return await handleSyncHotDeals(req);
    }
    if (route === "sync-logos" && req.method === "POST") {
      return await handleSyncLogos(req);
    }
    if (route === "sync-categories" && req.method === "POST") {
      return await handleSyncCategories(req);
    }
    return jsonResponse({ error: "Unknown route." }, 404);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    console.error("[member-auth]", message);
    return jsonResponse({ error: message }, 500);
  }
});
