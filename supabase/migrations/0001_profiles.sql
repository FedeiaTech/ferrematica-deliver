-- ============================================================================
-- Migration: 0001_profiles.sql
-- Change: pedidos — Order Management (dueño slice) — PR2 (Supabase migrations)
--
-- Creates the minimal `profiles` table used to source RLS role checks for
-- the `orders` table (see 0002_orders.sql), plus the `is_owner()` helper.
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  in order, before 0002_orders.sql.
--
-- No live Supabase project is provisioned for this repo yet (URL/anon key
-- are placeholders in dart_define.example.json). This migration has been
-- reviewed for correctness but NOT executed against a real database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: profiles
-- One row per auth.users row. `rol` drives RLS decisions for `orders`.
-- Spanish role values ('dueno' | 'cadete') match the rest of the domain's
-- Spanish-language enums (status, payment_method, payment_status).
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  rol text not null check (rol in ('dueno', 'cadete')),
  full_name text,
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Minimal user profile carrying the rol used by orders RLS policies. Not a full auth/user-management surface — out of scope for the pedidos slice.';
comment on column public.profiles.rol is
  'Domain role: dueno (owner, full order CRUD) | cadete (delivery courier, scoped read/update in a future slice).';

create index if not exists profiles_rol_idx on public.profiles (rol);

alter table public.profiles enable row level security;

-- A user may always read/update their own profile row. No cross-user access;
-- profile management UI is out of scope for this slice.
create policy profiles_select_own
  on public.profiles
  for select
  using (id = auth.uid());

create policy profiles_update_own
  on public.profiles
  for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- ----------------------------------------------------------------------------
-- Function: is_owner(row_created_by uuid)
--
-- MUST be SECURITY DEFINER: it queries `profiles`, which has RLS enabled.
-- Without SECURITY DEFINER, calling this function from an `orders` RLS
-- policy would recurse into `profiles`' own RLS as the querying user,
-- which is at best redundant and at worst breaks under certain policy
-- shapes. SECURITY DEFINER lets the function read `profiles` as its
-- owner (bypassing profiles' RLS) to make a single boolean decision,
-- while still root-checking against auth.uid() — this is the standard
-- Supabase pattern for role lookups used inside RLS predicates.
--
-- Returns true only when BOTH:
--   (a) the caller is authenticated as the given row's creator
--       (row_created_by = auth.uid()), AND
--   (b) the caller's profile has rol = 'dueno' and is active.
--
-- This single parameterized predicate implements the spec requirement
-- "an owner can read/write only orders they own (created_by = auth.uid())"
-- in one call, so `orders` RLS policies stay a simple
-- `using (is_owner(created_by))`.
-- ----------------------------------------------------------------------------
create or replace function public.is_owner(row_created_by uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    row_created_by is not null
    and row_created_by = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.rol = 'dueno'
        and p.active = true
    );
$$;

comment on function public.is_owner(uuid) is
  'SECURITY DEFINER: true iff auth.uid() both created the given row and holds an active dueno profile. Used by orders RLS to scope owner access to their own rows without recursing into profiles RLS.';

-- ----------------------------------------------------------------------------
-- Function: is_cadete()
-- Companion role check for the cadete-scoped policies added in
-- 0002_orders.sql (cadete_select / cadete_update). Cadete write access is
-- out of scope for this slice beyond these placeholder policies (see spec
-- domain order-security: "Cadete access to orders is out of scope for this
-- slice"), but the policies are scaffolded now since assigned_cadete_id
-- already exists on `orders` and column-level restriction is future work.
-- ----------------------------------------------------------------------------
create or replace function public.is_cadete()
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
      and p.rol = 'cadete'
      and p.active = true
  );
$$;

comment on function public.is_cadete() is
  'SECURITY DEFINER: true iff auth.uid() holds an active cadete profile.';
