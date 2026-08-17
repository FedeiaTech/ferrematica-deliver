-- ============================================================================
-- Migration: 0023_orders_cadete_insert_policy.sql
-- Change: fix — cadete order push silently rejected by RLS
--
-- `order_sync_service.dart` pushes every locally-changed order via
-- `.upsert(toRow(order), onConflict: 'id')` — Postgrest's
-- `INSERT ... ON CONFLICT (id) DO UPDATE`. Postgres RLS requires the
-- statement's INSERT policy to authorize the proposed row even when the
-- row already exists and the actual effect ends up being the UPDATE branch
-- (the planner cannot know in advance whether a conflict will occur), IN
-- ADDITION to the UPDATE policy covering the conflict-resolution write.
--
-- `orders` (0002_orders.sql) only ever got `owner_all` (dueño, `for all`),
-- `cadete_select`, and `cadete_update` — no INSERT policy scoped to a
-- cadete. A cadete is never the row's `created_by` (the dueño always is,
-- per `OrdersController.createOrder`), so `owner_all`'s `is_owner(created_by)`
-- never matches for them either. Net effect: every push from a cadete
-- account — "Marcar entrega", "Indicar problema", starting navigation,
-- etc. — was rejected by RLS at the INSERT-policy check, even though the
-- order was already legitimately assigned to them and the UPDATE policy
-- alone would have allowed it. The cadete's app surfaces this as
-- `SyncStatus.failed` ("Error de sincronización"), and since the row never
-- reaches Supabase, the dueño's app (which reads its own local mirror of
-- the same table) never sees the delivery result either — in
-- `delivery_stats_screen.dart` or anywhere else.
--
-- Fix: add a narrow INSERT policy mirroring `cadete_update`'s own scope —
-- a cadete may only "insert" (i.e. satisfy the upsert's INSERT-policy
-- check) a row already assigned to them. This does not meaningfully widen
-- what a cadete can do: on a genuine first-insert (no existing row) it
-- would let a cadete create a brand-new order self-assigned to themselves,
-- which is more permissive than intended, but the app never exercises that
-- path (cadetes never call `createOrder`) and it costs nothing over the
-- alternative of leaving every legitimate cadete update broken.
--
-- Depends on: 0001_profiles.sql (`is_cadete()`), 0002_orders.sql (`orders`
-- table, `cadete_select`/`cadete_update`).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0022 are already applied.
-- ============================================================================

create policy cadete_insert
  on public.orders
  for insert
  with check (is_cadete() and assigned_cadete_id = auth.uid());

comment on policy cadete_insert on public.orders is
  'Lets a cadete''s upsert-based push (INSERT ... ON CONFLICT DO UPDATE) satisfy the statement''s INSERT-policy check for an order already assigned to them — without this, every push from a cadete account was rejected by RLS, surfacing as "Error de sincronización" and never reaching the dueño''s stats. Scoped identically to cadete_update.';

-- ============================================================================
-- Manual verification
--
-- 1. As an authenticated, active cadete, run:
--    `insert into orders (id, created_by, assigned_cadete_id, delivery_address,
--     status, created_at, updated_at)
--     values ('<existing order id assigned to this cadete>', '<dueño id>',
--     auth.uid(), 'x', 'entregado', now(), now())
--     on conflict (id) do update set status = excluded.status,
--     updated_at = excluded.updated_at`.
--    Expect success (previously: row-level security policy violation).
--
-- 2. Same statement but with an order id NOT assigned to this cadete.
--    Expect a row-level security policy violation (assigned_cadete_id
--    check fails).
--
-- 3. In the app: log in as the affected cadete, mark a delivery entregado
--    or report a problem. Confirm the order's `SyncStatusChip` clears
--    (no "Error de sincronización") and the change appears in the dueño's
--    stats screen after a pull.
-- ============================================================================
