import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  emitPush,
  notifyAdminsOfSubmission,
  notifyMembersNewPromotion,
  notifySubmitterApproved,
  notifySubmitterRejected,
} from "./apns.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type AuthContext = {
  email: string;
  cmId: number;
  memberId: string;
  isAdmin: boolean;
  companyName: string;
  submitterName: string;
};

const ACTIVE_MEMBER_STATUS = "2";

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

const ALLOWED_REDEMPTION_TYPES = new Set([
  "No code needed",
  "Promo code",
  "Barcode",
  "QR code",
  "Other",
]);

const MAX_TITLE = 120;
const MAX_SHORT_DESCRIPTION = 280;
const MAX_FULL_DESCRIPTION = 4000;
const MAX_TERMS = 2000;
const MAX_REDEMPTION_INSTRUCTIONS = 2000;
const MAX_REDEMPTION_CODE = 200;
const MAX_CONTACT_EMAIL = 254;
const MAX_CONTACT_PHONE = 40;
const MAX_ADMIN_NOTES = 2000;

const RATE_LIMIT_SUBMISSION_MAX = 5;
const RATE_LIMIT_SUBMISSION_WINDOW_MIN = 60;
const RATE_LIMIT_DEVICE_TOKEN_MAX = 30;
const RATE_LIMIT_DEVICE_TOKEN_WINDOW_MIN = 60;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
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

function clipText(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

function parseIsoDate(value: unknown): string | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}

function validateSubmissionFields(
  submission: Record<string, unknown>,
): { ok: true; fields: Record<string, string> } | { ok: false; error: string } {
  const title = clipText(submission.title, MAX_TITLE);
  if (!title) return { ok: false, error: "Title is required." };

  const category = clipText(submission.category, 80) || "Other";
  if (!ALLOWED_CATEGORIES.has(category)) {
    return { ok: false, error: "Invalid category." };
  }

  const redemptionCodeType = clipText(submission.redemptionCodeType, 40) ||
    "No code needed";
  if (!ALLOWED_REDEMPTION_TYPES.has(redemptionCodeType)) {
    return { ok: false, error: "Invalid redemption code type." };
  }

  const redemptionCode = clipText(submission.redemptionCode, MAX_REDEMPTION_CODE);
  if (redemptionCodeType !== "No code needed" && !redemptionCode) {
    return { ok: false, error: "Redemption code is required for this type." };
  }

  const startDate = parseIsoDate(submission.startDate) ?? new Date().toISOString();
  const endDate = parseIsoDate(submission.endDate) ?? startDate;
  if (new Date(endDate).getTime() < new Date(startDate).getTime()) {
    return { ok: false, error: "End date must be on or after start date." };
  }

  const contactEmail = clipText(submission.contactEmail, MAX_CONTACT_EMAIL);
  if (contactEmail && !contactEmail.includes("@")) {
    return { ok: false, error: "Invalid contact email." };
  }

  return {
    ok: true,
    fields: {
      title,
      category,
      shortDescription: clipText(submission.shortDescription, MAX_SHORT_DESCRIPTION),
      fullDescription: clipText(submission.fullDescription, MAX_FULL_DESCRIPTION),
      terms: clipText(submission.terms, MAX_TERMS),
      redemptionInstructions: clipText(
        submission.redemptionInstructions,
        MAX_REDEMPTION_INSTRUCTIONS,
      ),
      redemptionCodeType,
      redemptionCode: redemptionCodeType === "No code needed" ? "" : redemptionCode,
      contactEmail,
      contactPhone: clipText(submission.contactPhone, MAX_CONTACT_PHONE),
      startDate,
      endDate,
    },
  };
}

function isEligibleMember(row: {
  email?: string | null;
  status?: string | null;
  display_flags?: string | null;
}): boolean {
  if (!row.email) return false;
  if (row.status !== ACTIVE_MEMBER_STATUS) return false;
  if ((row.display_flags ?? "").includes("DisableLogin")) return false;
  return true;
}

function memberDisplayName(row: {
  name?: string | null;
  display_name?: string | null;
  email?: string | null;
}): string {
  const display = (row.display_name ?? "").trim();
  if (display) return display;
  const name = (row.name ?? "").trim();
  if (name) return name;
  return (row.email ?? "Chamber Member").trim() || "Chamber Member";
}

