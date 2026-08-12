-- ============================================================================
-- Migration: 0011_ventas_mirror.sql
-- Change: ventas-sync-envio — Ventas mirror + venta/pedido link (PR 1)
--
-- Push-only mirror of the POS's local `ventas`/`detalles_venta` tables,
-- following the same pattern as `products` (0007): the desktop POS
-- (SistemaGestionFerreteria) is the sole writer, via an authenticated
-- upsert keyed on a natural composite key, and it never reads these tables
-- back (see design decision D2 — the POS role has no SELECT grant, exactly
-- like 0010 stripped it from `products`).
--
-- Also creates `venta_order_links`, written ONLY by the Flutter app when a
-- dueño confirms a pedido "desde venta" (design decision D4 — the UNIQUE
-- constraint on venta_id IS the anti-double-use mutex), and the
-- `ventas_disponibles()` RPC the app uses to list unlinked, recent,
-- completed ventas (design decision D7 — the anti-join against
-- venta_order_links is not expressible via plain PostgREST embedding).
--
-- Depends on: 0007_products.sql (`is_pos_sync()`), 0008_products_webshop_fields.sql
-- (`is_dueno()`), 0010_fix_pos_policy_scope.sql (the command-scoped RLS
-- pattern this migration follows from the start instead of retrofitting).
--
-- HOW TO APPLY:
--   Local/CI with Supabase CLI:   supabase db push
--   Manually against a project:   paste this file's contents into the
--                                  Supabase Dashboard → SQL Editor and run it,
--                                  AFTER 0001-0010 are already applied.
--
-- No live Supabase project is provisioned for this repo yet (URL/anon key
-- are placeholders in dart_define.example.json). This migration has been
-- reviewed for correctness but NOT executed against a real database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ventas
--
-- One row per POS sale (`Venta` in SistemaGestionFerreteria's local SQLite).
-- `id` is server-generated — the local autoincrement `id` is per-installation
-- and NOT globally unique across two POS installs, so it is never used as
-- the primary key here (design decision D1). Instead, `(install_id,
-- venta_local_id)` is the natural key and the upsert `on_conflict` target,
-- letting the push be idempotent on retry without any change to the local
-- SQLite schema.
--
-- `fecha` is the UTC-normalized timestamptz, converted at push time from the
-- local (zone-less) SQLite value (design decision D3). `fecha_local` keeps
-- the raw local string as an audit escape hatch in case the POS clock/zone
-- is ever misconfigured — it is never parsed back, only inspected manually.
-- ----------------------------------------------------------------------------
create table if not exists public.ventas (
  id uuid primary key default gen_random_uuid(),

  install_id uuid not null,
  venta_local_id integer not null,

  fecha timestamptz not null,
  fecha_local text not null,

  total numeric(12,2) not null default 0,
  estado text not null default 'completada'
    check (estado in ('completada', 'anulada')),
  motivo_anulacion text,

  synced_at timestamptz not null default now(),

  unique (install_id, venta_local_id)
);

comment on table public.ventas is
  'Push-only mirror of the POS local ventas table (SistemaGestionFerreteria). Sole writer is the POS sync service account via is_pos_sync(); no SELECT is granted to that role (write-only, see ventas_insert_pos/ventas_update_pos below) — see sdd/ventas-sync-envio design decision D1/D2.';
comment on column public.ventas.install_id is
  'UUID identifying the POS installation that produced this sale, persisted locally in configuracion.install_id and generated lazily on first sync. Part of the natural key — two installs never collide.';
comment on column public.ventas.venta_local_id is
  'The local autoincrement id from the POS SQLite ventas table. Only unique per install_id, hence the composite unique constraint below instead of using it as a global PK.';
comment on column public.ventas.fecha is
  'UTC timestamptz, converted at push time from the local zone-less SQLite value (design decision D3). The local SQLite value is never rewritten.';
comment on column public.ventas.fecha_local is
  'Raw local datetime string as originally stored in SQLite, pushed verbatim as an audit escape hatch if the POS clock/zone is ever misconfigured. Never parsed back programmatically.';
comment on column public.ventas.estado is
  'Mirrors the local venta lifecycle: completada (default) or anulada. Excluded from ventas_disponibles() once anulada, but an existing venta_order_links row is never broken when a venta is anulada after linking (design decision D8) — the app surfaces a warning instead.';

create index if not exists ventas_install_idx on public.ventas (install_id);
create index if not exists ventas_estado_idx on public.ventas (estado);
create index if not exists ventas_fecha_idx on public.ventas (fecha);

alter table public.ventas enable row level security;

-- ----------------------------------------------------------------------------
-- Table: detalle_ventas
--
-- One row per line item of a venta. References the parent `ventas` row via
-- the SAME composite natural key, NOT the server-generated `ventas.id`
-- returned by an INSERT — the POS sync role has no SELECT grant on `ventas`
-- (design decision D2), so it can never read back the uuid a prior insert
-- generated. The composite FK lets both ventas and detalle_ventas be pushed
-- write-only, in sequence (ventas first, then detalles), with the FK itself
-- enforcing referential integrity server-side.
-- ----------------------------------------------------------------------------
create table if not exists public.detalle_ventas (
  id uuid primary key default gen_random_uuid(),

  install_id uuid not null,
  venta_local_id integer not null,
  detalle_local_id integer not null,

  producto_codigo text,
  combo_id integer,
  descripcion text not null,
  cantidad numeric(12,3) not null default 0,
  precio_unitario numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0,

  synced_at timestamptz not null default now(),

  unique (install_id, venta_local_id, detalle_local_id),
  foreign key (install_id, venta_local_id)
    references public.ventas (install_id, venta_local_id)
    on delete cascade
);

comment on table public.detalle_ventas is
  'Push-only mirror of the POS local detalles_venta table. Composite FK to ventas(install_id, venta_local_id) rather than a server-generated ventas.id — the POS sync role never has SELECT on ventas to read that id back (design decision D2). Same write-only access pattern as ventas.';
comment on column public.detalle_ventas.detalle_local_id is
  'The local autoincrement id of the detail row, unique only within (install_id, venta_local_id). Combined with the parent key, forms the upsert conflict target.';
comment on column public.detalle_ventas.producto_codigo is
  'The POS-local sku/codigo of the sold product, when the line item is a product (not a combo). Nullable — no FK to products.sku, this mirror is an audit trail, not a live-referencing table.';
comment on column public.detalle_ventas.combo_id is
  'The POS-local combo id, when the line item is a combo rather than a single product. Nullable, mutually exclusive with producto_codigo in practice (not enforced by a check — mirrors the source data as-is).';
comment on column public.detalle_ventas.cantidad is
  'numeric(12,3), not integer: fractional kg/lt sales are valid, same rationale as products.stock (0007). App-side mapping to OrderItem.quantity (an int) rounds and appends the exact figure to the product name when fractional (design decision D6).';

create index if not exists detalle_ventas_parent_idx on public.detalle_ventas (install_id, venta_local_id);

alter table public.detalle_ventas enable row level security;

-- ----------------------------------------------------------------------------
-- Table: venta_order_links
--
-- Written ONLY by the Flutter app, and ONLY when a dueño confirms a pedido
-- created "desde venta" (never at mere selection time — see spec scenario
-- "Cancelar antes de confirmar no crea link"). The UNIQUE constraint on
-- venta_id is the actual concurrency control (design decision D4): two
-- devices racing to claim the same venta will have one INSERT succeed and
-- the other fail with a 23505 unique violation, which the app surfaces as
-- "Esa venta ya fue usada en otro pedido" without creating a duplicate
-- order. There is intentionally no FK to orders(id) — the order row may not
-- exist in Supabase yet at claim time, since OrderSyncService pushes it
-- later in the existing offline-first flow (design decision D4).
-- ----------------------------------------------------------------------------
create table if not exists public.venta_order_links (
  id uuid primary key default gen_random_uuid(),

  venta_id uuid not null references public.ventas (id) on delete cascade,
  order_id uuid not null,

  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),

  unique (venta_id)
);

