// ============================================================================
// Edge Function: update-cadete-password
// Change: cadete-crud — let a dueño reset a cadete's password from inside
// the app, mirroring `create-cadete`'s two-client security pattern (see that
// function's header comment for the full rationale — repeated here since
// both functions must independently enforce it, not share a helper, to keep
// each one auditable on its own).
//
// SECURITY PATTERN — TWO SUPABASE CLIENTS, DO NOT COLLAPSE INTO ONE:
//
//   1. `callerClient` — ANON key + the caller's own JWT (forwarded
//      automatically by `supabase.functions.invoke(...)`). Used ONLY to
//      verify the caller is an active dueño via their own `profiles` row
//      (`profiles_select_own` RLS, migration 0001).
//
//   2. `serviceClient` — `service_role` key. Used ONLY after the caller has
//      been verified, to call `auth.admin.updateUserById()` — resetting
//      another user's password requires bypassing normal auth entirely, and
//      MUST NOT be reachable before the dueño check above passes.
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Mirrors create-cadete's own MIN_PASSWORD_LENGTH — GoTrue's default
// `min_password_length: 6`.
const MIN_PASSWORD_LENGTH = 6;

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // ---------------------------------------------------------------------
  // 1. Parse + minimally validate the request body.
  // ---------------------------------------------------------------------
  let body: { cadeteId?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Cuerpo de la petición inválido (se esperaba JSON).' }, 400);
  }

  const cadeteId = typeof body.cadeteId === 'string' ? body.cadeteId.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!cadeteId) {
    return jsonResponse({ error: 'Falta el id del cadete.' }, 400);
  }
  if (!password || password.length < MIN_PASSWORD_LENGTH) {
    return jsonResponse(
      { error: `La contraseña debe tener al menos ${MIN_PASSWORD_LENGTH} caracteres.` },
      400,
    );
  }

  // ---------------------------------------------------------------------
  // 2. Verify the caller is an authenticated, active dueño.
  // ---------------------------------------------------------------------
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'No autorizado.' }, 401);
  }

  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user: callerUser },
    error: callerUserError,
  } = await callerClient.auth.getUser();

  if (callerUserError || !callerUser) {
    return jsonResponse({ error: 'No autorizado.' }, 401);
  }

  const { data: callerProfile, error: callerProfileError } = await callerClient
    .from('profiles')
    .select('rol, active')
    .eq('id', callerUser.id)
    .single();

  if (callerProfileError || !callerProfile) {
    return jsonResponse({ error: 'No se pudo verificar el perfil del solicitante.' }, 403);
  }
  if (callerProfile.rol !== 'dueno' || callerProfile.active !== true) {
    return jsonResponse(
      { error: 'Solo un dueño activo puede cambiar la contraseña de un cadete.' },
      403,
    );
  }

  // ---------------------------------------------------------------------
  // 3. Caller verified as dueño — now (and only now) use the service-role
  // client to confirm the target really is a cadete row, then reset the
  // password. The target-role check uses `serviceClient` (not
  // `callerClient`) because `profiles_select_cadetes` only lets the dueño
  // read cadete rows they'd already see in the roster — reusing it here
  // would be redundant with, not a replacement for, this function's own
  // authorization step above.
  // ---------------------------------------------------------------------
  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: targetProfile, error: targetProfileError } = await serviceClient
    .from('profiles')
    .select('rol')
    .eq('id', cadeteId)
    .maybeSingle();

  if (targetProfileError || !targetProfile || targetProfile.rol !== 'cadete') {
    return jsonResponse({ error: 'No se encontró ese cadete.' }, 404);
  }

  const { error: updateError } = await serviceClient.auth.admin.updateUserById(cadeteId, {
    password,
  });

  if (updateError) {
    return jsonResponse(
      { error: updateError.message ?? 'No se pudo actualizar la contraseña.' },
      updateError.status ?? 500,
    );
  }

  return jsonResponse({ ok: true }, 200);
});