async function requireAuth(req: Request): Promise<AuthContext> {
  const token = bearerToken(req);
  if (!token) {
    throw Object.assign(new Error("Missing authorization."), { status: 401 });
  }

  const payload = await verifyAccessToken(token);
  if (!payload || payload.typ !== "access") {
    throw Object.assign(new Error("Invalid or expired session."), { status: 401 });
  }

  const email = typeof payload.email === "string"
    ? payload.email.trim().toLowerCase()
    : "";
  if (!email) {
    throw Object.assign(new Error("Invalid session claims."), { status: 401 });
  }

  const supabase = supabaseAdmin();
  const [{ data: profile }, { data: memberRows, error: memberError }] =
    await Promise.all([
      supabase
        .from("app_profiles")
        .select("email, cm_id, is_chamber_admin")
        .eq("email", email)
        .maybeSingle(),
      supabase
        .from("chamber_members")
        .select("cm_id, name, display_name, email, status, display_flags")
        .eq("email", email)
        .eq("status", ACTIVE_MEMBER_STATUS)
        .order("cm_id", { ascending: true }),
    ]);

  if (memberError) throw memberError;

  const isAdmin = profile?.is_chamber_admin === true;
  const eligible = ((memberRows ?? []) as Array<{
    cm_id: number;
    name: string | null;
    display_name: string | null;
    email: string | null;
    status: string | null;
    display_flags: string | null;
  }>).filter(isEligibleMember);

  const member = eligible[0] ?? null;
  if (!member && !isAdmin) {
    throw Object.assign(
      new Error("Your membership is not currently active."),
      { status: 403 },
    );
  }

  const cmId = member?.cm_id ??
    (typeof profile?.cm_id === "number"
      ? profile.cm_id
      : Number(payload.cm_id ?? payload.sub));
  if (!Number.isFinite(cmId)) {
    throw Object.assign(new Error("Invalid session claims."), { status: 401 });
  }

  const companyName = member
    ? (member.name ?? "").trim() || "Chamber Member"
    : "Chamber Member";
  const submitterName = member
    ? memberDisplayName(member)
    : email;

  return {
    email,
    cmId,
    memberId: String(cmId),
    isAdmin,
    companyName,
    submitterName,
  };
}

function requireAdmin(auth: AuthContext) {
  if (!auth.isAdmin) {
    throw Object.assign(new Error("Admin access required."), { status: 403 });
  }
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
    archivedAt: row.archived_at ?? null,
  };
}

function mapDealDetail(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    title: row.title,
    businessId: row.business_id,
    businessName: row.business_name,
    description: row.description ?? "",
    terms: row.terms ?? null,
    redemptionInstructions: row.redemption_instructions ?? "",
    redemptionCode: row.redemption_code ?? null,
    startDate: row.start_date ?? null,
    expirationDate: row.end_date ?? null,
    category: row.category,
    imageURL: row.image_url ?? null,
    membersOnly: Boolean(row.members_only),
    isFeatured: Boolean(row.is_featured),
    archivedAt: row.archived_at ?? null,
  };
}

function mapSubmission(row: Record<string, unknown>) {
  return {
    id: String(row.id),
    submittedAt: row.submitted_at,
    submitterMemberId: row.submitter_member_id,
    submitterName: row.submitter_name,
    companyId: row.company_id ?? null,
    companyName: row.company_name,
    status: row.status,
    reviewedAt: row.reviewed_at ?? null,
    reviewedByAdminId: row.reviewed_by_admin_id ?? null,
    adminNotes: row.admin_notes ?? null,
    submission: {
      contactEmail: row.contact_email ?? "",
      contactPhone: row.contact_phone ?? "",
      title: row.title,
      category: row.category,
      shortDescription: row.short_description ?? "",
      fullDescription: row.full_description ?? "",
      terms: row.terms ?? "",
      redemptionInstructions: row.redemption_instructions ?? "",
      redemptionCodeType: row.redemption_code_type ?? "No code needed",
      redemptionCode: row.redemption_code ?? "",
      startDate: row.start_date,
      endDate: row.end_date,
    },
  };
}

