-- ============================================================================
-- Migration: 0008_products_webshop_fields.sql
-- Change: connect-web-catalog-to-shared-products — Web-Shop ownership fields
--
-- Extends `public.products` (created in 0007_products.sql) with the fields
-- Web-Shop needs and the POS never touches: a multi-image gallery, a
-- featured flag, and spec bullets. Also adds a general-purpose `is_dueno()`
-- role check reusable by any admin surface — 0007's `is_pos_sync()` is
-- intentionally POS-service-specific in name/intent, and the Web-Shop admin
-- panel authenticates as a separate Supabase Auth user from the POS sync
-- account, so a differently-named (but functionally identical) predicate
-- keeps each policy's intent clear at the call site.
--
-- Depends on: 0001_profiles.sql (`profiles` table, `rol`/`active` columns),
-- 0007_products.sql (`products` table, `is_pos_sync()` pattern this mirrors).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0007 are already applied.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: is_dueno()
--
-- MUST be SECURITY DEFINER — see is_owner()'s comment in 0001_profiles.sql
-- for the full rationale (queries `profiles`, which has its own RLS).
--
-- Identical predicate to is_pos_sync() (0007): true iff the caller is
-- authenticated as an active 'dueno' profile — regardless of WHICH dueno
-- account (the dedicated POS sync service account and a human business
-- owner logging into the Web-Shop admin panel both satisfy this equally).
-- Kept as a separate function (not a rename of is_pos_sync()) so existing
-- policies that reference is_pos_sync() by name keep reading as
-- POS-sync-specific, while new admin-surface policies read as
-- dueno-in-general.
-- ----------------------------------------------------------------------------
create or replace function public.is_dueno()
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

comment on function public.is_dueno() is
  'SECURITY DEFINER: true iff auth.uid() holds an active dueno profile. General-purpose owner check for admin surfaces (e.g. Web-Shop admin panel), functionally identical to is_pos_sync() but named for its broader intent.';

-- ----------------------------------------------------------------------------
-- products: Web-Shop-owned columns
--
-- is_featured / specs are additive, nullable-with-default, and never written
-- by the POS sync — SupabaseSyncService.java's COLUMNAS_PUSH allow-list does
-- not include them, the same way it already excludes description/image_url.
-- image_url (from 0007) stays as-is (fallback/thumbnail field); the real
-- product gallery lives in product_images below.
-- ----------------------------------------------------------------------------
alter table public.products add column if not exists is_featured boolean not null default false;
alter table public.products add column if not exists specs text[] not null default '{}';

comment on column public.products.is_featured is
  'Web-Shop-owned: shows the product in the home page featured grid. Never written by the POS sync.';
comment on column public.products.specs is
  'Web-Shop-owned: short spec bullets shown on the product detail page. Never written by the POS sync.';

-- ----------------------------------------------------------------------------
-- products: additional write policy for the Web-Shop admin
--
-- RLS policies are permissive (OR'd) — this ADDS to, does not replace,
-- 0007's products_write_pos (still the only path for sku/price/stock/etc.
-- upserts from the POS). This new policy lets any active dueno session
-- (i.e. the Web-Shop admin panel login) update existing product rows too,
-- which is required for it to ever set is_featured/specs/description/
-- image_url on a product the POS already created.
--
-- RLS is row-level, not column-level: nothing in Postgres stops a dueno
-- session from writing sku/price/stock via this policy. The ownership
-- boundary (Web-Shop never sends those fields) is enforced by each app's
-- own code, exactly like the POS's existing discipline of never sending
-- description/image_url — see 0007's products_write_pos comment.
-- ----------------------------------------------------------------------------
create policy products_write_owner
  on public.products
  for all
  to authenticated
  using (is_dueno())
  with check (is_dueno());

-- ----------------------------------------------------------------------------
-- Table: product_images
--
-- Multi-image gallery per product, entirely Web-Shop-owned. References
-- products.id (server-generated uuid, stable regardless of which side —
-- POS or Web-Shop — created the row). The POS never reads or writes this
-- table; SupabaseSyncService.java has no knowledge of it.
-- ----------------------------------------------------------------------------
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  url text not null,
  alt text,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

comment on table public.product_images is
  'Web-Shop-owned product photo gallery, multiple images per product. Never written or read by the POS.';
comment on column public.product_images.product_id is
  'References products.id. ON DELETE CASCADE: if a product row is ever hard-deleted, its images go with it (the POS itself never hard-deletes remotely — see products.is_active tombstone flow in 0007 — but Web-Shop or manual admin action might).';

create index if not exists product_images_product_id_idx on public.product_images (product_id);

alter table public.product_images enable row level security;

-- ----------------------------------------------------------------------------
-- RLS policies: product_images
--
-- product_images_select_public: anon/authenticated may read images only for
-- products that are currently active — mirrors products_select_public
-- (0007) via an EXISTS join, since product_images has no is_active column
-- of its own.
--
-- product_images_write_owner: only an active dueno session may
-- insert/update/delete gallery rows — the Web-Shop admin panel, never anon,
-- never the POS.
-- ----------------------------------------------------------------------------
create policy product_images_select_public
  on public.product_images
  for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.products p
      where p.id = product_images.product_id
        and p.is_active = true
    )
  );

create policy product_images_write_owner
  on public.product_images
  for all
  to authenticated
  using (is_dueno())
  with check (is_dueno());

-- ============================================================================
-- Manual verification (same convention as 0002/0007)
--
-- 1. Anon read/write scoping on product_images:
--    a. As anon, `select * from product_images` → only rows whose
--       product_id points to an is_active=true product.
--    b. As anon, attempt insert/update/delete on product_images → rejected.
--
-- 2. Dueno write access (Web-Shop admin panel login, a DIFFERENT Supabase
--    Auth user than the POS sync account, but also rol='dueno'/active=true
--    in profiles):
--    a. Update an existing product's is_featured/specs → succeeds via the
--       new products_write_owner policy.
--    b. Insert a product_images row for that product → succeeds via
--       product_images_write_owner.
--    c. Attempt the same as a non-dueno authenticated user (e.g. a cadete
--       profile, if one is logged into a Supabase session) → rejected by
--       both policies.
--
-- 3. Confirm the POS sync account (is_pos_sync(), from 0007) can STILL
--    upsert products via its existing allow-list after this migration —
--    products_write_pos is untouched; this migration only ADDS
--    products_write_owner alongside it (RLS policies are permissive/OR'd,
--    not replaced). A POS-account upsert should keep succeeding exactly as
--    before, and should NOT be able to set is_featured/specs from its own
--    payload (the POS's own allow-list simply never sends them — this is
--    an application-discipline check, not something RLS blocks).
-- ============================================================================
