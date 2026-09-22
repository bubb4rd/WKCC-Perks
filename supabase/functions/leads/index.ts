import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

// Staff-only lead inbox for the Member Success Hub. Auth matches `staff`:
// bearer access token + app_profiles.is_chamber_admin. Does not yet check
// staff_roles.lead_coordinator; every chamber admin has full access for now.

const ALLOWED_ORIGINS = new Set([
  "http://localhost:5173",
  "https://benefitswkcc.netlify.app", // placeholder -- update once the real subdomain is chosen
]);

function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
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

const STATUSES = [
  "new",
  "contacted",
  "qualified",
  "nurture",
  "won",
  "lost",
] as const;
const STATUS_SET = new Set<string>(STATUSES);
const OPEN_STATUSES = ["new", "contacted", "qualified", "nurture"] as const;

const SOURCES = [
  "staff_manual",
  "website",
  "event",
  "member_referral",
  "other",
] as const;
const SOURCE_SET = new Set<string>(SOURCES);

const ACTIVITY_KINDS = ["note", "status_change", "assignment", "follow_up"] as const;

const LEAD_PAGE_MAX = 50;
const LEAD_PAGE_DEFAULT = 25;

const SORT_COLUMNS: Record<string, string> = {
  company: "company_name",
  contact: "contact_name",
  status: "status",
  source: "source",
  owner: "owner_email",
  created: "created_at",
  followUp: "next_follow_up_on",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const LEAD_COLUMNS =
  "id, status, source, company_name, contact_name, email, phone, owner_email, referring_cm_id, converted_cm_id, next_follow_up_on, lost_reason, won_at, lost_at, created_by, created_at, updated_at";

type AuthContext = { email: string };

type LeadRow = Record<string, unknown>;

type ListParams = {
  search: string;
  status: string | null;
  source: string | null;
  owner: string | null;
  sortColumn: string;
  ascending: boolean;
  limit: number;
  offset: number;
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
    .select("email, is_chamber_admin")
    .eq("email", email)
    .maybeSingle();
  if (error) throw error;

  if (profile?.is_chamber_admin !== true) {
    throw Object.assign(new Error("Staff access required."), { status: 403 });
  }

  return { email };
}

function pathParts(pathname: string): string[] {
  // Gateways pass either `/functions/v1/leads/...` or `/leads/...`. Strip the
  // function prefix the same way `staff` does — last `/leads` is the mount.
  const cleaned = pathname.replace(/\/+$/, "");
  const idx = cleaned.lastIndexOf("/leads");
  const rest = idx >= 0 ? cleaned.slice(idx + "/leads".length) : cleaned;
  return rest.split("/").filter(Boolean);
}

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

function blankToNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}

function optionalEmail(value: unknown): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim().toLowerCase();
  if (trimmed === "") return null;
  if (!trimmed.includes("@")) return undefined;
  return trimmed;
}

function optionalCmId(value: unknown): number | null | undefined {
  if (value === undefined) return undefined;
  if (value === null || value === "") return null;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 0) return undefined;
  return n;
}

function optionalDate(value: unknown): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null || value === "") return null;
  if (typeof value !== "string") return undefined;
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : undefined;
}