function dealInsertFromSubmission(input: {
  submission: Record<string, unknown>;
  businessId: string;
  businessName: string;
  sourceSubmissionId?: string | null;
  createdBy?: string | null;
  isFeatured?: boolean;
}) {
  const s = input.submission;
  return {
    title: String(s.title ?? "").trim(),
    business_id: input.businessId,
    business_name: input.businessName,
    short_description: String(s.shortDescription ?? "").trim(),
    description: String(s.fullDescription ?? "").trim(),
    terms: String(s.terms ?? "").trim() || null,
    redemption_instructions: String(s.redemptionInstructions ?? "").trim(),
    redemption_code: String(s.redemptionCode ?? "").trim() || null,
    category: String(s.category ?? "Other"),
    start_date: s.startDate ?? null,
    end_date: s.endDate ?? null,
    image_url: null,
    members_only: true,
    is_featured: input.isFeatured ?? false,
    source_submission_id: input.sourceSubmissionId ?? null,
    created_by: input.createdBy ?? null,
    updated_at: new Date().toISOString(),
  };
}

function pathParts(pathname: string): string[] {
  // pathname like /perks/deals/abc or /functions/v1/perks/deals
  const cleaned = pathname.replace(/\/+$/, "");
  const idx = cleaned.lastIndexOf("/perks");
  const rest = idx >= 0 ? cleaned.slice(idx + "/perks".length) : cleaned;
  return rest.split("/").filter(Boolean);
}

async function handleGetDeals(): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("deals")
    .select("*")
    .is("archived_at", null)
    .or(`end_date.is.null,end_date.gte.${new Date().toISOString()}`)
    .order("is_featured", { ascending: false })
    .order("end_date", { ascending: true });
  if (error) throw error;
  return jsonResponse((data ?? []).map(mapDealSummary));
}

async function handleGetDeal(
  id: string,
  options: { allowArchived?: boolean } = {},
): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("deals")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    return jsonResponse({ error: "Deal not found." }, 404);
  }
  if (!options.allowArchived && data.archived_at != null) {
    return jsonResponse({ error: "Deal not found." }, 404);
  }
  return jsonResponse(mapDealDetail(data));
}

async function handleListSubmissions(
  auth: AuthContext,
  url: URL,
): Promise<Response> {
  const status = url.searchParams.get("status");
  const supabase = supabaseAdmin();
  let query = supabase.from("promotion_submissions").select("*").order(
    "submitted_at",
    { ascending: false },
  );

  if (auth.isAdmin) {
    if (status && status !== "all") {
      query = query.eq("status", status);
    }
  } else {
    query = query.eq("submitter_member_id", auth.memberId);
    if (status && status !== "all") {
      query = query.eq("status", status);
    }
  }

  const { data, error } = await query;
  if (error) throw error;
  return jsonResponse((data ?? []).map(mapSubmission));
}

async function handleGetSubmission(
  auth: AuthContext,
  id: string,
): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("promotion_submissions")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  if (!data) return jsonResponse({ error: "Submission not found." }, 404);
  if (
    !auth.isAdmin &&
    String(data.submitter_member_id) !== auth.memberId
  ) {
    return jsonResponse({ error: "Forbidden." }, 403);
  }
  return jsonResponse(mapSubmission(data));
}

async function handleCreateSubmission(
  auth: AuthContext,
  req: Request,
): Promise<Response> {
  await assertRateLimit(
    "submission-create",
    auth.memberId,
    RATE_LIMIT_SUBMISSION_MAX,
    RATE_LIMIT_SUBMISSION_WINDOW_MIN,
  );

  const body = await req.json().catch(() => null) as {
    submission?: Record<string, unknown>;
  } | null;

  const submission = body?.submission;
  if (!submission || typeof submission !== "object") {
    return jsonResponse({ error: "Invalid submission payload." }, 400);
  }

  const validated = validateSubmissionFields(submission);
  if (!validated.ok) {
    return jsonResponse({ error: validated.error }, 400);
  }
  const fields = validated.fields;

  const row = {
    submitter_member_id: auth.memberId,
    submitter_email: auth.email,
    submitter_name: auth.submitterName,
    company_id: String(auth.cmId),
    company_name: auth.companyName,
    contact_email: fields.contactEmail || auth.email,
    contact_phone: fields.contactPhone,
    title: fields.title,
    category: fields.category,
    short_description: fields.shortDescription,
    full_description: fields.fullDescription,
    terms: fields.terms,
    redemption_instructions: fields.redemptionInstructions,
    redemption_code_type: fields.redemptionCodeType,
    redemption_code: fields.redemptionCode,
    start_date: fields.startDate,
    end_date: fields.endDate,
    status: "pending",
  };

  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("promotion_submissions")
    .insert(row)
    .select("*")
    .single();
  if (error) throw error;

  emitPush(() =>
    notifyAdminsOfSubmission({
      submissionId: String(data.id),
      submitterName: String(data.submitter_name),
      title: String(data.title),
    })
  );

  return jsonResponse(mapSubmission(data), 201);
}

