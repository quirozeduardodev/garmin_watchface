# Compilar, probar e instalar

## 1. Requisitos

- **Connect IQ SDK 9.x**, con el SDK Manager de Garmin (https://developer.garmin.com/connect-iq/sdk/).
  En el SDK Manager descarga el SDK y el dispositivo **Forerunner 255**.
- **Java**: lo necesita `monkeyc`. El SDK Manager avisa si falta.
- **macOS:**
  - Para copiar al reloj: `brew install libmtp`, más `clang` (Xcode Command Line Tools).
  - Para vistas previas: `swiftc` y permiso de **Grabación de pantalla** para tu terminal.

El SDK queda en `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-<versión>/`.
Los scripts de `tools/` buscan el más nuevo de forma automática. Para usar otro, define `SDK=...`.

## 2. Llave de firma

Toda app de Connect IQ se firma con una llave RSA de 4096 bits.
**Guárdala fuera del repo y respáldala:** si la pierdes, una nueva firma hace que el reloj trate la carátula como otra app y se pierden sus ajustes.

```bash
mkdir -p ../keys && cd ../keys
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

Los scripts usan `../keys/developer_key.der`, es decir, una carpeta `keys` al lado del repo. Para usar otra ruta, define `KEY=...`.
El `.gitignore` bloquea `*.der` y `*.pem`.

## 3. Compilar

```bash
SDK="$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/"connectiq-sdk-* | sort | tail -1)"
"$SDK/bin/monkeyc" -f monkey.jungle -d fr255 -o bin/CaratulaPro.prg -y ../keys/developer_key.der -r
```

`-r` compila la versión de release (sin información de depuración).
Antes, revisa que todas las constantes de `source/Preview.mc` estén en `-1` / `false`.

## 4. Probar en el simulador

```bash
"$SDK/bin/connectiq" &                         # abre el simulador
"$SDK/bin/monkeydo" bin/CaratulaPro.prg fr255  # carga la carátula
```

Para fijar una escena y capturarla:

```bash
tools/preview.sh capturas/tmp noche "STYLE=4 BG=11 HM=1290 MONTH=11" lluvia "STYLE=0 BG=12 HM=900 WX=3"
```

Para juntar capturas en una hoja con nombres:

```bash
tools/.bin/labeled hoja.png 4 80 170 260 260 capturas/tmp/noche.png "Noche" capturas/tmp/lluvia.png "Lluvia"
```

`80 170 260 260` es el recorte de la pantalla dentro de la ventana del simulador.

Revisa el `.log` de cada captura. Si aparece `Watchdog Tripped Error`, la carátula tarda demasiado en dibujar y en el reloj se reiniciaría.

> El menú del simulador no se puede controlar desde scripts. Para probar el menú "Personalizar", usa las constantes de vista previa o abre el menú a mano.

## 5. Instalar en el reloj

### macOS (automático)

```bash
tools/install.sh
```

1. Revisa `Preview.mc` y compila en modo release.
2. Verifica que el simulador esté cerrado.
3. Compila `tools/mtpput.c` si hace falta.
4. Busca la carpeta `GARMIN/Apps` por su ID MTP, borra la versión anterior y copia la nueva.

¿Por qué una herramienta propia? El Forerunner 255 se conecta como **MTP**, no como disco. Con este reloj, `mtp-sendfile` de libmtp falla ("Parent folder could not be found" / "could not get storage id"). `mtpput` envía el archivo directamente al ID de la carpeta usando el almacenamiento del dispositivo.

### Windows

El reloj aparece en el Explorador como dispositivo portátil. Copia `bin/CaratulaPro.prg` a `Almacenamiento interno\GARMIN\Apps`.

### Linux

Con `jmtpfs`/`simple-mtpfs` monta el reloj y copia el `.prg` a `GARMIN/Apps`. También puedes compilar `tools/mtpput.c` contra libmtp.

### En el reloj

1. Desconecta el cable. En unos segundos el reloj instala la carátula.
2. Mantén presionado **UP** → **Carátula** → **Caratula Pro**.
3. Para ajustarla: **Carátula → Caratula Pro → Personalizar**.

## 6. Problemas comunes

| Síntoma | Solución |
|---|---|
| `PTP_ERROR_IO: failed to open session` | Cierra el simulador de Connect IQ (bloquea el USB), desconecta y reconecta el reloj |
| `No raw devices found` | Reconecta el cable y verifica que el reloj muestre que está conectado |
| No aparecen ajustes en Garmin Connect | Es normal en carátulas instaladas a mano: usa **Personalizar** en el reloj |
| El cielo muestra atardecer cuando ya es de noche | El reloj aún no tiene tu ubicación: abre Garmin Connect en el celular para sincronizar el clima, o haz una actividad con GPS. Después se guarda |
| La carátula se reinicia o queda en blanco | Probablemente "Watchdog": reduce el trabajo por cuadro (ver docs/FUNCIONAMIENTO.md › Rendimiento) |
| El segundero no aparece al levantar la muñeca | Depende del gesto del reloj; prueba **Segundos → Siempre** |

## 7. Publicar en la Connect IQ Store (opcional)

1. Compila un paquete `.iq`: `monkeyc -e -f monkey.jungle -o bin/CaratulaPro.iq -y <llave> -r`.
2. Súbelo en https://apps.garmin.com/developer.
3. En la tienda, los ajustes de `settings.xml` también aparecen en Garmin Connect.
