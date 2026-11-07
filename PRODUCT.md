# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Clientes de Saisei & Co** (público): personas en Puerto Cisnes y alrededores que piden sushi para delivery o retiro. Arman el pedido en la página desde el teléfono y lo envían por WhatsApp (o lo copian para Instagram).
- **Dueños** (equipo interno): manejan el negocio casi siempre desde el teléfono. En `/gestion` editan la carta, fotos, carrusel, paleta y avisos de la página; en `/cuentas` registran ventas, gastos, inventario y confirman los pedidos que llegan de la web.
- **Colaboradores**: rol existente con acceso al trabajo del día a día (pedidos, ventas, gastos, inventario, mostrar/ocultar productos, moderar opiniones), sin vistas de dinero, sin cambiar configuración y sin borrar. Los dueños son el uso principal.

## Product Purpose

Saisei & Co es una sushería de Puerto Cisnes (Patagonia chilena). El producto tiene tres superficies:

1. **Página pública** (`/`): muestra la carta y permite armar un pedido completo (opciones, salsas, toppings, entrega, datos y pago) que llega a WhatsApp ya escrito.
2. **Gestión** (`/gestion`): panel para que el negocio controle su propia página sin tocar código.
3. **Cuentas** (`/cuentas`): reemplazo del Excel `Gestion_Saisei_Co.xlsx` para llevar ventas, gastos, inventario, costeo de carta/recetas, resultados y punto de equilibrio.

Éxito en los próximos meses:
- Más pedidos armados en la web en vez de escritos a mano.
- Menos trabajo manual: dejar el Excel y que pedidos, ventas e inventario queden registrados sin retipear.
- Hacer crecer la marca más allá de Puerto Cisnes.

## Operating Context

- Los pedidos web se guardan en Supabase como `pendiente`; el dueño los revisa en Cuentas → Pedidos y solo al confirmar se crea la venta. Rechazar un pedido lo elimina.
- El mes contable va del día 16 al 15 (`diaCorte`).
- Las apps internas se usan sobre todo en el teléfono, a menudo con el negocio funcionando; deben funcionar con una mano y de un vistazo. Se instalan como app (manifest PWA).
- Contacto del negocio: WhatsApp +56 9 5035 7674, Instagram @cosaisei.

## Capabilities and Constraints

- **Pedido por WhatsApp, sin pago en línea.** El pedido se arma en la web y se confirma por WhatsApp; esto se mantiene en cualquier rediseño.
- **Las fórmulas de Cuentas deben calcular igual que el Excel** (food cost, costo unitario con flete y merma, punto de equilibrio).
- Sitio estático (HTML/CSS/JS sin framework) desplegado en Vercel, con datos en Supabase (proyecto `saisei-co`). Sin Supabase, Cuentas cae a `localStorage`.
- Roles: administrador > colaborador > invitado, guardados por correo en la tabla `usuarios`.
- Delivery con costo adicional; pago por transferencia, efectivo o tarjeta.
- Idioma: español de Chile.

## Brand Commitments

- Nombre: **Saisei & Co**. Los dueños pueden cambiar logo, paleta, forma de botones, movimiento e imágenes desde Gestión, así que la página debe seguir funcionando con cualquier paleta que elijan (incluidas paletas oscuras).

## Evidence on Hand

- Carta real con precios, cargada desde Supabase.
- Fotos de pedidos reales vía Instagram @cosaisei; imágenes de carta en `img/`.
- Opiniones de clientes reales enviadas desde la página (moderadas en Gestión).
- No hay testimonios de prensa, cifras de ventas públicas ni premios: no inventarlos.

## Product Principles

1. Pedir debe ser más fácil que escribir a mano por WhatsApp; si no, la web no gana pedidos.
2. Lo que el cliente arma es exactamente lo que llega al chat: total y detalle sin sorpresas.
3. Registrar algo en Cuentas tiene que tomar segundos en el teléfono; cada paso manual que se pueda evitar, se evita.
4. Los números del negocio cuadran con el Excel de siempre.
5. Los dueños controlan su página sin depender de un programador.
