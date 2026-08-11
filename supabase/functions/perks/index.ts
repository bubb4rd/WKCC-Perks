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
};

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
  const cmId = typeof payload.cm_id === "number"
    ? payload.cm_id
    : Number(payload.sub);
  if (!email || !Number.isFinite(cmId)) {
    throw Object.assign(new Error("Invalid session claims."), { status: 401 });
  }

  const supabase = supabaseAdmin();
  const { data: profile } = await supabase
    .from("app_profiles")
    .select("email, cm_id, is_chamber_admin")
    .eq("email", email)
    .maybeSingle();

  return {
    email,
    cmId,
    memberId: String(cmId),
    isAdmin: profile?.is_chamber_admin === true,
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
  const body = await req.json().catch(() => null) as {
    submission?: Record<string, unknown>;
    companyName?: string;
    companyId?: string | null;
    submitterName?: string;
  } | null;

  const submission = body?.submission;
  if (!submission || typeof submission.title !== "string") {
    return jsonResponse({ error: "Invalid submission payload." }, 400);
  }

  const row = {
    submitter_member_id: auth.memberId,
    submitter_email: auth.email,
    submitter_name: body?.submitterName?.trim() || auth.email,
    company_id: body?.companyId ?? String(auth.cmId),
    company_name: (body?.companyName ?? "Chamber Member").trim(),
    contact_email: String(submission.contactEmail ?? auth.email),
    contact_phone: String(submission.contactPhone ?? ""),
    title: String(submission.title).trim(),
    category: String(submission.category ?? "Other"),
    short_description: String(submission.shortDescription ?? ""),
    full_description: String(submission.fullDescription ?? ""),
    terms: String(submission.terms ?? ""),
    redemption_instructions: String(submission.redemptionInstructions ?? ""),
    redemption_code_type: String(submission.redemptionCodeType ?? "No code needed"),
    redemption_code: String(submission.redemptionCode ?? ""),
    start_date: submission.startDate ?? new Date().toISOString(),
    end_date: submission.endDate ?? new Date().toISOString(),
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
  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };
  if (typeof s.title === "string") updates.title = s.title.trim();
  if (typeof s.category === "string") updates.category = s.category;
  if (typeof s.shortDescription === "string") {
    updates.short_description = s.shortDescription;
  }
  if (typeof s.fullDescription === "string") {
    updates.full_description = s.fullDescription;
  }
  if (typeof s.terms === "string") updates.terms = s.terms;
  if (typeof s.redemptionInstructions === "string") {
    updates.redemption_instructions = s.redemptionInstructions;
  }
  if (typeof s.redemptionCodeType === "string") {
    updates.redemption_code_type = s.redemptionCodeType;
  }
  if (typeof s.redemptionCode === "string") {
    updates.redemption_code = s.redemptionCode;
  }
  if (s.startDate) updates.start_date = s.startDate;
  if (s.endDate) updates.end_date = s.endDate;
  if (typeof s.contactEmail === "string") updates.contact_email = s.contactEmail;
  if (typeof s.contactPhone === "string") updates.contact_phone = s.contactPhone;
  if (auth.isAdmin && body?.adminNotes !== undefined) {
    updates.admin_notes = body.adminNotes;
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

  const notes = body?.notes?.trim();
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
  const body = await req.json().catch(() => null) as { token?: string } | null;
  const token = body?.token?.trim() ?? "";
  if (!token || token.length < 32) {
    return jsonResponse({ error: "Invalid device token." }, 400);
  }

  const supabase = supabaseAdmin();
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
