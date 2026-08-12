-- ============================================================================
-- Migration: 0014_valor_envio.sql
-- Change: valor-envio-y-detalle — Delivery fee tracking (display-only)
--
-- Adds `orders.valor_envio`, the ONLY new column in this change, and
-- reshapes `estado_envios_pos()` (0012, reshaped again by 0013) to also
-- return it alongside the already-existing `orders.delivered_at`, so the
-- POS Reportes screen can surface both a delivery timestamp and the
-- delivery fee collected. No new table, no new RLS policy, no new grant
-- surface other than the mandatory re-emission of 0013's revoke/grant pair
-- (see below).
--
-- `delivered_at` is NOT a new column — it has existed on `orders` since an
-- earlier migration and the App already reads/writes it
-- (`supabase_orders_remote.dart`). It was simply never exposed through
-- `estado_envios_pos()`'s return shape until now.
--
-- Depends on: 0002_orders.sql (`orders.amount_to_charge`), the
-- pre-existing `orders.delivered_at` column, 0013_cobro_parcial.sql
-- (`estado_envios_pos()`, `pending_balance`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0013 are already applied.
--
-- ORDERING CONSTRAINT (design "Migration / Rollout", same shape as 0013):
-- apply this migration BEFORE shipping an App build that writes
-- `valor_envio` — PostgREST rejects an insert/update referencing an
-- unknown column. The POS is safe in either order (its parser degrades
-- `valor_envio`/`delivered_at` to null/absent when the RPC hasn't been
-- reshaped yet, or the columns are absent from the payload).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Column: orders.valor_envio
--
-- Additive, nullable, no backfill: the delivery fee is an optional field
-- the dueño/cadete fills in after the fact (design: "asignar valor de
-- envío a la app como opción a completar"). It is deliberately NOT part of
-- `amount_to_charge`/`pending_balance` — it is a display-only addend for
-- the Subtotal/Envío/Total breakdown shown in the App, never folded into
-- what's "cobrado" on the sale (design: "el valor total no es necesario
-- registrarlo en la factura"). The cadete keeps 100% of it — no company
-- profit to net out, so no separate costs/payouts table is needed; a
-- future "ganancias por cadete" report is a plain aggregate query over
-- this column plus the pre-existing `assigned_cadete_id`/`delivered_at`.
-- ----------------------------------------------------------------------------
alter table public.orders
  add column if not exists valor_envio numeric(12, 2);

comment on column public.orders.valor_envio is
  'Delivery fee, entered separately from amount_to_charge — optional, NULL until the dueño/cadete fills it in. Display-only addend (Subtotal + Envío = Total in the App); never part of amount_to_charge/pending_balance and never required on the invoice. The cadete keeps 100% of it (no cost/payout table).';

-- ----------------------------------------------------------------------------
-- Constraint: orders_valor_envio_no_negativo
--
-- Minimal sanity check — a delivery fee, when present, cannot be negative.
-- Unlike `orders_pending_balance_valido` there is no cross-column
-- invariant to enforce here (valor_envio is independent of
-- amount_to_charge/payment_status), so this is a plain single-column CHECK.
-- ----------------------------------------------------------------------------
alter table public.orders
  add constraint orders_valor_envio_no_negativo check (
    valor_envio is null or valor_envio >= 0
  );

comment on constraint orders_valor_envio_no_negativo on public.orders is
  'valor_envio must be null or >= 0. No other invariant — unlike pending_balance, it has no relationship to amount_to_charge/payment_status.';

-- ----------------------------------------------------------------------------
-- Function: estado_envios_pos(p_dias) — reshaped to append delivered_at,
-- valor_envio
--
-- MANDATORY MECHANICS NOTE (unchanged from 0013): `create or replace
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
-- signature, per 0013's own documented lesson).
--
-- Everything else about the function body is unchanged from 0013: the
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
  delivered_at timestamptz,    -- appended (this migration)
  valor_envio numeric          -- appended LAST (this migration)
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
    o.valor_envio
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
  'SECURITY DEFINER, plpgsql: explicitly raises 42501 when the caller has no active pos_installs row (spec requirement — an unprovisioned/unauthorized caller MUST NOT get a silent empty result), otherwise returns (venta_local_id, status, updated_at, pending_balance, delivered_at, valor_envio) for that install''s ventas linked to a non-deleted pedido within the last p_dias (default 90) days, filtered on ventas.fecha (design decision D4, 0012). delivered_at/valor_envio appended by 0014, always last. Authorization is resolved exclusively via pos_installs keyed on auth.uid() (design decision D2, 0012) — NEVER is_pos_sync()/is_dueno(). No p_install_id parameter (design decision D3, 0012).';

-- ----------------------------------------------------------------------------
-- Grants — MANDATORY re-emission, verbatim from 0013, single overload
--
-- `drop function` above discarded the ACL that 0013 set up. Without the
-- two statements below, the recreated SECURITY DEFINER function reverts
-- to default PUBLIC EXECUTE and becomes anon-callable — a real privilege
-- escalation and the single highest-severity regression risk in this
-- change (per design, same as every prior reshape of this function).
-- ----------------------------------------------------------------------------
revoke execute on function public.estado_envios_pos(integer) from public, anon;
grant execute on function public.estado_envios_pos(integer) to authenticated;

-- ============================================================================
-- Amendment to 0012/0013's manual verification block (step 3d / step 4)
--
-- 0013 amended 0012's step 3d to allow pending_balance as an expected 4th
-- column. This migration amends it again: delivered_at (5th) and
-- valor_envio (6th) are now also expected columns. amount_to_charge (and
-- every other orders column not explicitly selected) remains forbidden —
-- unchanged.
--
-- Step 4 (anon caller denied execute) is NOT superseded by this migration
-- — it must be RE-RUN after 0014 is applied, for the same reason 0013
-- called out: the drop+recreate above is exactly the mechanism that could
-- silently regress it.
-- ============================================================================

-- ============================================================================
-- Manual verification — re-run after applying this migration
--
-- No automated integration test can exercise Postgres RLS/SECURITY
-- DEFINER behavior from this repo without a live Supabase project +
-- authenticated sessions (same limitation documented in 0002/0007/0011-
-- 0013).
--
-- REGRESSION TEST — "anon caller denied execute after estado_envios_pos()
-- reshape" (re-run of 0012 step 4 / 0013's regression check, now against
-- the NEW 6-column signature):
--   a. As anon (anon key only, no Authorization bearer / no session),
--      attempt `select * from estado_envios_pos()` via PostgREST.
--   b. Expect execution to be denied (insufficient privilege / 401-403 at
--      the PostgREST layer), independent of the function's internal 42501
--      check. This MUST pass identically to the pre-0014 behavior; any
--      difference is the regression this migration is most at risk of
--      introducing (drop+recreate discarding the ACL).
--
-- 2. Registered POS reads its own linked ventas, now with delivered_at/
--    valor_envio:
--    a. As a session already provisioned per 0012's manual provisioning
--       block, run `select * from estado_envios_pos()`.
--    b. For a linked order with status = 'entregado' and a non-null
--       orders.delivered_at, expect the 5th returned column to equal that
--       timestamp.
--    c. For a linked order with a non-null orders.valor_envio, expect the
--       6th returned column to equal that value; for one with valor_envio
--       still unset, expect null (never 0, never omitted).
--
-- 3. CHECK constraint rejects a negative value:
--    a. Attempt `update orders set valor_envio = -1 where id = '<any
--       id>'` — expect a check violation (orders_valor_envio_no_negativo).
--    b. Attempt `update orders set valor_envio = 0 where id = '<any
--       id>'` — expect success (0 is a valid, if unusual, delivery fee —
--       unlike pending_balance, there's no "use null instead" rule here).
--    c. Attempt `update orders set valor_envio = null where id = '<any
--       id>'` — expect success (clearing it back to "not yet filled in").
--
-- Document actual results (pass/fail + Supabase project ref) once a real
-- project is provisioned and 0001-0014 have been applied via
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
--   pending_balance numeric
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
--     o.pending_balance
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
--   updated_at, pending_balance) — pre-0014 shape.';
--
-- revoke execute on function public.estado_envios_pos(integer) from public, anon;
-- grant  execute on function public.estado_envios_pos(integer) to authenticated;
--
-- alter table public.orders drop constraint if exists orders_valor_envio_no_negativo;
-- alter table public.orders drop column if exists valor_envio;
-- ============================================================================
