import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { compare } from "https://deno.land/x/bcrypt@v0.4.1/mod.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let payload: {
    email?: string;
    password?: string;
    code?: string;
  };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const emailRaw = payload.email;
  const password = payload.password;
  const code = payload.code?.trim() ?? "";

  if (!emailRaw || !password || !code) {
    return jsonResponse(
      { error: "email, password, and code are required" },
      400,
    );
  }

  const email = normalizeEmail(emailRaw);
  if (password.length < 8) {
    return jsonResponse(
      { error: "Password must be at least 8 characters" },
      400,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return jsonResponse({ error: "Server misconfiguration" }, 500);
  }

  const codeHashFromDb = Deno.env.get("TOURNAMENT_CODE_BCRYPT");
  const codePlain = Deno.env.get("TOURNAMENT_SIGNUP_CODE");

  let codeOk = false;
  if (codeHashFromDb) {
    try {
      codeOk = await compare(code, codeHashFromDb);
    } catch (e) {
      console.error("bcrypt compare failed", e);
      return jsonResponse({ error: "Server misconfiguration" }, 500);
    }
  } else if (codePlain) {
    const a = new TextEncoder().encode(codePlain);
    const b = new TextEncoder().encode(code);
    if (a.length !== b.length) {
      codeOk = false;
    } else {
      let diff = 0;
      for (let i = 0; i < a.length; i++) {
        diff |= a[i] ^ b[i];
      }
      codeOk = diff === 0;
    }
  } else {
    console.error("Set TOURNAMENT_CODE_BCRYPT or TOURNAMENT_SIGNUP_CODE secret");
    return jsonResponse({ error: "Tournament signup is not configured" }, 500);
  }

  if (!codeOk) {
    return jsonResponse({ error: "Invalid tournament code" }, 401);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: invite, error: inviteError } = await admin
    .from("invite_list")
    .select("id, display_name, is_admin, claimed_at")
    .eq("email", email)
    .maybeSingle();

  if (inviteError) {
    console.error(inviteError);
    return jsonResponse({ error: "Could not verify invite" }, 500);
  }

  if (!invite) {
    return jsonResponse(
      { error: "This email is not on the guest list" },
      403,
    );
  }

  if (invite.claimed_at) {
    return jsonResponse(
      { error: "This invite has already been used. Sign in instead." },
      409,
    );
  }

  const { data: created, error: createError } = await admin.auth.admin
    .createUser({
      email,
      password,
      email_confirm: true,
    });

  if (createError || !created.user) {
    const msg = createError?.message ?? "Could not create account";
    if (msg.includes("already been registered")) {
      return jsonResponse(
        { error: "An account already exists for this email. Sign in instead." },
        409,
      );
    }
    console.error(createError);
    return jsonResponse({ error: msg }, 400);
  }

  const userId = created.user.id;

  const { error: profileError } = await admin.from("profiles").insert({
    id: userId,
    email,
    display_name: invite.display_name,
    is_admin: invite.is_admin,
  });

  if (profileError) {
    console.error(profileError);
    await admin.auth.admin.deleteUser(userId);
    return jsonResponse({ error: "Could not finish signup" }, 500);
  }

  const { error: claimError } = await admin
    .from("invite_list")
    .update({
      claimed_at: new Date().toISOString(),
      auth_user_id: userId,
    })
    .eq("id", invite.id);

  if (claimError) {
    console.error(claimError);
    await admin.from("profiles").delete().eq("id", userId);
    await admin.auth.admin.deleteUser(userId);
    return jsonResponse({ error: "Could not finalize invite" }, 500);
  }

  return jsonResponse({ ok: true });
});
