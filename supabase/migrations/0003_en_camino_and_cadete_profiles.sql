-- ============================================================================
-- Migration: 0003_en_camino_and_cadete_profiles.sql
-- Change: navegacion-cadete — Auth, Assignment & Cadete Navigation — PR2
--
-- Widens the `orders.status` check constraint to accept the new `en_camino`
-- status (spec: order-management — "Status lifecycle with en_camino"), and
-- adds a `profiles` SELECT policy letting a dueño list `rol = 'cadete'`
-- rows — needed by PR3's "assign cadete" sheet.
--
-- Depends on: 0001_profiles.sql (is_owner(), is_cadete(), profiles table),
-- 0002_orders.sql (orders table + status check constraint being replaced).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it
--                                  AFTER 0001_profiles.sql and 0002_orders.sql.
--
-- No live Supabase project is provisioned for this repo yet (carried
-- forward from the pedidos archive) — this migration has been reviewed for
-- correctness but NOT executed against a real database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Widen orders.status check constraint to accept 'en_camino'
--
-- Additive: every previously-valid status value stays valid, only the new
-- one is added. Reversible only while no row holds 'en_camino' — drain
-- in-flight deliveries before rolling this migration back.
--
-- Postgres has no `alter constraint ... add value`-style shortcut for a
-- plain check constraint (unlike enum types), so this drops and recreates
-- it. The constraint name matches the one Postgres auto-generates for the
-- inline `check (...)` in 0002_orders.sql (`<table>_<column>_check`).
-- ----------------------------------------------------------------------------
alter table public.orders
  drop constraint if exists orders_status_check;

alter table public.orders
  add constraint orders_status_check
  check (status in ('pendiente', 'asignado', 'en_camino', 'entregado', 'cancelado'));

-- ----------------------------------------------------------------------------
-- Policy: profiles_select_cadetes
--
-- A dueño needs to list active cadete accounts to populate the
-- "assign cadete" sheet (PR3). `profiles_select_own` (0001_profiles.sql)
-- only lets a user read their own row, so this adds a second, narrower
-- SELECT policy: any authenticated dueño may read rows where
-- `rol = 'cadete'`. Postgres RLS policies are OR'd together for the same
-- command, so this is additive to `profiles_select_own`, not a replacement.
--
-- Scoped to `for select` only — a dueño still cannot insert/update/delete
-- a cadete's profile row through this policy.
-- ----------------------------------------------------------------------------
create policy profiles_select_cadetes
  on public.profiles
  for select
  using (
    rol = 'cadete'
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.rol = 'dueno'
        and p.active = true
    )
  );

comment on policy profiles_select_cadetes on public.profiles is
  'Lets an active dueño read rol=cadete profile rows, so the order-assignment UI (PR3) can list available cadetes. Additive to profiles_select_own — does not grant insert/update/delete.';

-- ============================================================================
-- Manual verification (carried forward — no live Supabase project yet)
--
-- 1. Status constraint:
--    a. Insert (or update) an order with status = 'en_camino'. Expect
--       success (previously this would have raised a check violation).
--    b. Attempt status = 'invalid_status'. Expect a check violation, same
--       as before this migration.
--
-- 2. profiles_select_cadetes:
--    a. As an authenticated dueño, `select * from profiles where rol =
--       'cadete'`. Expect all active cadete rows returned.
--    b. As an authenticated cadete (not dueño), run the same query. Expect
--       ZERO rows for OTHER cadetes (only `profiles_select_own` applies to
--       their own row) — this policy is dueño-only by its `exists` check.
-- ============================================================================
