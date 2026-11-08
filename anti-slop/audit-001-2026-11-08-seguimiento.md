# Seguimiento de la auditoría 001 · 8 nov 2026

Arreglé los 13 hallazgos de `audit-001-2026-11-08.md`. Los cambios todavía no están en un commit.

**Cómo comprobé:**
- Cargué las tres páginas en el navegador de la app (servidor local, datos reales, sin guardar nada).
- Las medí en tamaño teléfono (375 px) y en computador (800 px y 1280 px).
- Medí todo el texto visible: el contraste, el tamaño de los botones, el cursor, los campos sin etiqueta y si algo se sale de la pantalla.
- Recorrí las 15 vistas de Cuentas y 5 de las 6 secciones de Gestión. Dejé fuera Actividad, porque abrirla marca los avisos como vistos.

## Resultado por hallazgo

| N° | Regla | Estado | Qué cambió | Prueba |
|---|---|---|---|---|
| 1 | R-25 Contraste | PASA | Cuentas: el botón salmón, el globo de avisos, el botón flotante y el contador de productos usan texto oscuro (`--ink`) en vez de blanco. | 0 textos bajo el mínimo en las 15 vistas. |
| 2 | R-25 Contraste | PASA | Gestión: nuevo color `--accent-ink` (#7a5600) para el texto amarillo ("Gestión", enlaces, estrellas de Opiniones). Texto oscuro sobre el amarillo. La etiqueta "Administrador" usa el color de texto. "Quitar" usa un rojo más oscuro (#B23A26). "Redondo/Cuadrado" usa el color de texto. | "Gestión" 6,65:1; etiqueta de rol 10,7:1; globo de Actividad 10,37:1. 0 textos bajo el mínimo en 5 secciones. |
| 3 | R-25 Contraste | PASA | Cuentas: verde, ámbar y rojo de estado más oscuros (`--ok` #1f6e45, `--warn` #855600, `--bad` #a8352b). | 0 textos bajo el mínimo. |
| 4 | R-25 Contraste | PASA | Estrellas de Opiniones: la vacía tiene contorno; la llena tiene relleno mango y contorno, así que se distinguen por forma y no solo por color. **Corrección:** el aviso "Agrega algo de la carta…" no fallaba; mi script de la auditoría leía mal ese color y medía 3,01 cuando es ~6:1. | Contorno 6,95:1 sobre la tarjeta. |
| 5 | R-02 Raya | PASA | "Agregar al pedido · $X"; en WhatsApp, "Producto: $X" y "Nuevo pedido N° X · Saisei & Co". "Sin enlace", "Elige producto", "Sin productos", "Sin margen", "Sin indicar", "Ningún producto". | 0 rayas en texto de interfaz en los tres archivos. |
| 6 | R-39 Movimiento | PASA | El carrusel tiene botón de pausa (también en el teléfono). Se detiene con el mouse o el foco encima. No arranca con "reducir movimiento". El texto del anuncio solo se lee en voz alta cuando está en pausa. | Pausado 5 s: no cambió de foto. Al pasar el mouse se detiene y al salir sigue. |
| 7 | R-32 Foco | PASA | Pedido y Opiniones: contorno de 2 px pino además del borde. Cuentas: contorno pino sólido. | Revisado en el CSS de los tres archivos. |
| 8 | R-03 Tamaño táctil | PASA | En el teléfono todo control mide 44 px o más: puntos del carrusel, opciones, "Copiar y enviar por Instagram", estrellas, enlaces del pie, logo, pestañas de la carta; en Cuentas los botones pequeños, filtros, flechas, lápiz, selector de app y casillas. También en Gestión: botones de icono, paletas y selector de forma. | 0 controles bajo 44 px en las tres páginas a 375 px. |
| 9 | R-39 Cursor | PASA | Línea base en cada archivo: mano en selectores, etiquetas, casillas y `summary`; cursor de "no permitido" en lo desactivado. | 0 controles sin mano. |
| 10 | R-39 Etiqueta visible | PASA | "Buscar ventas", "Buscar insumos" (Cuentas) y "Link o código de la publicación" (Gestión) son etiquetas visibles. Los botones para subir fotos de Gestión tienen nombre accesible. | 0 campos sin etiqueta. |
| 11 | R-39 Estructura | PASA | Gestión tiene `header` y `main`. | Ambos presentes. |
| 12 | R-40 Rendimiento | PASA | El logo tiene 44 × 44. La primera foto del carrusel tiene `fetchpriority="high"` y ancho y alto. | Atributos presentes en la página cargada. |
| 13 | R-37 Dirección | PASA | Nuevo `DESIGN.md`: personalidad, tipografía, colores con su uso, forma, movimiento, diales y reglas de texto. | Archivo en la raíz del proyecto. |

## Otros cambios

- **El salmón de la página pública:** el color de respaldo del CSS (#E0683F) tenía 3,4:1 con texto blanco. La paleta guardada en Gestión ya usa #B4502C (5,1:1), así que igualé el respaldo a ese color. Se nota solo si Supabase no responde.
- **El pie del carrusel:** con los puntos más grandes, el texto del anuncio quedaba en 56 px de ancho. Ahora el texto va en su propia línea y los controles debajo. Con mouse, los puntos miden 24 px de ancho (mínimo WCAG); en pantallas táctiles, 44.

## Delivery Gate

- [x] Cada hallazgo aprobado tiene un arreglo y una prueba.
- [x] Nada se sale de la pantalla en el teléfono ni en el computador.
- [x] No hay errores en la consola.
- [x] Sin datos inventados.
- [ ] Revisión en un teléfono real. Solo probé en el navegador de la app.

## Lo que no revisé

- No hice capturas de pantalla: el panel del navegador estaba oculto. Las pruebas son mediciones del navegador.
- La sección Actividad de Gestión.
- Las paletas oscuras de Gestión aplicadas a la página pública.
