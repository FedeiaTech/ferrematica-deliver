-- ============================================================================
-- Migration: 0002_orders.sql
-- Change: pedidos — Order Management (dueño slice) — PR2 (Supabase migrations)
--
-- Creates the `orders` table (client-generated UUID PK, one-row-per-order
-- with embedded `items` jsonb per design decision — no separate
-- `order_items` table/collection), RLS policies scoping dueño access to
-- their own orders, and a BEFORE UPDATE trigger enforcing server-side
-- last-write-wins so a stale client cannot clobber newer data.
--
-- Depends on: 0001_profiles.sql (is_owner(), is_cadete()).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it
--                                  AFTER 0001_profiles.sql.
--
-- No live Supabase project is provisioned for this repo yet (URL/anon key
-- are placeholders in dart_define.example.json). This migration has been
-- reviewed for correctness but NOT executed against a real database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: orders
--
-- `id` is supplied by the client (Isar `Order.id`, a UUID string) — NOT
-- `default gen_random_uuid()` — so push/pull upsert-by-id stays idempotent
-- across the offline-first sync loop (order_sync_service, PR3).
--
-- Only `delivery_address` is required; every other business field is
-- nullable to match the domain invariant "address is the only mandatory
-- field at creation" (spec: order-model / Order fields and optionality).
-- ----------------------------------------------------------------------------
create table if not exists public.orders (
  id uuid primary key,

  created_by uuid not null references public.profiles (id),
  assigned_cadete_id uuid references public.profiles (id),

  delivery_address text not null check (length(trim(delivery_address)) > 0),
  latitude double precision,
  longitude double precision,

  client_name text,
  client_phone text,
  notes text,

  amount_to_charge numeric(12, 2),
  payment_method text not null default 'sin_definir'
    check (payment_method in ('efectivo', 'transferencia', 'sin_definir')),
  payment_status text not null default 'pendiente'
    check (payment_status in ('pendiente', 'cobrado')),
  status text not null default 'pendiente'
    check (status in ('pendiente', 'asignado', 'entregado', 'cancelado')),

  items jsonb not null default '[]'::jsonb,

  created_at timestamptz not null,
  updated_at timestamptz not null,
  delivered_at timestamptz,
  deleted_at timestamptz
);

comment on table public.orders is
  'One row per order. items is embedded jsonb (not a child table) so a single row upsert is the atomic sync unit under last-write-wins — see sdd/pedidos/design decision "items as embedded objects / jsonb".';
comment on column public.orders.id is
  'Client-generated UUID (matches Isar OrderModel.id). Never server-generated — required for idempotent upsert-by-id on push/pull.';
comment on column public.orders.updated_at is
  'Last-write-wins comparison key. Enforced server-side by orders_reject_stale_update (see trigger below) — a stale client cannot clobber newer data even if it tries.';

create index if not exists orders_status_idx on public.orders (status);
create index if not exists orders_updated_at_idx on public.orders (updated_at);
create index if not exists orders_assigned_cadete_idx on public.orders (assigned_cadete_id);
create index if not exists orders_created_by_idx on public.orders (created_by);

alter table public.orders enable row level security;

-- ----------------------------------------------------------------------------
-- RLS policies
--
-- owner_all: a dueño may select/insert/update/delete ONLY rows they created.
--   is_owner(created_by) checks BOTH the row-ownership match (created_by =
--   auth.uid()) AND that the caller currently holds an active 'dueno' rol —
--   see is_owner()'s definition in 0001_profiles.sql for why this is a
--   single SECURITY DEFINER function rather than two separate predicates.
--
-- cadete_select / cadete_update: scaffolded per design for the future
-- cadete-facing slice. Cadete write UI is explicitly out of scope for this
-- PR (spec: order-security — "Cadete access to orders is out of scope for
-- this slice"); these policies only ensure that IF a cadete session exists
-- today, it is restricted to rows assigned to them, never blanket order
-- access. Column-level restriction (e.g. cadete may update status but not
-- delivery_address) is deferred to the presentation slice that introduces
-- cadete write flows.
-- ----------------------------------------------------------------------------
create policy owner_all
  on public.orders
  for all
  using (is_owner(created_by))
  with check (is_owner(created_by));

create policy cadete_select
  on public.orders
  for select
  using (is_cadete() and assigned_cadete_id = auth.uid());

create policy cadete_update
  on public.orders
  for update
  using (is_cadete() and assigned_cadete_id = auth.uid())
  with check (is_cadete() and assigned_cadete_id = auth.uid());

-- ----------------------------------------------------------------------------
-- Trigger: orders_reject_stale_update
--
-- Server-side last-write-wins enforcement (design decision: "LWW enforced
-- server-side by trigger, not client trust"). Push is an upsert keyed by
-- `id`; on UPDATE, if the incoming row's updated_at is not strictly newer
-- than the stored row's, the trigger substitutes OLD.* for every mutable
-- column so the write becomes a no-op — the stale client's write is
-- silently discarded rather than erroring, matching the fire-and-forget
-- sync flow (the client doesn't await/inspect this outcome; the next pull
-- will bring it back into agreement with the winning row).
-- ----------------------------------------------------------------------------
create or replace function public.orders_reject_stale_update()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at <= old.updated_at then
    return old;
  end if;
  return new;
end;
$$;

comment on function public.orders_reject_stale_update() is
  'BEFORE UPDATE guard: discards the incoming row (returns OLD) when NEW.updated_at <= OLD.updated_at, enforcing last-write-wins server-side so a stale client cannot clobber newer data.';

drop trigger if exists orders_reject_stale_update on public.orders;
create trigger orders_reject_stale_update
  before update on public.orders
  for each row
  execute function public.orders_reject_stale_update();

-- ============================================================================
-- Manual RLS / trigger verification (task 2.5)
--
-- No automated integration test can exercise Postgres RLS/triggers from
-- this repo without a live Supabase project + two authenticated sessions
-- (see design "Open Questions": dev-session stub is not yet in place).
-- Once a project is provisioned, verify manually via the Supabase SQL
-- Editor (or `psql`) using two separate authenticated sessions:
--
-- 1. RLS — owner scoping:
--    a. As dueño A (JWT for a profile with rol='dueno'), insert an order
--       with created_by = A's auth.uid(). Confirm `select * from orders`
--       returns it.
--    b. As dueño B (a different rol='dueno' profile), run
--       `select * from orders where id = '<A''s order id>'`. Expect ZERO
--       rows (RLS denies read of another owner's order).
--    c. As dueño B, attempt
--       `update orders set delivery_address = 'x' where id = '<A''s order id>'`.
--       Expect 0 rows affected (RLS denies the write).
--
-- 2. RLS — non-owner blocked entirely:
--    a. As a cadete (or any session without an active 'dueno' profile row),
--       attempt `insert into orders (...) values (...)`. Expect a policy
--       violation / 0 rows affected.
--
-- 3. Stale-update trigger:
--    a. As dueño A, note the current `updated_at` of an existing order.
--    b. Attempt `update orders set notes = 'stale' , updated_at = now() - interval '1 hour'
--       where id = '<order id>'`. Expect the row's `notes`/`updated_at` to
--       remain UNCHANGED after the statement (trigger returned OLD).
--    c. Attempt the same update with `updated_at = now() + interval '1 hour'`.
--       Expect the row to be updated normally (trigger returned NEW).
--
-- Document actual results (pass/fail + Supabase project ref) in the PR
-- description once a real project is provisioned and this migration has
-- been applied via `supabase db push`.
-- ============================================================================
