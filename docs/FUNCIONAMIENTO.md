# Cómo funciona Caratula Pro

## El reloj de destino

| | Forerunner 255 (`fr255`) |
|---|---|
| Pantalla | 260 × 260, redonda, MIP (reflectiva) |
| Colores | 64: cada canal solo puede valer `00`, `55`, `AA` o `FF` |
| API de Connect IQ | 5.2 (la app pide mínimo 4.2.0) |
| Memoria para la carátula | ~128 KB de código y datos; las imágenes van a un "graphics pool" aparte |
| Fuentes | Solo las del sistema: `FONT_XTINY` … `FONT_NUMBER_THAI_HOT` (no hay fuentes vectoriales) |
| No disponible | `Dc.setFill` / `BitmapTexture` (solo en modelos AMOLED) |

Por ser MIP, los colores y fondos no gastan más batería que el negro. Lo que sí cuesta es el **tiempo de CPU** al dibujar.

## Ciclo de dibujo

`CaratulaProApp` crea `CaratulaProView` y un `CaratulaProDelegate`.

1. **`onUpdate`**: el sistema lo llama una vez por minuto, o cada segundo durante unos 10 s después de levantar la muñeca.
   - Calcula la hora (`ti`) y los ángulos de las manecillas (`hAng`, `mAng`).
   - `FaceData.refreshFast()` en cada llamada: batería, notificaciones, conexión y FC.
   - `FaceData.refreshSlow()` una vez por minuto: actividad, Body Battery, estrés, SpO2, distancia de la semana, clima, ubicación y viento.
   - `drawBackground()`: negro, color sólido, imagen de `resources/drawables/bg` o `Sky.draw()`.
   - El estilo elegido (`faceA` … `faceY`, ver la tabla).
   - Los segundos (`drawSec`) solo si corresponde.
2. **`onPartialUpdate`**: cada segundo y solo con "Segundos: Siempre".
   - La carátula completa se dibujó antes en un `BufferedBitmap`.
   - Aquí se recorta (`setClip`) al rectángulo del segundero anterior y del nuevo, se copia el búfer y se dibuja el segundero.
   - Si el reloj avisa que se pasó del presupuesto de energía (`onPowerBudgetExceeded`), vuelve a "al levantar la muñeca".
3. **`onEnterSleep` / `onExitSleep`**: marcan `awake`. Los segundos y los detalles vivos del cielo solo se dibujan despierto.

### Estilos

| `Style` | Nombre | Función | Notas |
|---|---|---|---|
| 0 | Pulso | `faceA` | Arco superior = Body Battery, arco inferior = pasos (10 segmentos) |
| 1 | Anillos | `faceB` | Tres anillos: pasos, Body Battery, km de la semana |
| 2 | Tablero | `faceE` | Rejilla con 7 datos y barra de pasos |
| 3 | Cronógrafo | `faceC` | Subesferas: clima (izq.), fecha (der.), batería (abajo) |
| 4 | Clásico | `faceK` | `analogData(true, true)` |
| 5 | Aviador | `faceM` | Triángulo en las 12, segundero de paleta |
| 6 | Esencial | `faceT` | Fecha sin marco |
| 7 | Romano | `faceW` | Números romanos |
| 8 | Bisel | `faceX` | Anillo gris con números, cardinales en color de acento |
| 9 | Militar | `faceY` | Pista de minutos tipo riel |

Todas las analógicas usan números `FONT_TINY` a radio 98 px, con el 12 en `FONT_SMALL`.

### Datos que esquivan las manecillas

`analogData()` coloca cuatro datos alrededor del centro: batería en 0°, fecha en 90°, clima en 270° y el dato extra en 180°.
Cada uno pasa por `slot(base, r)`, que prueba los ángulos `base`, ±35° y ±55° y se queda con el primero que esté a ≥ 24° de las dos manecillas.
Si ninguno lo está, se queda con el más alejado. Se apaga con el ajuste `AvoidHands`.

## Ajustes

Las carátulas instaladas a mano (sideload) **no** reciben ajustes desde Garmin Connect.
Por eso hay un menú propio: `AppBase.getSettingsView()` devuelve `CPSettingsMenu` (un `Menu2`).
En el reloj se llega por **Carátula → Caratula Pro → Personalizar**.

- Los valores se guardan en `Application.Properties`. Los valores por defecto están en `resources/settings/properties.xml`.
- `settings.xml` define los mismos ajustes, por si algún día se publica en la Connect IQ Store.
- Después de cada cambio, `CPSettings.applied()` llama a `onSettingsChanged()` → `loadSettings()`.

| Propiedad | Valores |
|---|---|
| `Style` | 0–9 (tabla de arriba) |
| `Accent` | 0–19 (`ACCENTS` en la vista) |
| `Background` | 0 negro, 1 azul marino, 2–10 imágenes, 11 cielo dinámico, 12 cielo dinámico con clima |
| `Frames` | Marco alrededor de la fecha en Clásico, Aviador, Romano y Bisel |
| `AvoidHands` | Mover datos tapados por las manecillas |
| `Seconds` | 0 al levantar la muñeca, 1 nunca, 2 siempre |
| `Extra` | Dato extra en analógicas: 0 ninguno, 1 FC, 2 Body Battery, 3 pasos, 4 notificaciones, 5 km semana, 6 kcal, 7 estrés |
| `RunGoal` | Meta semanal de carrera para el anillo de Anillos |
| `Language` | 0 automático, 1 español, 2 inglés (solo textos de la carátula) |
| `HourFormat`, `TempUnit`, `DistUnit` | 0 automático (del reloj) o forzado |
| `LeadingZero` | `09:30` vs `9:30` |

