-- ============================================================================
-- Migration: 0015_envio_cobro_parcial.sql
-- Change: envio-cobro-parcial — Partial payment on the delivery fee
--
-- Adds `orders.envio_pending_balance`, the ONLY new column in this change,
-- mirroring `orders.pending_balance` (0013) but for `orders.valor_envio`
-- (0014) instead of `orders.amount_to_charge`. Reshapes `estado_envios_pos()`
-- (0012, reshaped again by 0013 and 0014) to also return it, so the POS
-- Reportes screen can surface a partially-collected delivery fee. No new
-- table, no new RLS policy, no new grant surface other than the mandatory
-- re-emission of 0014's revoke/grant pair (see below).
--
-- Depends on: 0002_orders.sql (`orders.amount_to_charge`,
-- `orders.payment_status`), 0013_cobro_parcial.sql (`orders.pending_balance`,
-- `estado_envios_pos()`), 0014_valor_envio.sql (`orders.valor_envio`,
-- `estado_envios_pos()`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0014 are already applied.
--
-- ORDERING CONSTRAINT (design "Migration / Rollout", same shape as 0013/0014):
-- apply this migration BEFORE shipping an App build that writes
-- `envio_pending_balance` — PostgREST rejects an insert/update referencing an
-- unknown column. The POS is safe in either order (its parser degrades
-- `envio_pending_balance` to null/absent when the RPC hasn't been reshaped
-- yet, or the column is absent from the payload).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Column: orders.envio_pending_balance
--
-- Additive, nullable, no backfill (same rationale as 0013's
-- `pending_balance`): every pre-existing row reads
-- envio_pending_balance = null, i.e. either no delivery fee was ever
-- registered or it was collected in full — consistent with the implicit
-- behavior before this migration existed (the delivery fee was always
-- treated as fully collected once an order was delivered).
-- ----------------------------------------------------------------------------
alter table public.orders
  add column if not exists envio_pending_balance numeric(12, 2);

comment on column public.orders.envio_pending_balance is
  'Amount still owed on valor_envio after a partial collection of the delivery fee. NULL means either "no delivery fee" (valor_envio is null) or "delivery fee fully collected". When non-null, requires valor_envio is not null, and 0 < envio_pending_balance <= valor_envio (see orders_envio_pending_balance_valido). No historical backfill: rows written before this migration are treated as fully collected by default.';

-- ----------------------------------------------------------------------------
-- Constraint: orders_envio_pending_balance_valido
--
-- Database-level mirror of the domain invariant enforced by Order's
-- constructor assert: envio_pending_balance is either null, or a partial of
-- valor_envio. Unlike orders_pending_balance_valido (0013), this uses `<=`
-- instead of a strict `<`: an order where NOTHING was collected on the
-- delivery fee is representable as envio_pending_balance = valor_envio,
-- because — unlike the product side, which already has payment_status =
-- 'pendiente' to represent "nothing collected at all" — the delivery fee has
-- no separate status flag, so the fully-uncollected case must be
-- representable as a pending balance equal to the full fee.
-- ----------------------------------------------------------------------------
alter table public.orders
  add constraint orders_envio_pending_balance_valido check (
    envio_pending_balance is null
    or (
      valor_envio is not null
      and envio_pending_balance > 0
      and envio_pending_balance <= valor_envio
    )
  );

comment on constraint orders_envio_pending_balance_valido on public.orders is
  'Mirrors the Order domain invariant: envio_pending_balance must be null, or a partial of valor_envio (0 < envio_pending_balance <= valor_envio) with valor_envio not null. Unlike orders_pending_balance_valido, this allows envio_pending_balance = valor_envio (nothing collected yet on the delivery fee), since there is no separate payment_status column for the delivery fee.';

-- ----------------------------------------------------------------------------
-- Function: estado_envios_pos(p_dias) — reshaped to append
-- envio_pending_balance
--
-- MANDATORY MECHANICS NOTE (unchanged from 0013/0014): `create or replace
-- function` cannot change a function's `returns table (...)` shape —
-- Postgres rejects that with "cannot change return type of existing
-- function". The only way to append columns to the return table is `drop
-- function` + `create function`.
--
-- CRITICAL: dropping a function discards its ACL (revoke/grant state).
-- Recreating it reverts to the default PUBLIC EXECUTE, which — because
-- this function is SECURITY DEFINER — would make it callable by `anon`
-- again, undoing 0012 design decision D5 (see the revoke/grant
-- re-emission block immediately below the function body; treat that block
-- as load-bearing, not optional — this is the single highest-severity
-- regression risk in every migration that touches this function's
-- signature, per 0013/0014's own documented lesson).
--
-- Everything else about the function body is unchanged from 0014: the
-- 42501 guard for a caller with no active pos_installs row, the join path
-- (pos_installs → ventas → venta_order_links → orders), and the 90-day
-- window filtered on ventas.fecha (design decision D4, 0012).
-- ----------------------------------------------------------------------------
drop function if exists public.estado_envios_pos(integer);

create function public.estado_envios_pos(p_dias integer default 90)
returns table (
  venta_local_id integer,
  status text,
  updated_at timestamptz,
  pending_balance numeric,
  delivered_at timestamptz,
  valor_envio numeric,
  envio_pending_balance numeric   -- appended LAST (this migration)
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
    o.pending_balance,
    o.delivered_at,
    o.valor_envio,
    o.envio_pending_balance
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
  'SECURITY DEFINER, plpgsql: explicitly raises 42501 when the caller has no active pos_installs row (spec requirement — an unprovisioned/unauthorized caller MUST NOT get a silent empty result), otherwise returns (venta_local_id, status, updated_at, pending_balance, delivered_at, valor_envio, envio_pending_balance) for that install''s ventas linked to a non-deleted pedido within the last p_dias (default 90) days, filtered on ventas.fecha (design decision D4, 0012). envio_pending_balance appended by 0015, always last. Authorization is resolved exclusively via pos_installs keyed on auth.uid() (design decision D2, 0012) — NEVER is_pos_sync()/is_dueno(). No p_install_id parameter (design decision D3, 0012).';

-- ----------------------------------------------------------------------------
-- Grants — MANDATORY re-emission, verbatim from 0014, single overload
--
-- `drop function` above discarded the ACL that 0014 set up. Without the
-- two statements below, the recreated SECURITY DEFINER function reverts
-- to default PUBLIC EXECUTE and becomes anon-callable — a real privilege
-- escalation and the single highest-severity regression risk in this
-- change (per design, same as every prior reshape of this function).
-- ----------------------------------------------------------------------------
revoke execute on function public.estado_envios_pos(integer) from public, anon;
grant execute on function public.estado_envios_pos(integer) to authenticated;

-- ============================================================================
-- Amendment to 0014's manual verification block (step 3d / step 4)
--
-- 0014 amended 0013's step 3d to allow delivered_at (5th) and valor_envio
-- (6th) as expected columns. This migration amends it again:
-- envio_pending_balance (7th) is now also an expected column.
-- amount_to_charge (and every other orders column not explicitly selected)
-- remains forbidden — unchanged.
--
-- Step 4 (anon caller denied execute) is NOT superseded by this migration
-- — it must be RE-RUN after 0015 is applied, for the same reason 0013/0014
-- called out: the drop+recreate above is exactly the mechanism that could
-- silently regress it.
-- ============================================================================

-- ============================================================================
-- Manual verification — re-run after applying this migration
--
-- No automated integration test can exercise Postgres RLS/SECURITY
-- DEFINER behavior from this repo without a live Supabase project +
-- authenticated sessions (same limitation documented in 0002/0007/0011-
-- 0014).
--
-- REGRESSION TEST — "anon caller denied execute after estado_envios_pos()
-- reshape" (re-run of 0012 step 4 / 0013/0014's regression check, now
-- against the NEW 7-column signature):
--   a. As anon (anon key only, no Authorization bearer / no session),
--      attempt `select * from estado_envios_pos()` via PostgREST.
--   b. Expect execution to be denied (insufficient privilege / 401-403 at
--      the PostgREST layer), independent of the function's internal 42501
--      check. This MUST pass identically to the pre-0015 behavior; any
--      difference is the regression this migration is most at risk of
--      introducing (drop+recreate discarding the ACL).
--
-- 2. Registered POS reads its own linked ventas, now with
--    envio_pending_balance:
--    a. As a session already provisioned per 0012's manual provisioning
--       block, run `select * from estado_envios_pos()`.
--    b. For a linked order with a non-null orders.envio_pending_balance,
--       expect the 7th returned column to equal that value.
--    c. For a linked order with valor_envio set and the delivery fee fully
--       collected (envio_pending_balance = null), expect the 7th returned
--       column to be null.
--
-- 3. CHECK constraint rejects invalid shapes:
--    a. Attempt `update orders set valor_envio = null,
--       envio_pending_balance = 50 where id = '<any id>'` — expect a check
--       violation (orders_envio_pending_balance_valido): envio_pending_balance
--       must be null when valor_envio is null.
--    b. Attempt `update orders set valor_envio = 100,
--       envio_pending_balance = 150 where id = '<any id>'` — expect a check
--       violation: envio_pending_balance must be <= valor_envio.
--    c. Attempt `update orders set valor_envio = 100,
--       envio_pending_balance = 0 where id = '<any id>'` — expect a check
--       violation: envio_pending_balance must be strictly greater than 0
--       (use null for "fully collected", not 0).
--    d. Attempt `update orders set valor_envio = 100,
--       envio_pending_balance = 100 where id = '<any id>'` — expect success
--       (nothing collected on the delivery fee yet).
--    e. Attempt `update orders set valor_envio = 100,
--       envio_pending_balance = 40 where id = '<any id>'` — expect success.
--
-- Document actual results (pass/fail + Supabase project ref) once a real
-- project is provisioned and 0001-0015 have been applied via
-- `supabase db push`.
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
--   updated_at timestamptz,
--   pending_balance numeric,
--   delivered_at timestamptz,
--   valor_envio numeric
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
--     o.updated_at,
--     o.pending_balance,
--     o.delivered_at,
--     o.valor_envio
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
--   updated_at, pending_balance, delivered_at, valor_envio) — pre-0015
--   shape.';
--
-- revoke execute on function public.estado_envios_pos(integer) from public, anon;
-- grant  execute on function public.estado_envios_pos(integer) to authenticated;
--
-- alter table public.orders drop constraint if exists orders_envio_pending_balance_valido;
-- alter table public.orders drop column if exists envio_pending_balance;
-- ============================================================================