async function handleUpdateSubmission(
  auth: AuthContext,
  id: string,
  req: Request,
): Promise<Response> {
  const body = await req.json().catch(() => null) as {
    submission?: Record<string, unknown>;
    adminNotes?: string | null;
  } | null;

  const supabase = supabaseAdmin();
  const { data: existing, error: fetchError } = await supabase
    .from("promotion_submissions")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (fetchError) throw fetchError;
  if (!existing) return jsonResponse({ error: "Submission not found." }, 404);
  if (existing.status !== "pending") {
    return jsonResponse({ error: "This submission can no longer be updated." }, 409);
  }
  if (
    !auth.isAdmin &&
    String(existing.submitter_member_id) !== auth.memberId
  ) {
    return jsonResponse({ error: "Forbidden." }, 403);
  }

  const s = body?.submission ?? {};
  const validated = validateSubmissionFields({
    title: typeof s.title === "string" ? s.title : existing.title,
    category: typeof s.category === "string" ? s.category : existing.category,
    shortDescription: typeof s.shortDescription === "string"
      ? s.shortDescription
      : existing.short_description,
    fullDescription: typeof s.fullDescription === "string"
      ? s.fullDescription
      : existing.full_description,
    terms: typeof s.terms === "string" ? s.terms : existing.terms,
    redemptionInstructions: typeof s.redemptionInstructions === "string"
      ? s.redemptionInstructions
      : existing.redemption_instructions,
    redemptionCodeType: typeof s.redemptionCodeType === "string"
      ? s.redemptionCodeType
      : existing.redemption_code_type,
    redemptionCode: typeof s.redemptionCode === "string"
      ? s.redemptionCode
      : existing.redemption_code,
    startDate: s.startDate ?? existing.start_date,
    endDate: s.endDate ?? existing.end_date,
    contactEmail: typeof s.contactEmail === "string"
      ? s.contactEmail
      : existing.contact_email,
    contactPhone: typeof s.contactPhone === "string"
      ? s.contactPhone
      : existing.contact_phone,
  });
  if (!validated.ok) {
    return jsonResponse({ error: validated.error }, 400);
  }
  const fields = validated.fields;

  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
    title: fields.title,
    category: fields.category,
    short_description: fields.shortDescription,
    full_description: fields.fullDescription,
    terms: fields.terms,
    redemption_instructions: fields.redemptionInstructions,
    redemption_code_type: fields.redemptionCodeType,
    redemption_code: fields.redemptionCode,
    start_date: fields.startDate,
    end_date: fields.endDate,
    contact_email: fields.contactEmail || existing.contact_email,
    contact_phone: fields.contactPhone,
  };
  if (auth.isAdmin && body?.adminNotes !== undefined) {
    updates.admin_notes = clipText(body.adminNotes, MAX_ADMIN_NOTES) || null;
  }

  const { data, error } = await supabase
    .from("promotion_submissions")
    .update(updates)
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw error;
  return jsonResponse(mapSubmission(data));
}

