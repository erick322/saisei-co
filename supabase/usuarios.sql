-- =====================================================================
-- Saisei & Co — Tipos de usuario
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Requiere haber ejecutado antes setup.sql, cuentas.sql y pedidos.sql.
--
-- Solo hay 3 tipos de usuario, de mayor a menor acceso:
--
--  1. administrador  Dueño del negocio. Todo: carta y precios, apariencia,
--                    avisos, opiniones, cuentas completas (dinero, saldos,
--                    resultados, configuración) y quién entra al sistema.
--  2. colaborador    Equipo del día a día. En /cuentas: pedidos de la página,
--                    ventas, gastos e inventario (sin ver el dinero del negocio
--                    ni la configuración, y sin eliminar registros).
--                    En /gestion: mostrar u ocultar productos y aprobar u
--                    ocultar opiniones.
--  3. invitado       Cualquier otra persona (con o sin cuenta). Solo la página
--                    pública: ver la carta, hacer pedidos y dejar opiniones.
--
-- El rol se guarda por correo en la tabla usuarios (setup.sql); quien no está
-- ahí es invitado. El administrador agrega colaboradores en /gestion → Usuarios.
-- =====================================================================

-- Los administradores de la versión anterior (tabla admins) pasan a usuarios
do $$ begin
  if to_regclass('public.admins') is not null then
    insert into public.usuarios (email, rol) select lower(email), 'administrador' from public.admins on conflict do nothing;
    drop table public.admins;
  end if;
end $$;

-- Solo el administrador ve y cambia quién tiene acceso
drop policy if exists "admin usuarios" on public.usuarios;
create policy "admin usuarios" on public.usuarios for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- Siempre debe quedar al menos un administrador
create or replace function public.queda_un_admin() returns trigger
language plpgsql set search_path = public as $$
begin
  if old.rol = 'administrador' and (tg_op = 'DELETE' or new.rol <> 'administrador' or new.email <> old.email)
     and not exists (select 1 from public.usuarios where rol = 'administrador' and email <> old.email) then
    raise exception 'Debe quedar al menos un administrador';
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists queda_un_admin on public.usuarios;
create trigger queda_un_admin before update or delete on public.usuarios for each row execute function public.queda_un_admin();

-- El colaborador puede mostrar u ocultar un producto, pero no cambiar nada más de la carta
create or replace function public.mostrar_producto(p_id bigint, p_activo boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.es_equipo() then raise exception 'Sin permiso'; end if;
  update public.productos set activo = p_activo where id = p_id;
end $$;
revoke execute on function public.mostrar_producto(bigint, boolean) from public, anon;
grant execute on function public.mostrar_producto(bigint, boolean) to authenticated;
