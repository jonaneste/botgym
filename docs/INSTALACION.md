# Instalar Entrenos en el iPhone

## Lo que necesitas

- Un Mac con **Xcode 16 o posterior** (gratis en la Mac App Store).
- El iPhone y su cable.
- Un Apple ID. No hace falta pagar nada para empezar.

## Primera instalación

1. Abre `Entrenos.xcodeproj` haciendo doble clic.
2. En Xcode, menú **Xcode → Settings → Accounts**, pulsa **+**, elige
   *Apple ID* e inicia sesión con tu cuenta.
3. En la barra lateral izquierda pulsa el proyecto **Entrenos** (el icono azul
   de arriba), luego el target **Entrenos**, y ve a la pestaña
   **Signing & Capabilities**.
4. En **Team**, elige tu nombre (aparecerá como *Tu Nombre (Personal Team)*).
5. Conecta el iPhone. Desbloquéalo y pulsa **Confiar** si te lo pregunta.
6. Arriba, donde dice el dispositivo de destino, elige tu iPhone en lugar del
   simulador.
7. Pulsa el botón de **▶ Play** (o ⌘R).

La primera vez el iPhone rechazará la app porque el certificado no es de
confianza. En el iPhone ve a **Ajustes → General → VPN y gestión de
dispositivos**, toca tu Apple ID y pulsa **Confiar**. Vuelve a darle a Play en
Xcode.

## Si el identificador ya está cogido

`com.jonaneste.entrenos` es único en todo el mundo. Si Xcode se queja con
*"failed to register bundle identifier"*, cambia el **Bundle Identifier** en
*Signing & Capabilities* por algo como `com.tunombre.entrenos2` y vuelve a
intentarlo.

## Con cuenta gratuita: caduca cada 7 días

Un Apple ID sin la suscripción de desarrollador firma las apps con un
certificado que dura **7 días**. Pasado ese plazo la app deja de abrirse y hay
que volver a darle a Play en Xcode con el iPhone conectado. **Tus datos no se
pierden** al reinstalar: SwiftData guarda la base de datos en el contenedor de
la app, que sobrevive a la reinstalación mientras no borres la app a mano.

Dos formas de quitarse la molestia:

- **Pagar el Apple Developer Program** (99 €/año): el certificado pasa a durar
  un año, y además desbloquea HealthKit.
- **SideStore o AltStore**: refirman la app solas por WiFi desde el propio
  iPhone, sin tocar el Mac. Siguen usando certificado gratuito, así que no
  habilitan HealthKit, pero evitan el ritual semanal.

## Volcar los errores de compilación a texto

Si algo no compila y quieres pegarme la lista completa de errores, en la
terminal, dentro de la carpeta del proyecto:

```sh
xcodebuild -project Entrenos.xcodeproj -scheme Entrenos \
  -destination 'generic/platform=iOS' build 2>&1 | grep -E 'error:|warning:' | sort -u
```

Y para ejecutar los tests de la lógica, que no necesitan ni simulador ni
dispositivo:

```sh
swift test
```

## Límites de la cuenta gratuita, por si los encuentras

- Máximo **3 apps** instaladas a la vez por este método.
- Máximo **10 identificadores** nuevos por semana.
- Sin HealthKit, iCloud, notificaciones push remotas ni App Groups.
  Las **notificaciones locales** (las del temporizador de descanso) sí
  funcionan: no necesitan ninguna capability.
