#!/usr/bin/env bash
# Comprueba que Entrenos/Nucleo no dependa de frameworks de Apple.
#
# El núcleo tiene que compilar en Linux (y por tanto ejecutarse con `swift test`
# sin Xcode). Si alguien importa SwiftUI o SwiftData ahí dentro, los tests dejan
# de poder correr fuera de un Mac y nos quedamos sin red de seguridad.
set -euo pipefail

cd "$(dirname "$0")/.."

PROHIBIDOS='^import (SwiftUI|SwiftData|HealthKit|UIKit|Charts|CoreData|AppKit|WidgetKit|UserNotifications)'
fallos=0

while IFS= read -r archivo; do
    if grep -nE "$PROHIBIDOS" "$archivo"; then
        echo "  ↳ $archivo importa un framework de Apple y está en el núcleo." >&2
        fallos=1
    fi
done < <(find Entrenos/Nucleo -name '*.swift' -type f)

if [ "$fallos" -ne 0 ]; then
    echo "" >&2
    echo "FALLO: el núcleo debe importar solo Foundation." >&2
    exit 1
fi

total=$(find Entrenos/Nucleo -name '*.swift' -type f | wc -l | tr -d ' ')
echo "OK: $total archivos del núcleo, sin dependencias de Apple."
