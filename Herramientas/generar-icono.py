#!/usr/bin/env python3
"""Genera el icono de la app: claro, oscuro y teñido, a 1024x1024.

App Store Connect rechaza cualquier build sin icono de 1024 px, y lo rechaza
despues de subirla: el ciclo de error son diez minutos. El icono se genera aqui
en lugar de guardarlo solo como PNG para que cambiar el color o el trazo sea
editar dos numeros y no abrir un editor de imagenes.

    python3 Herramientas/generar-icono.py

Escribe el PNG a mano, con zlib y struct de la biblioteca estandar, y NO con
Pillow. Pillow no esta instalado en todas partes donde se trabaja este
proyecto, asi que la version anterior no se podia ni ejecutar donde hacia
falta; el icono es una barra con discos, o sea rectangulos redondeados, y eso
no justifica una dependencia.

Los PNG van sin canal alfa a proposito: Apple rechaza los iconos con
transparencia.

Tres variantes, porque desde iOS 18 el sistema pide tambien el icono oscuro y
el tenido, y sin ellas iOS se inventa el oscuro recortando el claro:

  claro   AppIcon-1024.png
  oscuro  AppIcon-1024-oscuro.png   mismo dibujo, fondo mas apagado
  tenido  AppIcon-1024-tenido.png   en gris; el color lo pone el sistema
"""

import struct
import zlib
from pathlib import Path

LADO = 1024

# Cuantas muestras por lado se toman de cada pixel antes de promediar. Es lo
# que suaviza los bordes curvos: sin esto los discos salen con escalones.
MUESTREO = 3

# El azul del AccentColor en claro, y una version mas oscura para el
# degradado. El icono tiene que llevar el color de la app: con el acento azul y
# el icono verde, la pantalla de inicio y la de dentro parecian dos apps.
AZUL = (10, 107, 255)
AZUL_OSCURO = (6, 58, 168)
# El oscuro no es el mismo azul apagado: la HIG pide que el icono oscuro sea
# mas sobrio, y que el fondo de color sea el que mas contraste da.
AZUL_NOCHE = (8, 48, 140)
AZUL_NOCHE_FONDO = (4, 22, 66)
BLANCO = (255, 255, 255)
# El tenido se entrega en gris y el sistema le aplica el color que el usuario
# haya elegido, asi que aqui solo importa la luminosidad.
GRIS_CLARO = (235, 235, 235)
GRIS_FONDO = (60, 60, 60)

CARPETA = (
    Path(__file__).resolve().parent.parent
    / "Entrenos/Assets.xcassets/AppIcon.appiconset"
)

# Geometria de la barra, en fraccion del lado. Compacta y gruesa a proposito:
# la HIG avisa de que los trazos finos pierden nitidez en los tamanos
# pequenos, y a 40 puntos la version anterior -barra de 56 px sobre 1024, y
# 720 px de largo- se quedaba en una raya de tres pixeles de ancho que cruzaba
# el icono de lado a lado. Ahora ocupa el 62 % del ancho y el triple de grosor,
# y por eso se sigue reconociendo en la pantalla de inicio.
MEDIO = LADO / 2
GROSOR_BARRA = LADO * 0.085
LARGO_BARRA = LADO * 0.62
# (distancia al centro, media altura, media anchura) de cada disco. El interior
# mas alto que el exterior, como una barra de verdad.
DISCOS = (
    (LADO * 0.205, LADO * 0.225, LADO * 0.047),
    (LADO * 0.285, LADO * 0.150, LADO * 0.040),
)


def rectangulo_redondeado(x0, y0, x1, y1, radio):
    """Devuelve una prueba de pertenencia para un rectangulo redondeado.

    Se usa como funcion y no se dibuja directamente porque el muestreo
    pregunta por muchos puntos dentro del mismo pixel.
    """

    def dentro(x, y):
        # Se lleva el punto al rectangulo interior, el que queda al descontar
        # el radio por los cuatro lados. Si cae dentro de ese rectangulo
        # pertenece sin mas; si no, lo que decide es la distancia a su esquina
        # mas cercana, que es el centro del arco.
        cx = min(max(x, x0 + radio), x1 - radio)
        cy = min(max(y, y0 + radio), y1 - radio)
        dx = x - cx
        dy = y - cy
        return dx * dx + dy * dy <= radio * radio

    return dentro


def poligono(puntos):
    """Prueba de pertenencia para un poligono, por lanzamiento de rayo.

    Hace falta porque el yunque no se puede componer con rectangulos
    redondeados: tiene un cuerno que se estrecha y una base que se abre, y eso
    son lados inclinados.
    """

    def dentro(x, y):
        # Se cuenta cuantas veces un rayo horizontal hacia la derecha cruza el
        # borde: impar es dentro. El `!=` compara en que lado del rayo queda
        # cada extremo del lado, que es la forma de no contar dos veces los
        # vertices que el rayo roza justo.
        cruces = False
        cuantos = len(puntos)
        j = cuantos - 1
        for i in range(cuantos):
            xi, yi = puntos[i]
            xj, yj = puntos[j]
            if (yi > y) != (yj > y):
                corte = xi + (y - yi) * (xj - xi) / (yj - yi)
                if x < corte:
                    cruces = not cruces
            j = i
        return cruces

    return dentro


