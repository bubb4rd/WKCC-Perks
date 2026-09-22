import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

// MVP staff API for the Member Success Hub: search a member, see what
// they're entitled to and what's been fulfilled, record a fulfillment.
// Now consumed by the Member Success Hub web app (a real browser client),
// so CORS is scoped to an explicit origin allowlist -- never "*".

const ALLOWED_ORIGINS = new Set([
  "http://localhost:5173",
  "https://benefitswkcc.netlify.app", // placeholder -- update once the real subdomain is chosen
]);

function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    Vary: "Origin",
  };
  if (origin && isAllowedOrigin(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function isAllowedOrigin(origin: string): boolean {
  if (ALLOWED_ORIGINS.has(origin)) return true;
  try {
    const { protocol, hostname } = new URL(origin);
    return protocol === "http:" && (hostname === "localhost" || hostname === "127.0.0.1");
  } catch {
    return false;
  }
}

const ACTIVE_MEMBER_STATUS = "2";

const FULFILLMENT_STATUSES = new Set([
  "available",
  "requested_by_member",
  "offered",
  "scheduled",
  "in_progress",
  "completed",
  "redeemed",
  "deferred",
  "declined",
  "not_applicable",
  "expired",
  "needs_followup",
]);

const FULFILLMENT_SOURCES = new Set([
  "allowance",
  "paid_add_on",
  "courtesy",
  "manual_exception",
]);

// Fulfillments in these statuses do not consume an entitlement's allowance.
const NON_CONSUMING_STATUSES = new Set(["declined", "not_applicable"]);

type AuthContext = {
  email: string;
  isAdmin: boolean;
  cmId: number | null;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function supabaseAdmin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new Error("Supabase service role is not configured.");
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

function base64UrlDecode(input: string): Uint8Array {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  const binary = atob(padded + pad);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
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

function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

// MVP auth: reuses the same bearer-token session as member-auth/perks. Most
// of this API is staff-only (app_profiles.is_chamber_admin) -- see
// requireStaffAccess below -- but a business member may read their own
// record (see requireMemberAccess), so this just authenticates the caller
// and returns their admin flag + own cm_id; endpoints decide what to allow.
// Does not yet check staff_roles -- that table exists for later role
// granularity (see the WKCC Benefit Ledger's Phase 1 plan) but every admin
// has full staff access for now.
async function requireStaffAuth(req: Request): Promise<AuthContext> {
  const token = bearerToken(req);
  if (!token) {
    throw Object.assign(new Error("Missing authorization."), { status: 401 });
  }

  const payload = await verifyAccessToken(token);
  if (!payload || payload.typ !== "access") {
    throw Object.assign(new Error("Invalid or expired session."), {
      status: 401,
    });
  }

  const email = typeof payload.email === "string"
    ? payload.email.trim().toLowerCase()
    : "";
  if (!email) {
    throw Object.assign(new Error("Invalid session claims."), { status: 401 });
  }

  const supabase = supabaseAdmin();
  const { data: profile, error } = await supabase
    .from("app_profiles")
    .select("email, cm_id, is_chamber_admin")
    .eq("email", email)
    .maybeSingle();
  if (error) throw error;

  return {
    email,
    isAdmin: profile?.is_chamber_admin === true,
    cmId: typeof profile?.cm_id === "number" ? profile.cm_id : null,
  };
}

function requireStaffAccess(auth: AuthContext): void {
  if (!auth.isAdmin) {
    throw Object.assign(new Error("Staff access required."), { status: 403 });
  }
}

/** Staff can read any member; a business member may only read their own. */
function requireMemberAccess(auth: AuthContext, cmId: number): void {
  if (auth.isAdmin || auth.cmId === cmId) return;
  throw Object.assign(new Error("Staff access required."), { status: 403 });
}

function pathParts(pathname: string): string[] {
  const cleaned = pathname.replace(/\/+$/, "");
  const idx = cleaned.lastIndexOf("/staff");
  const rest = idx >= 0 ? cleaned.slice(idx + "/staff".length) : cleaned;
  return rest.split("/").filter(Boolean);
}

function mapMemberSummary(row: Record<string, unknown>) {
  return {
    cmId: row.cm_id,
    name: (row.display_name as string) || (row.name as string) || "",
    email: row.email ?? null,
    status: row.status === ACTIVE_MEMBER_STATUS ? "active" : "inactive",
    tierRaw: row.membership_type ?? null,
    logoUrl: row.logo_url ?? null,
    category: row.category ?? null,
  };
}

const MEMBER_PAGE_MAX = 50;
const MEMBER_PAGE_DEFAULT = 20;

// Public sort keys -> chamber_members columns.
const MEMBER_SORT_COLUMNS: Record<string, string> = {
  name: "display_name",
  email: "email",
  tier: "membership_type",
  status: "status",
};

// Inactive members are queryable on purpose (staff sometimes need to look up
// a lapsed member), but only when asked for: `status` defaults to `active`,
// matching this endpoint's behavior before the param existed.
const MEMBER_STATUS_FILTERS = new Set(["active", "inactive", "all"]);

type MemberListParams = {
  search: string;
  tier: string | null;
  status: string;
  sortColumn: string;
  ascending: boolean;
  limit: number;
  offset: number;
};

function parseIntParam(
  url: URL,
  name: string,
  fallback: number,
  min: number,
  max: number,
): number | null {
  const raw = url.searchParams.get(name);
  if (raw === null || raw.trim() === "") return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < min) return null;
  return Math.min(value, max);
}

function parseMemberListParams(url: URL): MemberListParams | string {
  const status = url.searchParams.get("status") || "active";
  if (!MEMBER_STATUS_FILTERS.has(status)) {
    return "status must be one of: active, inactive, all.";
  }
  const sort = url.searchParams.get("sort") || "name";
  const sortColumn = MEMBER_SORT_COLUMNS[sort];
  if (!sortColumn) {
    return `sort must be one of: ${Object.keys(MEMBER_SORT_COLUMNS).join(", ")}.`;
  }
  const order = url.searchParams.get("order") || "asc";
  if (order !== "asc" && order !== "desc") {
    return "order must be asc or desc.";
  }
  const limit = parseIntParam(url, "limit", MEMBER_PAGE_DEFAULT, 1, MEMBER_PAGE_MAX);
  if (limit === null) return "limit must be a positive integer.";
  const offset = parseIntParam(url, "offset", 0, 0, Number.MAX_SAFE_INTEGER);
  if (offset === null) return "offset must be a non-negative integer.";

  return {
    search: (url.searchParams.get("search") ?? "").trim(),
    tier: url.searchParams.get("tier")?.trim() || null,
    status,
    sortColumn,
    ascending: order === "asc",
    limit,
    offset,
  };
}

// PostgREST `or=(...)` filters are comma/paren-delimited, so a raw search like
// "Grill, Inc." would break the filter. Double-quote the value instead.
function quoteFilterValue(value: string): string {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

// Search + status filters shared by the page query and the tier facet query.
// The tier filter is applied separately so facet counts ignore it.
function filteredMembersQuery(
  supabase: ReturnType<typeof supabaseAdmin>,
  columns: string,
  params: MemberListParams,
  options?: { count: "exact" },
) {
  let query = supabase.from("chamber_members").select(columns, options);

  if (params.status === "active") {
    query = query.eq("status", ACTIVE_MEMBER_STATUS);
  } else if (params.status === "inactive") {
    query = query.neq("status", ACTIVE_MEMBER_STATUS);
  }

  if (params.search) {
    const asNumber = Number(params.search);
    if (Number.isInteger(asNumber)) {
      query = query.eq("cm_id", asNumber);
    } else {
      const pattern = quoteFilterValue(`%${params.search}%`);
      query = query.or(
        `name.ilike.${pattern},display_name.ilike.${pattern},email.ilike.${pattern}`,
      );
    }
  }

  return query;
}

async function handleListMembers(url: URL): Promise<Response> {
  const params = parseMemberListParams(url);
  if (typeof params === "string") {
    return jsonResponse({ error: params }, 400);
  }
  const supabase = supabaseAdmin();

  let pageQuery = filteredMembersQuery(
    supabase,
    "cm_id, name, display_name, email, status, membership_type, logo_url, category",
    params,
    { count: "exact" },
  );
  if (params.tier) {
    pageQuery = pageQuery.eq("membership_type", params.tier);
  }
  // cm_id tiebreaker keeps page boundaries stable across offset requests.
  pageQuery = pageQuery
    .order(params.sortColumn, { ascending: params.ascending, nullsFirst: false })
    .order("cm_id", { ascending: true })
    .range(params.offset, params.offset + params.limit - 1);

  // Tier facet counts for the current search/status. The roster is a few
  // hundred rows, so fetching one column and counting here is cheap; move this
  // to a GROUP BY rpc if it ever approaches PostgREST's max_rows (1000).
  const tierQuery = filteredMembersQuery(supabase, "membership_type", params, {
    count: "exact",
  });

  const [page, tierRows] = await Promise.all([pageQuery, tierQuery]);
  if (tierRows.error) throw tierRows.error;
  let rows = (page.data ?? []) as unknown as Record<string, unknown>[];
  let total = page.count ?? 0;
  if (page.error?.code === "PGRST103") {
    // Offset past the end (e.g. the roster shrank while paging): PostgREST
    // answers 416, but callers should just see an empty page + real total.
    let countQuery = filteredMembersQuery(supabase, "cm_id", params, { count: "exact" });
    if (params.tier) countQuery = countQuery.eq("membership_type", params.tier);
    const counted = await countQuery.limit(1);
    if (counted.error) throw counted.error;
    rows = [];
    total = counted.count ?? 0;
  } else if (page.error) {
    throw page.error;
  }

  const tierCounts = new Map<string, number>();
  const facetRows = (tierRows.data ?? []) as unknown as Record<string, unknown>[];
  for (const row of facetRows) {
    const tier = row.membership_type as string | null;
    if (tier) tierCounts.set(tier, (tierCounts.get(tier) ?? 0) + 1);
  }
  const totalAllTiers = tierRows.count ?? facetRows.length;
  if (facetRows.length < totalAllTiers) {
    console.warn(
      `staff members: tier facets truncated (${facetRows.length}/${totalAllTiers} rows)`,
    );
  }

  return jsonResponse({
    members: rows.map(mapMemberSummary),
    total,
    limit: params.limit,
    offset: params.offset,
    // Count across all tiers (incl. untiered) for the current search/status.
    totalAllTiers,
    tiers: [...tierCounts]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([tier, count]) => ({ tier, count })),
  });
}

async function handleGetMember(cmId: number): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data: member, error } = await supabase
    .from("chamber_members")
    .select(
      "cm_id, name, display_name, email, status, membership_type, membership_established, logo_url, category, short_description, website_url, phone, address, address_public",
    )
    .eq("cm_id", cmId)
    .maybeSingle();
  if (error) throw error;
  if (!member) {
    return jsonResponse({ error: "Member not found." }, 404);
  }

  // membership_tier_code() returns a plain scalar, not a row set -- do not
  // chain .single() here, it expects a table-shaped result and will error.
  const { data: tier, error: tierError } = await supabase
    .rpc("membership_tier_code", { raw_tier: member.membership_type });
  if (tierError) throw tierError;
  const tierCode = typeof tier === "string" ? tier : null;

  // Staff always get the stored address, even when address_public is false.
  // member-auth GET business hides it from non-owners; this endpoint does not.
  return jsonResponse({
    member: {
      ...mapMemberSummary(member),
      tierCode,
      memberSince: member.membership_established ?? null,
      shortDescription: member.short_description ?? null,
      websiteUrl: member.website_url ?? null,
      phone: member.phone ?? null,
      address: member.address ?? null,
      addressPublic: member.address_public !== false,
    },
  });
}

async function handleGetMemberBenefits(cmId: number): Promise<Response> {
  const supabase = supabaseAdmin();

  const { data: member, error: memberError } = await supabase
    .from("chamber_members")
    .select("cm_id, membership_type")
    .eq("cm_id", cmId)
    .maybeSingle();
  if (memberError) throw memberError;
  if (!member) {
    return jsonResponse({ error: "Member not found." }, 404);
  }

  // Idempotent -- safe to call on every read. Materializes this member's
  // entitlements for their current benefit period if they don't already
  // exist. Members on a non-entitlement-bearing tier (Municipality, Chamber
  // of Commerce) generate zero rows, by design.
  const { error: genError } = await supabase.rpc("generate_entitlements", {
    p_cm_id: cmId,
    p_period_start: null,
    p_period_end: null,
  });
  if (genError) throw genError;

  const { data: entitlements, error: entError } = await supabase
    .from("benefit_entitlements")
    .select(
      "id, benefit_code, tier_code_snapshot, period_start, period_end, allowance_quantity, a_la_carte_price_cents, source, note",
    )
    .eq("cm_id", cmId)
    .order("period_start", { ascending: false });
  if (entError) throw entError;

  if (!entitlements || entitlements.length === 0) {
    return jsonResponse({ cmId, benefits: [] });
  }

  const entitlementIds = entitlements.map((e) => e.id as string);
  const benefitCodes = [...new Set(entitlements.map((e) => e.benefit_code as string))];

  const [{ data: catalogRows, error: catalogError }, { data: fulfillments, error: fulfillError }] =
    await Promise.all([
      supabase
        .from("benefit_catalog")
        .select("code, name, category, tracking_mode")
        .in("code", benefitCodes),
      supabase
        .from("benefit_fulfillments")
        .select(
          "id, entitlement_id, status, source, quantity_used, occurred_on, staff_owner_email, member_visible, member_visible_summary, unit_price_cents, external_invoice_reference, created_at",
        )
        .in("entitlement_id", entitlementIds)
        .order("created_at", { ascending: false }),
    ]);
  if (catalogError) throw catalogError;
  if (fulfillError) throw fulfillError;

  const catalogByCode = new Map(
    (catalogRows ?? []).map((c) => [c.code as string, c]),
  );
  const fulfillmentsByEntitlement = new Map<string, typeof fulfillments>();
  for (const f of fulfillments ?? []) {
    const key = f.entitlement_id as string;
    const list = fulfillmentsByEntitlement.get(key) ?? [];
    list.push(f);
    fulfillmentsByEntitlement.set(key, list);
  }

  const benefits = entitlements.map((ent) => {
    const catalog = catalogByCode.get(ent.benefit_code as string);
    const entFulfillments = fulfillmentsByEntitlement.get(ent.id as string) ?? [];

    const used = entFulfillments
      .filter((f) =>
        f.source === "allowance" && !NON_CONSUMING_STATUSES.has(f.status as string)
      )
      .reduce((sum, f) => sum + (Number(f.quantity_used) || 0), 0);

    const allowance = ent.allowance_quantity as number | null;
    const remaining = allowance === null ? null : Math.max(allowance - used, 0);

    return {
      entitlementId: ent.id,
      benefitCode: ent.benefit_code,
      name: catalog?.name ?? ent.benefit_code,
      category: catalog?.category ?? null,
      trackingMode: catalog?.tracking_mode ?? null,
      periodStart: ent.period_start,
      periodEnd: ent.period_end,
      allowanceQuantity: allowance,
      aLaCartePriceCents: ent.a_la_carte_price_cents,
      used,
      remaining,
      fulfillments: entFulfillments.map((f) => ({
        id: f.id,
        status: f.status,
        source: f.source,
        quantityUsed: f.quantity_used,
        occurredOn: f.occurred_on,
        staffOwnerEmail: f.staff_owner_email,
        memberVisible: f.member_visible,
        memberVisibleSummary: f.member_visible_summary,
        unitPriceCents: f.unit_price_cents,
        externalInvoiceReference: f.external_invoice_reference,
        createdAt: f.created_at,
      })),
    };
  });

  return jsonResponse({ cmId, benefits });
}

const BENEFITS_TREND_MONTHS = 6;
// Statuses that represent delivered value, for the dashboard's monthly
// trend -- a raw count of touched records (including "declined") would
// overstate what members actually got.
const DELIVERED_STATUSES = ["completed", "redeemed"];

function monthKey(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

/**
 * Org-wide benefit-fulfillment aggregate for the Dashboard: how much of
 * members' current-period allowances have actually been used, how many
 * benefits were delivered per month over the trailing window, and the same
 * used/allowance split broken out per membership tier. See README
 * "Dashboard data honesty" -- this is what backs the fulfillment card
 * instead of a ComingSoon placeholder.
 */
async function handleBenefitsSummary(): Promise<Response> {
  const supabase = supabaseAdmin();
  const now = new Date();
  const today = now.toISOString().slice(0, 10);
  const trendStart = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (BENEFITS_TREND_MONTHS - 1), 1),
  );
  // This-month-vs-last-month window for the per-tier bars -- covers exactly
  // the two calendar months the chart compares, so one query serves both.
  const thisMonthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const lastMonthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
  const thisMonthKey = monthKey(thisMonthStart);
  const lastMonthKey = monthKey(lastMonthStart);

  const [entRes, trendRes, periodRes, tiersRes] = await Promise.all([
    // Entitlements whose current period covers today and that carry a real
    // allowance -- unlimited/à-la-carte entitlements (null allowance) have
    // no denominator and are excluded, same as the per-member card.
    supabase
      .from("benefit_entitlements")
      .select("id, allowance_quantity")
      .lte("period_start", today)
      .gte("period_end", today)
      .not("allowance_quantity", "is", null),
    supabase
      .from("benefit_fulfillments")
      .select("occurred_on")
      .gte("occurred_on", trendStart.toISOString().slice(0, 10))
      .in("status", DELIVERED_STATUSES),
    // Delivered fulfillments across this month and last month, joined to
    // their entitlement's tier_code_snapshot -- the point-in-time tier the
    // entitlement was generated under, the right key for a per-tier
    // breakdown since a member's current tier can drift from what a past
    // period used. Every source counts here (not just "allowance"), since
    // this is about delivered volume, not allowance drawdown.
    supabase
      .from("benefit_fulfillments")
      .select("occurred_on, benefit_entitlements!inner(tier_code_snapshot)")
      .gte("occurred_on", lastMonthStart.toISOString().slice(0, 10))
      .in("status", DELIVERED_STATUSES),
    // Small, static-ish table -- just for display_name/display_order so the
    // per-tier rows below sort and label the same way the rest of the app
    // does, without duplicating that mapping here.
    supabase.from("membership_tiers").select("code, display_name, display_order"),
  ]);
  if (entRes.error) throw entRes.error;
  if (trendRes.error) throw trendRes.error;
  if (periodRes.error) throw periodRes.error;
  if (tiersRes.error) throw tiersRes.error;

  const entitlements = entRes.data ?? [];
  const entitlementIds = entitlements.map((e) => e.id as string);
  const totalAllowance = entitlements.reduce(
    (sum, e) => sum + (Number(e.allowance_quantity) || 0),
    0,
  );

  let totalUsed = 0;
  if (entitlementIds.length > 0) {
    const { data: usage, error: usageError } = await supabase
      .from("benefit_fulfillments")
      .select("quantity_used, status")
      .in("entitlement_id", entitlementIds)
      .eq("source", "allowance");
    if (usageError) throw usageError;
    for (const f of usage ?? []) {
      if (NON_CONSUMING_STATUSES.has(f.status as string)) continue;
      totalUsed += Number(f.quantity_used) || 0;
    }
  }

  const tierMeta = new Map(
    (tiersRes.data ?? []).map((t) => [
      t.code as string,
      { label: (t.display_name as string) ?? (t.code as string), order: Number(t.display_order) || 0 },
    ]),
  );

  const tierThisMonth = new Map<string, number>();
  const tierLastMonth = new Map<string, number>();
  for (const row of periodRes.data ?? []) {
    const occurred = typeof row.occurred_on === "string" ? row.occurred_on : "";
    const key = occurred.slice(0, 7);
    if (key !== thisMonthKey && key !== lastMonthKey) continue;
    const tier =
      (row.benefit_entitlements as { tier_code_snapshot?: string } | null)?.tier_code_snapshot ?? "";
    const target = key === thisMonthKey ? tierThisMonth : tierLastMonth;
    target.set(tier, (target.get(tier) ?? 0) + 1);
  }
  // Every known tier gets a row -- not just ones with activity in either
  // month -- so a quiet tier still renders as a zero bar instead of
  // disappearing from the chart. Union in any stray tier codes that show up
  // on fulfillments but aren't in membership_tiers (e.g. a legacy/blank
  // tier_code_snapshot) so their counts aren't silently dropped.
  const allTierCodes = new Set([...tierMeta.keys(), ...tierThisMonth.keys(), ...tierLastMonth.keys()]);
  const byTier = [...allTierCodes]
    .map((tier) => ({
      tier,
      tierLabel: tierMeta.get(tier)?.label ?? tier,
      current: tierThisMonth.get(tier) ?? 0,
      previous: tierLastMonth.get(tier) ?? 0,
    }))
    .sort((a, b) => (tierMeta.get(a.tier)?.order ?? 99) - (tierMeta.get(b.tier)?.order ?? 99));

  // Trailing N months, oldest first, zero-filled so a quiet month still
  // renders as a point on the line rather than a gap.
  const buckets = new Map<string, number>();
  for (let i = 0; i < BENEFITS_TREND_MONTHS; i++) {
    const d = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (BENEFITS_TREND_MONTHS - 1 - i), 1),
    );
    buckets.set(monthKey(d), 0);
  }
  for (const row of trendRes.data ?? []) {
    const occurred = typeof row.occurred_on === "string" ? row.occurred_on : "";
    const key = occurred.slice(0, 7);
    if (buckets.has(key)) buckets.set(key, (buckets.get(key) ?? 0) + 1);
  }

  return jsonResponse({
    utilizationRate: totalAllowance > 0 ? totalUsed / totalAllowance : null,
    totalUsed,
    totalAllowance,
    monthlyFulfillments: [...buckets.entries()].map(([month, count]) => ({ month, count })),
    byTier,
  });
}

