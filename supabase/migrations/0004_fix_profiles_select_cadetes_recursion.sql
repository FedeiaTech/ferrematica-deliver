-- ============================================================================
-- Migration: 0004_fix_profiles_select_cadetes_recursion.sql
-- Change: navegacion-cadete — fix for RLS recursion found during live verification
--
-- `profiles_select_cadetes` (0003_en_camino_and_cadete_profiles.sql) inlines
-- a `select 1 from public.profiles p where p.id = auth.uid() ...` subquery
-- directly in its `using()` clause. Because that subquery runs under RLS
-- (not SECURITY DEFINER), evaluating it re-triggers every SELECT policy on
-- `profiles` — including `profiles_select_cadetes` itself — causing
-- Postgres error 42P17 "infinite recursion detected in policy for relation
-- profiles" on any `select` against `profiles`.
--
-- `is_owner()` / `is_cadete()` (0001_profiles.sql) already avoid this by
-- being SECURITY DEFINER. This migration adds the same pattern for the
-- "is the caller an active dueño" check and repoints the policy at it.
--
-- HOW TO APPLY:
--   Manually against a project: paste this file into the Supabase
--   Dashboard → SQL Editor and run it, AFTER 0001, 0002, 0003.
-- ============================================================================

create or replace function public.is_active_dueno()
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

comment on function public.is_active_dueno() is
  'SECURITY DEFINER: true iff auth.uid() holds an active dueno profile. Used by profiles_select_cadetes to avoid recursing into profiles RLS.';

drop policy if exists profiles_select_cadetes on public.profiles;

create policy profiles_select_cadetes
  on public.profiles
  for select
  using (
    rol = 'cadete'
    and public.is_active_dueno()
  );

comment on policy profiles_select_cadetes on public.profiles is
  'Lets an active dueño read rol=cadete profile rows, so the order-assignment UI (PR3) can list available cadetes. Additive to profiles_select_own. Uses is_active_dueno() (SECURITY DEFINER) instead of an inline subquery to avoid RLS self-recursion (fixed 2026-08-02, found via live Supabase verification — see 42P17 error).';
