-- =====================================================================
-- Saisei & Co — Registro de ventas y gastos eliminados
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Requiere haber ejecutado antes cuentas.sql y usuarios.sql.
--
-- Cada venta o gasto (compra) que se elimina en /cuentas queda copiado
-- aquí, con el motivo que escribió quien lo borró. El administrador lo ve
-- en /cuentas → Más → Eliminados. Nadie puede cambiarlo ni borrarlo desde
-- la app, ni siquiera un administrador ni la clave secreta: solo el
-- programador, desde el SQL Editor de Supabase.
-- =====================================================================

create table if not exists public.borrados (
  id        bigint generated always as identity primary key,
  cuando    timestamptz not null default now(),
  coleccion text not null,
  ref       text not null,          -- id del registro en cuentas
  datos     jsonb not null,         -- el registro completo, tal como estaba
  motivo    text not null,
  correo    text                    -- quién lo eliminó
);
create index if not exists borrados_cuando on public.borrados (cuando desc);
alter table public.borrados enable row level security;
revoke all on public.borrados from anon, authenticated;
grant select on public.borrados to authenticated;
drop policy if exists "admin ve borrados" on public.borrados;
create policy "admin ve borrados" on public.borrados for select to authenticated using (public.es_admin());

-- Solo el SQL Editor (sin usuario de la app) puede cambiar o borrar el registro
create or replace function public.proteger_borrados() returns trigger
language plpgsql set search_path = public as $$
begin
  if nullif(current_setting('request.jwt.claims', true), '') is not null then
    raise exception 'El registro de eliminados no se puede cambiar' using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
revoke execute on function public.proteger_borrados() from public, anon, authenticated;
drop trigger if exists proteger_borrados on public.borrados;
create trigger proteger_borrados before update or delete on public.borrados for each row execute function public.proteger_borrados();

-- Antes de eliminar una venta o un gasto, se copia al registro con su motivo.
-- Desde la app el motivo es obligatorio; desde el SQL Editor se anota como tal.
create or replace function public.guardar_borrado() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_motivo text := nullif(btrim(current_setting('saisei.motivo', true)), '');
begin
  if old.coleccion not in ('ventas', 'gastos') then return old; end if;
  if v_motivo is null then
    if nullif(current_setting('request.jwt.claims', true), '') is null then
      v_motivo := 'Eliminado desde el panel de Supabase';
    else
      raise exception 'Para eliminar una venta o un gasto hay que escribir el motivo' using errcode = '42501';
    end if;
  end if;
  insert into public.borrados (coleccion, ref, datos, motivo, correo)
  values (old.coleccion, old.id, old.datos, left(v_motivo, 500), (select email from auth.users where id = auth.uid()));
  return old;
end $$;
revoke execute on function public.guardar_borrado() from public, anon, authenticated;
drop trigger if exists guardar_borrado on public.cuentas;
create trigger guardar_borrado before delete on public.cuentas for each row execute function public.guardar_borrado();

-- La app elimina ventas y gastos por aquí. Corre con los permisos de quien
-- llama, así que solo el administrador puede eliminar (igual que antes).
create or replace function public.borrar_con_motivo(p_col text, p_id text, p_motivo text) returns void
language plpgsql set search_path = public as $$
begin
  if length(btrim(coalesce(p_motivo, ''))) < 3 then
    raise exception 'Escribe el motivo' using errcode = '42501';
  end if;
  perform set_config('saisei.motivo', btrim(p_motivo), true);
  delete from public.cuentas where coleccion = p_col and id = p_id;
  perform set_config('saisei.motivo', '', true);
end $$;
revoke execute on function public.borrar_con_motivo(text, text, text) from public, anon;
grant execute on function public.borrar_con_motivo(text, text, text) to authenticated;