const ACTIVITY_PAGE_MAX = 50;
const ACTIVITY_PAGE_DEFAULT = 10;

/**
 * A staff member's own recent benefit actions, for the Dashboard's Activity
 * feed alongside their lead events. Every `benefit_fulfillments` row is
 * itself a discrete recorded action (there's no update endpoint -- see
 * handleCreateFulfillment), so unlike the summary's DELIVERED_STATUSES
 * filter, every status counts here: "declined" and "scheduled" are staff
 * actions worth showing, not just "completed"/"redeemed".
 */
async function handleBenefitActivity(url: URL): Promise<Response> {
  const owner = (url.searchParams.get("owner") ?? "").trim();
  if (!owner) {
    return jsonResponse({ error: "owner is required." }, 400);
  }
  const limit = parseIntParam(url, "limit", ACTIVITY_PAGE_DEFAULT, 1, ACTIVITY_PAGE_MAX);
  if (limit === null) {
    return jsonResponse({ error: "limit must be a positive integer." }, 400);
  }

  const supabase = supabaseAdmin();

  const { data: fulfillments, error: fulfillError } = await supabase
    .from("benefit_fulfillments")
    .select("id, entitlement_id, status, source, quantity_used, occurred_on, member_visible, created_at, staff_owner_email")
    .eq("staff_owner_email", owner)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (fulfillError) throw fulfillError;

  if (!fulfillments || fulfillments.length === 0) {
    return jsonResponse({ activity: [] });
  }

  const entitlementIds = [...new Set(fulfillments.map((f) => f.entitlement_id as string))];
  const { data: entitlements, error: entError } = await supabase
    .from("benefit_entitlements")
    .select("id, cm_id, benefit_code")
    .in("id", entitlementIds);
  if (entError) throw entError;

  const entitlementById = new Map((entitlements ?? []).map((e) => [e.id as string, e]));
  const cmIds = [...new Set((entitlements ?? []).map((e) => e.cm_id as number))];
  const benefitCodes = [...new Set((entitlements ?? []).map((e) => e.benefit_code as string))];

  const [{ data: members, error: memberError }, { data: catalogRows, error: catalogError }] =
    await Promise.all([
      cmIds.length > 0
        ? supabase.from("chamber_members").select("cm_id, name, display_name, logo_url").in("cm_id", cmIds)
        : Promise.resolve({ data: [], error: null }),
      benefitCodes.length > 0
        ? supabase.from("benefit_catalog").select("code, name").in("code", benefitCodes)
        : Promise.resolve({ data: [], error: null }),
    ]);
  if (memberError) throw memberError;
  if (catalogError) throw catalogError;

  const memberByCmId = new Map((members ?? []).map((m) => [m.cm_id as number, m]));
  const catalogByCode = new Map((catalogRows ?? []).map((c) => [c.code as string, c]));

  const activity = fulfillments.map((f) => {
    const entitlement = entitlementById.get(f.entitlement_id as string);
    const member = entitlement ? memberByCmId.get(entitlement.cm_id as number) : undefined;
    const catalog = entitlement ? catalogByCode.get(entitlement.benefit_code as string) : undefined;
    return {
      id: f.id,
      cmId: entitlement?.cm_id ?? null,
      companyName: (member?.display_name as string) || (member?.name as string) || null,
      companyLogoUrl: (member?.logo_url as string) ?? null,
      benefitCode: entitlement?.benefit_code ?? null,
      benefitName: (catalog?.name as string) ?? entitlement?.benefit_code ?? null,
      status: f.status,
      source: f.source,
      quantityUsed: f.quantity_used,
      occurredOn: f.occurred_on,
      memberVisible: f.member_visible,
      createdAt: f.created_at,
      actorEmail: (f.staff_owner_email as string) ?? null,
    };
  });

  return jsonResponse({ activity });
}

