-- =====================================================================
-- Saisei & Co — Pedidos que llegan desde la página
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Requiere haber ejecutado antes setup.sql (usa la función es_admin()).
--
-- Cada pedido enviado desde la página queda "pendiente". El administrador
-- lo revisa en /cuentas → Pedidos y, solo cuando lo confirma, se registra
-- como venta en las cuentas.
-- =====================================================================

create table if not exists public.pedidos (
  id         bigint generated always as identity primary key,
  codigo     text not null unique check (codigo ~ '^[A-Z0-9]{4,8}$'),   -- el N° que ve el cliente en su mensaje
  creado     timestamptz not null default now(),
  estado     text not null default 'pendiente' check (estado in ('pendiente', 'confirmado', 'rechazado')),
  cliente    text not null check (length(cliente) between 1 and 120),
  telefono   text not null check (length(telefono) between 3 and 40),
  entrega    text not null check (entrega in ('Delivery', 'Retiro')),
  direccion  text check (length(direccion) <= 300),
  referencia text check (length(referencia) <= 300),
  hora       text check (length(hora) <= 120),
  pago       text check (length(pago) <= 60),
  notas      text check (length(notas) <= 1000),
  items      jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 60),
  total      int not null default 0 check (total between 0 and 10000000),
  venta_id   text,          -- la venta creada en /cuentas al confirmar
  revisado   timestamptz    -- cuándo lo confirmó o rechazó el administrador
);
create index if not exists pedidos_estado_creado on public.pedidos (estado, creado desc);

alter table public.pedidos enable row level security;
drop policy if exists "cliente crea pedido" on public.pedidos;
drop policy if exists "admin ve pedidos" on public.pedidos;
drop policy if exists "admin cambia pedidos" on public.pedidos;
drop policy if exists "admin borra pedidos" on public.pedidos;
drop policy if exists "equipo ve pedidos" on public.pedidos;
drop policy if exists "equipo cambia pedidos" on public.pedidos;
drop policy if exists "equipo borra pedidos" on public.pedidos;

-- Cualquiera puede ENVIAR un pedido nuevo (siempre entra como pendiente), pero no puede ver ni cambiar pedidos.
create policy "cliente crea pedido" on public.pedidos for insert to anon, authenticated
  with check (estado = 'pendiente' and venta_id is null and revisado is null);
-- Solo el equipo (administrador y colaborador) los ve, confirma o rechaza (al rechazar se borran).
create policy "equipo ve pedidos"     on public.pedidos for select to authenticated using (public.es_equipo());
create policy "equipo cambia pedidos" on public.pedidos for update to authenticated using (public.es_equipo()) with check (public.es_equipo());
create policy "equipo borra pedidos"  on public.pedidos for delete to authenticated using (public.es_equipo());

-- La fecha del pedido la pone la base de datos (si la pusiera el cliente, pedidos con
-- fecha futura dejarían fuera de la lista a los reales) y cada ítem debe ser un objeto.
create or replace function public.pedido_nuevo() returns trigger
language plpgsql set search_path = public as $$
begin
  new.creado := now();
  if exists (select 1 from jsonb_array_elements(new.items) e where jsonb_typeof(e) <> 'object') then
    raise exception 'Cada ítem del pedido debe ser un objeto';
  end if;
  return new;
end $$;
drop trigger if exists pedido_nuevo on public.pedidos;
create trigger pedido_nuevo before insert on public.pedidos for each row execute function public.pedido_nuevo();