function mapLead(row: LeadRow) {
  return {
    id: row.id,
    status: row.status,
    source: row.source,
    companyName: row.company_name ?? null,
    contactName: row.contact_name ?? null,
    email: row.email ?? null,
    phone: row.phone ?? null,
    ownerEmail: row.owner_email ?? null,
    referringCmId: row.referring_cm_id ?? null,
    convertedCmId: row.converted_cm_id ?? null,
    nextFollowUpOn: row.next_follow_up_on ?? null,
    lostReason: row.lost_reason ?? null,
    wonAt: row.won_at ?? null,
    lostAt: row.lost_at ?? null,
    createdBy: row.created_by ?? null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapActivity(row: LeadRow) {
  return {
    id: row.id,
    leadId: row.lead_id,
    kind: row.kind,
    body: row.body ?? null,
    actorEmail: row.actor_email ?? null,
    occurredAt: row.occurred_at,
  };
}

/** Backend stores status_change bodies as raw `"{from} → {to}"` slugs (see `handlePatch`) -- parse them back into typed statuses for the cross-lead activity feed. */
function parseStatusChangeBody(
  body: string | null,
): { from: string | null; to: string | null } | null {
  if (!body) return null;
  const parts = body.split("→").map((s) => s.trim());
  if (parts.length !== 2) return null;
  const [from, to] = parts;
  return {
    from: STATUS_SET.has(from) ? from : null,
    to: STATUS_SET.has(to) ? to : null,
  };
}

function escapeIlike(value: string): string {
  return value.replace(/[%_,]/g, " ").trim();
}

function applyListFilters(
  // deno-lint-ignore no-explicit-any
  query: any,
  params: ListParams,
) {
  if (params.search) {
    const pattern = `%${escapeIlike(params.search)}%`;
    query = query.or(
      `company_name.ilike.${pattern},contact_name.ilike.${pattern},email.ilike.${pattern},phone.ilike.${pattern}`,
    );
  }
  if (params.status) query = query.eq("status", params.status);
  if (params.source) query = query.eq("source", params.source);
  if (params.owner === "unassigned") query = query.is("owner_email", null);
  else if (params.owner) query = query.eq("owner_email", params.owner);
  return query;
}

function parseListParams(url: URL): ListParams | string {
  const search = (url.searchParams.get("search") ?? "").trim();
  const statusRaw = (url.searchParams.get("status") ?? "").trim();
  const sourceRaw = (url.searchParams.get("source") ?? "").trim();
  const ownerRaw = (url.searchParams.get("owner") ?? "").trim().toLowerCase();
  const sortRaw = (url.searchParams.get("sort") ?? "created").trim();
  const orderRaw = (url.searchParams.get("order") ?? "desc").trim();

  if (statusRaw && statusRaw !== "all" && !STATUS_SET.has(statusRaw)) {
    return `Invalid status. Allowed: all, ${STATUSES.join(", ")}`;
  }
  if (sourceRaw && sourceRaw !== "all" && !SOURCE_SET.has(sourceRaw)) {
    return `Invalid source. Allowed: all, ${SOURCES.join(", ")}`;
  }
  if (!(sortRaw in SORT_COLUMNS)) {
    return `Invalid sort. Allowed: ${Object.keys(SORT_COLUMNS).join(", ")}`;
  }
  if (orderRaw !== "asc" && orderRaw !== "desc") {
    return "Invalid order. Allowed: asc, desc";
  }

  const limit = parseIntParam(url, "limit", LEAD_PAGE_DEFAULT, 1, LEAD_PAGE_MAX);
  const offset = parseIntParam(url, "offset", 0, 0, 100_000);
  if (limit === null || offset === null) return "Invalid limit or offset.";

  return {
    search,
    status: !statusRaw || statusRaw === "all" ? null : statusRaw,
    source: !sourceRaw || sourceRaw === "all" ? null : sourceRaw,
    owner: ownerRaw === "" || ownerRaw === "all" ? null : ownerRaw,
    sortColumn: SORT_COLUMNS[sortRaw],
    ascending: orderRaw === "asc",
    limit,
    offset,
  };
}

async function insertActivity(
  leadId: string,
  kind: (typeof ACTIVITY_KINDS)[number],
  body: string | null,
  actorEmail: string,
) {
  const supabase = supabaseAdmin();
  const { error } = await supabase.from("lead_activities").insert({
    lead_id: leadId,
    kind,
    body,
    actor_email: actorEmail,
  });
  if (error) throw error;
}

async function insertAudit(row: {
  actorEmail: string;
  action: string;
  resourceId: string;
  before?: unknown;
  after?: unknown;
}) {
  const supabase = supabaseAdmin();
  const { error } = await supabase.from("audit_events").insert({
    actor_email: row.actorEmail,
    actor_role: "admin",
    action: row.action,
    resource_type: "lead",
    resource_id: row.resourceId,
    before: row.before ?? null,
    after: row.after ?? null,
  });
  if (error) console.error("leads audit insert failed:", error.message);
}

async function handleList(url: URL): Promise<Response> {
  const params = parseListParams(url);
  if (typeof params === "string") return jsonResponse({ error: params }, 400);

  const supabase = supabaseAdmin();
  let pageQuery = applyListFilters(
    supabase.from("leads").select(LEAD_COLUMNS, { count: "exact" }),
    params,
  );
  pageQuery = pageQuery
    .order(params.sortColumn, { ascending: params.ascending, nullsFirst: false })
    .order("id", { ascending: true })
    .range(params.offset, params.offset + params.limit - 1);

  const page = await pageQuery;
  let rows = (page.data ?? []) as LeadRow[];
  let total = page.count ?? 0;
  if (page.error?.code === "PGRST103") {
    const counted = await applyListFilters(
      supabase.from("leads").select("id", { count: "exact" }),
      params,
    ).limit(1);
    if (counted.error) throw counted.error;
    rows = [];
    total = counted.count ?? 0;
  } else if (page.error) {
    throw page.error;
  }

  return jsonResponse({
    leads: rows.map(mapLead),
    total,
    limit: params.limit,
    offset: params.offset,
  });
}

async function handleSummary(): Promise<Response> {
  const supabase = supabaseAdmin();
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    .toISOString();
  const today = now.toISOString().slice(0, 10);

  const [openRes, newRes, wonRes, overdueRes, statusRes] = await Promise.all([
    supabase
      .from("leads")
      .select("id", { count: "exact", head: true })
      .in("status", [...OPEN_STATUSES]),
    supabase
      .from("leads")
      .select("id", { count: "exact", head: true })
      .gte("created_at", weekAgo),
    supabase
      .from("leads")
      .select("id", { count: "exact", head: true })
      .eq("status", "won")
      .gte("won_at", monthStart),
    supabase
      .from("leads")
      .select("id", { count: "exact", head: true })
      .in("status", [...OPEN_STATUSES])
      .lt("next_follow_up_on", today),
    // Full pipeline breakdown for the dashboard's status donut. Leads are a
    // low-volume table (a chamber's whole pipeline, not a transaction log),
    // so counting in JS beats a second round trip for a GROUP BY RPC.
    supabase.from("leads").select("status"),
  ]);

  for (const res of [openRes, newRes, wonRes, overdueRes, statusRes]) {
    if (res.error) throw res.error;
  }

  const byStatus: Record<string, number> = Object.fromEntries(
    STATUSES.map((s) => [s, 0]),
  );
  for (const row of statusRes.data ?? []) {
    if (typeof row.status === "string" && row.status in byStatus) {
      byStatus[row.status]++;
    }
  }

  return jsonResponse({
    open: openRes.count ?? 0,
    newLast7Days: newRes.count ?? 0,
    wonThisMonth: wonRes.count ?? 0,
    overdueFollowUps: overdueRes.count ?? 0,
    byStatus,
  });
}

/**
 * A staff member's own recent lead pipeline status changes across every
 * lead they own, for the Dashboard's Activity feed alongside their benefit
 * actions. Two queries rather than a PostgREST embed (matches this repo's
 * existing manual-join style, e.g. `staff`'s handleBenefitActivity): first
 * the owned lead ids + display fields, then the status_change rows for
 * those ids.
 */
async function handleActivity(url: URL): Promise<Response> {
  const ownerRaw = (url.searchParams.get("owner") ?? "").trim().toLowerCase();
  const owner = ownerRaw === "" || ownerRaw === "all" ? null : ownerRaw;
  const limit = parseIntParam(url, "limit", 10, 1, LEAD_PAGE_MAX);
  if (limit === null) {
    return jsonResponse({ error: "limit must be a positive integer." }, 400);
  }

  const supabase = supabaseAdmin();

  let leadQuery = supabase.from("leads").select("id, company_name, contact_name");
  if (owner === "unassigned") leadQuery = leadQuery.is("owner_email", null);
  else if (owner) leadQuery = leadQuery.eq("owner_email", owner);
  const { data: leadRows, error: leadError } = await leadQuery;
  if (leadError) throw leadError;

  if (!leadRows || leadRows.length === 0) {
    return jsonResponse({ activity: [] });
  }

  const leadById = new Map((leadRows as LeadRow[]).map((row) => [row.id as string, row]));

  const { data: activityRows, error: activityError } = await supabase
    .from("lead_activities")
    .select("id, lead_id, body, actor_email, occurred_at")
    .eq("kind", "status_change")
    .in("lead_id", [...leadById.keys()])
    .order("occurred_at", { ascending: false })
    .limit(limit);
  if (activityError) throw activityError;

  const activity = (activityRows ?? []).map((row) => {
    const lead = leadById.get(row.lead_id as string);
    const parsed = parseStatusChangeBody(row.body as string | null);
    return {
      id: row.id,
      leadId: row.lead_id,
      companyName: (lead?.company_name as string) ?? null,
      contactName: (lead?.contact_name as string) ?? null,
      fromStatus: parsed?.from ?? null,
      toStatus: parsed?.to ?? null,
      actorEmail: (row.actor_email as string) ?? null,
      occurredAt: row.occurred_at,
    };
  });

  return jsonResponse({ activity });
}

async function handleGet(id: string): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("leads")
    .select(LEAD_COLUMNS)
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  if (!data) return jsonResponse({ error: "Lead not found." }, 404);

  const activities = await supabase
    .from("lead_activities")
    .select("id, lead_id, kind, body, actor_email, occurred_at")
    .eq("lead_id", id)
    .order("occurred_at", { ascending: false });
  if (activities.error) throw activities.error;

  return jsonResponse({
    lead: mapLead(data as LeadRow),
    activities: (activities.data ?? []).map((row) => mapActivity(row as LeadRow)),
  });
}

async function handleCreate(auth: AuthContext, req: Request): Promise<Response> {
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const companyName = blankToNull(body.companyName);
  const contactName = blankToNull(body.contactName);
  if (!companyName && !contactName) {
    return jsonResponse(
      { error: "Provide a company name or a contact name." },
      400,
    );
  }

  const source = typeof body.source === "string" && body.source
    ? body.source
    : "staff_manual";
  if (!SOURCE_SET.has(source)) {
    return jsonResponse({ error: `Invalid source. Allowed: ${SOURCES.join(", ")}` }, 400);
  }

  const ownerEmail = optionalEmail(body.ownerEmail);
  if (body.ownerEmail !== undefined && ownerEmail === undefined) {
    return jsonResponse({ error: "Invalid ownerEmail." }, 400);
  }
  const referringCmId = optionalCmId(body.referringCmId);
  if (body.referringCmId !== undefined && referringCmId === undefined) {
    return jsonResponse({ error: "Invalid referringCmId." }, 400);
  }
  const nextFollowUpOn = optionalDate(body.nextFollowUpOn);
  if (body.nextFollowUpOn !== undefined && nextFollowUpOn === undefined) {
    return jsonResponse({ error: "Invalid nextFollowUpOn (use YYYY-MM-DD)." }, 400);
  }

  const email = optionalEmail(body.email);
  if (body.email !== undefined && email === undefined) {
    return jsonResponse({ error: "Invalid email." }, 400);
  }

  const insertRow = {
    status: "new",
    source,
    company_name: companyName,
    contact_name: contactName,
    email: email ?? null,
    phone: blankToNull(body.phone),
    owner_email: ownerEmail === undefined ? auth.email : ownerEmail,
    referring_cm_id: referringCmId ?? null,
    next_follow_up_on: nextFollowUpOn ?? null,
    created_by: auth.email,
  };

  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("leads")
    .insert(insertRow)
    .select(LEAD_COLUMNS)
    .single();
  if (error) throw error;

  const lead = mapLead(data as LeadRow);
  const note = blankToNull(body.notes);
  if (note) await insertActivity(lead.id as string, "note", note, auth.email);
  if (insertRow.owner_email) {
    await insertActivity(
      lead.id as string,
      "assignment",
      `Assigned to ${insertRow.owner_email}`,
      auth.email,
    );
  }
  if (insertRow.next_follow_up_on) {
    await insertActivity(
      lead.id as string,
      "follow_up",
      `Follow up ${insertRow.next_follow_up_on}`,
      auth.email,
    );
  }
  await insertAudit({
    actorEmail: auth.email,
    action: "lead.create",
    resourceId: lead.id as string,
    after: lead,
  });

  return jsonResponse({ lead }, 201);
}

async function handlePatch(
  auth: AuthContext,
  id: string,
  req: Request,
): Promise<Response> {
  const supabase = supabaseAdmin();
  const existing = await supabase.from("leads").select(LEAD_COLUMNS).eq("id", id)
    .maybeSingle();
  if (existing.error) throw existing.error;
  if (!existing.data) return jsonResponse({ error: "Lead not found." }, 404);
  const before = mapLead(existing.data as LeadRow);

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };

  if ("companyName" in body) patch.company_name = blankToNull(body.companyName);
  if ("contactName" in body) patch.contact_name = blankToNull(body.contactName);
  if ("companyName" in body || "contactName" in body) {
    const nextCompany = "companyName" in body ? patch.company_name : before.companyName;
    const nextContact = "contactName" in body ? patch.contact_name : before.contactName;
    if (!nextCompany && !nextContact) {
      return jsonResponse(
        { error: "Provide a company name or a contact name." },
        400,
      );
    }
  }

  if ("email" in body) {
    const email = optionalEmail(body.email);
    if (body.email !== null && body.email !== "" && email === undefined) {
      return jsonResponse({ error: "Invalid email." }, 400);
    }
    patch.email = email ?? null;
  }
  if ("phone" in body) patch.phone = blankToNull(body.phone);

  if ("source" in body) {
    if (typeof body.source !== "string" || !SOURCE_SET.has(body.source)) {
      return jsonResponse({ error: `Invalid source. Allowed: ${SOURCES.join(", ")}` }, 400);
    }
    patch.source = body.source;
  }

  if ("ownerEmail" in body) {
    const ownerEmail = optionalEmail(body.ownerEmail);
    if (body.ownerEmail !== null && body.ownerEmail !== "" && ownerEmail === undefined) {
      return jsonResponse({ error: "Invalid ownerEmail." }, 400);
    }
    patch.owner_email = ownerEmail ?? null;
  }

  if ("referringCmId" in body) {
    const referringCmId = optionalCmId(body.referringCmId);
    if (body.referringCmId !== null && body.referringCmId !== "" && referringCmId === undefined) {
      return jsonResponse({ error: "Invalid referringCmId." }, 400);
    }
    patch.referring_cm_id = referringCmId ?? null;
  }
  if ("convertedCmId" in body) {
    const convertedCmId = optionalCmId(body.convertedCmId);
    if (body.convertedCmId !== null && body.convertedCmId !== "" && convertedCmId === undefined) {
      return jsonResponse({ error: "Invalid convertedCmId." }, 400);
    }
    patch.converted_cm_id = convertedCmId ?? null;
  }

  if ("nextFollowUpOn" in body) {
    const nextFollowUpOn = optionalDate(body.nextFollowUpOn);
    if (body.nextFollowUpOn !== null && body.nextFollowUpOn !== "" && nextFollowUpOn === undefined) {
      return jsonResponse({ error: "Invalid nextFollowUpOn (use YYYY-MM-DD)." }, 400);
    }
    patch.next_follow_up_on = nextFollowUpOn ?? null;
  }

  if ("lostReason" in body) patch.lost_reason = blankToNull(body.lostReason);

  if ("status" in body) {
    if (typeof body.status !== "string" || !STATUS_SET.has(body.status)) {
      return jsonResponse({ error: `Invalid status. Allowed: ${STATUSES.join(", ")}` }, 400);
    }
    patch.status = body.status;
    if (body.status === "won") {
      patch.won_at = before.wonAt ?? new Date().toISOString();
      patch.lost_at = null;
    } else if (body.status === "lost") {
      patch.lost_at = before.lostAt ?? new Date().toISOString();
      patch.won_at = null;
    } else {
      patch.won_at = null;
      patch.lost_at = null;
    }
  }

  const { data, error } = await supabase
    .from("leads")
    .update(patch)
    .eq("id", id)
    .select(LEAD_COLUMNS)
    .single();
  if (error) throw error;
  const lead = mapLead(data as LeadRow);

  if (before.status !== lead.status) {
    await insertActivity(
      id,
      "status_change",
      `${before.status} → ${lead.status}`,
      auth.email,
    );
    await insertAudit({
      actorEmail: auth.email,
      action: "lead.status_change",
      resourceId: id,
      before,
      after: lead,
    });
  }
  if (before.ownerEmail !== lead.ownerEmail) {
    await insertActivity(
      id,
      "assignment",
      lead.ownerEmail ? `Assigned to ${lead.ownerEmail}` : "Unassigned",
      auth.email,
    );
    await insertAudit({
      actorEmail: auth.email,
      action: "lead.assignment",
      resourceId: id,
      before,
      after: lead,
    });
  }
  if (before.nextFollowUpOn !== lead.nextFollowUpOn) {
    await insertActivity(
      id,
      "follow_up",
      lead.nextFollowUpOn ? `Follow up ${lead.nextFollowUpOn}` : "Follow-up cleared",
      auth.email,
    );
  }

  return jsonResponse({ lead });
}