def figura_yunque():
    """El yunque de Forja, de una pieza.

    Un yunque y no la mancuerna de siempre: la mancuerna es el icono por
    defecto de cualquier app de gimnasio, y ademas esta app lleva tambien las
    carreras. El yunque dice el nombre, se reconoce por su silueta y no por un
    detalle, y aguanta a 40 puntos porque es una masa compacta y no un trazo.

    Las coordenadas van sobre el lienzo de 1024 y en fraccion para que
    cambiar el tamano del icono no obligue a rehacerlas.
    """
    u = LADO / 1024

    cuerpo = [
        # Cara de arriba, de izquierda a derecha.
        (296 * u, 330 * u),
        (812 * u, 330 * u),
        # Talon: el corte recto de la derecha, con su escalon.
        (812 * u, 398 * u),
        (768 * u, 440 * u),
        (640 * u, 440 * u),
        # Cintura, concava: dos puntos por lado en vez de uno, que es lo que
        # separa un yunque de un reloj de arena.
        (612 * u, 498 * u),
        (600 * u, 566 * u),
        # La base se abre.
        (700 * u, 606 * u),
        (748 * u, 606 * u),
        (748 * u, 694 * u),
        (276 * u, 694 * u),
        (276 * u, 606 * u),
        (324 * u, 606 * u),
        (424 * u, 566 * u),
        (412 * u, 498 * u),
        (384 * u, 440 * u),
        (296 * u, 440 * u),
        # El cuerno, largo y afilado, que es lo que se reconoce de un yunque.
        (150 * u, 396 * u),
        (296 * u, 330 * u),
    ]
    return [poligono(cuerpo)]


def figura_barra():
    """Las pruebas de pertenencia de la barra y sus cuatro discos."""
    piezas = [
        rectangulo_redondeado(
            MEDIO - LARGO_BARRA / 2,
            MEDIO - GROSOR_BARRA / 2,
            MEDIO + LARGO_BARRA / 2,
            MEDIO + GROSOR_BARRA / 2,
            GROSOR_BARRA / 2,
        )
    ]
    for distancia, alto, ancho in DISCOS:
        for signo in (-1, 1):
            x = MEDIO + signo * distancia
            piezas.append(
                rectangulo_redondeado(x - ancho, MEDIO - alto, x + ancho, MEDIO + alto, ancho)
            )
    return piezas


def pintar(color_arriba, color_abajo, color_figura):
    """Degradado vertical con la figura encima, como filas RGB."""
    piezas = figura_yunque()
    paso = 1.0 / MUESTREO
    muestras = [(i + 0.5) * paso for i in range(MUESTREO)]
    total = MUESTREO * MUESTREO

    filas = []
    for y in range(LADO):
        # El degradado se calcula una vez por fila: no varia a lo ancho.
        t = y / (LADO - 1)
        fondo = tuple(
            round(a + (b - a) * t) for a, b in zip(color_arriba, color_abajo)
        )
        fila = bytearray()
        for x in range(LADO):
            cubierto = 0
            for dy in muestras:
                py = y + dy
                for dx in muestras:
                    px = x + dx
                    if any(pieza(px, py) for pieza in piezas):
                        cubierto += 1
            if cubierto == 0:
                fila += bytes(fondo)
            elif cubierto == total:
                fila += bytes(color_figura)
            else:
                # Borde: se mezcla figura y fondo segun cuanto se cubrio.
                peso = cubierto / total
                fila += bytes(
                    round(f + (c - f) * peso) for f, c in zip(fondo, color_figura)
                )
        filas.append(bytes(fila))
    return filas


def escribir_png(destino, filas):
    """Guarda las filas RGB como PNG de 8 bits sin alfa."""

    def trozo(tipo, datos):
        cuerpo = tipo + datos
        return (
            struct.pack(">I", len(datos))
            + cuerpo
            + struct.pack(">I", zlib.crc32(cuerpo) & 0xFFFFFFFF)
        )

    # Cada fila va precedida de su byte de filtro, que aqui es 0: sin filtrar.
    cruda = b"".join(b"\x00" + fila for fila in filas)
    cabecera = struct.pack(">IIBBBBB", LADO, LADO, 8, 2, 0, 0, 0)
    destino.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + trozo(b"IHDR", cabecera)
        + trozo(b"IDAT", zlib.compress(cruda, 9))
        + trozo(b"IEND", b"")
    )


VARIANTES = (
    ("AppIcon-1024.png", AZUL, AZUL_OSCURO, BLANCO),
    ("AppIcon-1024-oscuro.png", AZUL_NOCHE, AZUL_NOCHE_FONDO, BLANCO),
    ("AppIcon-1024-tenido.png", GRIS_FONDO, GRIS_FONDO, GRIS_CLARO),
)


def main() -> None:
    CARPETA.mkdir(parents=True, exist_ok=True)
    for nombre, arriba, abajo, figura in VARIANTES:
        destino = CARPETA / nombre
        escribir_png(destino, pintar(arriba, abajo, figura))
        print(f"escrito {destino.relative_to(Path.cwd())} ({LADO}x{LADO}, sin alfa)")


if __name__ == "__main__":
    main()
