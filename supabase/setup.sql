-- =====================================================================
-- Saisei & Co — Base de datos de la carta
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Antes de ejecutarlo, cambia el correo del administrador (abajo, paso 2).
-- =====================================================================

-- 1) Tablas -------------------------------------------------------------
create table if not exists public.categorias (
  id          bigint generated always as identity primary key,
  nombre      text not null,
  emoji       text default '',
  descripcion text default '',
  orden       int  default 0,
  creado      timestamptz default now()
);

create table if not exists public.productos (
  id           bigint generated always as identity primary key,
  categoria_id bigint not null references public.categorias(id) on delete cascade,
  nombre       text not null,
  descripcion  text default '',
  precio       int  default 0,                -- precio único (si no hay variantes)
  variantes    jsonb default '[]'::jsonb,     -- ej: [{"n":"Chicken","p":12000},{"n":"Mixta","p":15500}]
  rolls        int  default 0,                -- > 0: el cliente elige esa cantidad de rolls (tablas)
  salsa        boolean default false,         -- muestra selector de salsa
  es_topping   boolean default false,         -- true: el cliente elige a qué roll de su pedido se agrega
  badge        text default '',               -- etiqueta, ej: "Nuevo"
  foto         text default '',               -- URL de la foto
  activo       boolean default true,          -- false = oculto en la página
  orden        int  default 0,
  creado       timestamptz default now()
);

-- Por si la tabla ya existía de una versión anterior:
alter table public.productos add column if not exists es_topping boolean default false;

-- 2) Administradores ----------------------------------------------------
create table if not exists public.admins (email text primary key);
alter table public.admins enable row level security;  -- nadie puede leerla desde la web

-- 👇 CAMBIA ESTE CORREO por el del administrador (el mismo que crearás en Authentication → Users)
insert into public.admins (email) values ('CAMBIA-ESTE-CORREO@ejemplo.com') on conflict do nothing;

create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

-- 3) Seguridad: todos pueden VER la carta, solo el admin puede CAMBIARLA --
alter table public.categorias enable row level security;
alter table public.productos  enable row level security;

drop policy if exists "ver categorias" on public.categorias;
drop policy if exists "admin categorias" on public.categorias;
drop policy if exists "ver productos" on public.productos;
drop policy if exists "admin productos" on public.productos;

create policy "ver categorias"   on public.categorias for select using (true);
create policy "admin categorias" on public.categorias for all to authenticated using (public.es_admin()) with check (public.es_admin());
create policy "ver productos"    on public.productos  for select using (activo or public.es_admin());
create policy "admin productos"  on public.productos  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- 4) Fotos (Storage) ----------------------------------------------------
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', true) on conflict (id) do nothing;

drop policy if exists "ver fotos" on storage.objects;
drop policy if exists "admin sube fotos" on storage.objects;
drop policy if exists "admin edita fotos" on storage.objects;
drop policy if exists "admin borra fotos" on storage.objects;

create policy "ver fotos"         on storage.objects for select using (bucket_id = 'fotos');
create policy "admin sube fotos"  on storage.objects for insert to authenticated with check (bucket_id = 'fotos' and public.es_admin());
create policy "admin edita fotos" on storage.objects for update to authenticated using (bucket_id = 'fotos' and public.es_admin());
create policy "admin borra fotos" on storage.objects for delete to authenticated using (bucket_id = 'fotos' and public.es_admin());

-- 5) Carta inicial (solo se carga si no hay categorías) ------------------
do $$
declare c_shari bigint; c_promos bigint; c_furea bigint; c_esp bigint; c_top bigint;
begin
  if exists (select 1 from public.categorias) then return; end if;

  insert into public.categorias (nombre, emoji, descripcion, orden) values
    ('Shari', '🍱', 'Tablas para compartir. Elige Chicken (solo pollo) o Mixta (pollo y salmón) y luego tus rolls.', 1) returning id into c_shari;
  insert into public.categorias (nombre, emoji, descripcion, orden) values
    ('Promos', '🎉', 'Promos de hand rolls.', 2) returning id into c_promos;
  insert into public.categorias (nombre, emoji, descripcion, orden) values
    ('Furea', '🔥', 'Rolls especiales con salsa a elección (o sin salsa). ¿Quieres más? Mira los Toppings.', 3) returning id into c_furea;
  insert into public.categorias (nombre, emoji, descripcion, orden) values
    ('Especiales', '🌭', 'Corn dogs: vienesa con queso envuelta en panko, crujiente por fuera y con queso que se estira.', 4) returning id into c_esp;
  insert into public.categorias (nombre, emoji, descripcion, orden) values
    ('Toppings', '✨', 'Agrega un topping y elige a cuál de tus rolls se lo ponemos.', 5) returning id into c_top;

  -- "foto" con nombres como 'rollA' usan los recortes de las cartas incluidos en la página.
  insert into public.productos (categoria_id, nombre, descripcion, precio, variantes, rolls, salsa, es_topping, badge, foto, orden) values
    (c_shari,  'Tabla 20 piezas', 'Elige 2 rolls de 10 piezas.', 0, '[{"n":"Chicken","p":12000},{"n":"Mixta","p":15500}]', 2, false, false, '',         'rollA',  1),
    (c_shari,  'Tabla 30 piezas', 'Elige 3 rolls de 10 piezas.', 0, '[{"n":"Chicken","p":17000},{"n":"Mixta","p":20000}]', 3, false, false, 'Favorita', 'nigiri', 2),
    (c_shari,  'Tabla 40 piezas', 'Elige 4 rolls de 10 piezas.', 0, '[{"n":"Chicken","p":20000},{"n":"Mixta","p":24000}]', 4, false, false, '',         'rollB',  3),
    (c_promos, 'Promo Sai',  '3 hand rolls de pollo, palta y queso crema.', 10000, '[]', 0, false, false, '', 'panda', 1),
    (c_promos, 'Promo & Co', '2 hand rolls de pollo, palta y queso crema + 1 hand roll de salmón, palta y queso crema.', 12000, '[]', 0, false, false, '', 'rollP', 2),
    (c_furea,  'Ebi Mango',   'Camarón y queso, envuelto en mango.', 6500, '[]', 0, true, false, '', 'ebi', 1),
    (c_furea,  'Sake Furea',  'Palta, pepino y queso crema, envuelto en salmón flameado. Pruébalo con salmón ahumado: más firme e intenso.', 0, '[{"n":"Fresco","p":6500},{"n":"Ahumado","p":6500}]', 0, true, false, '', 'sake', 2),
    (c_furea,  'Aburi Chizu', 'Atún, queso y palta, envuelto en queso crema con topping de papas al hilo.', 7500, '[]', 0, true, false, 'Nuevo', 'aburi', 3),
    (c_top,    'Papas al hilo', 'Crujientes papas al hilo sobre el roll que elijas.', 1000, '[]', 0, false, true, '', '', 1),
    (c_esp,    '1 Corn', 'Vienesa con queso envuelta en panko.',              2500, '[]', 0, false, false, '', '', 1),
    (c_esp,    '3 Corn', 'Vienesa con queso en panko, 2 salsas a elección.',   6500, '[]', 0, false, false, '', '', 2),
    (c_top,    'Ceviche',       'Ceviche fresco sobre el roll que elijas.',           2500, '[]', 0, false, true, '', '', 2),
    (c_top,    'Centolla',      'Centolla desmenuzada con salsa y cilantro fresco.',  3500, '[]', 0, false, true, 'Nuevo', '', 3);
end $$;
