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

-- 2) Usuarios y roles ---------------------------------------------------
-- Solo 3 tipos de usuario: administrador, colaborador e invitado (quien no
-- está en esta tabla). Qué puede hacer cada uno: ver supabase/usuarios.sql.
create table if not exists public.usuarios (
  email  text primary key check (email = lower(email) and email like '%@%'),
  rol    text not null check (rol in ('administrador', 'colaborador')),
  nombre text default '' check (char_length(nombre) <= 60),
  creado timestamptz default now()
);
alter table public.usuarios enable row level security;  -- solo el administrador la ve (usuarios.sql)

-- 👇 Solo la primera vez: quita el "--" de la línea de abajo y pon el correo del
--    administrador (el mismo que crearás en Authentication → Users). Si se deja un
--    correo de ejemplo, quien se registre con él sería administrador.
-- insert into public.usuarios (email, rol) values ('correo-del-administrador@...', 'administrador') on conflict do nothing;

-- Rol de quien está conectado. Solo cuenta un correo confirmado, para que nadie
-- pueda registrarse con el correo de otra persona y heredar su rol.
create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((
    select x.rol from public.usuarios x join auth.users u on lower(u.email) = x.email
    where u.id = auth.uid() and u.email_confirmed_at is not null
  ), 'invitado');
$$;
create or replace function public.es_admin()  returns boolean language sql stable security definer set search_path = public as $$ select public.mi_rol() = 'administrador'; $$;
create or replace function public.es_equipo() returns boolean language sql stable security definer set search_path = public as $$ select public.mi_rol() in ('administrador', 'colaborador'); $$;

-- 3) Seguridad: todos pueden VER la carta, solo el admin puede CAMBIARLA --
--    (el colaborador ve los productos ocultos y solo puede mostrarlos u ocultarlos: usuarios.sql)
alter table public.categorias enable row level security;
alter table public.productos  enable row level security;

drop policy if exists "ver categorias" on public.categorias;
drop policy if exists "admin categorias" on public.categorias;
drop policy if exists "ver productos" on public.productos;
drop policy if exists "admin productos" on public.productos;

create policy "ver categorias"   on public.categorias for select using (true);
create policy "admin categorias" on public.categorias for all to authenticated using (public.es_admin()) with check (public.es_admin());
create policy "ver productos"    on public.productos  for select using (activo or public.es_equipo());
create policy "admin productos"  on public.productos  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- 3b) Apariencia de la página (una sola fila, se edita en /gestion) -----
create table if not exists public.ajustes (
  id             int primary key default 1 check (id = 1),
  colores        jsonb default '{}'::jsonb,   -- paleta: {"pine":"#0E3B2E","salmon":"#EE7A4F",...}
  logo           text default '',             -- URL del logo (vacío = círculo con "S")
  foto_portada   text default '',             -- foto redonda de la portada
  foto_destacada text default '',             -- foto de la franja destacada
  portada        jsonb default '[]'::jsonb,   -- carrusel: [{"src":"...","txt":"...","ir":"Shari"}] (vacío = cartas originales)
  agotado        boolean default false,       -- aviso "Agotamos stock": solo se muestra si está activado
  agotado_titulo text default 'Agotamos stock',
  agotado_texto  text default 'Gracias por tanto, puerto querido. Pide con tiempo y asegura tu tabla.',
  actualizado    timestamptz default now()
);
-- Contacto de la página (se edita en /gestion → Avisos y portada; vacío = el número y usuario de index.html)
alter table public.ajustes add column if not exists whatsapp  text default '';
alter table public.ajustes add column if not exists instagram text default '';
-- Galería de Instagram (se edita en /gestion → Avisos y portada): ["CODIGO1","CODIGO2",...]. Vacío = las publicaciones que trae index.html.
alter table public.ajustes add column if not exists instagram_posts jsonb default '[]'::jsonb;
-- Pago con tarjeta en el pedido (se activa/desactiva en /gestion → Avisos y portada)
alter table public.ajustes add column if not exists pago_tarjeta boolean default true;
insert into public.ajustes (id) values (1) on conflict do nothing;
alter table public.ajustes enable row level security;
drop policy if exists "ver ajustes" on public.ajustes;
drop policy if exists "admin ajustes" on public.ajustes;
create policy "ver ajustes"   on public.ajustes for select using (true);
create policy "admin ajustes" on public.ajustes for update to authenticated using (public.es_admin()) with check (public.es_admin());

-- 3c) Opiniones de clientes (se dejan en la página, se moderan en /gestion) ---
create table if not exists public.opiniones (
  id        bigint generated always as identity primary key,
  nombre    text    not null check (char_length(nombre) between 1 and 60),
  estrellas int     not null check (estrellas between 1 and 5),
  texto     text    not null check (char_length(texto) between 1 and 600),
  aprobado  boolean not null default false,   -- solo se ve en la página cuando el admin la aprueba
  creado    timestamptz not null default now()
);
alter table public.opiniones enable row level security;
drop policy if exists "ver opiniones aprobadas" on public.opiniones;
drop policy if exists "crear opinion" on public.opiniones;
drop policy if exists "admin opiniones" on public.opiniones;
drop policy if exists "equipo ve opiniones" on public.opiniones;
drop policy if exists "equipo modera opiniones" on public.opiniones;
drop policy if exists "admin borra opiniones" on public.opiniones;
-- Cualquiera ve SOLO las aprobadas
create policy "ver opiniones aprobadas" on public.opiniones for select using (aprobado);
-- Cualquiera puede dejar una opinión, pero entra SIN aprobar (no puede autoaprobarse)
create policy "crear opinion" on public.opiniones for insert to anon, authenticated with check (aprobado = false);
-- El equipo (administrador y colaborador) ve todas y las aprueba u oculta; solo el administrador las elimina
create policy "equipo ve opiniones"     on public.opiniones for select to authenticated using (public.es_equipo());
create policy "equipo modera opiniones" on public.opiniones for update to authenticated using (public.es_equipo()) with check (public.es_equipo());
create policy "admin borra opiniones"   on public.opiniones for delete to authenticated using (public.es_admin());

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
