-- =====================================================================
-- Saisei & Co — Lo más pedido de la semana (para el carrusel de la página)
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Requiere haber ejecutado antes cuentas.sql (tabla cuentas).
--
-- La página pública no puede leer las ventas. Esta función solo entrega
-- los nombres de los productos más vendidos en los últimos 7 días (hora
-- de Chile), en orden. No entrega cantidades, montos ni clientes.
-- Se excluyen los servicios (Delivery) y los toppings.
-- =====================================================================

create or replace function public.mas_vendidos_semana()
returns table (puesto int, nombre text)
language sql stable security definer set search_path = public as $$
  with hoy as (select (now() at time zone 'America/Santiago')::date d),
  carta as (
    select datos->>'id' id, coalesce(datos->>'categoria', '') categoria
    from cuentas where coleccion = 'carta'
  ),
  items as (
    select i->>'nombre' nombre, i->>'prod' prod,
           coalesce((i->>'cant')::numeric, 1) cant, (v.datos->>'fecha')::date fecha
    from cuentas v, jsonb_array_elements(v.datos->'items') i, hoy
    where v.coleccion = 'ventas'
      and v.datos->>'fecha' ~ '^\d{4}-\d{2}-\d{2}$'
      and (v.datos->>'fecha')::date between hoy.d - 6 and hoy.d
  )
  select (row_number() over (order by sum(it.cant) desc, max(it.fecha) desc, min(it.nombre)))::int, min(it.nombre)
  from items it left join carta c on c.id = it.prod
  where coalesce(c.categoria, '') not in ('Servicio', 'Topping')
    and it.nombre is not null and it.nombre !~* '^(delivery|topping)'
  group by lower(it.nombre)
  order by 1
  limit 10;
$$;

revoke all on function public.mas_vendidos_semana() from public;
grant execute on function public.mas_vendidos_semana() to anon, authenticated;
