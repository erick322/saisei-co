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

-- Solo el administrador puede ver y cambiar las cuentas (nadie más, ni siquiera para leer).
alter table public.cuentas enable row level security;
drop policy if exists "admin cuentas" on public.cuentas;
create policy "admin cuentas" on public.cuentas for all to authenticated
  using (public.es_admin()) with check (public.es_admin());
