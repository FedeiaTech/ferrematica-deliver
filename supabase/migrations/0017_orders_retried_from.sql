-- ============================================================================
-- Migration: 0017_orders_retried_from.sql
-- Change: retry-chain-link — links a "Reintentar entrega" order back to the
-- cancelled order it was created from
--
-- Adds `orders.retried_from_order_id`, set once at creation by
-- `OrdersController.createOrder` (App) when the order form is opened via
-- "Reintentar entrega". Purely additive, nullable, no backfill — every
-- pre-existing row reads `retried_from_order_id = null`, meaning "not
-- created as a retry", consistent with how every prior order was created
-- before this column existed.
--
-- No FK to `orders(id)`, same rationale as `venta_order_links.order_id` in
-- 0011_ventas_mirror.sql: the referenced (original, cancelled) order might
-- not have synced to Supabase yet by the time this retry order pushes,
-- under the app's offline-first sync model.
--
-- Depends on: 0002_orders.sql (`orders` table).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0016 are already applied.
--
-- ORDERING CONSTRAINT (same shape as 0013/0014/0015): apply this migration
-- BEFORE shipping an App build that writes `retried_from_order_id` —
-- PostgREST rejects an insert/update referencing an unknown column.
-- ============================================================================

alter table public.orders
  add column if not exists retried_from_order_id uuid;

comment on column public.orders.retried_from_order_id is
  'The id of the cancelled order this one was created from via "Reintentar entrega" — null for every order created any other way. Never cleared once set. No FK: the referenced order may not have synced yet (offline-first). A retry-of-a-retry points at its own immediate predecessor, not the original — walk the chain to find the first attempt.';
