#!/usr/bin/env python3
"""Comprueba que nadie convierta un `Double` a `Int` con `Int(_:)` a pelo.

`Int(_: Double)` **atrapa** si el valor no es finito o no cabe en `Int64`, y en
Swift una trampa cierra la app en el sitio: no es una excepción que se pueda
capturar. Y los `Double` de esta app vienen de donde no se controla —un peso
que escribe el usuario a mano, un archivo de export de Salud que escribe otra
app— así que el infinito es alcanzable de verdad. Ya pasó: un peso imposible
guardado en una serie dejaba la app cerrándose cada vez que se abría la
pantalla de ese ejercicio.

`LimitesEntrada.entero(_:)` hace la misma conversión sin atrapar.

Se marcan los casos reconocibles leyendo el texto: el argumento redondea, o
acota con `min`/`max`, o es un `Double(...)` explícito. No se puede saber el
tipo de una variable suelta sin compilar, así que esto no lo encuentra todo;
encuentra la forma en la que el fallo se ha escrito siempre.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# Solo la app. En un test, una trampa hace fallar la suite y se ve en el acto;
# en la app cierra el iPhone del usuario sin dejar rastro. Y hay un test que
# compara a propósito las dos conversiones en el peor caso admitido
# (`LimitesEntradaTests.testElVolumenDeUnaSerieAlTopeSigueSiendoConvertible`),
# que es justo lo que este guion marcaría.
CARPETAS = ['Entrenos/**/*.swift']

# `LimitesEntrada` es justo quien tiene que hacer la conversión, después de
# acotar el valor. Es el único sitio donde `Int(_:)` sobre un `Double` está bien.
EXENTOS = {'Entrenos/Nucleo/Modelos/LimitesEntrada.swift'}

# Un argumento que delata un `Double`.
SOSPECHOSO = (
    re.compile(r'\.rounded\s*\('),
    re.compile(r'^\s*(?:min|max)\s*\('),
    re.compile(r'\bDouble\s*\('),
)


def sin_comentarios(texto: str) -> str:
    """Quita comentarios de línea y de bloque.

    Los comentarios de este repo citan `Int(1e300)` y `Int(unDouble)` para
    explicar justo este fallo, y marcarlos sería ruido. Quitar de más solo
    puede hacer que algo pase desapercibido, nunca que se avise en falso.
    """
    texto = re.sub(r'/\*.*?\*/', '', texto, flags=re.DOTALL)
    return re.sub(r'//[^\n]*', '', texto)


def argumentos_de_int(texto: str):
    """Devuelve (linea, argumento) de cada `Int(...)` del archivo."""
    for coincidencia in re.finditer(r'\bInt\s*\(', texto):
        inicio = coincidencia.end() - 1
        profundidad = 0
        for posicion in range(inicio, len(texto)):
            if texto[posicion] == '(':
                profundidad += 1
            elif texto[posicion] == ')':
                profundidad -= 1
                if profundidad == 0:
                    linea = texto.count('\n', 0, coincidencia.start()) + 1
                    yield linea, texto[inicio + 1:posicion]
                    break


def main() -> int:
    fallos = []
    revisados = 0

    archivos = sorted(
        archivo
        for patron in CARPETAS
        for archivo in RAIZ.glob(patron)
    )
    for archivo in archivos:
        relativo = str(archivo.relative_to(RAIZ))
        if relativo in EXENTOS:
            continue
        texto = sin_comentarios(archivo.read_text(encoding='utf-8'))
        if 'Int(' not in texto:
            continue
        for linea, argumento in argumentos_de_int(texto):
            revisados += 1
            if any(patron.search(argumento) for patron in SOSPECHOSO):
                resumen = ' '.join(argumento.split())
                if len(resumen) > 60:
                    resumen = resumen[:57] + '...'
                fallos.append(
                    f"{relativo}:{linea}: Int({resumen}) convierte un Double. "
                    f"Usa LimitesEntrada.entero(_:)."
                )

    if fallos:
        print("FALLO: conversiones a Int que pueden atrapar.\n", file=sys.stderr)
        for fallo in fallos:
            print(f"  {fallo}", file=sys.stderr)
        print(
            "\n`Int(_: Double)` atrapa con un valor no finito o fuera de Int64, "
            "y eso\ncierra la app sin poder capturarlo. "
            "Ver Entrenos/Nucleo/Modelos/LimitesEntrada.swift.",
            file=sys.stderr,
        )
        return 1

    print(f"OK: {revisados} conversiones a Int, ninguna sobre un Double sin acotar.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
