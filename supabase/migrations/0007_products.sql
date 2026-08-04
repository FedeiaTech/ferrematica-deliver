-- ============================================================================
-- Migration: 0007_products.sql
-- Change: ferrematica-single-tenant-supabase-sync — Products Catalog (PR B)
--
-- Creates the `public.products` table that the desktop POS
-- (`SistemaGestionFerreteria`) pushes stock/price snapshots into via
-- PostgREST, and that the Flutter app / Web-Shop read as the storefront
-- catalog. Also creates the `is_pos_sync()` SECURITY DEFINER helper used
-- by the write policy below.
--
-- Depends on: 0001_profiles.sql (`profiles` table, `is_owner()`/`is_cadete()`
-- pattern that `is_pos_sync()` mirrors).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001_profiles.sql (and after any
--                                  migration up to 0006 already applied).
--
-- No live Supabase project is provisioned for this repo yet (URL/anon key
-- are placeholders in dart_define.example.json). This migration has been
-- reviewed for correctness but NOT executed against a real database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: products
--
-- POS (SistemaGestionFerreteria) is the sole writer of stock/price/name/sku
-- fields via an authenticated upsert keyed on `sku` (see
-- sdd/ferrematica-single-tenant-supabase-sync design — allow-list
-- COLUMNAS_PUSH). Web-Shop admin owns `description` and `image_url`
-- (marketing copy / photography) — those columns are NEVER written by the
-- POS sync and are therefore untouched across upserts matched on `sku`.
--
-- `stock` is numeric(12,3), NOT integer: the SQLite source column is REAL
-- and `ItemVenta.stock` is a Java double (kg/lt sales are fractional).
--
-- `id` is server-generated (`gen_random_uuid()`) — the SQLite autoincrement
-- `id` from the POS is never sent; `sku` is the natural key and the upsert
-- conflict target (`on_conflict=sku`).
-- ----------------------------------------------------------------------------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique check (length(trim(sku)) > 0),
  name text not null,
  description text,
  price numeric(12,2) not null default 0,
  stock numeric(12,3) not null default 0,
  unit text not null default 'u',
  category text not null default 'General',
  is_service boolean not null default false,
  image_url text,
  is_active boolean not null default true,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table public.products is
  'Product catalog synced from the desktop POS (upsert on sku, allow-listed columns only) and read by the storefront (Flutter app + Web-Shop). description/image_url are Web-Shop-owned and never written by the POS sync.';
comment on column public.products.sku is
  'Natural key, mirrors the POS-local items.codigo. Upsert conflict target for POS sync (on_conflict=sku). Never blank — enforced by the check constraint.';
comment on column public.products.stock is
  'numeric(12,3), not integer: SQLite source column is REAL, ItemVenta.stock is a Java double (fractional kg/lt sales are valid).';
comment on column public.products.is_active is
  'Pushed by the POS sync as part of the deletion-tombstone flow (items_eliminados) — set false when a product is deleted locally. Never set true again by the sync; a re-created SKU simply upserts a fresh active row.';
comment on column public.products.description is
  'Web-Shop-owned marketing copy. Not part of the POS sync allow-list — never overwritten by a POS upsert.';
comment on column public.products.image_url is
  'Web-Shop-owned product photography. Not part of the POS sync allow-list — never overwritten by a POS upsert.';

create index if not exists products_category_idx on public.products (category);
create index if not exists products_is_active_idx on public.products (is_active);

alter table public.products enable row level security;

-- ----------------------------------------------------------------------------
-- Function: is_pos_sync()
--
-- MUST be SECURITY DEFINER: it queries `profiles`, which has RLS enabled.
-- Without SECURITY DEFINER, calling this function from a `products` RLS
-- policy would recurse into `profiles`' own RLS as the querying user —
-- see is_owner()'s comment in 0001_profiles.sql for the full rationale;
-- this function mirrors that exact pattern.
--
-- Returns true only when the caller is authenticated as an active 'dueno'
-- profile. The POS never uses the bare anon key to write — it authenticates
-- via GoTrue as a dedicated sync service account whose profile has
-- rol = 'dueno', sending that JWT as Authorization: Bearer. The anon key
-- remains only the apikey header, never the authorization — see design
-- decision "RLS write identity — NOT the bare anon key".
-- ----------------------------------------------------------------------------
create or replace function public.is_pos_sync()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.rol = 'dueno'
      and p.active = true
  );
$$;

comment on function public.is_pos_sync() is
  'SECURITY DEFINER: true iff auth.uid() holds an active dueno profile. Used by products_write_pos to scope catalog writes to the authenticated POS sync service account, never the bare anon key.';

