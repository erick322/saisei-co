-- =====================================================================
-- Saisei & Co — Registro de actividad y límites contra abusos
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Requiere haber ejecutado antes setup.sql, cuentas.sql, pedidos.sql y usuarios.sql.
--
-- Cada cambio en la base de datos queda anotado: quién, qué, cuándo y desde
-- qué conexión. Lo que conviene revisar queda marcado como alerta. El
-- administrador lo ve en /gestion → Actividad; nadie puede editarlo ni borrarlo.
-- =====================================================================

create table if not exists public.registro (
  id      bigint generated always as identity primary key,
  cuando  timestamptz not null default now(),
  correo  text,               -- vacío = invitado (la página pública)
  rol     text not null,
  accion  text not null check (accion in ('crear', 'cambiar', 'eliminar')),
  tabla   text not null,
  ref     text,               -- qué registro: colección/id, N° de pedido, correo...
  resumen text,
  ip      text,               -- conexión desde donde se hizo
  alerta  text                -- motivo para revisarlo, si lo hay
);
create index if not exists registro_cuando on public.registro (cuando desc);
create index if not exists registro_ip on public.registro (tabla, ip, cuando desc);
alter table public.registro enable row level security;
revoke all on public.registro from anon, authenticated;
grant select on public.registro to authenticated;
drop policy if exists "admin ve registro" on public.registro;
create policy "admin ve registro" on public.registro for select to authenticated using (public.es_admin());

-- Conexión (IP) de quien hace la petición, tal como la entrega Supabase
create or replace function public.ip_cliente() returns text
language sql stable set search_path = public as $$
  select nullif(coalesce(h->>'cf-connecting-ip', split_part(h->>'x-forwarded-for', ',', 1)), '')
  from (select nullif(current_setting('request.headers', true), '')::json h) x;
$$;
revoke execute on function public.ip_cliente() from public, anon, authenticated;

create or replace function public.anotar() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  n jsonb := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  o jsonb := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  f jsonb := coalesce(n, o);
  d jsonb := coalesce(f->'datos', '{}'::jsonb);
  -- "sistema" = hecho en el panel de Supabase; "servicio" = con la clave secreta (service_role), que la app nunca usa
  v_rol text := case when nullif(current_setting('request.jwt.claims', true), '') is null then 'sistema'
                     when auth.role() = 'service_role' then 'servicio' else public.mi_rol() end;
  v_ip text := public.ip_cliente();
  v_accion text := case tg_op when 'INSERT' then 'crear' when 'UPDATE' then 'cambiar' else 'eliminar' end;
  v_ref text; v_res text; v_alerta text; v_cambios text;