async function handleCreateFulfillment(
  auth: AuthContext,
  cmId: number,
  entitlementId: string,
  req: Request,
): Promise<Response> {
  const supabase = supabaseAdmin();

  const { data: entitlement, error: entError } = await supabase
    .from("benefit_entitlements")
    .select("id, cm_id")
    .eq("id", entitlementId)
    .eq("cm_id", cmId)
    .maybeSingle();
  if (entError) throw entError;
  if (!entitlement) {
    return jsonResponse({ error: "Entitlement not found for this member." }, 404);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const status = typeof body.status === "string" ? body.status : "";
  if (!FULFILLMENT_STATUSES.has(status)) {
    return jsonResponse(
      { error: `Invalid status. Allowed: ${[...FULFILLMENT_STATUSES].join(", ")}` },
      400,
    );
  }

  const source = typeof body.source === "string" && body.source
    ? body.source
    : "allowance";
  if (!FULFILLMENT_SOURCES.has(source)) {
    return jsonResponse(
      { error: `Invalid source. Allowed: ${[...FULFILLMENT_SOURCES].join(", ")}` },
      400,
    );
  }

  const quantityUsed = Number.isFinite(Number(body.quantityUsed))
    ? Math.max(Math.trunc(Number(body.quantityUsed)), 0)
    : 1;

  const insertRow = {
    entitlement_id: entitlementId,
    status,
    source,
    quantity_used: quantityUsed,
    occurred_on: typeof body.occurredOn === "string" && body.occurredOn
      ? body.occurredOn
      : new Date().toISOString().slice(0, 10),
    staff_owner_email: typeof body.staffOwnerEmail === "string" && body.staffOwnerEmail
      ? body.staffOwnerEmail
      : auth.email,
    member_visible: body.memberVisible === true,
    member_visible_summary: typeof body.memberVisibleSummary === "string"
      ? body.memberVisibleSummary
      : null,
    internal_notes: typeof body.internalNotes === "string" ? body.internalNotes : null,
    unit_price_cents: Number.isFinite(Number(body.unitPriceCents))
      ? Math.trunc(Number(body.unitPriceCents))
      : null,
    external_invoice_reference:
      typeof body.externalInvoiceReference === "string"
        ? body.externalInvoiceReference
        : null,
    evidence_url: typeof body.evidenceUrl === "string" ? body.evidenceUrl : null,
  };

  const { data: created, error: insertError } = await supabase
    .from("benefit_fulfillments")
    .insert(insertRow)
    .select(
      "id, entitlement_id, status, source, quantity_used, occurred_on, staff_owner_email, member_visible, member_visible_summary, unit_price_cents, external_invoice_reference, created_at",
    )
    .single();
  if (insertError) throw insertError;

  return jsonResponse({
    fulfillment: {
      id: created.id,
      entitlementId: created.entitlement_id,
      status: created.status,
      source: created.source,
      quantityUsed: created.quantity_used,
      occurredOn: created.occurred_on,
      staffOwnerEmail: created.staff_owner_email,
      memberVisible: created.member_visible,
      memberVisibleSummary: created.member_visible_summary,
      unitPriceCents: created.unit_price_cents,
      externalInvoiceReference: created.external_invoice_reference,
      createdAt: created.created_at,
    },
  }, 201);
}

const STAFF_USER_PAGE_MAX = 50;
const STAFF_USER_PAGE_DEFAULT = 25;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function mapStaffUser(
  profile: { email: string; cmId: number | null },
  member: Record<string, unknown> | undefined,
) {
  const name = (member?.display_name as string) || (member?.name as string) ||
    profile.email.split("@")[0];
  return {
    email: profile.email,
    name,
    logoUrl: (member?.logo_url as string) ?? null,
  };
}

/**
 * Chamber-staff accounts searchable for the Settings "add teammate" control
 * (#42). Staff accounts are few (a handful of admins), so this fetches
 * every is_chamber_admin profile and filters/paginates in memory rather
 * than fighting PostgREST's lack of cross-table OR filters -- unlike
 * /members this never needs to scale past a few dozen rows.
 */
async function handleListStaffUsers(url: URL): Promise<Response> {
  const limit = parseIntParam(url, "limit", STAFF_USER_PAGE_DEFAULT, 1, STAFF_USER_PAGE_MAX);
  if (limit === null) return jsonResponse({ error: "limit must be a positive integer." }, 400);
  const offset = parseIntParam(url, "offset", 0, 0, Number.MAX_SAFE_INTEGER);
  if (offset === null) return jsonResponse({ error: "offset must be a non-negative integer." }, 400);
  const search = (url.searchParams.get("search") ?? "").trim().toLowerCase();

  const supabase = supabaseAdmin();
  const { data: profiles, error: profileError } = await supabase
    .from("app_profiles")
    .select("email, cm_id")
    .eq("is_chamber_admin", true);
  if (profileError) throw profileError;

  const cmIds = [
    ...new Set(
      (profiles ?? [])
        .map((p) => p.cm_id as number | null)
        .filter((id): id is number => id != null),
    ),
  ];
  const { data: members, error: memberError } = cmIds.length > 0
    ? await supabase.from("chamber_members").select("cm_id, name, display_name, logo_url").in(
      "cm_id",
      cmIds,
    )
    : { data: [] as Record<string, unknown>[], error: null };
  if (memberError) throw memberError;
  const memberByCmId = new Map((members ?? []).map((m) => [m.cm_id as number, m]));

  let users = (profiles ?? []).map((p) =>
    mapStaffUser(
      { email: p.email as string, cmId: (p.cm_id as number | null) ?? null },
      p.cm_id != null ? memberByCmId.get(p.cm_id as number) : undefined,
    )
  );

  if (search) {
    users = users.filter(
      (u) => u.email.toLowerCase().includes(search) || u.name.toLowerCase().includes(search),
    );
  }
  users.sort((a, b) => a.name.localeCompare(b.name) || a.email.localeCompare(b.email));

  const total = users.length;
  const page = users.slice(offset, offset + limit);

  return jsonResponse({ staffUsers: page, total, limit, offset });
}

/**
 * Resolves a set of emails against the staff-account roster (same lookup as
 * /staff-users) so admin_team_members rows -- which may reference a bare
 * email that isn't a chamber-staff account yet -- get a real name/logo when
 * one is available.
 */
async function resolveStaffDisplay(
  supabase: ReturnType<typeof supabaseAdmin>,
  emails: string[],
): Promise<Map<string, { name: string; logoUrl: string | null }>> {
  if (emails.length === 0) return new Map();
  const { data: profiles, error: profileError } = await supabase
    .from("app_profiles")
    .select("email, cm_id")
    .eq("is_chamber_admin", true)
    .in("email", emails);
  if (profileError) throw profileError;

  const cmIds = [
    ...new Set(
      (profiles ?? [])
        .map((p) => p.cm_id as number | null)
        .filter((id): id is number => id != null),
    ),
  ];
  const { data: members, error: memberError } = cmIds.length > 0
    ? await supabase.from("chamber_members").select("cm_id, name, display_name, logo_url").in(
      "cm_id",
      cmIds,
    )
    : { data: [] as Record<string, unknown>[], error: null };
  if (memberError) throw memberError;
  const memberByCmId = new Map((members ?? []).map((m) => [m.cm_id as number, m]));

  const resolved = new Map<string, { name: string; logoUrl: string | null }>();
  for (const p of profiles ?? []) {
    const member = p.cm_id != null ? memberByCmId.get(p.cm_id as number) : undefined;
    const name = (member?.display_name as string) || (member?.name as string) ||
      (p.email as string).split("@")[0];
    resolved.set((p.email as string).toLowerCase(), {
      name,
      logoUrl: (member?.logo_url as string) ?? null,
    });
  }
  return resolved;
}

function mapTeamMember(
  row: { member_email: string; display_name: string | null },
  staffByEmail: Map<string, { name: string; logoUrl: string | null }>,
) {
  const staff = staffByEmail.get(row.member_email.toLowerCase());
  return {
    email: row.member_email,
    name: staff?.name ?? row.display_name ?? row.member_email.split("@")[0],
    logoUrl: staff?.logoUrl ?? null,
    isStaffAccount: staff !== undefined,
  };
}

/** The admin's own curated teammate roster (#43). */
async function handleListTeam(auth: AuthContext): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data: rows, error } = await supabase
    .from("admin_team_members")
    .select("member_email, display_name")
    .eq("admin_email", auth.email);
  if (error) throw error;

  const staffByEmail = await resolveStaffDisplay(
    supabase,
    (rows ?? []).map((r) => r.member_email as string),
  );
  const team = (rows ?? [])
    .map((r) =>
      mapTeamMember(
        { member_email: r.member_email as string, display_name: r.display_name as string | null },
        staffByEmail,
      )
    )
    .sort((a, b) => a.name.localeCompare(b.name));

  return jsonResponse({ team });
}