async function handleNote(
  auth: AuthContext,
  id: string,
  req: Request,
): Promise<Response> {
  const supabase = supabaseAdmin();
  const existing = await supabase.from("leads").select("id").eq("id", id).maybeSingle();
  if (existing.error) throw existing.error;
  if (!existing.data) return jsonResponse({ error: "Lead not found." }, 404);

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const note = blankToNull(body.body) ?? blankToNull(body.notes);
  if (!note) return jsonResponse({ error: "Note body is required." }, 400);

  await insertActivity(id, "note", note, auth.email);
  return await handleGet(id);
}

async function handleRequest(req: Request): Promise<Response> {
  try {
    const url = new URL(req.url);
    const parts = pathParts(url.pathname);
    const auth = await requireStaffAuth(req);

    if (
      req.method === "GET" &&
      (parts.length === 0 || (parts.length === 1 && parts[0] === "leads"))
    ) {
      return await handleList(url);
    }

    if (req.method === "GET" && parts.length === 1 && parts[0] === "summary") {
      return await handleSummary();
    }
    if (
      req.method === "GET" &&
      parts.length === 2 &&
      parts[0] === "leads" &&
      parts[1] === "summary"
    ) {
      return await handleSummary();
    }

    if (req.method === "GET" && parts.length === 1 && parts[0] === "activity") {
      return await handleActivity(url);
    }
    if (
      req.method === "GET" &&
      parts.length === 2 &&
      parts[0] === "leads" &&
      parts[1] === "activity"
    ) {
      return await handleActivity(url);
    }

    if (
      req.method === "POST" &&
      (parts.length === 0 || (parts.length === 1 && parts[0] === "leads"))
    ) {
      return await handleCreate(auth, req);
    }

    const idPart = parts[0] === "leads" ? parts[1] : parts[0];
    const rest = parts[0] === "leads" ? parts.slice(2) : parts.slice(1);
    if (!idPart || !UUID_RE.test(idPart)) {
      return jsonResponse({ error: "Not found." }, 404);
    }

    if (req.method === "GET" && rest.length === 0) {
      return await handleGet(idPart);
    }

    if (req.method === "PATCH" && rest.length === 0) {
      return await handlePatch(auth, idPart, req);
    }

    if (req.method === "POST" && rest.length === 1 && rest[0] === "notes") {
      return await handleNote(auth, idPart, req);
    }

    return jsonResponse({ error: "Not found." }, 404);
  } catch (error) {
    const status = typeof (error as { status?: number }).status === "number"
      ? (error as { status: number }).status
      : 500;
    const message = error instanceof Error ? error.message : "Unexpected error.";
    console.error("leads error:", message);
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