begin
  -- Qué campos cambiaron (en cuentas, dentro de "datos"; "upd" y "actualizado" son marcas de tiempo)
  if tg_op = 'UPDATE' then
    select string_agg(k, ', ' order by k) into v_cambios from (
      select key k from jsonb_each(case when tg_table_name = 'cuentas' then n->'datos' else n end)
      where key not in ('upd', 'actualizado')
        and value is distinct from (case when tg_table_name = 'cuentas' then o->'datos' else o end)->key
      union
      select key from jsonb_each(case when tg_table_name = 'cuentas' then o->'datos' else o end)
      where key not in ('upd', 'actualizado')
        and not (case when tg_table_name = 'cuentas' then n->'datos' else n end) ? key) c;
    if v_cambios is null then return null; end if;   -- se guardó igual que estaba: nada que anotar
  end if;

  if tg_table_name = 'cuentas' then
    v_ref := (f->>'coleccion') || '/' || (f->>'id');
    v_res := concat_ws(' · ', d->>'fecha', case when d ? 'num' then 'N° ' || (d->>'num') end,
      nullif(d->>'nombre', ''), nullif(d->>'desc', ''), nullif(d->>'cliente', ''),
      case when d ? 'monto' then '$' || (d->>'monto') end);
    if f->>'coleccion' in ('ventas', 'gastos', 'sueldos', 'saldos', 'apartados') then
      if tg_op = 'DELETE' then v_alerta := 'Se eliminó un registro de dinero';
      elsif tg_op = 'UPDATE' and v_rol = 'colaborador' then v_alerta := 'Un colaborador cambió un registro de dinero ya anotado';
      end if;
    end if;
  elsif tg_table_name = 'pedidos' then
    v_ref := 'N° ' || (f->>'codigo');
    v_res := concat_ws(' · ', f->>'cliente', '$' || (f->>'total'), f->>'estado');
  elsif tg_table_name = 'usuarios' then
    v_ref := f->>'email';
    v_res := concat_ws(' · ', f->>'rol', nullif(f->>'nombre', ''));
    v_alerta := 'Cambió quién tiene acceso al sistema';
  elsif tg_table_name = 'productos' then
    v_ref := f->>'nombre';
    v_res := concat_ws(' · ', case when (f->>'precio')::int > 0 then '$' || (f->>'precio') end, case when (f->>'activo')::boolean then 'visible' else 'oculto' end);
  elsif tg_table_name = 'categorias' then
    v_ref := f->>'nombre';
  elsif tg_table_name = 'opiniones' then
    v_ref := f->>'nombre';
    v_res := concat_ws(' · ', (f->>'estrellas') || '★', left(f->>'texto', 80));
  else
    v_ref := f->>'id';
  end if;
  if v_cambios is not null then v_res := concat_ws(' · ', v_res, 'cambió: ' || v_cambios); end if;

  -- Envíos seguidos desde la misma conexión en la página pública
  if tg_op = 'INSERT' and v_rol = 'invitado' and v_ip is not null and tg_table_name in ('pedidos', 'opiniones')
     and (select count(*) from public.registro r where r.tabla = tg_table_name and r.accion = 'crear'
          and r.ip = v_ip and r.cuando > now() - interval '10 minutes') >= 2 then
    v_alerta := 'Varios envíos seguidos desde la misma conexión';
  end if;
  if v_rol = 'servicio' then v_alerta := 'Cambio hecho con la clave secreta de Supabase'; end if;

  insert into public.registro (correo, rol, accion, tabla, ref, resumen, ip, alerta)
  values ((select email from auth.users where id = auth.uid()), v_rol, v_accion, tg_table_name, v_ref, left(v_res, 300), v_ip, v_alerta);
  -- El registro guarda 6 meses
  if random() < 0.02 then delete from public.registro where cuando < now() - interval '6 months'; end if;
  return null;
end $$;
revoke execute on function public.anotar() from public, anon, authenticated;

do $$ declare t text; begin
  foreach t in array array['cuentas', 'pedidos', 'usuarios', 'productos', 'categorias', 'ajustes', 'opiniones'] loop
    execute format('drop trigger if exists anotar on public.%I', t);
    execute format('create trigger anotar after insert or update or delete on public.%I for each row execute function public.anotar()', t);
  end loop;
end $$;

-- Límite de envíos desde la página pública: por conexión (5 pedidos o 3 opiniones
-- cada 10 minutos) y en total (40 pedidos o 15 opiniones cada 10 minutos), para que
-- nadie pueda llenar la base de datos con envíos falsos.
create or replace function public.limitar_envios() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_ip text := public.ip_cliente();
  por_ip int := case tg_table_name when 'pedidos' then 5 else 3 end;
  total int := case tg_table_name when 'pedidos' then 40 else 15 end;
begin
  if public.es_equipo() then return new; end if;
  if (v_ip is not null and (select count(*) from public.registro r where r.tabla = tg_table_name and r.accion = 'crear'
        and r.ip = v_ip and r.cuando > now() - interval '10 minutes') >= por_ip)
     or (select count(*) from public.registro r where r.tabla = tg_table_name and r.accion = 'crear'
        and r.rol = 'invitado' and r.cuando > now() - interval '10 minutes') >= total then
    raise exception 'Demasiados envíos seguidos. Espera unos minutos e inténtalo de nuevo.' using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke execute on function public.limitar_envios() from public, anon, authenticated;
drop trigger if exists limitar_envios on public.pedidos;
create trigger limitar_envios before insert on public.pedidos for each row execute function public.limitar_envios();
drop trigger if exists limitar_envios on public.opiniones;
create trigger limitar_envios before insert on public.opiniones for each row execute function public.limitar_envios();
