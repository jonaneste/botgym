#!/usr/bin/env python3
"""Comprueba que ningún `#Predicate` capture un acceso a miembro.

`#Predicate` es un macro puramente sintáctico: no tiene información de tipos,
así que convierte cualquier cadena `Algo.otro` en un key path del modelo. Esto:

    #Predicate<Entreno> { $0.estadoRaw == EstadoEntreno.finalizado.rawValue }

se expande a `keyPath: \\.finalizado` y no compila. Solo los identificadores
simples se capturan como valor, así que el valor hay que sacarlo antes a una
constante o a una variable local.

Es un error que solo aparece al compilar con el SDK de iOS, y este proyecto se
desarrolla desde Linux. De ahí este lint.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
# Tipo en mayúscula seguido de punto y un miembro: `EstadoEntreno.finalizado`.
MIEMBRO = re.compile(r'\b([A-Z][A-Za-z0-9_]*)\.([a-z][A-Za-z0-9_]*)')


def cuerpos_de_predicado(texto: str):
    """Devuelve (linea, cuerpo) de cada closure de #Predicate del archivo."""
    for coincidencia in re.finditer(r'#Predicate(?:<\w+>)?\s*\{', texto):
        inicio = coincidencia.end() - 1
        profundidad = 0
        for posicion in range(inicio, len(texto)):
            if texto[posicion] == '{':
                profundidad += 1
            elif texto[posicion] == '}':
                profundidad -= 1
                if profundidad == 0:
                    linea = texto.count('\n', 0, coincidencia.start()) + 1
                    yield linea, texto[inicio + 1:posicion]
                    break


def main() -> int:
    fallos = []
    revisados = 0

    for archivo in sorted(RAIZ.glob('Entrenos/**/*.swift')):
        texto = archivo.read_text(encoding='utf-8')
        if '#Predicate' not in texto:
            continue
        for linea, cuerpo in cuerpos_de_predicado(texto):
            revisados += 1
            limpio = re.sub(r'\$0\.\w+', '', cuerpo)
            for tipo, miembro in MIEMBRO.findall(limpio):
                fallos.append(
                    f"{archivo.relative_to(RAIZ)}:{linea}: el predicado captura "
                    f"«{tipo}.{miembro}». Sácalo antes a una constante."
                )

    if fallos:
        print("FALLO: predicados con acceso a miembro.\n", file=sys.stderr)
        for fallo in fallos:
            print(f"  {fallo}", file=sys.stderr)
        print(
            "\n`#Predicate` lo convertiría en un key path del modelo y no "
            "compilaría.\nVer el comentario de rawEntrenoEnCurso en "
            "Entrenos/Datos/Entreno.swift.",
            file=sys.stderr,
        )
        return 1

    print(f"OK: {revisados} predicados, todos capturan solo identificadores simples.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
