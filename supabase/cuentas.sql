-- =====================================================================
-- Saisei & Co — Base de datos de la app de cuentas (/cuentas)
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Requiere haber ejecutado antes setup.sql (usa la función es_admin()).
-- Sin esto la app funciona igual, pero guarda los datos solo en el
-- dispositivo donde los anotas.
-- =====================================================================

-- Una fila por registro: ventas, gastos, insumos, recetas, carta,
-- proveedores, costos fijos y parámetros. "datos" guarda el registro completo.
create table if not exists public.cuentas (
  coleccion   text not null,
  id          text not null,
  datos       jsonb not null default '{}'::jsonb,
  actualizado timestamptz default now(),
  primary key (coleccion, id)
);

-- El administrador ve y cambia todo. El colaborador lee lo necesario para anotar
-- ventas, gastos e inventario (sin saldos, dinero apartado ni costos fijos);
-- anota y corrige, pero no elimina. El invitado no ve nada.
alter table public.cuentas enable row level security;
drop policy if exists "admin cuentas" on public.cuentas;
drop policy if exists "colaborador lee cuentas" on public.cuentas;
drop policy if exists "colaborador anota cuentas" on public.cuentas;
drop policy if exists "colaborador corrige cuentas" on public.cuentas;
create policy "admin cuentas" on public.cuentas for all to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "colaborador lee cuentas" on public.cuentas for select to authenticated
  using (public.es_equipo() and coleccion in ('ventas', 'gastos', 'insumos', 'recetas', 'carta', 'proveedores', 'config'));
create policy "colaborador anota cuentas" on public.cuentas for insert to authenticated
  with check (public.es_equipo() and coleccion in ('ventas', 'gastos', 'insumos'));
create policy "colaborador corrige cuentas" on public.cuentas for update to authenticated
  using (public.es_equipo() and coleccion in ('ventas', 'gastos', 'insumos'))
  with check (public.es_equipo() and coleccion in ('ventas', 'gastos', 'insumos'));

-- Forma mínima de cada registro, para que uno escrito a mano por la API no rompa
-- las pantallas: un objeto, la fecha como AAAA-MM-DD y la venta con su lista de ítems.
alter table public.cuentas drop constraint if exists cuentas_datos_forma;
alter table public.cuentas add constraint cuentas_datos_forma check (
  jsonb_typeof(datos) = 'object'
  and (not datos ? 'fecha' or (jsonb_typeof(datos->'fecha') = 'string' and datos->>'fecha' ~ '^\d{4}-\d{2}-\d{2}$'))
  and (coleccion <> 'ventas' or (jsonb_typeof(datos->'items') = 'array'
       and not jsonb_path_exists(datos, '$.items[*] ? (@.type() != "object")')))
);