comment on table public.venta_order_links is
  'Records which venta a pedido was created from. The UNIQUE(venta_id) constraint is the anti-double-use mutex (design decision D4): claim-before-create, so a losing race gets a 23505 and no duplicate delivery is ever built from the same sale. No UPDATE/DELETE policy below — a claim is final by design.';
comment on column public.venta_order_links.order_id is
  'The client-generated order UUID (Isar Order.id). Intentionally NOT a foreign key to orders(id): the order is claimed before it syncs to Supabase, so the referenced row may not exist yet at insert time.';
comment on column public.venta_order_links.created_by is
  'The dueño profile that performed the claim, for audit purposes only — not used by any RLS predicate here (ownership of the underlying order is governed by orders.created_by, unrelated to this table).';

create index if not exists venta_order_links_order_idx on public.venta_order_links (order_id);

alter table public.venta_order_links enable row level security;

-- ----------------------------------------------------------------------------
-- RLS policies
--
-- Command-scoped from the start, following the lesson documented in 0010:
-- a "for all" policy implicitly grants SELECT too, which the POS sync role
-- must never have on ventas/detalle_ventas (design decision D2 — write-only
-- writer). ventas/detalle_ventas therefore get an insert + an update policy
-- for is_pos_sync(), and a select policy for is_dueno() (the app's read
-- path — although in practice the app reads via ventas_disponibles() below,
-- not a direct select, this keeps ad-hoc dueño reads from the SQL Editor /
-- future features consistent with products' pattern). No delete policy on
-- either table — the POS never deletes a pushed venta, and the app never
-- deletes at all.
--
-- venta_order_links gets select + insert for is_dueno() only — no update,
-- no delete: a claim is final (see table comment above). No POS access at
-- all — the POS role never touches this table.
-- ----------------------------------------------------------------------------
create policy ventas_insert_pos
  on public.ventas
  for insert
  to authenticated
  with check (is_pos_sync());

create policy ventas_update_pos
  on public.ventas
  for update
  to authenticated
  using (is_pos_sync())
  with check (is_pos_sync());

create policy ventas_select_owner
  on public.ventas
  for select
  to authenticated
  using (is_dueno());

comment on policy ventas_insert_pos on public.ventas is
  'Scoped to INSERT only (command-scoped from the start, not a "for all" — see 0010''s regression for why). Covers the new-venta half of the POS''s on_conflict upsert.';
comment on policy ventas_update_pos on public.ventas is
  'Scoped to UPDATE only, paired with ventas_insert_pos to cover the POS''s on_conflict upsert. Never SELECT or DELETE — the POS sync role is write-only on this table (design decision D2).';
comment on policy ventas_select_owner on public.ventas is
  'Dueño-only read access. The app''s actual read path is the ventas_disponibles() RPC below (security invoker, so this policy still applies), not a direct select — this policy exists for parity with products and any future ad-hoc read need.';

create policy detalle_ventas_insert_pos
  on public.detalle_ventas
  for insert
  to authenticated
  with check (is_pos_sync());

create policy detalle_ventas_update_pos
  on public.detalle_ventas
  for update
  to authenticated
  using (is_pos_sync())
  with check (is_pos_sync());

create policy detalle_ventas_select_owner
  on public.detalle_ventas
  for select
  to authenticated
  using (is_dueno());

comment on policy detalle_ventas_insert_pos on public.detalle_ventas is
  'Scoped to INSERT only, same rationale as ventas_insert_pos. Pushed after the parent ventas row in the same sync cycle (composite FK requires the parent to exist first).';
comment on policy detalle_ventas_update_pos on public.detalle_ventas is
  'Scoped to UPDATE only, paired with detalle_ventas_insert_pos for the on_conflict upsert. Never SELECT or DELETE.';
comment on policy detalle_ventas_select_owner on public.detalle_ventas is
  'Dueño-only read access, consumed via ventas_disponibles() in practice. Parity with ventas_select_owner.';

create policy venta_order_links_select_owner
  on public.venta_order_links
  for select
  to authenticated
  using (is_dueno());

create policy venta_order_links_insert_owner
  on public.venta_order_links
  for insert
  to authenticated
  with check (is_dueno() and created_by = auth.uid());

comment on policy venta_order_links_select_owner on public.venta_order_links is
  'Dueño-only read access — the app needs to know which ventas are already linked (also covered by ventas_disponibles()''s anti-join, but kept for direct reads/debugging).';
comment on policy venta_order_links_insert_owner on public.venta_order_links is
  'Dueño-only claim, and only as themselves (created_by must equal auth.uid()). No UPDATE/DELETE policy exists on this table at all — a claim is final by design (design decision D4).';

-- ----------------------------------------------------------------------------
-- Function: ventas_disponibles(p_dias)
--
-- Single RPC call returning ventas eligible for the "desde venta" pedido
-- picker: estado = 'completada', within the last p_dias days, and with NO
-- row in venta_order_links (anti-join). This anti-join is not expressible
-- through plain PostgREST resource embedding, hence the function (design
-- decision D7). SECURITY INVOKER (not DEFINER, unlike is_pos_sync()/
-- is_dueno()) — RLS is still evaluated as the calling dueño, so this
-- function grants no more access than the caller's own policies already
-- allow; it only expresses a query shape PostgREST cannot.
--
-- Each row embeds its detalle_ventas as jsonb so the app gets venta + line
-- items in one round trip.
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
    )
  order by v.fecha desc;