-- ----------------------------------------------------------------------------
-- RLS policies
--
-- products_select_public: anon and authenticated may read only active
-- products — this is the storefront-facing read (Flutter app, Web-Shop).
-- Inactive (soft-deleted) products are invisible to the storefront but
-- remain in the table for audit/history.
--
-- products_write_pos: only an authenticated session that passes
-- is_pos_sync() may insert/update/delete. There is no anon write policy —
-- the anon key alone (without a dueno-role JWT) can never mutate this
-- table, closing the catalog-vandalism risk of publishing anon in the
-- app/Web-Shop bundles.
-- ----------------------------------------------------------------------------
create policy products_select_public
  on public.products
  for select
  to anon, authenticated
  using (is_active = true);

create policy products_write_pos
  on public.products
  for all
  to authenticated
  using (is_pos_sync())
  with check (is_pos_sync());

-- ============================================================================
-- Manual RLS verification (task B3)
--
-- No automated integration test can exercise Postgres RLS from this repo
-- without a live Supabase project + an authenticated dueno session (see
-- design "Open Questions" — requires a real project + a dedicated
-- rol='dueno' sync account, see B4 provisioning steps below). Once a
-- project is provisioned and this migration applied, verify manually via
-- the Supabase SQL Editor (or two `psql`/HTTP sessions):
--
-- 1. Anon read/write scoping:
--    a. As anon (using only the anon key, no Authorization header),
--       `select * from products`. Expect only rows where is_active = true.
--    b. As anon, attempt `insert into products (sku, name) values ('x', 'x')`.
--       Expect a policy violation / 0 rows affected.
--    c. As anon, attempt `update products set price = 0 where sku = '<any sku>'`.
--       Expect 0 rows affected.
--    d. As anon, attempt `delete from products where sku = '<any sku>'`.
--       Expect 0 rows affected.
--
-- 2. POS sync write (dueno JWT):
--    a. Authenticate via GoTrue as the dedicated sync account (see B4)
--       to obtain a JWT for a profile with rol='dueno' and active=true.
--    b. As that session, `insert into products (sku, name, price, stock)
--       values ('TEST-001', 'Test product', 10.50, 3.000)`. Expect success.
--    c. Re-run the same insert with a different price/stock as an upsert
--       (`on_conflict=sku, resolution=merge-duplicates` via PostgREST, or
--       `insert ... on conflict (sku) do update set ...` in SQL). Expect
--       the existing row to update, not a duplicate row.
--
-- 3. image_url survives a POS upsert:
--    a. As a Web-Shop admin session (or directly via SQL Editor), set
--       `image_url` on an existing product: `update products set
--       image_url = 'https://example.com/test.jpg' where sku = 'TEST-001'`.
--    b. As the dueno sync session, upsert the SAME sku with only the
--       POS allow-listed columns (sku, name, price, stock, unit, category,
--       is_service, is_active, synced_at — never image_url or description).
--    c. `select image_url from products where sku = 'TEST-001'`. Expect
--       the value set in step (a) to be UNCHANGED — the POS upsert must
--       never null out or overwrite image_url/description.
--
-- Document actual results (pass/fail + Supabase project ref) in the PR
-- description once a real project is provisioned and this migration has
-- been applied via `supabase db push`.
-- ============================================================================

-- ============================================================================
-- Manual provisioning: dedicated sync service account (task B4)
--
-- The POS never authenticates as anon for writes (see is_pos_sync() comment
-- above). Before PR C's SupabaseSyncService can run against a real project,
-- provision a dedicated Supabase auth user for it:
--
-- 1. In the Supabase Dashboard → Authentication → Users, create a new user
--    (email + password) reserved exclusively for the POS sync service —
--    do NOT reuse a human dueño's personal login.
-- 2. Insert (or update) the corresponding `profiles` row for that user's
--    auth.uid():
--      insert into public.profiles (id, rol, full_name, active)
--      values ('<the new user''s auth.uid()>', 'dueno', 'POS Sync Service', true)
--      on conflict (id) do update set rol = 'dueno', active = true;
-- 3. Store that email + password in the POS's local `configuracion` table
--    (`supabase_sync_email` / `supabase_sync_password`, see PR C) — plaintext
--    is accepted at the same trust level as the rest of the gitignored
--    local SQLite file (see design "Open Questions").
-- 4. Confirm the account authenticates via GoTrue
--    (`POST /auth/v1/token?grant_type=password`) and that the resulting
--    JWT passes `is_pos_sync()` before wiring it into PR C's config screen.
--
-- This is a manual, one-time step per Supabase project (dev/staging/prod)
-- and cannot be scripted from this repo without live project credentials.
-- ============================================================================
