#!/usr/bin/env bash
# Captura vistas previas de la carátula desde el simulador de Connect IQ.
#
# Uso:
#   tools/preview.sh <carpeta_salida> <nombre> "STYLE=4 BG=11 HM=1260 WX=0 MOON=50 MONTH=11" \
#                    [<nombre> "<ajustes>" ...]
#
# Cada ajuste fija una constante de source/Preview.mc (PREVIEW_<NOMBRE>):
#   STYLE 0-9, BG 0-12, EXTRA 0-7, LANG 1|2, SEC 0-2, HM minutos desde
#   medianoche, FRAMES 0|1, WX 0-6, MOON 0-99, MONTH 1-12.
# Al terminar, todas las constantes vuelven a -1 y el simulador se cierra.
# Para juntar capturas en una hoja: tools/.bin/labeled (ver docs/DESPLIEGUE.md).
#
# Requiere permiso de "Grabación de pantalla" para la terminal (macOS).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$1"; shift
KEY="${KEY:-../keys/developer_key.der}"
SDK="${SDK:-$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/"connectiq-sdk-* 2>/dev/null | sort | tail -1)}"
BIN_DIR="tools/.bin"
mkdir -p "$OUT" "$BIN_DIR"
[ -x "$BIN_DIR/winid" ] || swiftc -O -o "$BIN_DIR/winid" tools/winid.swift
[ -x "$BIN_DIR/labeled" ] || swiftc -O -o "$BIN_DIR/labeled" tools/labeled.swift

reset_preview() {
    sed -i '' -E 's/const PREVIEW_([A-Z]+) = -?[0-9]+;/const PREVIEW_\1 = -1;/' source/Preview.mc
}
trap 'reset_preview; pkill -f "monkeydo|monkeybrains|bin/shell --transport" || true; pkill -f "ConnectIQ.app/Contents/MacOS/simulator" || true' EXIT

pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null || { ("$SDK/bin/connectiq" >/dev/null 2>&1 &); sleep 8; }

while [ $# -ge 2 ]; do
    NAME="$1"; SETTINGS="$2"; shift 2
    reset_preview
    for kv in $SETTINGS; do
        k="${kv%%=*}"; v="${kv#*=}"
        sed -i '' -E "s/const PREVIEW_${k} = -?[0-9]+;/const PREVIEW_${k} = ${v};/" source/Preview.mc
    done
    "$SDK/bin/monkeyc" -f monkey.jungle -d fr255 -o "$BIN_DIR/prev.prg" -y "$KEY" > "$BIN_DIR/build.log" 2>&1 \
        || { echo "Falló la compilación de $NAME"; grep ERROR "$BIN_DIR/build.log" | head -5; continue; }
    ("$SDK/bin/monkeydo" "$BIN_DIR/prev.prg" fr255 > "$OUT/$NAME.log" 2>&1 &)
    sleep 6
    WIN=$("$BIN_DIR/winid" | awk '{print $1}' | head -1)
    screencapture -x -o -l "$WIN" "$OUT/$NAME.png"
    if grep -q "Error:" "$OUT/$NAME.log"; then echo "ERROR en $NAME:"; grep -A3 "Error:" "$OUT/$NAME.log"; fi
    echo "$OUT/$NAME.png"
done