/** Add a teammate to the caller's roster. 409s on a duplicate (#43). */
async function handleAddTeamMember(auth: AuthContext, req: Request): Promise<Response> {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  if (!EMAIL_RE.test(email)) {
    return jsonResponse({ error: "A valid email is required." }, 400);
  }
  const displayName = typeof body.displayName === "string" && body.displayName.trim()
    ? body.displayName.trim()
    : null;

  const supabase = supabaseAdmin();
  const { data: inserted, error } = await supabase
    .from("admin_team_members")
    .insert({ admin_email: auth.email, member_email: email, display_name: displayName })
    .select("member_email, display_name")
    .single();
  if (error) {
    if (error.code === "23505") {
      return jsonResponse({ error: "Already on your team." }, 409);
    }
    throw error;
  }

  const staffByEmail = await resolveStaffDisplay(supabase, [email]);
  const member = mapTeamMember(
    {
      member_email: inserted.member_email as string,
      display_name: inserted.display_name as string | null,
    },
    staffByEmail,
  );
  return jsonResponse({ member }, 201);
}

/** Remove a teammate from the caller's roster. Idempotent. */
async function handleRemoveTeamMember(auth: AuthContext, email: string): Promise<Response> {
  const supabase = supabaseAdmin();
  const { error } = await supabase
    .from("admin_team_members")
    .delete()
    .eq("admin_email", auth.email)
    .eq("member_email", email.trim().toLowerCase());
  if (error) throw error;
  return jsonResponse({ ok: true });
}

