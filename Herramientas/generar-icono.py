#!/usr/bin/env python3
"""Genera el icono de la app a 1024x1024.

App Store Connect rechaza cualquier build sin icono de 1024 px, y lo rechaza
despues de subirla: el ciclo de error son diez minutos. El icono se genera aqui
en lugar de guardarlo solo como PNG para que cambiar el color o el trazo sea
editar dos numeros y no abrir un editor de imagenes.

    python3 Herramientas/generar-icono.py

El PNG resultante va sin canal alfa a proposito: Apple rechaza los iconos con
transparencia.
"""

from pathlib import Path

from PIL import Image, ImageDraw

LADO = 1024
# El verde del AccentColor en claro, y una version mas oscura para el degradado.
VERDE = (0, 122, 59)
VERDE_OSCURO = (0, 74, 36)
BLANCO = (255, 255, 255)

DESTINO = (
    Path(__file__).resolve().parent.parent
    / "Entrenos/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
)


def fondo() -> Image.Image:
    """Degradado vertical del verde claro al oscuro."""
    imagen = Image.new("RGB", (LADO, LADO))
    lapiz = ImageDraw.Draw(imagen)
    for y in range(LADO):
        t = y / (LADO - 1)
        color = tuple(
            round(claro + (oscuro - claro) * t)
            for claro, oscuro in zip(VERDE, VERDE_OSCURO)
        )
        lapiz.line([(0, y), (LADO, y)], fill=color)
    return imagen


def barra(lapiz: ImageDraw.ImageDraw) -> None:
    """Una barra con dos discos a cada lado, centrada y horizontal."""
    medio = LADO // 2
    grosor_barra = 56
    # Discos: el interior mas alto que el exterior, como una barra de verdad.
    # (distancia al centro, media altura, mitad del ancho)
    discos = [(250, 250, 34), (330, 160, 30)]

    lapiz.rounded_rectangle(
        [medio - 360, medio - grosor_barra // 2, medio + 360, medio + grosor_barra // 2],
        radius=grosor_barra // 2,
        fill=BLANCO,
    )
    for distancia, alto, semiancho in discos:
        for signo in (-1, 1):
            x = medio + signo * distancia
            lapiz.rounded_rectangle(
                [x - semiancho, medio - alto, x + semiancho, medio + alto],
                radius=semiancho,
                fill=BLANCO,
            )


def main() -> None:
    imagen = fondo()
    barra(ImageDraw.Draw(imagen))
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    imagen.save(DESTINO, "PNG")
    print(f"escrito {DESTINO.relative_to(Path.cwd())} ({LADO}x{LADO}, sin alfa)")


if __name__ == "__main__":
    main()