async function handleApproveSubmission(
  auth: AuthContext,
  id: string,
): Promise<Response> {
  requireAdmin(auth);
  const supabase = supabaseAdmin();
  const { data: existing, error: fetchError } = await supabase
    .from("promotion_submissions")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (fetchError) throw fetchError;
  if (!existing) return jsonResponse({ error: "Submission not found." }, 404);
  if (existing.status !== "pending") {
    return jsonResponse({ error: "This submission can no longer be updated." }, 409);
  }

  const now = new Date().toISOString();
  const { data: updated, error: updateError } = await supabase
    .from("promotion_submissions")
    .update({
      status: "approved",
      reviewed_at: now,
      reviewed_by_admin_id: auth.memberId,
      updated_at: now,
    })
    .eq("id", id)
    .select("*")
    .single();
  if (updateError) throw updateError;

  const dealRow = dealInsertFromSubmission({
    submission: {
      title: updated.title,
      shortDescription: updated.short_description,
      fullDescription: updated.full_description,
      terms: updated.terms,
      redemptionInstructions: updated.redemption_instructions,
      redemptionCode: updated.redemption_code,
      category: updated.category,
      startDate: updated.start_date,
      endDate: updated.end_date,
    },
    businessId: updated.company_id ?? `biz-sub-${updated.id}`,
    businessName: updated.company_name,
    sourceSubmissionId: updated.id,
    createdBy: auth.memberId,
  });

  const { data: deal, error: dealError } = await supabase
    .from("deals")
    .insert(dealRow)
    .select("id")
    .single();
  if (dealError) throw dealError;

  const submitterMemberId = String(updated.submitter_member_id);
  const perkTitle = String(updated.title);
  const businessName = String(updated.company_name);
  const submissionId = String(updated.id);
  const dealId = String(deal.id);

  emitPush(async () => {
    await notifySubmitterApproved({
      submitterMemberId,
      title: perkTitle,
      submissionId,
    });
    await notifyMembersNewPromotion({
      title: perkTitle,
      businessName,
      dealId,
      excludeMemberId: submitterMemberId,
    });
  });

  return jsonResponse(mapSubmission(updated));
}

async function handleRejectSubmission(
  auth: AuthContext,
  id: string,
  req: Request,
): Promise<Response> {
  requireAdmin(auth);
  const body = await req.json().catch(() => null) as { notes?: string } | null;
  const supabase = supabaseAdmin();
  const { data: existing, error: fetchError } = await supabase
    .from("promotion_submissions")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (fetchError) throw fetchError;
  if (!existing) return jsonResponse({ error: "Submission not found." }, 404);
  if (existing.status !== "pending") {
    return jsonResponse({ error: "This submission can no longer be updated." }, 409);
  }

  const notes = body?.notes?.trim().slice(0, 2000);
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("promotion_submissions")
    .update({
      status: "rejected",
      reviewed_at: now,
      reviewed_by_admin_id: auth.memberId,
      admin_notes: notes || existing.admin_notes,
      updated_at: now,
    })
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw error;

  emitPush(() =>
    notifySubmitterRejected({
      submitterMemberId: String(data.submitter_member_id),
      title: String(data.title),
      submissionId: String(data.id),
      notes: typeof data.admin_notes === "string" ? data.admin_notes : null,
    })
  );

  return jsonResponse(mapSubmission(data));
}

async function handlePendingCount(auth: AuthContext): Promise<Response> {
  requireAdmin(auth);
  const supabase = supabaseAdmin();
  const { count, error } = await supabase
    .from("promotion_submissions")
    .select("id", { count: "exact", head: true })
    .eq("status", "pending");
  if (error) throw error;
  return jsonResponse({ count: count ?? 0 });
}

async function handleAdminListDeals(): Promise<Response> {
  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("deals")
    .select("*")
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return jsonResponse((data ?? []).map(mapDealSummary));
}

async function handleAdminCreateDeal(
  auth: AuthContext,
  req: Request,
): Promise<Response> {
  requireAdmin(auth);
  const body = await req.json().catch(() => null) as {
    submission?: Record<string, unknown>;
    businessId?: string;
    businessName?: string;
  } | null;

  if (!body?.submission || !body.businessId || !body.businessName) {
    return jsonResponse({ error: "Invalid create payload." }, 400);
  }

  const row = dealInsertFromSubmission({
    submission: body.submission,
    businessId: body.businessId,
    businessName: body.businessName,
    createdBy: auth.memberId,
  });

  const supabase = supabaseAdmin();
  const { data, error } = await supabase
    .from("deals")
    .insert(row)
    .select("*")
    .single();
  if (error) throw error;

  emitPush(() =>
    notifyMembersNewPromotion({
      title: String(data.title),
      businessName: String(data.business_name),
      dealId: String(data.id),
    })
  );

  return jsonResponse(mapDealDetail(data), 201);
}

