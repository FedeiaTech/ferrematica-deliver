-- ============================================================================
-- Migration: 0012_pos_estado_envios.sql
-- Change: pos-estado-envios — Estado de envío en Reportes del POS
--
-- Adds `pos_installs`, the ONLY new identity binding a POS installation to
-- an authenticated Supabase session, and `estado_envios_pos()`, the ONLY
-- new read surface: a SECURITY DEFINER RPC that lets a registered POS
-- install read back the delivery status of its own ventas (via
-- venta_order_links → orders), scoped to the last 90 days, without any new
-- SELECT policy on orders/venta_order_links/ventas and without reusing
-- is_pos_sync()/is_dueno() for authorization (see design decision D2 — a
-- dueño JWT alone must NOT be sufficient to read order data through this
-- path).
--
-- Depends on: 0001_profiles.sql (`profiles`), 0002_orders.sql (`orders`),
-- 0011_ventas_mirror.sql (`ventas`, `venta_order_links`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0011 are already applied.
--
-- No live Supabase project is provisioned for this repo yet (URL/anon key
-- are placeholders in dart_define.example.json). Migrations 0001-0011 are
-- also still unapplied to a real project (per prior session notes). This
-- migration has been reviewed for correctness but NOT executed against a
-- real database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: pos_installs
--
-- The ONLY binding between a Supabase auth identity (auth.uid()) and a POS
-- installation. `install_id` has intentionally NO foreign key (design
-- decision D1): `ventas` only has `unique(install_id, venta_local_id)`, not
-- a unique constraint on `install_id` alone, so a plain FK is impossible —
-- and a POS may legitimately be registered before its first venta exists
-- anyway. `profile_id` IS a real FK to `profiles(id)` and is unique: one
-- profile maps to at most one active install.
--
-- RLS is enabled with ZERO policies for `authenticated` — row management
-- (insert/update/delete) is service_role / SQL Editor only, via the manual
-- provisioning procedure at the end of this file (design decision D6: the
-- install_id is a random UUID v4 generated client-side on first sync, so it
-- is unknowable at migration-write time and cannot be backfilled).
-- ----------------------------------------------------------------------------
create table if not exists public.pos_installs (
  install_id uuid primary key,

  profile_id uuid not null unique references public.profiles (id),
  active boolean not null default true,

  created_at timestamptz not null default now()
);

comment on table public.pos_installs is
  'Binds a POS installation (install_id, generated client-side on first sync — see ventas.install_id in 0011) to a Supabase profile. The ONLY identity source used by estado_envios_pos() for authorization (design decision D2) — never is_pos_sync()/is_dueno(). RLS enabled, zero policies: rows are managed exclusively via service_role / SQL Editor, see manual provisioning block below.';
comment on column public.pos_installs.install_id is
  'No foreign key by design (D1): ventas has no unique constraint on install_id alone (only unique(install_id, venta_local_id)), and a POS may be registered before its first venta. Matches the type/value space of ventas.install_id.';
comment on column public.pos_installs.profile_id is
  'The Supabase profile (auth.uid()) authorized to read this install''s estado de envío data. Unique — one profile maps to at most one active install.';
comment on column public.pos_installs.active is
  'Soft-disable switch for a provisioned install without deleting the row (audit trail). estado_envios_pos() only resolves rows where active = true.';

alter table public.pos_installs enable row level security;

-- ----------------------------------------------------------------------------
-- Function: estado_envios_pos(p_dias)
--
-- SECURITY DEFINER, resolving the caller's install_id via pos_installs
-- keyed on auth.uid() (design decision D2). MUST NOT use is_pos_sync() or
-- is_dueno() — both are `rol = 'dueno' AND active`, so reusing either would
-- turn every dueño JWT into an order reader regardless of pos_installs
-- provisioning. A caller with no active pos_installs row (including a
-- dueño with no install registered) is rejected with SQLSTATE 42501 —
-- NEVER a silently empty result set, which would be indistinguishable from
-- "this install legitimately has zero linked orders" (spec requirement
-- "estado_envios_pos() authorization independence").
--
-- No p_install_id parameter (design decision D3): install resolution is
-- server-side only, never client-supplied, even though the system is
-- single-tenant today.
--
-- The 90-day window filters ventas.fecha, NOT orders.updated_at (design
-- decision D4): filtering on orders.updated_at would make an old,
-- long-delivered pedido vanish from the result and render as an em dash —
-- indistinguishable from "no pedido", i.e. a lie. Filtering on v.fecha
-- (indexed via ventas_fecha_idx, 0011) means "the last 90 days of sales",
-- exactly what the column claims. orders.updated_at is still RETURNED, as
-- a freshness signal for the UI tooltip. A soft-deleted pedido
-- (orders.deleted_at is not null) is excluded and therefore also renders
-- as no-pedido.
--
-- Join path: pos_installs (auth.uid()) → ventas (install_id) →
-- venta_order_links (venta_id) → orders (id). All inner joins — a venta
-- with no link, or a link whose order is soft-deleted, contributes no row.
--
-- NOTE — deviation from the tasks artifact's "language sql": a plain SQL
-- function body cannot RAISE an explicit exception before evaluating its
-- FROM clause, so a `language sql` implementation of this authorization
-- check would only ever be able to return zero rows for an unprovisioned
-- caller — exactly the silent-empty-set ambiguity the spec forbids
-- ("Unprovisioned POS account is rejected the same way", "MUST NOT
-- silently return an empty result set"). `language plpgsql` is required to
-- honor that requirement with an explicit `raise ... using errcode =
-- '42501'` guard before the query runs. All other constraints from design
-- D2/D3/D4 (auth.uid() resolution only, no p_install_id, filter on
-- ventas.fecha) are preserved unchanged.
-- ----------------------------------------------------------------------------
create or replace function public.estado_envios_pos(p_dias integer default 90)
returns table (
  venta_local_id integer,
  status text,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.pos_installs pi
    where pi.profile_id = auth.uid()
      and pi.active = true
  ) then
    raise exception 'caller has no active pos_installs row'
      using errcode = '42501';
  end if;

  return query
  select
    v.venta_local_id,
    o.status,
    o.updated_at
  from public.pos_installs pi
  join public.ventas v
    on v.install_id = pi.install_id
  join public.venta_order_links l
    on l.venta_id = v.id
  join public.orders o
    on o.id = l.order_id
  where pi.profile_id = auth.uid()
    and pi.active = true
    and v.fecha >= now() - (p_dias || ' days')::interval
    and o.deleted_at is null;
end;
$$;

comment on function public.estado_envios_pos(integer) is
  'SECURITY DEFINER, plpgsql: explicitly raises 42501 when the caller has no active pos_installs row (spec requirement — an unprovisioned/unauthorized caller MUST NOT get a silent empty result), otherwise returns (venta_local_id, status, updated_at) for that install''s ventas linked to a non-deleted pedido within the last p_dias (default 90) days, filtered on ventas.fecha (design decision D4). Authorization is resolved exclusively via pos_installs keyed on auth.uid() (design decision D2) — NEVER is_pos_sync()/is_dueno(). No p_install_id parameter (design decision D3).';

-- ----------------------------------------------------------------------------
-- Grants
--
-- NEW pattern in this repo (design decision D5): no migration 0001-0011
-- contains an explicit `grant execute`. ventas_disponibles() (0011) relies
-- on the default PUBLIC EXECUTE, which is safe there only because it is
-- SECURITY INVOKER — RLS still applies as the calling session. This
-- function is SECURITY DEFINER, so under the default grant it would be
-- callable by `anon` too (the DEFINER's own privileges apply, not the
-- caller's), which is exactly the exposure the spec's "Grants restrict
-- execution" requirement forbids. Both function signatures created above
-- are the same overload (integer), so a single revoke/grant pair covers
-- whichever definition is left in place.
-- ----------------------------------------------------------------------------
revoke execute on function public.estado_envios_pos(integer) from public, anon;
grant execute on function public.estado_envios_pos(integer) to authenticated;

-- ============================================================================
-- Manual RLS/RPC verification (task T4)
--
-- No automated integration test can exercise Postgres RLS/SECURITY DEFINER
-- behavior from this repo without a live Supabase project + authenticated
-- sessions (same limitation documented in 0002/0007/0011). Once a project
-- is provisioned and this migration applied, verify manually via the
-- Supabase SQL Editor (or authenticated HTTP sessions):
--
-- 1. Human dueño JWT without pos_installs is rejected:
--    a. As a session whose profile has rol = 'dueno' and NO row in
--       pos_installs, run `select * from estado_envios_pos()`.
--    b. Expect an error with SQLSTATE 42501 ("caller has no active
--       pos_installs row"), NOT zero rows returned successfully.
--
-- 2. Unprovisioned POS account is rejected the same way:
--    a. As any authenticated session with no matching ACTIVE pos_installs
--       row (e.g. a row exists but active = false), run
--       `select * from estado_envios_pos()`.
--    b. Expect the same 42501 error as step 1.
--
-- 3. Registered POS reads its own linked ventas:
--    a. Insert a pos_installs row for a test profile:
--       `insert into pos_installs (install_id, profile_id) values
--       ('<uuid>', '<profile id>')`.
--    b. Ensure at least one ventas row exists with that install_id, linked
--       via venta_order_links to an orders row with a known status.
--    c. As that profile's session, run `select * from estado_envios_pos()`.
--    d. Expect exactly one row: venta_local_id, status, updated_at
--       matching the linked order. Confirm NO other columns are present —
--       specifically no client_name, client_phone, delivery_address,
--       amount_to_charge, or any other orders column.
--
-- 4. Anonymous caller cannot execute:
--    a. As anon (anon key only, no Authorization bearer / no session),
--       attempt `select * from estado_envios_pos()` via PostgREST
--       (`GET /rest/v1/rpc/estado_envios_pos` or `POST` with the anon
--       apikey and no bearer override).
--    b. Expect execution to be denied (insufficient privilege / 401-403 at
--       the PostgREST layer), independent of the function's internal
--       42501 check — the revoke above must deny it before the function
--       body ever runs.
--
-- 5. Window independence from UI filter:
--    a. As the registered POS session from step 3, run
--       `select * from estado_envios_pos()` (no p_dias override) and
--       confirm it still evaluates a 90-day window regardless of whatever
--       date range the Reportes screen itself is filtered to — the RPC
--       has no knowledge of and is never driven by the UI's own filter.
--
-- Document actual results (pass/fail + Supabase project ref) in the PR
-- description once a real project is provisioned and 0001-0012 have been
-- applied via `supabase db push`.
-- ============================================================================

-- ============================================================================
-- Manual provisioning: registering a POS install (task T5, design D6)
--
-- ConfiguracionDAO.obtenerOGenerarInstallId() generates a random UUID v4 on
-- the POS's first sync and persists it in local SQLite — it is unknowable
-- at migration-write time, so no backfill is possible (chicken-and-egg).
-- Mirrors 0007's task B4 manual provisioning block for the sync service
-- account. Until this procedure runs for a given POS installation,
-- estado_envios_pos() raises 42501 for that install's sync account and the
-- Reportes "Estado de envío" column renders blank for every row — this is
-- the documented degraded state (spec's graceful-degradation requirement),
-- NOT a bug.
--
-- 1. Run the POS once against the target Supabase project with ventas sync
--    enabled (see 0011's own provisioning prerequisites — this reuses the
--    same POS sync service account credentials).
-- 2. Read the generated install_id from the POS's local SQLite:
--      select install_id from configuracion;
-- 3. Insert the binding via the Supabase Dashboard → SQL Editor:
--      insert into public.pos_installs (install_id, profile_id)
--      values ('<install_id from step 2>', '<POS sync account profiles.id>')
--      on conflict (install_id) do update set active = true;
-- 4. Confirm the RPC now succeeds for that install by authenticating as
--    the POS sync account and running `select * from estado_envios_pos()`
--    — expect success (possibly zero rows if no ventas are linked yet),
--    not a 42501 error.
--
-- This is a manual, one-time step per POS installation per Supabase
-- project (dev/staging/prod) and cannot be scripted from this repo without
-- live project credentials and a running POS instance.
-- ============================================================================

-- ============================================================================
-- Rollback
--
-- drop function public.estado_envios_pos(integer);
-- drop table public.pos_installs;
-- ============================================================================
