-- ============================================================================
-- Migration: 0022_products_is_combo.sql
-- Change: web-shop-combo-display — Show POS combos in the Web-Shop catalog
--
-- Adds `products.is_combo`, letting the POS sync push combo rows into the
-- same shared `products` table (0007) instead of building a parallel
-- combo-specific table/fetch path. A combo has no stock of its own — it's
-- resolved from its components' stock only inside the POS at sale time
-- (`VentaDAO.registrarVenta`) — so combo rows are pushed with `stock = 0`
-- (satisfies `products.stock`'s NOT NULL constraint; the number is never
-- shown, see below) and `unit = 'u'` (matches the column default; a combo
-- is always sold as a whole unit).
--
-- Web-Shop is DISPLAY ONLY for combos: this storefront has no cart/checkout
-- flow at all (catalog + "close via WhatsApp"), so there is no risk of a
-- combo being "purchased" online out of sync with real component stock.
-- The Web-Shop UI is responsible for hiding the stock number specifically
-- for `is_combo = true` rows (regular products keep showing stock as
-- before) — that's an application-layer concern, not enforced by this
-- migration.
--
-- Sync-layer detail (SupabaseSyncService, POS side): combo `codigo` values
-- share no uniqueness guarantee with `items.codigo` in the POS's local
-- SQLite (they're separate tables/namespaces), so the sync prefixes combo
-- codes with "COMBO-" before writing to `products.sku` to avoid a
-- collision with an item that happens to use the same code. That's a
-- sync-layer transform only — nothing to enforce here.
--
-- Depends on: 0007_products.sql (`products` table).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0021 are already applied.
--
-- ORDERING CONSTRAINT (same shape as 0013/0014/0015/0018/0020/0021): apply
-- this migration BEFORE shipping a POS build that pushes combo rows to
-- `products` — PostgREST rejects an upsert referencing an unknown column,
-- so an un-migrated project would reject the whole combo-push payload (or
-- silently drop just that field depending on the client, don't rely on
-- either — apply first).
-- ============================================================================

alter table public.products
  add column if not exists is_combo boolean not null default false;

comment on column public.products.is_combo is
  'True for a POS combo (bundle/kit) row, pushed by the POS sync alongside regular items (sku prefixed "COMBO-" to avoid colliding with an item code). Combos have no real stock — stock is resolved from components only inside the POS at sale time — so is_combo=true rows carry stock=0 as a NOT-NULL placeholder; the storefront must hide the stock number for these rows rather than trust the value. Web-Shop has no purchase flow, so this is read/display-only everywhere.';

-- ============================================================================
-- Manual verification
--
-- 1. As the POS sync service account (see 0007's B4 provisioning note),
--    upsert a combo row: `insert into products (sku, name, price, stock,
--    unit, category, is_service, is_active, is_combo) values ('COMBO-001',
--    'Combo Test', 100.00, 0, 'u', 'Combos', false, true, true) on conflict
--    (sku) do update set ...`. Expect success.
-- 2. As anon (storefront read), `select * from products where sku =
--    'COMBO-001'`. Expect the row visible (is_active = true) with
--    is_combo = true.
-- 3. Regular item upserts (is_combo omitted) still default is_combo to
--    false — confirm an existing item row's is_combo stays false after a
--    normal POS sync cycle.
-- ============================================================================
