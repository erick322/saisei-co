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
-- anota y corrige, pero no elimina. De ventas y gastos solo ve, anota y corrige
-- los de hoy y ayer (en hora de Chile): el historial de dinero no baja a su teléfono.
-- El invitado no ve nada.
alter table public.cuentas enable row level security;
create or replace function public.reciente(d jsonb) returns boolean
language sql stable set search_path = public as $$
  select coalesce(d->>'fecha' >= ((now() at time zone 'America/Santiago')::date - 1)::text, false);
$$;
revoke execute on function public.reciente(jsonb) from public, anon;
grant execute on function public.reciente(jsonb) to authenticated;
drop policy if exists "admin cuentas" on public.cuentas;
drop policy if exists "colaborador lee cuentas" on public.cuentas;
drop policy if exists "colaborador anota cuentas" on public.cuentas;
drop policy if exists "colaborador corrige cuentas" on public.cuentas;
create policy "admin cuentas" on public.cuentas for all to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "colaborador lee cuentas" on public.cuentas for select to authenticated
  using (public.es_equipo() and (coleccion in ('insumos', 'recetas', 'carta', 'proveedores', 'config')
    or (coleccion in ('ventas', 'gastos') and public.reciente(datos))));
create policy "colaborador anota cuentas" on public.cuentas for insert to authenticated
  with check (public.es_equipo() and (coleccion = 'insumos' or (coleccion in ('ventas', 'gastos') and public.reciente(datos))));
create policy "colaborador corrige cuentas" on public.cuentas for update to authenticated
  using (public.es_equipo() and (coleccion = 'insumos' or (coleccion in ('ventas', 'gastos') and public.reciente(datos))))
  with check (public.es_equipo() and (coleccion = 'insumos' or (coleccion in ('ventas', 'gastos') and public.reciente(datos))));

-- Número de la última venta, para que el colaborador (que no ve el historial) no repita números
create or replace function public.ultimo_num_venta() returns bigint
language sql stable security definer set search_path = public as $$
  select case when public.es_equipo() then coalesce(max((datos->>'num')::bigint), 0) end
  from public.cuentas where coleccion = 'ventas' and datos->>'num' ~ '^\d{1,15}$';
$$;
revoke execute on function public.ultimo_num_venta() from public, anon;
grant execute on function public.ultimo_num_venta() to authenticated;

-- El colaborador que es trabajador (su correo anotado en su ficha por el administrador)
-- ve solo su ficha, sus días trabajados y sus pagos. Cuenta solo un correo confirmado, como en mi_rol().
create or replace function public.mis_trabajadores() returns setof text
language sql stable security definer set search_path = public as $$
  select c.id from public.cuentas c join auth.users u on lower(u.email) = lower(c.datos->>'email')
  where c.coleccion = 'trabajadores' and u.id = auth.uid() and u.email_confirmed_at is not null;
$$;
revoke execute on function public.mis_trabajadores() from public, anon;
grant execute on function public.mis_trabajadores() to authenticated;
drop policy if exists "trabajador ve sus dias" on public.cuentas;
create policy "trabajador ve sus dias" on public.cuentas for select to authenticated
  using (public.es_equipo() and (
    (coleccion = 'trabajadores' and id in (select public.mis_trabajadores()))
    or (coleccion in ('jornadas', 'sueldos') and datos->>'trab' in (select public.mis_trabajadores()))));

-- Forma mínima de cada registro, para que uno escrito a mano por la API no rompa
-- las pantallas: un objeto, la fecha como AAAA-MM-DD y la venta con su lista de ítems.
alter table public.cuentas drop constraint if exists cuentas_datos_forma;
alter table public.cuentas add constraint cuentas_datos_forma check (
  jsonb_typeof(datos) = 'object'
  and (not datos ? 'fecha' or (jsonb_typeof(datos->'fecha') = 'string' and datos->>'fecha' ~ '^\d{4}-\d{2}-\d{2}$'))
  and (coleccion <> 'ventas' or (jsonb_typeof(datos->'items') = 'array'
       and not jsonb_path_exists(datos, '$.items[*] ? (@.type() != "object")')))
);
-- Ningún registro de las cuentas pesa más de 20 KB (hoy el más grande pesa ~1 KB)
alter table public.cuentas drop constraint if exists cuentas_datos_tamano;
alter table public.cuentas add constraint cuentas_datos_tamano check (octet_length(datos::text) <= 20000);
