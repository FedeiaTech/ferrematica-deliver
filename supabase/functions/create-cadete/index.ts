// ============================================================================
// Edge Function: create-cadete
// Change: cadete-account-creation — let a dueño create cadete accounts from
// inside the app instead of the Supabase Dashboard (see
// lib/features/auth/domain/cadete_directory.dart's former "design decision
// #5" comment, which documented the manual process this function replaces).
//
// SECURITY PATTERN — TWO SUPABASE CLIENTS, DO NOT COLLAPSE INTO ONE:
//
//   1. `callerClient` — built with the ANON key + the caller's own JWT
//      (forwarded automatically by `supabase.functions.invoke(...)` from an
//      authenticated Flutter session as the `Authorization` header). This
//      client is used ONLY to read the caller's own `profiles` row via
//      `select rol where id = auth.uid()`, relying on the existing
//      `profiles_select_own` RLS policy (migration 0001). If this client
//      could not read a `rol = 'dueno'` row, the request is rejected before
//      anything else happens.
//
//   2. `serviceClient` — built with the `service_role` key (server-side env
//      secret, never shipped to the app). This client is used ONLY after
//      the caller has been verified as an active dueño, to call
//      `auth.admin.createUser()` and insert the new `profiles` row —
//      operations that require bypassing RLS/auth entirely.
//
//   The `service_role` key is capable of doing ANYTHING against this
//   project's database, including creating arbitrary users. If a future
//   edit "simplifies" this to a single `service_role` client and moves the
//   role check to rely on "well, only the app calls this URL", that
//   assumption is false: this function's URL is invocable by anyone with
//   the project's anon key (i.e. anyone who has the Flutter app installed
//   or reads its source). The `callerClient` role check is the ONLY actual
//   security boundary here — do not remove it, and do not let the
//   `serviceClient` do any work before it passes.
// ============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Supabase Auth's own minimum password length (GoTrue default `min_password_length: 6`).
// Mirrored here so a too-short password is rejected with a clear 400 before
// even reaching `auth.admin.createUser()`, instead of surfacing GoTrue's own
// less specific error.
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
  let body: { email?: unknown; password?: unknown; nombre?: unknown; nro?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Cuerpo de la petición inválido (se esperaba JSON).' }, 400);
  }

  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const nombre = typeof body.nombre === 'string' ? body.nombre.trim() : '';

  if (!email) {
    return jsonResponse({ error: 'El email es obligatorio.' }, 400);
  }
  if (!password || password.length < MIN_PASSWORD_LENGTH) {
    return jsonResponse(
      { error: `La contraseña debe tener al menos ${MIN_PASSWORD_LENGTH} caracteres.` },
      400,
    );
  }

  // `nro` is optional (the dueño may not have a number ready yet) but, when
  // present, must be a genuine integer — `Number.isInteger` rejects floats,
  // NaN, and strings that merely *look* numeric, so a typo like "3a" fails
  // loudly here instead of silently coercing to something unexpected.
  let nro: number | null = null;
  if (body.nro !== undefined && body.nro !== null) {
    if (typeof body.nro !== 'number' || !Number.isInteger(body.nro)) {
      return jsonResponse({ error: 'El número de cadete debe ser un entero.' }, 400);
    }
    nro = body.nro;
  }

  // ---------------------------------------------------------------------
  // 2. Verify the caller is an authenticated, active dueño.
  //
  // `callerClient` is scoped with the ANON key and the caller's own JWT
  // (forwarded via the `Authorization` header by `functions.invoke`), so
  // this query runs AS the caller, subject to their own RLS policies —
  // `profiles_select_own` (0001_profiles.sql) lets them read only their
  // own row.
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
      { error: 'Solo un dueño activo puede crear cuentas de cadete.' },
      403,
    );
  }

  // ---------------------------------------------------------------------
  // 3. Caller verified as dueño — now (and only now) use the service-role
  // client to create the auth user and its profiles row.
  // ---------------------------------------------------------------------
  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: createdUser, error: createUserError } =
    await serviceClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // No SMTP/invite-email flow set up — the dueño hands the password to the cadete directly.
    });

  if (createUserError || !createdUser?.user) {
    const status = createUserError?.status ?? 500;
    // GoTrue reports a duplicate email as a 422/400 with "already been
    // registered" in the message — surface that distinctly as 409.
    const message = createUserError?.message ?? 'No se pudo crear el usuario.';
    const isDuplicate = /already.*registered|already exists/i.test(message);
    return jsonResponse(
      { error: isDuplicate ? 'Ya existe una cuenta con ese email.' : message },
      isDuplicate ? 409 : status >= 400 && status < 600 ? status : 500,
    );
  }

  const newUserId = createdUser.user.id;

  const { error: profileInsertError } = await serviceClient.from('profiles').insert({
    id: newUserId,
    rol: 'cadete',
    full_name: nombre || null,
    nro,
    active: true,
  });

  if (profileInsertError) {
    // The auth user was created but the profiles row failed — clean up so
    // we don't leave an orphaned auth.users row with no matching profile
    // (which `SupabaseAuthRepository._resolveSession` would then throw on
    // on next sign-in attempt).
    await serviceClient.auth.admin.deleteUser(newUserId);
    // Postgres unique-violation is 23505 — surface the
    // `profiles_cadete_nro_active_unique` conflict (0021) with a message
    // the dueño can act on, instead of the raw constraint-name error.
    const isDuplicateNro = profileInsertError.code === '23505';
    return jsonResponse(
      {
        error: isDuplicateNro
          ? 'Ya hay un cadete activo con ese número.'
          : `No se pudo crear el perfil del cadete: ${profileInsertError.message}`,
      },
      isDuplicateNro ? 409 : 500,
    );
  }

  return jsonResponse({ id: newUserId }, 200);
});
