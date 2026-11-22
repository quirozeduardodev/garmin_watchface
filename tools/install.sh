#!/usr/bin/env bash
# Compila CaratulaPro y la instala en un Forerunner 255 conectado por USB.
# Pensado para macOS: el reloj se conecta como MTP y se copia con libmtp.
#
# Uso:   tools/install.sh
# Variables opcionales:
#   KEY=ruta/a/developer_key.der   (por defecto ../keys/developer_key.der)
#   SDK=ruta/al/connectiq-sdk      (por defecto el SDK más nuevo instalado)
#   DEVICE=fr255
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="${KEY:-../keys/developer_key.der}"
DEVICE="${DEVICE:-fr255}"
SDK="${SDK:-$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/"connectiq-sdk-* 2>/dev/null | sort | tail -1)}"
BIN_DIR="tools/.bin"

[ -f "$KEY" ] || { echo "No encuentro la llave de firma: $KEY (define KEY=...)"; exit 1; }
[ -x "$SDK/bin/monkeyc" ] || { echo "No encuentro el SDK de Connect IQ (define SDK=...)"; exit 1; }

# 1. Las constantes de vista previa deben estar apagadas en una versión real.
if grep -nE 'const PREVIEW_[A-Z]+ = ([0-9]+|true);' source/Preview.mc; then
    echo "source/Preview.mc tiene valores de prueba. Déjalos en -1 / false."
    exit 1
fi

# 2. Compilar (versión de release).
mkdir -p bin "$BIN_DIR"
"$SDK/bin/monkeyc" -f monkey.jungle -d "$DEVICE" -o bin/CaratulaPro.prg -y "$KEY" -r
ls -l bin/CaratulaPro.prg

# 3. El simulador bloquea la conexión USB con el reloj: debe estar cerrado.
if pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null; then
    echo "Cierra el simulador de Connect IQ, desconecta y reconecta el reloj, y vuelve a correr esto."
    exit 1
fi

# 4. Herramienta de copia (libmtp de Homebrew: brew install libmtp).
if [ ! -x "$BIN_DIR/mtpput" ]; then
    BREW="$(brew --prefix)"
    clang -O2 -o "$BIN_DIR/mtpput" tools/mtpput.c -I"$BREW/include" -L"$BREW/lib" -lmtp
fi

export LANG=en_US.UTF-8
APPS=$(mtp-folders 2>/dev/null | awk -F'\t' '$2=="  Apps"{print $1}')
if [ -z "$APPS" ]; then
    echo "No pude abrir el reloj por USB. Reconecta el cable (y cierra el simulador) e intenta de nuevo."
    exit 1
fi

# 5. Borrar la versión anterior y copiar la nueva a GARMIN/Apps.
OLD=$(mtp-files 2>/dev/null | grep -B1 "Filename: CaratulaPro.prg" | grep "File ID" | awk '{print $3}' || true)
for id in $OLD; do mtp-delfile -n "$id" >/dev/null 2>&1 || true; done
"$BIN_DIR/mtpput" bin/CaratulaPro.prg "$APPS" CaratulaPro.prg | tail -1
mtp-files 2>/dev/null | grep -A3 "Filename: CaratulaPro.prg" | grep -E "size|Parent"
echo "Listo. Desconecta el reloj y elige la carátula en Carátula > Caratula Pro."
