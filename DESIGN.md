# Design

Dirección visual de Saisei & Co, escrita a partir de lo que ya está publicado (noviembre 2026). Sirve para que cada cambio de diseño parta de aquí y las tres páginas no se separen. El contexto del negocio está en `PRODUCT.md`.

## Personalidad

- **Pública (`/`):** una sushería de pueblo, cálida y cuidada. Verde pino profundo como el bosque de Puerto Cisnes, arroz claro de fondo, salmón y mango como los colores de la comida. Fotos grandes de los platos; el texto acompaña, no compite.
- **Gestión y Cuentas:** herramientas de trabajo para el teléfono. Tranquilas, densas y claras. Mismos colores y letras que la página, con menos adorno.

## Tipografía

- **Marcellus** para títulos y el nombre de la marca: letra con remates suaves, recuerda a un letrero pintado.
- **Figtree** para todo lo demás: se lee bien en pantallas chicas y tiene números tabulares para montos.
- Escala compartida `--t-*` en Gestión y Cuentas. Montos siempre con `font-variant-numeric: tabular-nums`.

## Color

| Token | Valor | Uso |
|---|---|---|
| `--pine` | `#0E3B2E` | Color de la marca: cabeceras, fondos oscuros, foco, botones principales en las apps. |
| `--rice` / `--rice-2` | `#F4F6EE` / `#E8EDE1` | Fondos claros y botones secundarios. |
| `--ink` / `--ink-soft` | `#13261F` / `#4A5E55` | Texto principal y secundario. |
| `--salmon` | `#B4502C` en la página, `#EE7A4F` en Cuentas | Acción principal. En la página lleva texto blanco (5,2:1); en Cuentas, al ser más claro, lleva texto `--ink`. |
| `--mango` | `#E7B64A` / `#F3C552` | Acentos y estrellas. **Nunca como color de texto sobre fondo claro**: para texto se usa `--accent-ink` (`#7a5600`). Sobre mango, el texto va en `#2a1a00`. |
| `--ok` / `--warn` / `--bad` (Cuentas) | `#1f6e45` / `#855600` / `#a8352b` | Estados. Todos pasan 4,5:1 sobre blanco y sobre su fondo `*-bg`. |

La paleta de la página pública se puede cambiar desde Gestión; cualquier paleta nueva debe mantener 4,5:1 para texto y 3:1 para controles.

## Forma y espacio

- Botones redondeados según `--btn-radius` (elegible en Gestión). Tarjetas con radio moderado, sin sombras grandes.
- En pantallas táctiles, todo control mide al menos 44 × 44 px.
- Foco visible siempre: contorno de 2 px o más (mango en la página, pino en las apps). Nunca `outline:none` sin reemplazo.

## Movimiento

- Transiciones cortas (150–300 ms) solo para cambios de estado.
- El carrusel de la portada avanza solo, pero se pausa con un botón, al pasar el mouse o el foco, y no arranca si el teléfono pide "reducir movimiento".

## Diales

| Superficie | Energía | Ritmo | Movimiento |
|---|---|---|---|
| Página pública | 2 de 3 | 2–3 de 3 | 2 de 3 |
| Gestión y Cuentas | 1 de 3 | 1 de 3 | 1 de 3 |

- **Energía:** cuánto color y tamaño compiten por atención.
- **Ritmo:** cuánto cambia la composición entre secciones.
- **Movimiento:** cuánta animación hay.

## Texto

- Español de Chile, frases cortas, tú.
- Sin rayas (—): usar dos puntos, punto medio (·) o una palabra ("Sin enlace", "Sin indicar").
- Nada inventado: ni cifras, ni opiniones, ni sellos.
