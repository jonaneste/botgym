# Cartera de valor

Tu cartera de acciones, valorada a diario y analizada con criterios de
inversión en valor por Claude. Sin cuentas, sin suscripciones y sin
conectarse al broker: la cartera es un JSON tuyo, las cuentas de las empresas
salen de la SEC y las cotizaciones de Yahoo.

```
cartera.json ──┐
               ├──► servidor MCP ──► Claude + skills ──► decisiones
SEC · Yahoo · BCE ─┘                         │
                                             └──► panel (artifact de claude.ai)
```

## Qué hace

| Herramienta MCP | Para qué |
|---|---|
| `ver_cartera` | Valor en euros, plusvalía, peso de cada posición, concentración y alertas |
| `analizar_empresa` | PER, EV/EBIT, flujo libre, ROIC, Piotroski, DCF inverso, valor en tres escenarios y trampas de valor |
| `cribar` | Analiza decenas de empresas y las ordena de más a menos infravalorada |
| `proponer_aportacion` | Reparte dinero nuevo sin pasar del peso máximo, una empresa por sector; nunca vende |
| `registrar_operacion` | Apunta compras, ventas y dividendos en `cartera.json` |
| `exportar_panel` | Prepara los datos del panel y guarda la foto del día |

| Skill | Cuándo la usa Claude |
|---|---|
| `inversion-en-valor` | ¿Está barata esta empresa? ¿A qué precio compraría? |
| `revisar-cartera` | Repaso periódico, qué hacer con la próxima aportación, fiscalidad al vender |
| `cazar-infravaloradas` | Ideas nuevas: criba, descarte de trampas y encaje con la cartera |

## Puesta en marcha

Hace falta `node` 18 o posterior. Nada más: no hay `npm install`.

### 1. Tu cartera

```sh
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/Inversiones
cp inversiones/cartera.ejemplo.json \
   ~/Library/Mobile\ Documents/com~apple~CloudDocs/Inversiones/cartera.json
```

En iCloud Drive la puedes abrir y editar desde el iPhone. El servidor la
busca ahí, en `~/Inversiones/cartera.json` y en `inversiones/cartera.json`
(ignorado por git); con `CARTERA_JSON` le das otra ruta.

Cada posición:

```json
{ "nombre": "Microsoft", "ticker": "MSFT", "participaciones": 2, "invertidoEUR": 780.00 }
```

- `ticker`: el de EE. UU. Si cotiza en otra bolsa, el de Yahoo (`SAP.DE`,
  `ASML.AS`) y su archivo en `datos/fundamentales/`.
- `simboloCotizacion`: solo si el precio se tiene que buscar con otro
  símbolo que el ticker.
- `invertidoEUR`: lo que te costó todo, comisiones incluidas.

`reglas` fija el peso máximo por empresa (25 %), la nota mínima para
proponer compra, la orden mínima y la comisión por orden.

### 2. Claude Code

```sh
cd inversiones
claude
```

Al abrirlo en esta carpeta carga solo el servidor (`.mcp.json`) y las tres
skills (`.claude/skills/`). Pídele «revisa mi cartera».

### 3. Claude Desktop

En `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "cartera-de-valor": {
      "command": "node",
      "args": ["/Users/TUUSUARIO/botgym/inversiones/mcp/servidor-inversiones.mjs"]
    }
  }
}
```

Rutas absolutas, y reinicia Claude Desktop. Las skills se suben comprimiendo
cada carpeta de `.claude/skills/` y añadiéndola en la configuración de
Skills de Claude.

### 4. El panel

El panel es un artifact privado de claude.ai con cinco conjuntos de datos:
resumen, posiciones, valoración, histórico y alertas. Para actualizarlo,
pide «actualiza el panel»: la skill `revisar-cartera` exporta los datos con
`exportar_panel`, los sube y apunta la foto del día en el histórico. Guarda
la URL del panel en `cartera.json` como `"panel": "https://claude.ai/artifact/…"`.

## Empresas fuera de EE. UU.

La SEC solo tiene las que cotizan allí. Para el resto,
`datos/fundamentales/<TICKER>.json` con el formato de `FTK.DE.json`:

- cifras en unidades de la moneda, no en millones;
- `ttm` (últimos doce meses), `balance`, `acciones` y, si puedes, `anual`
  con varios ejercicios para que salga el crecimiento;
- `financiera: true` para bancos, aseguradoras y brokers;
- `notas` con la fuente de cada cifra.

Pídeselo a Claude con la skill `inversion-en-valor`: busca el informe anual
y el último trimestral y escribe el archivo con las fuentes.

## Cómo valora

Resumen; la skill `inversion-en-valor` lo explica entero y
`mcp/valoracion.mjs` es la fuente de verdad.

- **Últimos doce meses** con «anual + acumulado del año − acumulado del año
  anterior», porque los 10-Q no traen el cuarto trimestre.
- **Flujo**: libre menos remuneración en acciones. Cuando el capex supera
  1,5 veces la amortización se enseña también el flujo del propietario.
- **DCF inverso**: qué crecimiento anual durante diez años justifica el
  precio, comparado con el histórico de ingresos recortado a 12 %.
- **Valor intrínseco**: deja de crecer / histórico / histórico + 4 puntos,
  descontado al 10 / 9 / 8 % con crecimiento terminal del 2,5 %.
- **Puntuación 0-100** absoluta: 50 % valor, 35 % calidad, 15 % solidez.
- **Señales**: infravalorada, atractiva, en precio, exigente, cíclica en
  pico, sin valoración.

## Límites

- No es asesoramiento financiero. Es una herramienta para pensar mejor tus
  propias decisiones.
- Las cotizaciones de Yahoo salen de un endpoint no documentado. Si deja de
  funcionar, el resto sigue y las cotizaciones caen a la última de la caché.
- La SEC pide identificarse: si rechaza las peticiones, define
  `INVERSIONES_USER_AGENT` con tu nombre y correo.
- Los datos de la SEC llegan con el 10-Q, semanas después de los resultados.
- Caché en `~/.cache/cartera-de-valor/` (`INVERSIONES_CACHE` para otra).

## Pruebas

```sh
node inversiones/mcp/prueba.mjs   # sin red
```
