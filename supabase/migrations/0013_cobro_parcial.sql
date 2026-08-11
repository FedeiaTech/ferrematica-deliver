-- ============================================================================
-- Migration: 0013_cobro_parcial.sql
-- Change: cobro-parcial-pedidos — Partial payment on delivery (PR 1 of 4)
--
-- Adds `orders.pending_balance`, the ONLY new column in this change, and
-- reshapes `estado_envios_pos()` (0012) to also return it, so the POS
-- Reportes screen can surface a partially-collected delivery. No new table,
-- no new RLS policy, no new grant surface other than the mandatory
-- re-emission of 0012's revoke/grant pair (see below).
--
-- Depends on: 0002_orders.sql (`orders.amount_to_charge`,
-- `orders.payment_status`), 0012_pos_estado_envios.sql
-- (`estado_envios_pos()`, `pos_installs`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0012 are already applied.
--
-- No live Supabase project is provisioned for this repo yet (URL/anon key
-- are placeholders in dart_define.example.json). Migrations 0001-0012 are
-- also still unapplied to a real project (per prior session notes). This
-- migration has been reviewed for correctness but NOT executed against a
-- real database.
--
-- ORDERING CONSTRAINT (design "Migration / Rollout"): apply this migration
-- BEFORE shipping an App build that writes `pending_balance` — PostgREST
-- rejects an insert/update referencing an unknown column. The POS is safe
-- in either order (its parser degrades `pending_balance` to null when the
-- RPC hasn't been reshaped yet, or the column is absent from the payload).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Column: orders.pending_balance
--
-- Additive, nullable, no backfill (design decision "No backfill — existing
-- cobrado rows are fully paid by definition"): every pre-existing
-- entregado+cobrado row reads pending_balance = null, i.e. fully paid,
-- consistent with the only meaning `cobrado` ever had before this change.
-- ----------------------------------------------------------------------------
alter table public.orders
  add column if not exists pending_balance numeric(12, 2);

comment on column public.orders.pending_balance is
  'Amount still owed on a partially-collected delivery. NULL means either "fully paid" (payment_status = cobrado) or "not yet collected" (payment_status = pendiente) — never populated for pendiente. When non-null, strictly between 0 and amount_to_charge (see orders_pending_balance_valido). No historical backfill: rows written before this migration are fully paid by definition.';

-- ----------------------------------------------------------------------------
-- Constraint: orders_pending_balance_valido
--
-- Database-level mirror of the domain invariant enforced by Order's
-- constructor assert (design decision DA3): pending_balance is either null,
-- or a strict partial of amount_to_charge on a cobrado order. This is the
-- real backstop — the Dart assert is stripped in release builds, this CHECK
-- is not. A violation here surfaces as a loud sync failure (row stuck at
-- syncStatus: pending), never silent data corruption (spec requirement
-- "Invalid row is rejected at sync time").
-- ----------------------------------------------------------------------------
alter table public.orders
  add constraint orders_pending_balance_valido check (
    pending_balance is null
    or (
      payment_status = 'cobrado'
      and pending_balance > 0
      and amount_to_charge is not null
      and pending_balance < amount_to_charge
    )
  );

comment on constraint orders_pending_balance_valido on public.orders is
  'Mirrors the Order domain invariant (design decision DA3): pending_balance must be null, or a strict partial of amount_to_charge (0 < pending_balance < amount_to_charge) on a payment_status = cobrado row. pendiente rows must always carry a null pending_balance.';

-- ----------------------------------------------------------------------------
-- Function: estado_envios_pos(p_dias) — reshaped to append pending_balance
--
-- MANDATORY MECHANICS NOTE: `create or replace function` cannot change a
-- function's `returns table (...)` shape — Postgres rejects that with
-- "cannot change return type of existing function". The only way to append
-- a column to the return table is `drop function` + `create function`. This
-- is unavoidable here since 0012's estado_envios_pos() must gain a 4th
-- output column (pending_balance numeric, appended LAST after updated_at).
--
-- CRITICAL: dropping a function discards its ACL (revoke/grant state).
-- Recreating it reverts to the default PUBLIC EXECUTE, which — because this
-- function is SECURITY DEFINER — would make it callable by `anon` again,
-- undoing 0012 design decision D5 (see the revoke/grant re-emission block
-- immediately below the function body; treat that block as load-bearing,
-- not optional).
--
-- Everything else about the function body is unchanged from 0012: the
-- 42501 guard for a caller with no active pos_installs row, the join path
-- (pos_installs → ventas → venta_order_links → orders), and the 90-day
-- window filtered on ventas.fecha (design decision D4, NOT orders.updated_at
-- — see 0012's comment block for the full rationale, still valid here
-- unchanged).
-- ----------------------------------------------------------------------------
drop function if exists public.estado_envios_pos(integer);

create function public.estado_envios_pos(p_dias integer default 90)
returns table (
  venta_local_id integer,
  status text,
  updated_at timestamptz,
  pending_balance numeric      -- appended LAST (this migration)
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
    o.updated_at,
    o.pending_balance
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
  'SECURITY DEFINER, plpgsql: explicitly raises 42501 when the caller has no active pos_installs row (spec requirement — an unprovisioned/unauthorized caller MUST NOT get a silent empty result), otherwise returns (venta_local_id, status, updated_at, pending_balance) for that install''s ventas linked to a non-deleted pedido within the last p_dias (default 90) days, filtered on ventas.fecha (design decision D4, 0012). pending_balance appended by 0013 (cobro-parcial-pedidos), always last. Authorization is resolved exclusively via pos_installs keyed on auth.uid() (design decision D2, 0012) — NEVER is_pos_sync()/is_dueno(). No p_install_id parameter (design decision D3, 0012).';

-- ----------------------------------------------------------------------------
-- Grants — MANDATORY re-emission, verbatim from 0012, single overload
--
-- `drop function` above discarded the ACL that 0012 set up. Without the two
-- statements below, the recreated SECURITY DEFINER function reverts to
-- default PUBLIC EXECUTE and becomes anon-callable — a real privilege
-- escalation and the single highest-severity regression risk in this
-- change (per design). This block is byte-identical in intent to 0012's
-- grants block, updated only for the fact both statements still target the
-- same single (integer) overload — the signature's parameter list did not
-- change, only the return table shape did, so no additional overload
-- exists to grant separately.
-- ----------------------------------------------------------------------------
revoke execute on function public.estado_envios_pos(integer) from public, anon;
grant execute on function public.estado_envios_pos(integer) to authenticated;

-- ============================================================================
-- Amendment to 0012's manual verification block (step 3d / step 4)
--
-- 0012 step 3d said: "Confirm NO other columns are present — specifically
-- no client_name, client_phone, delivery_address, amount_to_charge, or any
-- other orders column." That statement is amended as of this migration:
-- `pending_balance` IS now an expected 4th column in the result set.
-- `amount_to_charge` (and every other orders column not explicitly
-- selected) remains forbidden — unchanged.
--
-- 0012 step 4 (anon caller denied execute) is NOT superseded by this
-- migration — it must be RE-RUN after 0013 is applied, because the
-- drop+recreate above is exactly the mechanism that could silently regress
-- it. This is now a named regression check, not just a one-time
-- verification: any future migration that touches estado_envios_pos()'s
-- signature MUST re-run this same step before merging.
-- ============================================================================

-- ============================================================================
-- Manual verification (task 1.5) — re-run after applying this migration
--
-- No automated integration test can exercise Postgres RLS/SECURITY DEFINER
-- behavior from this repo without a live Supabase project + authenticated
-- sessions (same limitation documented in 0002/0007/0011/0012).
--
-- REGRESSION TEST — "anon caller denied execute after estado_envios_pos()
-- reshape" (re-run of 0012 step 4, now against the NEW 4-column signature):
--   a. As anon (anon key only, no Authorization bearer / no session),
--      attempt `select * from estado_envios_pos()` via PostgREST
--      (`GET /rest/v1/rpc/estado_envios_pos` or `POST` with the anon
--      apikey and no bearer override).
--   b. Expect execution to be denied (insufficient privilege / 401-403 at
--      the PostgREST layer), independent of the function's internal 42501
--      check — the revoke above must deny it before the function body
--      ever runs. This MUST pass identically to the pre-0013 behavior;
--      any difference is the regression this migration is most at risk of
--      introducing (drop+recreate discarding the ACL).
--
-- 2. Registered POS reads its own linked ventas, now with pending_balance:
--    a. As a session already provisioned per 0012's manual provisioning
--       block, run `select * from estado_envios_pos()`.
--    b. For a linked order with payment_status = cobrado and a non-null
--       orders.pending_balance, expect the 4th returned column to equal
--       that value.
--    c. For a linked order that is fully paid or still pendiente, expect
--       pending_balance = null in the result — no accidental non-null
--       leakage from an unrelated row.
--
-- 3. CHECK constraint rejects invalid shapes:
--    a. Attempt `update orders set payment_status = 'pendiente',
--       pending_balance = 50 where id = '<any id>'` — expect a check
--       violation (orders_pending_balance_valido): pending_balance must be
--       null when payment_status != 'cobrado'.
--    b. Attempt `update orders set payment_status = 'cobrado',
--       amount_to_charge = 100, pending_balance = 150 where id = '<any
--       id>'` — expect a check violation: pending_balance must be strictly
--       less than amount_to_charge.
--    c. Attempt `update orders set payment_status = 'cobrado',
--       amount_to_charge = 100, pending_balance = 0 where id = '<any
--       id>'` — expect a check violation: pending_balance must be strictly
--       greater than 0 (use null for "fully paid", not 0).
--    d. Attempt `update orders set payment_status = 'cobrado',
--       amount_to_charge = 100, pending_balance = 40 where id = '<any
--       id>'` — expect success.
--
-- Document actual results (pass/fail + Supabase project ref) in the PR
-- description once a real project is provisioned and 0001-0013 have been
-- applied via `supabase db push`.
-- ============================================================================

-- ============================================================================
-- Rollback
--
-- drop function public.estado_envios_pos(integer);
--
-- create function public.estado_envios_pos(p_dias integer default 90)
-- returns table (
--   venta_local_id integer,
--   status text,
--   updated_at timestamptz
-- )
-- language plpgsql
-- security definer
-- stable
-- set search_path = public
-- as $$
-- begin
--   if not exists (
--     select 1
--     from public.pos_installs pi
--     where pi.profile_id = auth.uid()
--       and pi.active = true
--   ) then
--     raise exception 'caller has no active pos_installs row'
--       using errcode = '42501';
--   end if;
--
--   return query
--   select
--     v.venta_local_id,
--     o.status,
--     o.updated_at
--   from public.pos_installs pi
--   join public.ventas v
--     on v.install_id = pi.install_id
--   join public.venta_order_links l
--     on l.venta_id = v.id
--   join public.orders o
--     on o.id = l.order_id
--   where pi.profile_id = auth.uid()
--     and pi.active = true
--     and v.fecha >= now() - (p_dias || ' days')::interval
--     and o.deleted_at is null;
-- end;
-- $$;
--
-- comment on function public.estado_envios_pos(integer) is
--   'SECURITY DEFINER, plpgsql: explicitly raises 42501 when the caller has
--   no active pos_installs row, otherwise returns (venta_local_id, status,
--   updated_at) — pre-0013 shape.';
--
-- revoke execute on function public.estado_envios_pos(integer) from public, anon;
-- grant  execute on function public.estado_envios_pos(integer) to authenticated;
--
-- alter table public.orders drop constraint if exists orders_pending_balance_valido;
-- alter table public.orders drop column if exists pending_balance;
-- ============================================================================
