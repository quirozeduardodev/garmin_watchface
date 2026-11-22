# Instrucciones para agentes

Proyecto: carátula Connect IQ (Monkey C) para **Garmin Forerunner 255** (`fr255`).
Lee [docs/FUNCIONAMIENTO.md](docs/FUNCIONAMIENTO.md) antes de cambiar el dibujo y [docs/DESPLIEGUE.md](docs/DESPLIEGUE.md) antes de compilar o instalar.

## Reglas básicas

- **Idioma:** la persona dueña del proyecto habla español. Escribe en español los comentarios del código, los textos para el usuario y la documentación.
  - Todo texto nuevo del menú va en **los dos** archivos: `resources/strings/strings.xml` (inglés) y `resources-spa/strings/strings.xml` (español).
  - Los textos de la carátula van en `DAYS_*`, `MONS_*` y `LBL_*`, en `CaratulaProView.mc`.
- **Nunca** subas llaves (`*.der`, `*.pem`), compilados (`bin/`, `*.prg`) ni datos personales: rutas de tu máquina, correos, ciudad o coordenadas reales. El repo es público.
- **`source/Preview.mc`:** todas las constantes deben quedar en `-1` / `false` en cualquier commit e instalación. `tools/install.sh` falla si no es así.
- **Antes de proponer código, muestra cómo se verá:** captura en el simulador (`tools/preview.sh`) y comparte la hoja de capturas.
- **Antes de instalar en el reloj, confirma que el simulador esté cerrado.** Si está abierto, el reloj rechaza la conexión USB.

## Comandos

```bash
# Compilar (release)
SDK="$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/"connectiq-sdk-* | sort | tail -1)"
"$SDK/bin/monkeyc" -f monkey.jungle -d fr255 -o bin/CaratulaPro.prg -y ../keys/developer_key.der -r

# Capturas en el simulador (cierra el simulador al terminar y regresa Preview.mc a -1)
tools/preview.sh <carpeta> <nombre> "STYLE=4 BG=11 HM=1260 WX=0 MOON=50 MONTH=11"

# Instalar en el reloj (macOS, USB)
tools/install.sh
```

No hay pruebas automáticas. Verifica así:

- La compilación termina en `BUILD SUCCESSFUL`.
- Los `.log` de `preview.sh` no tienen `Error:`. Fíjate sobre todo en `Watchdog Tripped`.
- Las capturas se ven bien.

## Límites del dispositivo

- **64 colores:** cada canal solo puede valer `00/55/AA/FF`. Cualquier otro color se aproxima.
- **Sin `Dc.setFill`/`BitmapTexture`** en fr255. Los degradados se hacen con líneas diagonales (`Sky.band`).
- **~128 KB de memoria de app.** Las imágenes van al graphics pool. Las imágenes nuevas se generan con `tools/bggen.swift` y se declaran con su paleta exacta y `dithering="none"`.
- **Watchdog:** pocas operaciones por llamada. Precalcula la trigonometría en `initialize()`, guarda en caché en un `BufferedBitmap`, prefiere polígonos a bucles de líneas, y crea los objetos pesados en `loadSettings()`.
- **Batería:** lo que cuesta es la CPU, no el color.
  - Todo lo que se mueva cada segundo debe dibujarse solo con `awake == true`.
  - Lo que cambia lento va en caché.

## Cómo agregar cosas

**Un ajuste nuevo:**
1. Valor por defecto en `resources/settings/properties.xml`.
2. Entrada en `resources/settings/settings.xml`.
3. Textos en los dos `strings.xml`.
4. Agrégalo a `CPSettings.ITEMS` y a `listDef()` (o a `isToggle()`) en `SettingsMenu.mc`.
5. Léelo en `loadSettings()` (`CaratulaProView.mc`), validando el rango.

**Un estilo nuevo:**
1. Función `faceN()` en la vista.
2. `case` en el `switch` de `onUpdate`.
3. Ajusta el rango de `style` en `loadSettings`.
4. Agrega la entrada `S<n>` en ajustes y textos.
5. Las analógicas usan `ticks()`, `nums(98, FONT_TINY, [], FONT_SMALL, …)`, `analogData()` y `hands()`.

**Un fondo nuevo:**
- **Imagen:** PNG en `resources/drawables/bg`, declarado en `drawables.xml`, más su `case` en `drawBackground()` y su entrada `BG<n>`.
- **Procedural:** dentro de `Sky.mc` o como una función nueva con caché.

## Preferencias de diseño de la persona dueña

- **Simetría:** nada cargado a un solo lado. Por ejemplo, las colinas del cielo son simétricas.
- **Analógicas:**
  - Siempre se ven los 12 números, a tamaño `FONT_TINY` (12 en `FONT_SMALL`).
  - Batería arriba, fecha a la derecha, clima a la izquierda y un dato extra abajo.
  - Los datos se mueven si una manecilla los tapa.
- **Batería del reloj** visible en todos los estilos.
- **Estilos con nombre**, no con letras.
- **Clima mínimo** en el cielo dinámico: nunca cubrir el cielo de gris. Estrellas, luna y Vía Láctea siempre visibles; solo 2–3 nubecitas arriba.
- **Todo sincronizado con la realidad:** hora solar real, fase y salida de la luna, cielo que gira, viento real y estaciones.
- **Antes de programar, muestra opciones visuales.** Evita duplicados casi iguales.
