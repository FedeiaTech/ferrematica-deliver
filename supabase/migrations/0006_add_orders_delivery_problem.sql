-- ============================================================================
-- Migration: 0006_add_orders_delivery_problem.sql
-- Change: navegacion-cadete — "Indicar problema" delivery-failure reporting
--
-- Adds `orders.delivery_problem`, populated by
-- OrdersController.reportDeliveryProblem when a cadete (or a self-delivery
-- dueño) can't complete a delivery — the order's status moves to
-- `cancelado` at the same time, same column already accepts NULL for
-- every order that never had a problem reported.
--
-- HOW TO APPLY:
--   Manually against a project: paste this file into the Supabase
--   Dashboard → SQL Editor and run it, AFTER 0001-0005.
-- ============================================================================

alter table public.orders
  add column if not exists delivery_problem text;
