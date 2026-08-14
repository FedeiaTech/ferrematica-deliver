-- ============================================================================
-- Migration: 0020_orders_incobrable_resolved.sql
-- Change: incobrable-resuelto — audit marker for a written-off debt that
-- got collected after all
--
-- Adds `orders.incobrable_resolved_at`, set once by the App's
-- `OrdersController.collectPayment` when a dueño registers a late payment
-- against an order whose debt was previously written off
-- (`payment_status` had been `incobrable`). Purely additive, nullable, no
-- backfill.
--
-- Resolving does NOT reopen `incobrable_at`/`incobrable_reason` (0018) —
-- those stay as the permanent record that the debt WAS written off at some
-- point. This column is the counterpart: "and it stopped being incobrable
-- on this date". `payment_status` itself goes back to `cobrado` via the
-- same `collectPayment` write, reusing 0013's existing
-- `orders_pending_balance_valido` constraint shape unchanged (it already
-- accepts `cobrado` with a partial `pending_balance`, or `cobrado` with
-- `pending_balance` null for a full collection) — no constraint changes
-- needed here.
--
-- Depends on: 0018_orders_incobrable.sql (`orders.incobrable_at`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0019 are already applied.
--
-- ORDERING CONSTRAINT (same shape as 0013/0014/0015/0018): apply this
-- migration BEFORE shipping an App build that writes
-- `incobrable_resolved_at` — PostgREST rejects a write referencing an
-- unknown column.
-- ============================================================================

alter table public.orders
  add column if not exists incobrable_resolved_at timestamptz;

comment on column public.orders.incobrable_resolved_at is
  'Set once, by the App''s OrdersController.collectPayment, when a debt previously written off (incobrable_at non-null) gets collected after all. Payment_status itself goes back to cobrado via the same write — this column is a pure audit marker on top ("was incobrable from incobrable_at until this date"), never cleared, never gates any other behavior.';
