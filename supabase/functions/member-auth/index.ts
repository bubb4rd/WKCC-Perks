import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

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
  raw?: Record<string, unknown> | null;
};

const MEMBER_COLUMNS =
  "cm_id, name, display_name, email, status, level, membership_type, membership_established, drop_date, slug, display_flags, logo_url";

const PROFILE_COLUMNS =
  "category, short_description, website_url, phone, address, address_public";

/** Includes `raw` for lat/long when listing business directory entries. */
const BUSINESS_COLUMNS = `${MEMBER_COLUMNS}, ${PROFILE_COLUMNS}, raw`;

const ALLOWED_CATEGORIES = new Set([
  "Shopping and Specialty Retail",
  "Health Care",
  "Home and Garden",
  "Restaurants, Food and Beverages",
  "Government, Education and Individuals",
  "Personal Services and Care",
  "Business and Professional Services",
  "Finance and Insurance",
  "Advertising and Media",
  "Other",
]);

const MAX_LOGO_BYTES = 2 * 1024 * 1024;
const ALLOWED_LOGO_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const MAX_SHORT_DESCRIPTION = 280;
const MAX_ADDRESS = 200;
const MAX_PHONE = 40;
const MAX_WEBSITE = 300;

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
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return [...bytes].map((b) => (b % 10).toString()).join("");
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

function mapMember(
  member: ChamberMemberRow,
  profile: AppProfileRow | null,
) {
  const { firstName, lastName } = deriveNames(member);
  const isActive = member.status === ACTIVE_STATUS;
  const isAdmin = profile?.is_chamber_admin === true;

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
  const category =
    typeof member.category === "string" && member.category.trim()
      ? member.category.trim()
      : "Other";
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
  if (!payload || typeof payload.email !== "string") {
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
    member: mapMember(member, profile),
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

async function handleMe(req: Request): Promise<Response> {
  try {
    const { member, profile } = await requireSessionMember(req);
    return jsonResponse({ member: mapMember(member, profile) });
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

  const body = await req.json().catch(() => null) as {
    imageBase64?: string;
    contentType?: string;
  } | null;

  const imageBase64 = typeof body?.imageBase64 === "string" ? body.imageBase64 : "";
  const contentType = typeof body?.contentType === "string"
    ? body.contentType.toLowerCase().trim()
    : "image/jpeg";

  if (!imageBase64) {
    return jsonResponse({ error: "imageBase64 is required." }, 400);
  }
  if (!ALLOWED_LOGO_TYPES.has(contentType)) {
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

  const supabase = supabaseAdmin();
  const ext = logoExtension(contentType);
  const path = `${session.member.cm_id}/logo.${ext}`;

  const blob = new Blob([bytes], { type: contentType });
  const { error: uploadError } = await supabase.storage
    .from("business-logos")
    .upload(path, blob, {
      contentType,
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
    .update({ logo_url: logoURL })
    .eq("cm_id", session.member.cm_id)
    .select(MEMBER_COLUMNS)
    .single();
  if (updateError) throw updateError;

  return jsonResponse({
    member: mapMember(updated as ChamberMemberRow, session.profile),
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

  const category = typeof body.category === "string" ? body.category.trim() : "";
  if (!ALLOWED_CATEGORIES.has(category)) {
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
  const { data: updated, error } = await supabase
    .from("chamber_members")
    .update({
      category,
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

type ChamberMasterMember = {
  Id?: number | string;
  Name?: string;
  DisplayName?: string;
  Email?: string | null;
  Status?: number | string;
  Level?: number | string | null;
  MembershipEstablished?: string | null;
  DropDate?: string | null;
  Slug?: string | null;
  DisplayFlags?: string | null;
  [key: string]: unknown;
};

async function handleSyncMembers(req: Request): Promise<Response> {
  const syncSecret = Deno.env.get("MEMBER_SYNC_SECRET") ?? "";
  const provided = req.headers.get("x-sync-secret") ?? "";
  if (!syncSecret || provided !== syncSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const apiKey = Deno.env.get("CHAMBERMASTER_API_KEY") ?? "";
  const baseURL = (Deno.env.get("CHAMBERMASTER_BASE_URL") ?? "").replace(/\/+$/, "");
  if (!apiKey || !baseURL) {
    return jsonResponse(
      { error: "ChamberMaster API is not configured on the server." },
      503,
    );
  }

  const response = await fetch(`${baseURL}/api/v1/members`, {
    headers: {
      Accept: "application/json",
      "X-ApiKey": apiKey,
    },
  });

  if (!response.ok) {
    const text = await response.text();
    return jsonResponse(
      { error: `ChamberMaster sync failed: ${response.status} ${text}` },
      502,
    );
  }

  const payload = await response.json();
  const list: ChamberMasterMember[] = Array.isArray(payload)
    ? payload
    : Array.isArray(payload?.Members)
    ? payload.Members
    : Array.isArray(payload?.items)
    ? payload.items
    : [];

  const rows = list
    .map((item) => {
      const cmId = Number(item.Id);
      if (!Number.isFinite(cmId)) return null;
      const email = typeof item.Email === "string" && item.Email.trim()
        ? item.Email.trim().toLowerCase()
        : null;
      return {
        cm_id: cmId,
        name: String(item.Name ?? item.DisplayName ?? `Member ${cmId}`),
        display_name: String(item.DisplayName ?? item.Name ?? `Member ${cmId}`),
        email,
        status: String(item.Status ?? ""),
        level: item.Level == null ? null : String(item.Level),
        membership_established: item.MembershipEstablished ?? null,
        drop_date: item.DropDate ?? null,
        slug: item.Slug ?? null,
        display_flags: String(item.DisplayFlags ?? ""),
        raw: item,
        synced_at: new Date().toISOString(),
      };
    })
    .filter(Boolean);

  const supabase = supabaseAdmin();
  const { error } = await supabase.from("chamber_members").upsert(rows, {
    onConflict: "cm_id",
  });
  if (error) throw error;

  return jsonResponse({ ok: true, upserted: rows.length });
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
    if (route === "refresh" && req.method === "POST") {
      return await handleRefresh(req);
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
    return jsonResponse({ error: "Unknown route." }, 404);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    console.error("[member-auth]", message);
    return jsonResponse({ error: message }, 500);
  }
});
