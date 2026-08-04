-- ============================================================================
-- Migration: 0009_fix_owner_policy_scope.sql
-- Change: connect-web-catalog-to-shared-products — fix RLS over-permission
--
-- Bug found in manual testing: 0008's `products_write_owner` and
-- `product_images_write_owner` policies were declared `for all`, which in
-- Postgres implicitly includes SELECT — not just insert/update/delete. RLS
-- policies are permissive (OR'd together), so a dueno-authenticated session
-- could read ALL rows via this policy, bypassing `products_select_public`'s
-- `is_active = true` filter entirely. Confirmed via curl: a tombstoned
-- (is_active=false) product was still visible to a dueno session and showed
-- up as an editable item in the Web-Shop admin panel — it should have been
-- invisible, exactly like it already is to anon/public readers.
--
-- Fix: replace the `for all` policies with policies scoped to only the
-- commands each app actually issues — `update` for products (Web-Shop never
-- inserts/deletes product rows, see 0008's own comments), and
-- insert/update/delete for product_images (Web-Shop's gallery manager does
-- all three, but never needs its own broadened SELECT — reads are already
-- covered by product_images_select_public). Postgres CREATE POLICY only
-- accepts a single command per policy (no `for insert, update` list), so
-- product_images needs three separate command-scoped policies instead of
-- one `for all`.
--
-- Depends on: 0008_products_webshop_fields.sql (is_dueno(), the policies
-- being replaced here).
--
-- HOW TO APPLY: same as prior migrations — supabase db push, or paste into
-- SQL Editor, AFTER 0001-0008.
-- ============================================================================

drop policy if exists products_write_owner on public.products;

create policy products_update_owner
  on public.products
  for update
  to authenticated
  using (is_dueno())
  with check (is_dueno());

comment on policy products_update_owner on public.products is
  'Scoped to UPDATE only (not the "for all" this replaces) — Web-Shop never inserts/deletes products, and unscoped "for all" was accidentally granting dueno sessions unrestricted SELECT, bypassing the is_active=true filter in products_select_public.';

drop policy if exists product_images_write_owner on public.product_images;

create policy product_images_insert_owner
  on public.product_images
  for insert
  to authenticated
  with check (is_dueno());

create policy product_images_update_owner
  on public.product_images
  for update
  to authenticated
  using (is_dueno())
  with check (is_dueno());

create policy product_images_delete_owner
  on public.product_images
  for delete
  to authenticated
  using (is_dueno());

comment on table public.product_images is
  'Web-Shop-owned product photo gallery, multiple images per product. Never written or read by the POS. Write access split into insert/update/delete policies (not "for all") so dueno sessions never get an implicit unrestricted SELECT — reads stay governed solely by product_images_select_public.';

-- ============================================================================
-- Manual verification
--
-- 1. As a dueno-authenticated session: `select sku, is_active from products
--    where is_active = false` → must now return ZERO rows (previously
--    returned the tombstoned ones). The Web-Shop admin panel's product list
--    must no longer show a deleted/synced-out product as editable.
-- 2. As the same session: updating an existing ACTIVE product's
--    description/is_featured/specs must still succeed (products_update_owner
--    covers this).
-- 3. As the same session: insert/update/delete on product_images for an
--    active product must still succeed (the three new policies cover this).
-- 4. Public/anon reads are unaffected — products_select_public and
--    product_images_select_public (both from 0007/0008) were never touched.
-- ============================================================================
