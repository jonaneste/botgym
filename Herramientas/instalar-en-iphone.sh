#!/usr/bin/env bash
# Compila Entrenos firmada y la instala en el iPhone conectado, sin abrir Xcode.
#
# Existe por dos motivos. El primero es que con un Apple ID gratuito la app
# CADUCA A LOS 7 DÍAS, así que reinstalar no es algo que se haga una vez: es
# algo que se hace todas las semanas, y abrir Xcode y buscar el botón de Play
# cada vez sobra. El segundo es que así la instalación se puede pedir en una
# línea desde cualquier sitio, incluida una sesión de Claude Code en el Mac.
#
#   ./Herramientas/instalar-en-iphone.sh
#
# Opcionales, por si la detección automática no acierta:
#
#   EQUIPO=ABCDE12345    ./Herramientas/instalar-en-iphone.sh   # tu Team ID
#   BUNDLE=com.tunombre.entrenos ./Herramientas/instalar-en-iphone.sh
#   UDID=...             ./Herramientas/instalar-en-iphone.sh   # columna Identifier
#   SOLO_COMPILAR=1      ./Herramientas/instalar-en-iphone.sh   # no instala
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[2m%s\033[0m\n' "$*"; }
titulo(){ printf '\n\033[1m── %s\033[0m\n' "$*"; }

morir() { rojo "✗ $1"; shift; for l in "$@"; do printf '  %s\n' "$l"; done; exit 1; }

# ---------------------------------------------------------------- comprobaciones

titulo "Comprobando el entorno"

[ "$(uname -s)" = "Darwin" ] || morir \
    "Esto solo funciona en un Mac." \
    "Firmar e instalar en un iPhone necesita Xcode y el dispositivo conectado," \
    "así que no hay forma de hacerlo desde Linux ni desde un contenedor."

# `command -v xcodebuild` NO sirve para esto, aunque lo parezca: macOS trae un
# enlace en /usr/bin que existe siempre, incluso con solo las Command Line Tools
# instaladas, y al usarlo falla con
#
#   xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer
#   directory '/Library/Developer/CommandLineTools' is a command line tools instance
#
# Lo que decide es si se puede ejecutar de verdad. Comprobarlo mal hacía que el
# script siguiera adelante y acabara culpando a la identidad de firma, mandando
# al usuario a los ajustes de un Xcode que no tiene.
if ! version=$(xcodebuild -version 2>&1); then
    activo=$(xcode-select -p 2>/dev/null || true)
    morir \
        "Falta Xcode. Aquí solo están las Command Line Tools, que no traen el SDK de iOS ni la firma." \
        "Directorio activo: ${activo:-ninguno}" \
        "" \
        "1. Instala Xcode desde la App Store. Son unos 10 GB: tarda un rato largo." \
        "2. Ábrelo una vez y acepta la licencia." \
        "3. Añade tu Apple ID en Xcode → Settings → Accounts." \
        "" \
        "Si tras instalarlo sigue saliendo esto, apunta las herramientas al Xcode nuevo:" \
        "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

printf '%s\n' "$version" | head -1 | sed 's/^/  /'

# ------------------------------------------------------------------ equipo

titulo "Buscando tu identidad de firma"

equipo="${EQUIPO:-}"
if [ -z "$equipo" ]; then
    # En el nombre de la identidad, el Team ID va entre paréntesis al final:
    #   "Apple Development: tu@correo.com (ABCDE12345)"
    equipos=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*(\([A-Z0-9]\{10\}\))".*/\1/p' | sort -u)

    # `find-identity` solo cuenta un certificado si encuentra su clave privada
    # EN UN LLAVERO DE ARCHIVO. Desde Xcode 26 la clave va al llavero protegido
    # por datos, que `security` no sabe mirar, así que con un certificado
    # perfectamente válido responde «0 valid identities found». Sin esta
    # segunda vuelta el script manda a crear un certificado que ya existe, y
    # con firma gratuita hay que reinstalar cada semana: mordería cada vez.
    #
    # Buscar el certificado a secas sí lo encuentra. Que se pueda firmar con él
    # lo dirá `xcodebuild`, que sí ve los dos llaveros; aquí solo hace falta el
    # Team ID.
    if [ -z "$equipos" ]; then
        equipos=$(security find-certificate -a -c "Apple Development" 2>/dev/null \
            | sed -n 's/.*"labl"<blob>=".*(\([A-Z0-9]\{10\}\))".*/\1/p' | sort -u)
        [ -n "$equipos" ] && gris "  (la clave está en el llavero protegido por datos)"
    fi

    numero=$(printf '%s' "$equipos" | grep -c . || true)

    if [ "$numero" -eq 0 ]; then
        morir "No hay ninguna identidad de firma en este Mac." \
            "Abre Xcode → Settings → Accounts y añade tu Apple ID." \
            "Con eso basta: no hace falta la cuenta de pago del Developer Program."
    elif [ "$numero" -gt 1 ]; then
        rojo "✗ Hay varias identidades y no sé cuál quieres:"
        printf '%s' "$equipos" | sed 's/^/    /'
        morir "Elige una." "Vuelve a lanzarlo así:  EQUIPO=$(printf '%s' "$equipos" | head -1) $0"
    fi
    equipo="$equipos"
fi
verde "✓ Team ID: $equipo"

bundle="${BUNDLE:-com.jonaneste.entrenos}"
gris "  Identificador: $bundle"

# ------------------------------------------------------------------ dispositivo

titulo "Buscando el iPhone"

udid="${UDID:-}"
nombre=""

# Por JSON y no leyendo la tabla. La tabla de `devicectl list devices` tiene dos
# columnas que parecen un identificador —Hostname, que lleva el UDID del
# aparato, e Identifier, que es el UUID que `devicectl` acepta en --device— y
# cualquier expresión regular sobre el texto puede coger la que no es. El JSON
# las distingue por nombre, que es lo único que no se presta a confusión.
if [ -z "$udid" ] && xcrun devicectl list devices >/dev/null 2>&1; then
    json=$(mktemp "${TMPDIR:-/tmp}/entrenos-dispositivos.XXXXXX") || json=""
    if [ -n "$json" ] \
       && xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 \
       && [ -s "$json" ] && command -v python3 >/dev/null 2>&1; then
        leido=$(python3 - "$json" <<'PY' 2>/dev/null
import json, sys
try:
    datos = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)

for d in datos.get("result", {}).get("devices", []):
    propiedades = d.get("deviceProperties", {}) or {}
    conexion = d.get("connectionProperties", {}) or {}
    hardware = d.get("hardwareProperties", {}) or {}

    nombre = propiedades.get("name") or "iPhone"
    estado = (conexion.get("tunnelState") or "").lower()
    emparejado = (conexion.get("pairingState") or "").lower()
    tipo = (hardware.get("deviceType") or "").lower()
    identificador = d.get("identifier")

    if not identificador or tipo and tipo != "iphone":
        continue
    # Un aparato visto por wifi pero no accesible no sirve para instalar.
    if estado in ("unavailable",) or emparejado == "unpaired":
        continue
    print(identificador)
    print(nombre)
    break
PY
        )
        udid=$(printf '%s' "$leido" | sed -n 1p)
        nombre=$(printf '%s' "$leido" | sed -n 2p)
    fi
    rm -f "$json"

    # Sin python3 o con un JSON que no entiendo, se lee la tabla. La columna
    # Identifier es un UUID con el formato 8-4-4-4-12, que no se confunde con el
    # UDID del Hostname (8 hex, guion, 16 hex).
    if [ -z "$udid" ]; then
        linea=$(xcrun devicectl list devices 2>/dev/null \
            | grep -i 'iphone' | grep -iv 'unavailable' | head -1)
        if [ -n "$linea" ]; then
            udid=$(printf '%s' "$linea" \
                | grep -oE '[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}' | head -1)
            nombre=$(printf '%s' "$linea" | sed -E 's/[[:space:]]{2,}.*//; s/\t.*//')
        fi
    fi
fi

if [ -z "$udid" ]; then
    # Xcode antiguo, sin devicectl: xctrace lista "Nombre (versión) (UDID)".
    linea=$(xcrun xctrace list devices 2>/dev/null \
        | grep -i 'iphone' | grep -iv 'simulator' | head -1)
    udid=$(printf '%s' "$linea" | sed -n 's/.*(\([0-9A-Fa-f-]\{25,\}\)).*/\1/p')
    nombre=$(printf '%s' "$linea" | sed 's/ (.*//')
fi

[ -n "$udid" ] || morir \
    "No veo ningún iPhone conectado." \
    "Conéctalo por cable, desbloquéalo y, si sale el aviso, dale a «Confiar en este ordenador»." \
    "" \
    "Si está conectado y aun así no lo ve, mira qué dice esto:" \
    "   xcrun devicectl list devices" \
    "y pásale el de la columna Identifier a mano:" \
    "   UDID=el-identificador-de-ahi $0"

verde "✓ ${nombre:-el dispositivo que has indicado}"
gris "  $udid"

# ------------------------------------------------------------------ compilar

titulo "Compilando firmada"
gris "  La primera vez Xcode crea el perfil de aprovisionamiento solo, y puede"
gris "  pedirte la contraseña del llavero. Es normal."

salida=$(mktemp "${TMPDIR:-/tmp}/entrenos-build.XXXXXX") || morir \
    "No he podido crear un archivo temporal para el registro de compilación." \
    "Revisa que \$TMPDIR apunte a un sitio donde se pueda escribir."
construccion=".build-iphone"

if ! xcodebuild build \
        -project Entrenos.xcodeproj \
        -scheme Entrenos \
        -configuration Debug \
        -destination "id=$udid" \
        -derivedDataPath "$construccion" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$equipo" \
        PRODUCT_BUNDLE_IDENTIFIER="$bundle" \
        > "$salida" 2>&1; then

    rojo "✗ La compilación ha fallado. Los errores:"
    grep -E 'error:|Provisioning|provisioning profile|No profiles|Failed to register' "$salida" \
        | sort -u | head -20 | sed 's/^/    /'

    if grep -qiE 'bundle identifier .* is not available|already in use|unavailable' "$salida"; then
        printf '\n'
        rojo "  Ese identificador ya está cogido por otra cuenta de Apple."
        printf '  Vuelve a lanzarlo con uno tuyo:\n'
        printf '    BUNDLE=com.tunombre.entrenos %s\n' "$0"
    elif grep -qiE 'No signing certificate|no account|Select a development team' "$salida"; then
        printf '\n'
        rojo "  Falta tu Apple ID en Xcode."
        printf '  Xcode → Settings → Accounts → + → Apple ID, y vuelve a lanzarlo.\n'
    fi
    printf '\n'
    gris "  Registro completo: $salida"
    exit 1
fi

app="$construccion/Build/Products/Debug-iphoneos/Entrenos.app"
[ -d "$app" ] || morir \
    "Compiló, pero no encuentro el .app donde esperaba." \
    "Buscaba: $app" \
    "Registro completo: $salida"

verde "✓ Compilada: $app"

if [ -n "${SOLO_COMPILAR:-}" ]; then
    gris "  SOLO_COMPILAR está puesto: no se instala."
    exit 0
fi

# ------------------------------------------------------------------ instalar

titulo "Instalando en el iPhone"

if ! command -v xcrun >/dev/null 2>&1 || ! xcrun devicectl --version >/dev/null 2>&1; then
    rojo "✗ Este Xcode no trae devicectl, que es lo que instala en el dispositivo."
    printf '  La app está compilada y firmada. Para meterla en el iPhone:\n'
    printf '    open Entrenos.xcodeproj   y darle a Play con el iPhone elegido como destino.\n'
    exit 1
fi

if ! xcrun devicectl device install app --device "$udid" "$app" 2>&1 | tee "$salida.install" | sed 's/^/  /'; then
    rojo "✗ La instalación ha fallado."
    if grep -qiE 'not paired|unlock|trust' "$salida.install"; then
        printf '  Desbloquea el iPhone y acepta «Confiar en este ordenador».\n'
    fi
    gris "  Registro: $salida.install"
    exit 1
fi

verde "✓ Instalada"

# ------------------------------------------------------------------ y ahora qué

titulo "Lo que falta, y lo tienes que hacer tú en el iPhone"
cat <<'FIN'
  La primera vez, iOS no deja abrir una app firmada con un Apple ID gratuito
  hasta que confías en el certificado a mano:

    Ajustes → General → VPN y gestión de dispositivos → tu Apple ID → Confiar

  Después se abre con normalidad. Y ojo al plazo: con cuenta gratuita la firma
  CADUCA A LOS 7 DÍAS y la app deja de abrirse. Para revivirla, vuelve a lanzar
  este mismo script; no se pierde ningún dato, porque el historial vive en el
  dispositivo y la reinstalación no lo borra.
FIN