async function handleRegisterDeviceToken(
  auth: AuthContext,
  req: Request,
): Promise<Response> {
  await assertRateLimit(
    "device-token-register",
    auth.memberId,
    RATE_LIMIT_DEVICE_TOKEN_MAX,
    RATE_LIMIT_DEVICE_TOKEN_WINDOW_MIN,
  );

  const body = await req.json().catch(() => null) as { token?: string } | null;
  const token = body?.token?.trim() ?? "";
  if (!/^[0-9a-fA-F]{64,200}$/.test(token)) {
    return jsonResponse({ error: "Invalid device token." }, 400);
  }

  const supabase = supabaseAdmin();
  const { data: existing, error: existingError } = await supabase
    .from("device_push_tokens")
    .select("member_id")
    .eq("token", token)
    .maybeSingle();
  if (existingError) throw existingError;
  if (existing && String(existing.member_id) !== auth.memberId) {
    return jsonResponse(
      { error: "Device token already registered to another account." },
      409,
    );
  }

  const { error } = await supabase.from("device_push_tokens").upsert(
    {
      token,
      member_id: auth.memberId,
      platform: "ios",
      updated_at: new Date().toISOString(),
    },
    { onConflict: "token" },
  );
  if (error) throw error;
  return jsonResponse({ ok: true });
}

async function handleUnregisterDeviceToken(
  auth: AuthContext,
  req: Request,
): Promise<Response> {
  const body = await req.json().catch(() => null) as { token?: string } | null;
  const token = body?.token?.trim();
  const supabase = supabaseAdmin();

  if (token) {
    const { error } = await supabase
      .from("device_push_tokens")
      .delete()
      .eq("token", token)
      .eq("member_id", auth.memberId);
    if (error) throw error;
  } else {
    const { error } = await supabase
      .from("device_push_tokens")
      .delete()
      .eq("member_id", auth.memberId);
    if (error) throw error;
  }

  return jsonResponse({ ok: true });
}

async function handleAdminUpdateDeal(
  auth: AuthContext,
  id: string,
  req: Request,
): Promise<Response> {
  requireAdmin(auth);
  const body = await req.json().catch(() => null) as {
    submission?: Record<string, unknown>;
    businessId?: string;
    businessName?: string;
  } | null;

  if (!body?.submission || !body.businessId || !body.businessName) {
    return jsonResponse({ error: "Invalid update payload." }, 400);
  }

  const supabase = supabaseAdmin();
  const { data: existing, error: fetchError } = await supabase
    .from("deals")
    .select("is_featured")
    .eq("id", id)
    .maybeSingle();
  if (fetchError) throw fetchError;
  if (!existing) return jsonResponse({ error: "Deal not found." }, 404);

  const row = dealInsertFromSubmission({
    submission: body.submission,
    businessId: body.businessId,
    businessName: body.businessName,
    createdBy: auth.memberId,
    isFeatured: Boolean(existing.is_featured),
  });

  const { data, error } = await supabase
    .from("deals")
    .update(row)
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw error;
  return jsonResponse(mapDealDetail(data));
}

