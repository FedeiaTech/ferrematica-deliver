-- ============================================================================
-- Migration: 0010_fix_pos_policy_scope.sql
-- Change: connect-web-catalog-to-shared-products — fix the ORIGINAL RLS
-- over-permission, inherited from 0007
--
-- 0009 fixed the newer `products_write_owner`/`product_images_write_owner`
-- policies (both `for all`, both accidentally granting unrestricted SELECT),
-- but missed that `products_write_pos` (0007) has the EXACT SAME bug and
-- was there first: it's `for all to authenticated using (is_pos_sync())`.
--
-- Confirmed via `select policyname, cmd from pg_policies where tablename =
-- 'products'` after 0009 was applied: `products_write_pos` still shows
-- `cmd = ALL`, and a dueno-authenticated session still saw a tombstoned
-- (is_active=false) product. Root cause: `is_pos_sync()` and `is_dueno()`
-- check the exact same predicate (`rol = 'dueno' and active = true`) by
-- design (0008's comment says so explicitly) — so ANY dueno session,
-- including the Web-Shop admin login, trivially satisfies `is_pos_sync()`
-- too, and inherits products_write_pos's unrestricted SELECT. This bug
-- existed since 0007 but was never observed because the POS's own Java
-- code (SupabaseSyncService) never issues a SELECT against products, only
-- POST upserts — it never exercised the over-broad read path. Testing
-- through Web-Shop (which does read) surfaced it.
--
-- Fix: same pattern as 0009 — split into command-scoped policies. The POS
-- only ever needs INSERT (a genuinely new sku) and UPDATE (an existing sku,
-- via on_conflict) in a single upsert statement; never SELECT, never DELETE.
--
-- Depends on: 0007_products.sql (is_pos_sync(), the policy being replaced).
--
-- HOW TO APPLY: same as prior migrations — supabase db push, or paste into
-- SQL Editor, AFTER 0001-0009.
-- ============================================================================

drop policy if exists products_write_pos on public.products;

create policy products_insert_pos
  on public.products
  for insert
  to authenticated
  with check (is_pos_sync());

create policy products_update_pos
  on public.products
  for update
  to authenticated
  using (is_pos_sync())
  with check (is_pos_sync());

comment on policy products_insert_pos on public.products is
  'Scoped to INSERT only. Replaces the original products_write_pos ("for all", 0007), which accidentally granted the POS sync session unrestricted SELECT on top of write access — see 0010''s migration header for how this surfaced.';
comment on policy products_update_pos on public.products is
  'Scoped to UPDATE only, paired with products_insert_pos to cover the POS''s on_conflict upsert (which needs both INSERT and UPDATE grants in a single statement, but never SELECT or DELETE).';

-- ============================================================================
-- Manual verification
--
-- 1. As a dueno-authenticated session (POS sync account OR Web-Shop admin —
--    both satisfy is_pos_sync()/is_dueno() identically): `select sku,
--    is_active from products where is_active = false` → must now return
--    ZERO rows. This is the actual regression check for this migration.
-- 2. As the same session: a POS-style upsert to /rest/v1/products?
--    on_conflict=sku (insert-or-update in one call) must still succeed —
--    products_insert_pos + products_update_pos together cover it exactly
--    like the single products_write_pos did before.
-- 3. Re-run the SupabaseSyncService end-to-end flow from the POS (or a
--    manual "Sincronizar ahora") once this is applied — a real sync should
--    behave identically to before, since it never relied on SELECT access.
-- ============================================================================
