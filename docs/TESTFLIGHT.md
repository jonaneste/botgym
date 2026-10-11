# Publicar Entrenos en TestFlight

TestFlight instala la app en el iPhone **sin cable y sin que caduque a los 7
días**: se baja desde la app TestFlight como cualquier otra y dura 90 días por
build. Es la vía recomendada, y la única que no obliga a tener el Mac delante
cada semana.

Necesita el **Apple Developer Program**: 99 € al año. Si no lo tienes,
[INSTALACION.md](INSTALACION.md) explica el camino gratuito con el cable.

La subida la hace el repositorio, no tu Mac: el workflow
`.github/workflows/testflight.yml` archiva, firma y sube desde un runner de
macOS de GitHub Actions. Lo que sigue es lo único que no se puede automatizar
porque son cuentas y claves tuyas.

## Lo que tienes que hacer tú, una vez

### 1. Apple Developer Program

En <https://developer.apple.com/programs/enroll/>, con tu Apple ID. Son 99 €
al año y la aprobación tarda entre unas horas y dos días. Al acabar, en
<https://developer.apple.com/account> → *Membership* aparece el **Team ID**:
diez caracteres tipo `A1B2C3D4E5`. Guárdalo.

### 2. Crear la app en App Store Connect

En <https://appstoreconnect.apple.com> → *Apps* → **+** → *Nueva app*:

- **Plataforma**: iOS
- **Nombre**: Entrenos
- **Idioma principal**: Español
- **Bundle ID**: `com.jonaneste.entrenos` (si no aparece en la lista, créalo
  primero en *Certificates, Identifiers & Profiles* → *Identifiers* → **+** →
  *App IDs* → *App*, con ese mismo identificador)
- **SKU**: `entrenos` (es un código interno, da igual cuál)

No hay que rellenar nada de la ficha de la tienda: para TestFlight interno
basta con que la app exista.

### 3. La clave de API

En App Store Connect → *Users and Access* → *Integrations* → *App Store
Connect API* → **+**:

- **Nombre**: `GitHub Actions`
- **Acceso**: **App Manager** (hace falta ese nivel, porque el workflow deja
  que Xcode cree solo el certificado de distribución)

Al crearla te deja descargar un fichero `AuthKey_XXXXXXXXXX.p8` **una única
vez**. Descárgalo y guárdalo. En la misma tabla verás el **Key ID** y, arriba,
el **Issuer ID**.

### 4. Los secretos del repositorio

En <https://github.com/jonaneste/botgym/settings/secrets/actions>, *New
repository secret*, cuatro veces:

| Secreto | Valor |
|---|---|
| `APPLE_TEAM_ID` | el Team ID del paso 1 |
| `APP_STORE_CONNECT_KEY_ID` | el Key ID del paso 3 |
| `APP_STORE_CONNECT_ISSUER_ID` | el Issuer ID del paso 3 |
| `APP_STORE_CONNECT_PRIVATE_KEY` | **el contenido** del `.p8`, pegado entero, con las líneas `-----BEGIN PRIVATE KEY-----` y `-----END PRIVATE KEY-----` incluidas |

El `.p8` es una clave privada: no va al repositorio ni a ningún fichero, solo
ahí.

### 5. Instalar TestFlight en el iPhone

Desde la App Store, se llama **TestFlight**. Entra con el mismo Apple ID de la
cuenta de desarrollador y la app aparece sola cuando la primera build termine de
procesarse.

## Lanzar una subida

Desde <https://github.com/jonaneste/botgym/actions/workflows/testflight.yml> →
*Run workflow*. El campo *notas* es opcional y se ve en TestFlight como «qué
probar».

También sube sola al empujar una etiqueta de versión:

```sh
git tag v1.0 && git push origin v1.0
```

El workflow tarda unos 15 minutos, y procesar la build en App Store Connect
otros 10 ó 15. Luego llega la notificación de TestFlight al iPhone.

El **número de build** lo pone el contador del run de Actions, así que sube solo
y no hay que tocar el proyecto entre subidas. La **versión** sí es manual:
`MARKETING_VERSION` en `Entrenos.xcodeproj` (y en `project.yml`), que ahora está
en `1.0`.

## Si falla

- **«Faltan estos secretos del repositorio»**: falta alguno del paso 4, y el
  mensaje dice cuál.
- **Error de firma al archivar**: casi siempre la clave de API no tiene nivel
  *App Manager*, o el Bundle ID del paso 2 no existe todavía.
- **«The bundle version must be higher than the previously uploaded version»**:
  esa build ya estaba subida. Volver a lanzar el workflow coge el número
  siguiente.
- Cuando el fallo es de `xcodebuild`, el run deja los logs completos como
  artefacto `logs-testflight`.

## La alternativa: el cable y una cuenta gratuita

Sin pagar nada, con el Mac y el iPhone conectado:

```sh
./Herramientas/instalar-en-iphone.sh
```

Instala en un comando, pero la firma de un Apple ID gratuito **caduca a los 7
días** y hay que repetirlo cada semana. Los datos no se pierden al reinstalar.
El detalle está en [INSTALACION.md](INSTALACION.md).
