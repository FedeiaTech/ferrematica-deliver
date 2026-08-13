-- ============================================================================
-- Migration: 0016_venta_release_on_cancel.sql
-- Change: retry-cancelled-order-venta-release
--
-- Soft-releases a venta_order_links claim when its order is cancelled, so
-- the same POS sale can be reclaimed by a "Reintentar entrega" retry — or a
-- retry of that retry, and so on — instead of being permanently excluded
-- from ventas_disponibles() the moment its first order fails. Before this,
-- 0011_ventas_mirror.sql's design decision D4 ("a claim is final") meant a
-- cancelled order's linked venta could never be picked again by anyone.
--
-- Depends on: 0011_ventas_mirror.sql (venta_order_links, ventas_disponibles()),
-- 0002_orders.sql (orders.status).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0015 are already applied.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Column: venta_order_links.released_at
--
-- Null while the claim is active. Set (never cleared once set) when the
-- linked order transitions to `cancelado` (see the trigger below) — a soft
-- release, not a delete, so the audit trail from D4/D8 in
-- 0011_ventas_mirror.sql still holds: every claim a venta ever had stays
-- queryable, we just stop treating a released one as exclusive.
-- ----------------------------------------------------------------------------
alter table public.venta_order_links
  add column if not exists released_at timestamptz;

comment on column public.venta_order_links.released_at is
  'Set when the linked order is cancelled (venta_order_links_release_on_cancel trigger) — the venta becomes reclaimable again (see venta_order_links_venta_id_active_idx and ventas_disponibles()''s anti-join) without deleting the historical link row.';

-- The original `unique (venta_id)` constraint (0011) forbade ANY second
-- claim, active or not. Replaced by a partial unique index scoped to active
-- (released_at is null) claims, so a released venta can be claimed again
-- while at most one ACTIVE claim per venta still exists at any time.
alter table public.venta_order_links
  drop constraint if exists venta_order_links_venta_id_key;

create unique index if not exists venta_order_links_venta_id_active_idx
  on public.venta_order_links (venta_id)
  where released_at is null;

comment on index public.venta_order_links_venta_id_active_idx is
  'Replaces the old unconditional unique(venta_id): only one ACTIVE (released_at is null) claim per venta at a time — the actual anti-double-use mutex now that released claims can coexist with a fresh one (design decision D4, relaxed).';

-- ----------------------------------------------------------------------------
-- Trigger: venta_order_links_release_on_cancel
--
-- SECURITY DEFINER because the acting dueño session has no UPDATE policy on
-- venta_order_links (a claim was designed to be immutable from the app's
-- own privilege level — see 0011's comment on venta_order_links_insert_owner);
-- the release itself is a system-level side effect of cancelling an order,
-- not a claim the dueño is directly making. Fires whenever `status` becomes
-- `cancelado` regardless of which device performed/synced the cancellation,
-- so an offline cancel still releases its venta(s) the moment it syncs.
-- ----------------------------------------------------------------------------
create or replace function public.venta_order_links_release_on_cancel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'cancelado' and old.status is distinct from 'cancelado' then
    update public.venta_order_links
      set released_at = now()
      where order_id = new.id
        and released_at is null;
  end if;
  return new;
end;
$$;

comment on function public.venta_order_links_release_on_cancel() is
  'AFTER UPDATE ON orders: when status transitions into cancelado, soft-releases every still-active venta_order_links row for that order (released_at = now()) so its venta(s) become reclaimable via ventas_disponibles() again. SECURITY DEFINER — the dueño session itself has no UPDATE grant on venta_order_links.';

drop trigger if exists venta_order_links_release_on_cancel on public.orders;
create trigger venta_order_links_release_on_cancel
  after update on public.orders
  for each row
  execute function public.venta_order_links_release_on_cancel();

-- ----------------------------------------------------------------------------
-- ventas_disponibles(): the anti-join must now only exclude ACTIVE claims —
-- a released one (released_at is not null) no longer hides the venta.
-- Reshaped in place (design decision D7 unchanged, only the anti-join
-- predicate gains `and l.released_at is null`).
-- ----------------------------------------------------------------------------
create or replace function public.ventas_disponibles(p_dias integer default 7)
returns table (
  id uuid,
  install_id uuid,
  venta_local_id integer,
  fecha timestamptz,
  total numeric,
  estado text,
  detalles jsonb
)
language sql
security invoker
stable
set search_path = public
as $$
  select
    v.id,
    v.install_id,
    v.venta_local_id,
    v.fecha,
    v.total,
    v.estado,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'producto_codigo', d.producto_codigo,
            'combo_id', d.combo_id,
            'descripcion', d.descripcion,
            'cantidad', d.cantidad,
            'precio_unitario', d.precio_unitario,
            'subtotal', d.subtotal
          )
          order by d.detalle_local_id
        )
        from public.detalle_ventas d
        where d.install_id = v.install_id
          and d.venta_local_id = v.venta_local_id
      ),
      '[]'::jsonb
    ) as detalles
  from public.ventas v
  where v.estado = 'completada'
    and v.fecha >= now() - make_interval(days => p_dias)
    and not exists (
      select 1
      from public.venta_order_links l
      where l.venta_id = v.id
        and l.released_at is null
    )
  order by v.fecha desc;
$$;

comment on function public.ventas_disponibles(integer) is
  'SECURITY INVOKER: lists ventas completada, within the last p_dias days, with no ACTIVE (released_at is null) row in venta_order_links, each with its detalle_ventas embedded as jsonb. A venta released by venta_order_links_release_on_cancel reappears here even though its historical link row still exists. Consumed by the app''s "Usar venta del POS" picker (design decision D7).';

-- ============================================================================
-- Manual verification (once applied to the live project)
--
-- 1. Claim a venta for order A (`insert into venta_order_links (venta_id,
--    order_id, created_by) values (...)`), confirm it's absent from
--    `select * from ventas_disponibles(7)`.
-- 2. Cancel order A (`update orders set status = 'cancelado', updated_at =
--    now() where id = '<A>'`). Confirm the trigger fired:
--    `select released_at from venta_order_links where order_id = '<A>'`
--    should now be non-null.
-- 3. Re-run `select * from ventas_disponibles(7)` — the venta should be
--    visible again.
-- 4. Claim the SAME venta for a new order B. Expect success (no 23505 —
--    the old row is released, so the partial unique index doesn't collide).
-- 5. Cancel order B too, and repeat step 4 for an order C — confirms the
--    retry-of-a-retry chain keeps working, not just a single retry.
-- ============================================================================
