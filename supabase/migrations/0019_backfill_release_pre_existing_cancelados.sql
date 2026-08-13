-- ============================================================================
-- Migration: 0019_backfill_release_pre_existing_cancelados.sql
-- Change: one-time backfill — release venta_order_links for orders that
-- were ALREADY cancelado before 0016 existed
--
-- 0016's `venta_order_links_release_on_cancel` trigger only fires on an
-- UPDATE that TRANSITIONS `orders.status` into 'cancelado'
-- (`old.status is distinct from 'cancelado'`). Any order that was already
-- sitting at `status = 'cancelado'` by the time 0016 was applied never
-- produced that transition event, so its venta_order_links row(s) were
-- never released — the trigger has no retroactive effect. This showed up
-- concretely as: retrying delivery of an already-cancelled order (e.g. a
-- venta re-picked for a new pedido) failing with "Esa venta ya fue usada
-- en otro pedido", even though the order it was originally linked to was
-- cancelled.
--
-- This is a ONE-TIME data backfill, not a repeatable schema change — it is
-- idempotent (only touches rows with released_at still null), so re-running
-- it is harmless, but it only needs to run once.
--
-- Depends on: 0016_venta_release_on_cancel.sql (`venta_order_links.released_at`,
-- `venta_order_links_venta_id_active_idx`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0018 are already applied.
-- ============================================================================

update public.venta_order_links l
set released_at = now()
from public.orders o
where l.order_id = o.id
  and o.status = 'cancelado'
  and l.released_at is null;

-- ============================================================================
-- Manual verification
--
-- 1. Before running, check how many rows this will touch:
--    select count(*) from public.venta_order_links l
--    join public.orders o on o.id = l.order_id
--    where o.status = 'cancelado' and l.released_at is null;
--
-- 2. After running, that same count should be 0.
--
-- 3. Spot-check: `select * from ventas_disponibles(90)` should now include
--    the venta(s) that were stuck behind an old cancelled order, assuming
--    they're still within the p_dias window and estado = 'completada'.
-- ============================================================================
