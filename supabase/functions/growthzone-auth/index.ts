import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const growthZoneHost = Deno.env.get("GROWTHZONE_HOST") ?? "";
const clientId = Deno.env.get("GROWTHZONE_CLIENT_ID") ?? "";
const clientSecret = Deno.env.get("GROWTHZONE_CLIENT_SECRET") ?? "";
const allowedRedirectUri =
  Deno.env.get("GROWTHZONE_REDIRECT_URI") ?? "wkcc-perks://auth/callback";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type TokenRequest = {
  code?: string;
  codeVerifier?: string;
  redirectUri?: string;
  refreshToken?: string;
};

type GrowthZoneTokenResponse = {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  id_token?: string;
  token_type?: string;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function ensureConfigured(): string | null {
  if (!growthZoneHost || !clientId || !clientSecret) {
    return "GrowthZone OAuth is not configured on the server.";
  }
  return null;
}

function normalizeHost(host: string): string {
  return host.replace(/\/+$/, "");
}

async function exchangeAuthorizationCode(
  code: string,
  codeVerifier: string,
  redirectUri: string,
): Promise<GrowthZoneTokenResponse> {
  const tokenURL = `${normalizeHost(growthZoneHost)}/oauth/token`;
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: clientId,
    client_secret: clientSecret,
    code,
    redirect_uri: redirectUri,
    code_verifier: codeVerifier,
  });

  const response = await fetch(tokenURL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      typeof payload?.error_description === "string"
        ? payload.error_description
        : "Token exchange failed.",
    );
  }

  return payload as GrowthZoneTokenResponse;
}

async function refreshAccessToken(
  refreshToken: string,
): Promise<GrowthZoneTokenResponse> {
  const tokenURL = `${normalizeHost(growthZoneHost)}/oauth/token`;
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
  });

  const response = await fetch(tokenURL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      typeof payload?.error_description === "string"
        ? payload.error_description
        : "Token refresh failed.",
    );
  }

  return payload as GrowthZoneTokenResponse;
}

function mapTokenResponse(tokens: GrowthZoneTokenResponse) {
  return {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token ?? null,
    expiresIn: tokens.expires_in ?? null,
    idToken: tokens.id_token ?? null,
    tokenType: tokens.token_type ?? "Bearer",
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const configError = ensureConfigured();
  if (configError) {
    return jsonResponse({ error: configError }, 503);
  }

  const url = new URL(req.url);
  const route = url.pathname.split("/").filter(Boolean).at(-1);

  let payload: TokenRequest;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  try {
    if (route === "token") {
      const { code, codeVerifier, redirectUri } = payload;
      if (!code || !codeVerifier || !redirectUri) {
        return jsonResponse(
          { error: "code, codeVerifier, and redirectUri are required." },
          400,
        );
      }

      if (redirectUri !== allowedRedirectUri) {
        return jsonResponse({ error: "redirectUri is not allowed." }, 400);
      }

      const tokens = await exchangeAuthorizationCode(
        code,
        codeVerifier,
        redirectUri,
      );
      return jsonResponse(mapTokenResponse(tokens));
    }

    if (route === "refresh") {
      const { refreshToken } = payload;
      if (!refreshToken) {
        return jsonResponse({ error: "refreshToken is required." }, 400);
      }

      const tokens = await refreshAccessToken(refreshToken);
      return jsonResponse(mapTokenResponse(tokens));
    }

    return jsonResponse({ error: "Unknown route." }, 404);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error.";
    return jsonResponse({ error: message }, 502);
  }
});