Los textos del **menú** siguen el idioma del reloj (`resources/` = inglés, `resources-spa/` = español).
Los textos **de la carátula** (días, meses, etiquetas) salen de `DAYS_*`, `MONS_*` y `LBL_*` en la vista, según `Language`.

## Fondos de imagen

Las imágenes 2–10 son PNG de 260×260 generados por `tools/bggen.swift`.
Solo usan colores de la paleta del reloj, y el tramado está hecho a mano.
En `drawables.xml` cada imagen declara su paleta exacta y `dithering="none"`, así el compilador no las altera y ocupan poco.
Se cargan con `WatchUi.loadResource` y viven en el graphics pool; solo ocupan unos 300 bytes de la memoria de la app.

## Cielo dinámico (`source/Sky.mc`)

### Estado (`update`)

- **Ubicación:** `FaceData.resolveLocation()` la busca en este orden:
  1. Clima del celular (`observationLocationPosition`).
  2. Última posición GPS (`Activity.getActivityInfo().currentLocation`).
  3. Última guardada en `Application.Storage("loc")`.
  4. Si no hay ninguna, la longitud se estima por la zona horaria, con latitud 20°.
- **Sol:** `sunTimes()` aplica la fórmula de la NOAA y devuelve el amanecer, el atardecer y los crepúsculos civil (−6°) y náutico (−12°) en minutos locales.
- **Fases del cielo:** noche, alba, amanecer, día, hora dorada, atardecer y anochecer, según esos tiempos. Cada fase tiene su lista de colores en `skyStops()`.
- **Estación:** sale del mes y se invierte en el hemisferio sur.
- **Luna:**
  - **Fase:** días desde una luna nueva de referencia ÷ 29.53.
  - **Tránsito:** mediodía solar + fase × 24 h.
  - **Visibilidad:** se ve si está a menos de 6 h 12 min de su tránsito, así que hay noches sin luna.
- **Tiempo sidéreo local (`lst`):** se calcula con la fórmula GMST + longitud y hace girar el cielo estrellado.
- **Clima:** `weatherCat()` agrupa las condiciones de Garmin en despejado, parcial, nublado, lluvia, tormenta, nieve y niebla. Solo se usa si `useWeather` (fondo 12).
- **Viento:** `windBearing` y `windSpeed` definen hacia dónde y qué tan rápido avanzan las nubes.

### Dibujo (`draw` / `render`)

1. El cielo se dibuja en su propio `BufferedBitmap`. Solo se rehace cuando cambia la clave de caché: fase, clima, estación, posición del sol o de la luna, fase lunar o un bloque de 10 minutos. El resto del tiempo solo se copia.
2. **Degradado:** franjas horizontales con 7 niveles de mezcla entre dos colores. Las mezclas intermedias se hacen con líneas diagonales espaciadas cada 2, 3 o 4 px, porque no hay `setFill`.
3. **Estrellas:**
   - El catálogo tiene 170 estrellas al azar en la esfera celeste. Sus senos y cosenos se precalculan en `initialize()`.
   - Se proyectan mirando al sur: el este queda a la izquierda, el oeste a la derecha y el cenit arriba.
   - Con luna brillante se ven menos; en el crepúsculo solo las brillantes.
4. **Vía Láctea:** 200 puntos sobre el plano galáctico, convertidos a coordenadas ecuatoriales y más densos hacia Sagitario. Solo aparece en noches sin luna.
5. **Constelaciones:** cada una tiene su centro real (`CONST_CENTER`, AR/Dec). Se dibujan hasta 2 de las que estén sobre el horizonte, las más altas, con su forma fija (`CONST_PTS`/`CONST_LINES`).
6. **Sol y luna** sobre un arco de este a oeste. Las digitales usan un arco más pegado al borde. La luna se dibuja fila por fila según su fase; en el hemisferio sur, invertida.
7. **Clima mínimo:** 2–3 nubecitas arriba. Su acomodo cambia cada día y avanzan con el viento. Cerca del horizonte aparecen franjas de niebla.
8. **Colinas:** dos polígonos simétricos del color de la estación.
9. **`live()`:** se dibuja sobre el búfer en cada actualización.
   - Con la muñeca levantada: estrellas que titilan, alguna estrella fugaz y relámpagos.
   - Siempre: lluvia o nieve debajo de las nubes.

### Rendimiento

Connect IQ corta una función que ejecuta demasiadas instrucciones ("Watchdog Tripped").
Para no llegar al límite:

- El objeto `Sky` y su catálogo se crean en `loadSettings()`, fuera del dibujo.
- No hay trigonometría por estrella: se usan productos con senos y cosenos precalculados.
- Las colinas son `fillPolygon`, no columnas de líneas.
- El cielo se rehace como máximo cada 10 minutos.

## Vistas previas en el simulador

`source/Preview.mc` tiene constantes que fuerzan valores para capturar escenas: `PREVIEW_STYLE`, `PREVIEW_BG`, `PREVIEW_HM` (hora), `PREVIEW_WX`, `PREVIEW_MOON`, `PREVIEW_MONTH`, etc.
Con `PREVIEW_HM ≥ 0` el cielo usa una ubicación de prueba fija.
**Todas deben quedar en `-1` / `false`** en una versión real; `tools/install.sh` lo verifica.
`tools/preview.sh` las cambia, compila, captura y las regresa a `-1`.
