#!/usr/bin/env bash
# Todo lo que CI comprueba, en un comando.
#
# Sirve para no empujar un ciclo de diez minutos por algo que se ve en treinta
# segundos. La compilación de iOS solo se intenta si hay Xcode: en Linux no
# existe el SDK, y ahí CI es el único compilador.
set -uo pipefail

cd "$(dirname "$0")/.."

fallos=0
pasos=0

paso() {
    local nombre="$1"; shift
    pasos=$((pasos + 1))
    printf '\n\033[1m── %s\033[0m\n' "$nombre"
    if "$@"; then
        printf '\033[32m✓ %s\033[0m\n' "$nombre"
    else
        printf '\033[31m✗ %s\033[0m\n' "$nombre"
        fallos=$((fallos + 1))
    fi
}

if command -v node >/dev/null 2>&1; then
    paso "Sintaxis del servidor MCP" node --check mcp/servidor-entrenos.mjs
    paso "Pruebas del servidor MCP" node mcp/prueba.mjs
else
    printf '\n\033[33m⊘ Sin node: el servidor MCP no se comprueba\033[0m\n'
fi

paso "El núcleo no depende de frameworks de Apple" ./Herramientas/verificar-nucleo.sh
paso "Los #Predicate solo capturan identificadores simples" ./Herramientas/verificar-predicados.py

if command -v swift >/dev/null 2>&1; then
    paso "Tests del núcleo" swift test
else
    printf '\n\033[33m⊘ Sin toolchain de Swift: los tests del núcleo no se ejecutan.\033[0m\n'
    printf '  Se verifican en CI, en Linux y en macOS.\n'
fi

# La app solo compila donde hay SDK de iOS.
if command -v xcodebuild >/dev/null 2>&1; then
    paso "Compilar la app para iOS" bash -c '
        set -o pipefail
        xcodebuild build \
            -project Entrenos.xcodeproj \
            -scheme Entrenos \
            -configuration Debug \
            -destination "generic/platform=iOS Simulator" \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            | tee build.log \
            | grep -E "error:|warning:|BUILD" || true
        grep -q "BUILD SUCCEEDED" build.log
    '
else
    printf '\n\033[33m⊘ Sin xcodebuild: la app no se compila aquí.\033[0m\n'
    printf '  Es el único paso que necesita macOS; CI lo cubre en cada push.\n'
fi

printf '\n'
if [ "$fallos" -eq 0 ]; then
    printf '\033[32mTodo en verde: %d comprobaciones.\033[0m\n' "$pasos"
else
    printf '\033[31m%d de %d comprobaciones han fallado.\033[0m\n' "$fallos" "$pasos"
fi
exit "$fallos"
