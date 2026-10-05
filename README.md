# Entrenos

App nativa de iPhone para registrar entrenos de gimnasio. Uso personal, sin
backend, sin cuentas y sin suscripciones: todo vive en el dispositivo.

Inspirada en Hevy, pero recortada a lo que hace falta y con la progresión
automatizada.

## Estado

| Fase | Contenido | Estado |
|------|-----------|--------|
| 0 | Esqueleto del proyecto, núcleo testeable, documentación | lista y validada en dispositivo |
| 1 | Biblioteca de ejercicios, rutinas, entreno en curso, historial | lista, CI en verde |
| 2 | Doble progresión, récords, gráficas, series semanales | lista, CI en verde |
| 3 | HealthKit, exportación JSON/CSV, importación de rutinas | lista, CI en verde |
| 4 | Apple Salud como centro de datos | lista, CI en verde |
| 5 | Servidor MCP: Claude lee tus datos y te aconseja | **lista, a validar en dispositivo** |

## Stack

- Swift + SwiftUI, iOS 17 o superior
- SwiftData para la persistencia local
- Swift Charts para las gráficas
- HealthKit para leer carreras y escribir los entrenos de fuerza
- Sin dependencias externas

## Estructura

```
Package.swift            Tests de la lógica pura: `swift test`, sin Xcode
Entrenos.xcodeproj       Proyecto de Xcode (escrito a mano, Xcode 16+)
project.yml              Alternativa con XcodeGen, por si el anterior falla
Entrenos/
  Nucleo/                Lógica pura. Solo Foundation. Compila en Linux.
    Modelos/             Tipos valor: Material, TipoRegistro, SerieValor…
    Progresion/          Doble progresión e incrementos de carga
    Records/             1RM estimado (Epley) y récords personales
    Volumen/             Volumen y series semanales por grupo muscular
    JSON/                Esquema de importación y exportación, y CSV
    Salud/               Export de Apple Health y estimación de energía
  Datos/                 Modelos de SwiftData y repositorio
  Vistas/                SwiftUI, una carpeta por pestaña
  Servicios/             HealthKit, notificaciones, exportación
  DatosIniciales/        Semilla: ejercicios y la rutina de 5 días
Tests/                   Tests unitarios del núcleo
mcp/                     Servidor MCP para que Claude lea tus datos
Herramientas/            Scripts de verificación
docs/                    Instalación y esquema JSON
```

### Por qué el núcleo está separado

Toda la lógica que se puede equivocar en silencio —cuándo subir el peso, cuándo
es un récord, cuántas series semanales llevas— vive en `Entrenos/Nucleo` y no
importa nada de Apple. Eso permite dos cosas:

1. Ejecutar los tests con `swift test` en segundos, sin simulador.
2. Que esa lógica se pueda razonar y testear sin base de datos de por medio:
   los modelos de SwiftData se convierten a tipos valor antes de entrar.

`Package.swift` apunta a esa misma carpeta, así que **no hay código
duplicado**: los mismos archivos se compilan dentro de la app y dentro de los
tests.

## Desarrollo

```sh
swift test                             # tests de la lógica
./Herramientas/verificar-nucleo.sh     # el núcleo no depende de Apple
./Herramientas/verificar-predicados.py # los #Predicate compilan
```

### Integración continua

`.github/workflows/compilar.yml` compila la app con `xcodebuild` y ejecuta los
tests en un runner de macOS en cada push y cada pull request. Es el compilador
real del proyecto: el desarrollo se hace desde un contenedor Linux, donde no
existe el SDK de iOS, así que un error de compilación aparece aquí antes de
llegar al iPhone. Los runners de macOS son gratuitos en repositorios
públicos.

## Consejos de Claude sobre tus datos

La app puede volcar un `entrenos.json` en una carpeta de iCloud Drive cada vez
que terminas un entreno. En el Mac, el servidor de [`mcp/`](mcp/README.md) se
lo sirve a Claude por MCP, que puede entonces mirar tu progresión, tus récords
y tu volumen por grupo muscular y darte consejos concretos.

No necesita la capability de iCloud, ni backend, ni credenciales de nada: el
permiso de la carpeta llega por el selector de archivos del sistema, y el
servidor solo lee un archivo local.

```sh
node mcp/prueba.mjs    # 55 comprobaciones, sin instalar nada
```

## Instalación en el iPhone

Ver [docs/INSTALACION.md](docs/INSTALACION.md).