async function handleAdminArchiveDeal(
  auth: AuthContext,
  id: string,
): Promise<Response> {
  requireAdmin(auth);
  const supabase = supabaseAdmin();
  const { data: existing, error: fetchError } = await supabase
    .from("deals")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (fetchError) throw fetchError;
  if (!existing) return jsonResponse({ error: "Deal not found." }, 404);
  if (existing.archived_at != null) {
    return jsonResponse({ error: "This perk is already archived." }, 409);
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("deals")
    .update({
      archived_at: now,
      archived_by: auth.memberId,
      updated_at: now,
    })
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw error;
  return jsonResponse(mapDealDetail(data));
}

async function handleAdminUnarchiveDeal(
  auth: AuthContext,
  id: string,
): Promise<Response> {
  requireAdmin(auth);
  const supabase = supabaseAdmin();
  const { data: existing, error: fetchError } = await supabase
    .from("deals")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (fetchError) throw fetchError;
  if (!existing) return jsonResponse({ error: "Deal not found." }, 404);
  if (existing.archived_at == null) {
    return jsonResponse({ error: "This perk is not archived." }, 409);
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("deals")
    .update({
      archived_at: null,
      archived_by: null,
      updated_at: now,
    })
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw error;
  return jsonResponse(mapDealDetail(data));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const parts = pathParts(url.pathname);
    const auth = await requireAuth(req);

    // POST /device-tokens
    if (
      req.method === "POST" &&
      parts.length === 1 &&
      parts[0] === "device-tokens"
    ) {
      return await handleRegisterDeviceToken(auth, req);
    }

    // DELETE /device-tokens
    if (
      req.method === "DELETE" &&
      parts.length === 1 &&
      parts[0] === "device-tokens"
    ) {
      return await handleUnregisterDeviceToken(auth, req);
    }

    // GET /deals
    if (req.method === "GET" && parts.length === 1 && parts[0] === "deals") {
      return await handleGetDeals();
    }

    // GET /deals/:id
    if (req.method === "GET" && parts.length === 2 && parts[0] === "deals") {
      return await handleGetDeal(parts[1]);
    }

    // GET /submissions
    if (
      req.method === "GET" && parts.length === 1 && parts[0] === "submissions"
    ) {
      return await handleListSubmissions(auth, url);
    }

    // GET /submissions/pending-count
    if (
      req.method === "GET" &&
      parts.length === 2 &&
      parts[0] === "submissions" &&
      parts[1] === "pending-count"
    ) {
      return await handlePendingCount(auth);
    }

    // GET /submissions/:id
    if (
      req.method === "GET" && parts.length === 2 && parts[0] === "submissions"
    ) {
      return await handleGetSubmission(auth, parts[1]);
    }

    // POST /submissions
    if (
      req.method === "POST" && parts.length === 1 && parts[0] === "submissions"
    ) {
      return await handleCreateSubmission(auth, req);
    }

    // PATCH /submissions/:id
    if (
      req.method === "PATCH" && parts.length === 2 && parts[0] === "submissions"
    ) {
      return await handleUpdateSubmission(auth, parts[1], req);
    }

    // POST /submissions/:id/approve
    if (
      req.method === "POST" &&
      parts.length === 3 &&
      parts[0] === "submissions" &&
      parts[2] === "approve"
    ) {
      return await handleApproveSubmission(auth, parts[1]);
    }

    // POST /submissions/:id/reject
    if (
      req.method === "POST" &&
      parts.length === 3 &&
      parts[0] === "submissions" &&
      parts[2] === "reject"
    ) {
      return await handleRejectSubmission(auth, parts[1], req);
    }

    // GET /admin/deals
    if (
      req.method === "GET" &&
      parts.length === 2 &&
      parts[0] === "admin" &&
      parts[1] === "deals"
    ) {
      requireAdmin(auth);
      return await handleAdminListDeals();
    }

    // POST /admin/deals
    if (
      req.method === "POST" &&
      parts.length === 2 &&
      parts[0] === "admin" &&
      parts[1] === "deals"
    ) {
      return await handleAdminCreateDeal(auth, req);
    }

    // PATCH /admin/deals/:id
    if (
      req.method === "PATCH" &&
      parts.length === 3 &&
      parts[0] === "admin" &&
      parts[1] === "deals"
    ) {
      return await handleAdminUpdateDeal(auth, parts[2], req);
    }

    // POST /admin/deals/:id/archive
    if (
      req.method === "POST" &&
      parts.length === 4 &&
      parts[0] === "admin" &&
      parts[1] === "deals" &&
      parts[3] === "archive"
    ) {
      return await handleAdminArchiveDeal(auth, parts[2]);
    }

    // POST /admin/deals/:id/unarchive
    if (
      req.method === "POST" &&
      parts.length === 4 &&
      parts[0] === "admin" &&
      parts[1] === "deals" &&
      parts[3] === "unarchive"
    ) {
      return await handleAdminUnarchiveDeal(auth, parts[2]);
    }

    // GET /admin/deals/:id
    if (
      req.method === "GET" &&
      parts.length === 3 &&
      parts[0] === "admin" &&
      parts[1] === "deals"
    ) {
      requireAdmin(auth);
      return await handleGetDeal(parts[2], { allowArchived: true });
    }

    return jsonResponse({ error: "Not found." }, 404);
  } catch (error) {
    const status = typeof (error as { status?: number }).status === "number"
      ? (error as { status: number }).status
      : 500;
    const message = error instanceof Error
      ? error.message
      : "Unexpected error.";
    console.error("perks error:", message);
    return jsonResponse({ error: message }, status);
  }
});
