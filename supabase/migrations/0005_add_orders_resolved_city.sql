-- ============================================================================
-- Migration: 0005_add_orders_resolved_city.sql
-- Change: navegacion-cadete — show the actual delivery city in order detail
--
-- Adds `orders.resolved_city`, populated by reverse-geocoding the order's
-- latitude/longitude once they're resolved (HttpGeocodingClient
-- .reverseGeocodeCity via Nominatim). Distinct from the city hint the
-- dueño picks in the order form to disambiguate the forward geocoding
-- search — that hint is transient form state, never persisted.
--
-- Additive, nullable — no backfill needed for existing rows (they simply
-- show no delivery city until next edited/re-geocoded).
--
-- HOW TO APPLY:
--   Manually against a project: paste this file into the Supabase
--   Dashboard → SQL Editor and run it, AFTER 0001-0004.
-- ============================================================================

alter table public.orders
  add column if not exists resolved_city text;
