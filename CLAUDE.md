# Entrenos

App nativa de iPhone para registrar entrenos de gimnasio. Uso personal: sin
backend, sin cuentas y sin suscripciones. Todo vive en el dispositivo, y un
`entrenos.json` opcional en iCloud Drive es lo que el servidor de `mcp/` sirve
a Claude para dar consejos.

El [README](README.md) explica la estructura. Esto es lo que hay que saber
**antes de tocar código**, porque son decisiones que ya costaron un fallo.

## Reglas que no se pueden romper

**No añadas la entitlement de HealthKit al `project.pbxproj`.** Con un Apple ID
gratuito, Xcode no puede firmar un target que la lleve, así que la app dejaría
de instalarse *entera* y no solo la parte de Salud. Las descripciones de uso
del `Info.plist` sí tienen que estar, porque sin ellas el sistema mata la app al
pedir permiso. Todo lo de HealthKit va detrás de un interruptor apagado por
defecto. Activarlo con cuenta de pago es marcar una casilla en Xcode;
`docs/INSTALACION.md` lo explica.

**`Entrenos/Nucleo` solo importa Foundation.** Ni SwiftUI, ni SwiftData, ni
HealthKit. Es lo que permite correr los tests en segundos y en Linux.
`Herramientas/verificar-nucleo.sh` falla si se cuela algo. Los modelos de
SwiftData se convierten a tipos valor (`SerieValor`, `SesionEjercicio`) antes
de entrar ahí.

**`#Predicate` es un macro puramente sintáctico.** No tiene información de
tipos, así que convierte *cualquier* cadena de acceso a miembro en un key path
del modelo:

```swift
// error: key path cannot refer to enum case 'finalizado'
#Predicate<Entreno> { $0.estadoRaw == EstadoEntreno.finalizado.rawValue }

// bien: solo los identificadores simples se capturan como valor
#Predicate<Entreno> { $0.estadoRaw == rawEntrenoFinalizado }
```

Fue el único error de compilación en las primeras 4.600 líneas.
`Herramientas/verificar-predicados.py` lo detecta; está verificado
reintroduciendo el error original.

**Nunca `Int(unDouble)` a pelo.** Convertir un `Double` que no cabe en `Int64`,
o que es infinito, **atrapa**: en Swift eso cierra la app y no se puede
capturar. Los pesos los escribe el usuario a mano y el volumen es peso ×
repeticiones, así que hereda cualquier valor absurdo. Usa
`LimitesEntrada.entero(_:)`, y recorta la entrada en el campo con
`LimitesEntrada.peso(_:)`.

**No mutes una relación de SwiftData mientras la iteras.** Copia a un `Array`
ordenado primero y borra después. Al revés, el recorrido se corrompe a mitad.

**Toda URL que venga del selector de archivos se usa dentro del ámbito de
seguridad.** Incluido `bookmarkData()`, que si no falla con el error 257. Esa
línea fuera de sitio dejó inalcanzable la carpeta para Claude entera, y el
resto de usos del repo sí lo envolvían: es un fallo fácil de repetir.

**En una clase `@MainActor`, `Task { }` hereda el aislamiento.** No sirve para
sacar trabajo del hilo principal; solo lo aplaza al siguiente turno. Para
sacarlo de verdad hace falta `Task.detached` y, si es un miembro estático de
una clase `@MainActor`, marcarlo `nonisolated` — el atributo de la clase
alcanza también a los estáticos.

**Los enums se persisten como `String` crudo** con un accesor calculado encima,
porque en iOS 17 SwiftData no filtra ni ordena de forma fiable por propiedades
de tipo enum.

**`EjercicioEntreno` copia los objetivos de la rutina, no los referencia.**
Cambiar un rango de 8-10 a 6-8 no puede reescribir el historial de los meses
anteriores. También denormaliza `idEjercicio`, `fechaEntreno` y
`entrenoFinalizado`: "lo que hice la última vez" tiene que ser una consulta
directa, porque en iOS 17 un `#Predicate` que atraviesa una relación puede
petar en ejecución.

**El orden de las relaciones a muchos es explícito** (`orden: Int`) y se ordena
en Swift: SwiftData no conserva el orden de inserción.

**Nada identifica por fecha.** Todos los ejercicios de un entreno comparten
`fechaEntreno`, así que usar la fecha como identidad en un `ForEach` o un
`Chart` hace desaparecer filas en silencio.

## Cómo verificar

```sh
./Herramientas/verificar.sh      # todo: lints, tests del núcleo y del MCP
```

Con Xcode presente añade también la compilación de iOS. Por separado:

```sh
swift test                              # tests del núcleo, sin simulador
node mcp/prueba.mjs                     # protocolo y agregados del MCP
./Herramientas/verificar-nucleo.sh
./Herramientas/verificar-predicados.py
```

**Sin Xcode, CI es el único compilador del proyecto.** El desarrollo se ha
hecho desde un contenedor Linux sin SDK de iOS, así que
`.github/workflows/compilar.yml` corre en cada push a cualquier rama y es donde
aparece un error antes de llegar al iPhone. Si estás en un sitio sin
compilador: lee tu propio diff como si fueras el compilador antes de empujar,
porque cada push fallido es un ciclo de diez minutos.

## Convenciones

Identificadores, interfaz, comentarios, mensajes de commit y descripciones de
PR **en español**. Los comentarios explican el *por qué*, no el qué: si un
comentario se puede deducir de la línea de abajo, sobra.

La interfaz tiene que servir con el móvil en el banco y una mano: botones
grandes, teclado numérico, y copiar el peso de la serie anterior de un toque.

Un entreno a medias no se puede perder. Vive en SwiftData desde el primer
instante y se escribe serie a serie; el fin del descanso se guarda **como
fecha** y no como cuenta atrás, para que siga contando bien tras cerrar y
reabrir la app.

## Lo que no se hace

**No se escribe un cliente de la API de Zepp.** No hay API pública: las rutas
que existen son de ingeniería inversa, piden las credenciales del usuario,
violan sus condiciones y se rompen al primer cambio. Las carreras entran por
Apple Salud. Y no se piden ni se guardan credenciales de Zepp en ningún sitio.

**No se inventan datos de salud.** La estimación de calorías está apagada por
defecto y sin peso corporal no estima nada. Un ejercicio creado al importar una
rutina no adivina grupo muscular ni material: una suposición mala falsearía el
recuento semanal en silencio.

## Si esta sesión corre en el Mac

Entonces puedes hacer lo que una sesión en la nube no: `xcodebuild` de verdad,
compilar firmada e instalar en el iPhone conectado.

```sh
./Herramientas/instalar-en-iphone.sh
```

Hace todo el lado del Mac sin abrir Xcode y explica qué hacer en cada fallo que
sabe reconocer. `docs/INSTALACION.md` tiene el camino manual y los límites de la
cuenta gratuita.

Lo que hay que comprobar en el dispositivo, en este orden, porque CI no lo
alcanza:

1. **Matar la app a mitad de una serie** y reabrirla: el entreno se tiene que
   reanudar con el temporizador de descanso contando bien.
2. **Reabrir la app y pulsar «Volcar ahora»** en Datos: confirma que el permiso
   de la carpeta sobrevive al reinicio. Ese arreglo se hizo leyendo código y no
   se ha ejecutado nunca.
3. **La notificación de fin de descanso con la pantalla bloqueada.**
4. Que las gráficas se lean en una pantalla de móvil y que el aviso de récord
   no tape la serie que acabas de marcar.