async function handleRequest(req: Request): Promise<Response> {
  try {
    const url = new URL(req.url);
    const parts = pathParts(url.pathname);
    const auth = await requireStaffAuth(req);

    // GET /members?search=&tier=&status=&sort=&order=&limit=&offset=
    if (req.method === "GET" && parts.length === 1 && parts[0] === "members") {
      requireStaffAccess(auth);
      return await handleListMembers(url);
    }

    // GET /benefits/summary -- org-wide utilization rate + monthly trend for the Dashboard.
    if (req.method === "GET" && parts.length === 2 && parts[0] === "benefits" && parts[1] === "summary") {
      requireStaffAccess(auth);
      return await handleBenefitsSummary();
    }

    // GET /activity/benefits?owner=&limit= -- a staff member's own recent
    // benefit actions, for the Dashboard's Activity feed.
    if (
      req.method === "GET" && parts.length === 2 && parts[0] === "activity" && parts[1] === "benefits"
    ) {
      requireStaffAccess(auth);
      return await handleBenefitActivity(url);
    }

    // GET /members/:cmId -- staff can read any member; a business member may
    // read their own record (the web app's "My business" page).
    if (
      req.method === "GET" && parts.length === 2 && parts[0] === "members"
    ) {
      const cmId = Number(parts[1]);
      if (!Number.isInteger(cmId)) {
        return jsonResponse({ error: "Invalid member id." }, 400);
      }
      requireMemberAccess(auth, cmId);
      return await handleGetMember(cmId);
    }

    // GET /members/:cmId/benefits -- same access as above.
    if (
      req.method === "GET" &&
      parts.length === 3 &&
      parts[0] === "members" &&
      parts[2] === "benefits"
    ) {
      const cmId = Number(parts[1]);
      if (!Number.isInteger(cmId)) {
        return jsonResponse({ error: "Invalid member id." }, 400);
      }
      requireMemberAccess(auth, cmId);
      return await handleGetMemberBenefits(cmId);
    }

    // POST /members/:cmId/benefits/:entitlementId/fulfillment -- recording
    // activity stays staff-only.
    if (
      req.method === "POST" &&
      parts.length === 5 &&
      parts[0] === "members" &&
      parts[2] === "benefits" &&
      parts[4] === "fulfillment"
    ) {
      requireStaffAccess(auth);
      const cmId = Number(parts[1]);
      if (!Number.isInteger(cmId)) {
        return jsonResponse({ error: "Invalid member id." }, 400);
      }
      return await handleCreateFulfillment(auth, cmId, parts[3], req);
    }

    // GET /staff-users?search=&limit=&offset= -- chamber-staff accounts
    // searchable for the Settings "add teammate" control (#42).
    if (req.method === "GET" && parts.length === 1 && parts[0] === "staff-users") {
      requireStaffAccess(auth);
      return await handleListStaffUsers(url);
    }

    // GET /team -- the admin's own curated teammate roster (#43).
    if (req.method === "GET" && parts.length === 1 && parts[0] === "team") {
      requireStaffAccess(auth);
      return await handleListTeam(auth);
    }

    // POST /team { email, displayName? } -- add a teammate to the roster.
    if (req.method === "POST" && parts.length === 1 && parts[0] === "team") {
      requireStaffAccess(auth);
      return await handleAddTeamMember(auth, req);
    }

    // DELETE /team/:email -- remove a teammate from the roster.
    if (req.method === "DELETE" && parts.length === 2 && parts[0] === "team") {
      requireStaffAccess(auth);
      return await handleRemoveTeamMember(auth, decodeURIComponent(parts[1]));
    }

    return jsonResponse({ error: "Not found." }, 404);
  } catch (error) {
    const status = typeof (error as { status?: number }).status === "number"
      ? (error as { status: number }).status
      : 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    console.error("staff error:", message);
    return jsonResponse({ error: message }, status);
  }
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get("origin"));

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  const response = await handleRequest(req);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(cors)) {
    headers.set(key, value);
  }
  return new Response(response.body, { status: response.status, headers });
});