$$;

comment on function public.ventas_disponibles(integer) is
  'SECURITY INVOKER: lists ventas completada, within the last p_dias days, not yet linked in venta_order_links, each with its detalle_ventas embedded as jsonb. RLS still applies as the caller (ventas_select_owner/detalle_ventas_select_owner) — this function only expresses the anti-join PostgREST cannot, it grants no extra access. Consumed by the app''s "Usar venta del POS" picker (design decision D7).';

-- ============================================================================
-- Manual RLS verification (task 1.6)
--
-- No automated integration test can exercise Postgres RLS from this repo
-- without a live Supabase project + authenticated sessions for both the POS
-- sync account and a dueño account (same limitation documented in 0002/0007).
-- Once a project is provisioned and this migration applied, verify manually
-- via the Supabase SQL Editor (or two authenticated HTTP sessions):
--
-- 1. POS sync write, write-only (dueno-role JWT for the POS sync account):
--    a. Insert a venta: `insert into ventas (install_id, venta_local_id,
--       fecha, fecha_local, total) values ('<uuid>', 1, now(), '2026-08-08 10:00',
--       1000)`. Expect success.
--    b. Re-run the same insert as an upsert via PostgREST
--       (`on_conflict=install_id,venta_local_id`, or `insert ... on conflict
--       (install_id, venta_local_id) do update set ...` in SQL). Expect the
--       existing row to update, not a duplicate.
--    c. Insert a matching detalle_ventas row referencing the same
--       (install_id, venta_local_id). Expect success (FK satisfied).
--    d. Attempt `select * from ventas` as the SAME POS sync session. Expect
--       ZERO rows / policy denial — the POS role has no select policy.
--
-- 2. App (dueño) read/write scoping:
--    a. As a dueño-authenticated session, `select * from ventas_disponibles(7)`.
--       Expect the venta inserted in step 1 to appear with its detalle
--       embedded in `detalles`.
--    b. As the same session, attempt `insert into ventas (...) values (...)`.
--       Expect a policy violation — the app has no write access to ventas.
--    c. As the same session, `insert into venta_order_links (venta_id,
--       order_id, created_by) values ('<venta id from 1a>', gen_random_uuid(),
--       auth.uid())`. Expect success.
--    d. Re-run `select * from ventas_disponibles(7)`. Expect the same venta
--       to be ABSENT now (anti-join excludes it once linked).
--
-- 3. Double-claim rejection:
--    a. As the SAME or a different dueño session, attempt a second
--       `insert into venta_order_links (venta_id, order_id, created_by)
--       values ('<same venta id as 2c>', gen_random_uuid(), auth.uid())`.
--       Expect a 23505 unique violation on venta_id — no second link is
--       created, matching design decision D4.
--
-- Document actual results (pass/fail + Supabase project ref) in the PR
-- description once a real project is provisioned and this migration has
-- been applied via `supabase db push`.
-- ============================================================================
