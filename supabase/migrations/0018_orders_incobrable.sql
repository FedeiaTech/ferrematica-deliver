-- ============================================================================
-- Migration: 0018_orders_incobrable.sql
-- Change: orders-incobrable — "Marcar incobrable" (write off outstanding
-- debt on a delivered order, App-side action; POS gets read-only visibility)
--
-- Adds `orders.incobrable_at`/`orders.incobrable_reason` and extends the
-- `payment_status` CHECK constraint to accept a third value, `'incobrable'`
-- (App domain: `PaymentStatus.incobrable`, appended at the end of that enum
-- — same Isar-ordinal-safety rationale as `OrderStatus.enCamino`). Also
-- reshapes `estado_envios_pos()` (0012, reshaped again by 0013/0014/0015)
-- to append `payment_status`, so the POS Reportes screen can tell a written-
-- off debt apart from one still outstanding — today it can only show
-- `pending_balance` as a bare "falta $X" with no payment-status label at
-- all (`ReportsController`'s `colEstadoEnvio` cell).
--
-- `pending_balance` is deliberately left UNCHANGED when payment_status
-- becomes 'incobrable' — the App keeps it as a historical record of what
-- was written off (see `Order.incobrableAt`'s doc comment), so
-- `orders_pending_balance_valido` (0013) is widened to also accept
-- `payment_status = 'incobrable'`, not just `'cobrado'`.
--
-- No new table, no new RLS policy — `orders` UPDATE is already covered by
-- the existing owner policy from 0002_orders.sql, and this action is
-- App-only (dueño), never POS-initiated (POS never writes to `orders` —
-- confirmed read-only via `estado_envios_pos()` only).
--
-- Depends on: 0002_orders.sql (`orders.payment_status`),
-- 0013_cobro_parcial.sql (`orders.pending_balance`,
-- `orders_pending_balance_valido`, `estado_envios_pos()`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0017 are already applied.
--
-- ORDERING CONSTRAINT (same shape as 0013/0014/0015): apply this migration
-- BEFORE shipping an App build that writes `payment_status = 'incobrable'`
-- or `incobrable_at`/`incobrable_reason` — PostgREST rejects a write
-- referencing an unknown column, and the old CHECK constraint would reject
-- the new payment_status value outright. The POS is safe in either order —
-- its parser degrades `payment_status` to absent/null when the RPC hasn't
-- been reshaped yet.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Columns: orders.incobrable_at, orders.incobrable_reason
--
-- Additive, nullable, no backfill — every pre-existing row reads both as
-- null, i.e. "never written off", consistent with every order created
-- before this migration existed. Set once by the App's
-- `OrdersController.markIncobrable`, never cleared — final, no "undo"
-- action exists (design decision, matches `venta_order_links`/
-- `deliveryProblem`'s one-way-claim precedent elsewhere in this schema).
-- ----------------------------------------------------------------------------
alter table public.orders
  add column if not exists incobrable_at timestamptz,
  add column if not exists incobrable_reason text;

comment on column public.orders.incobrable_at is
  'When the dueño wrote off this order''s outstanding debt as uncollectible (App action, OrdersController.markIncobrable). Null = never written off. Set once, never cleared.';
comment on column public.orders.incobrable_reason is
  'Optional free-text note captured alongside incobrable_at — why the debt was written off. Never required.';

-- ----------------------------------------------------------------------------
-- Constraint: orders_payment_status_check — widened to accept 'incobrable'
--
-- Inline `check (payment_status in (...))` from 0002_orders.sql, dropped
-- under Postgres' default auto-generated name for a column-level CHECK
-- (`<table>_<column>_check`) and recreated under the same name with the
-- third value added, so no other migration needs to learn a new name.
-- ----------------------------------------------------------------------------
alter table public.orders
  drop constraint if exists orders_payment_status_check;

alter table public.orders
  add constraint orders_payment_status_check
    check (payment_status in ('pendiente', 'cobrado', 'incobrable'));

-- ----------------------------------------------------------------------------
-- Constraint: orders_pending_balance_valido — widened to also allow
-- 'incobrable', not just 'cobrado'
--
-- 0013 required `payment_status = 'cobrado'` whenever `pending_balance` is
-- set. Marking an order incobrable deliberately leaves `pending_balance`
-- untouched (historical record of what was forgiven — see
-- `orders.incobrable_at`'s comment above), so the constraint must accept
-- BOTH statuses now. Recreated under 0013's original name (no separate
-- named constraint for this migration's own drop/recreate cycle).
-- ----------------------------------------------------------------------------
alter table public.orders
  drop constraint if exists orders_pending_balance_valido;

alter table public.orders
  add constraint orders_pending_balance_valido check (
    pending_balance is null
    or (
      payment_status in ('cobrado', 'incobrable')
      and amount_to_charge is not null
      and pending_balance > 0
      and pending_balance < amount_to_charge
    )
  );

comment on constraint orders_pending_balance_valido on public.orders is
  'Mirrors the Order domain invariant: pending_balance must be null, or a strict partial of amount_to_charge (0 < pending_balance < amount_to_charge) on an order whose payment_status is cobrado OR incobrable (incobrable keeps pending_balance as a historical record of what was written off — 0018).';

-- ----------------------------------------------------------------------------
-- Function: estado_envios_pos(p_dias) — reshaped to append payment_status
--
-- Same drop+recreate mechanics as every prior reshape of this function
-- (0013/0014/0015) — `create or replace` cannot change `returns table
-- (...)`. The mandatory revoke/grant re-emission below is LOAD-BEARING:
-- dropping discards this SECURITY DEFINER function's ACL, and skipping the
-- re-emission makes it anon-callable again (0012 design decision D5).
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
  envio_pending_balance numeric,
  payment_status text   -- appended LAST (this migration)
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
    o.envio_pending_balance,
    o.payment_status
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
  'SECURITY DEFINER, plpgsql: explicitly raises 42501 when the caller has no active pos_installs row, otherwise returns (venta_local_id, status, updated_at, pending_balance, delivered_at, valor_envio, envio_pending_balance, payment_status) for that install''s ventas linked to a non-deleted pedido within the last p_dias (default 90) days, filtered on ventas.fecha (design decision D4, 0012). payment_status appended by 0018 (always last) so the POS Reportes screen can distinguish a written-off (incobrable) debt from one still outstanding — see ReportsController''s colEstadoEnvio. Authorization resolved exclusively via pos_installs keyed on auth.uid() (design decision D2, 0012). No p_install_id parameter (design decision D3, 0012).';

-- ----------------------------------------------------------------------------
-- Grants — MANDATORY re-emission, verbatim pattern from 0013/0014/0015
-- ----------------------------------------------------------------------------
revoke execute on function public.estado_envios_pos(integer) from public, anon;
grant execute on function public.estado_envios_pos(integer) to authenticated;

-- ============================================================================
-- Amendment to 0015's manual verification block (step 3d)
--
-- payment_status (8th column) is now also an expected column returned by
-- estado_envios_pos(). Every other orders column not explicitly selected
-- remains forbidden — unchanged.
--
-- Step "anon caller denied execute" is NOT superseded by this migration —
-- it must be RE-RUN after 0018 is applied, same reason as every prior
-- reshape: the drop+recreate above is exactly the mechanism that could
-- silently regress it.
-- ============================================================================

-- ============================================================================
-- Manual verification — re-run after applying this migration
--
-- No automated integration test can exercise Postgres RLS/SECURITY
-- DEFINER behavior from this repo without a live Supabase project +
-- authenticated sessions (same limitation documented in every prior
-- migration touching estado_envios_pos()).
--
-- 1. REGRESSION TEST — anon caller denied execute, now against the NEW
--    8-column signature:
--    a. As anon (anon key only), attempt `select * from estado_envios_pos()`.
--    b. Expect execution denied (401/403 at PostgREST). Any difference from
--       pre-0018 behavior is the regression this migration is most at risk
--       of introducing.
--
-- 2. payment_status round-trips through the RPC:
--    a. Update a linked order: `update orders set payment_status =
--       'incobrable', incobrable_at = now(), incobrable_reason = 'test'
--       where id = '<any linked order id>'`. Expect success (CHECK
--       constraint accepts the new value).
--    b. As the linked POS session, `select * from estado_envios_pos()`.
--       Expect the 8th column to read 'incobrable' for that row.
--
-- 3. orders_pending_balance_valido still enforces the partial-amount shape,
--    now for both statuses:
--    a. Attempt `update orders set payment_status = 'incobrable',
--       pending_balance = 50, amount_to_charge = 40 where id = '<any id>'`
--       — expect a check violation (pending_balance must be < amount_to_charge).
--    b. Attempt `update orders set payment_status = 'pendiente',
--       pending_balance = 50 where id = '<any id>'` — expect a check
--       violation (pending_balance requires cobrado or incobrable).
--
-- Document actual results (pass/fail + Supabase project ref) once applied.
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
--   valor_envio numeric,
--   envio_pending_balance numeric
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
--     o.valor_envio,
--     o.envio_pending_balance
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
-- revoke execute on function public.estado_envios_pos(integer) from public, anon;
-- grant  execute on function public.estado_envios_pos(integer) to authenticated;
--
-- alter table public.orders drop constraint if exists orders_pending_balance_valido;
-- alter table public.orders add constraint orders_pending_balance_valido check (
--   pending_balance is null
--   or (
--     payment_status = 'cobrado'
--     and amount_to_charge is not null
--     and pending_balance > 0
--     and pending_balance < amount_to_charge
--   )
-- );
--
-- alter table public.orders drop constraint if exists orders_payment_status_check;
-- alter table public.orders add constraint orders_payment_status_check
--   check (payment_status in ('pendiente', 'cobrado'));
--
-- alter table public.orders drop column if exists incobrable_reason;
-- alter table public.orders drop column if exists incobrable_at;
-- ============================================================================
