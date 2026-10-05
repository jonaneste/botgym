# Servidor MCP de Entrenos

Expone tu historial de entrenamiento a Claude para que pueda leerlo y darte
consejos, sin subir nada a ningún servidor y sin pedir credenciales de nada.

```
app Entrenos (iPhone) ──► entrenos.json en iCloud Drive ──► tu Mac ──► este MCP ──► Claude
```

## Qué hace falta

- `node` (versión 18 o posterior). Nada más: **el servidor no tiene
  dependencias**, así que no hay `npm install`.
- Que la app haya escrito el `entrenos.json`. En la app: **Ajustes → Exportar,
  importar y Salud → Carpeta para Claude**, y eliges una carpeta de iCloud
  Drive. A partir de ahí escribe sola cada vez que terminas un entreno.

## Probarlo

```sh
ENTRENOS_JSON=~/Library/Mobile\ Documents/com~apple~CloudDocs/Entrenos/entrenos.json \
  node mcp/servidor-entrenos.mjs
```

Se queda esperando, que es lo correcto: habla por stdin/stdout. Para
comprobar que responde, sin instalar nada:

```sh
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | ENTRENOS_JSON=mcp/ejemplo/entrenos.json node mcp/servidor-entrenos.mjs
```

Si no le pasas `ENTRENOS_JSON`, busca por su cuenta en
`~/Library/Mobile Documents/com~apple~CloudDocs/Entrenos/entrenos.json` y en
algunos sitios más.

## Conectarlo a Claude Desktop

Edita `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "entrenos": {
      "command": "node",
      "args": ["/Users/TUUSUARIO/botgym/mcp/servidor-entrenos.mjs"],
      "env": {
        "ENTRENOS_JSON": "/Users/TUUSUARIO/Library/Mobile Documents/com~apple~CloudDocs/Entrenos/entrenos.json"
      }
    }
  }
}
```

Rutas **absolutas**, y reinicia Claude Desktop.

## Conectarlo a Claude Code

```sh
claude mcp add entrenos -- node /ruta/a/botgym/mcp/servidor-entrenos.mjs
```

## Herramientas que expone

| Herramienta | Para qué |
|---|---|
| `resumen_general` | Visión de conjunto: cuántos entrenos, desde cuándo, volumen total |
| `resumen_semanal` | Semana a semana: series, volumen, series por grupo muscular, km |
| `historial_ejercicio` | Todas las sesiones de un ejercicio con su 1RM estimado |
| `records` | Peso máximo, mejor 1RM y mejor volumen por ejercicio, con fechas |
| `ultimos_entrenos` | Las últimas sesiones con series, RIR, notas y molestias |
| `rutinas` | Lo planificado, para comparar con lo que de verdad se hizo |
| `carreras` | Carreras con ritmo y pulso, y resumen semanal |

Son consultas estructuradas y no el archivo entero a propósito: así Claude
puede preguntar «¿cómo va mi press banca?» sin tragarse dos años de series.

## Cómo pedirle consejo

Una vez conectado, basta con hablarle normal. Algunos arranques que funcionan:

> Mira mi resumen semanal de las últimas 8 semanas. ¿Hay algún grupo muscular
> que esté descuidando o alguno con demasiado volumen?

> ¿Cómo va mi progresión en press banca? ¿Debería subir peso o seguir sumando
> repeticiones?

> Repasa mis últimos 3 entrenos y la molestia de hombro que anoté. ¿Ves algún
> patrón entre los ejercicios que hago y cuándo me duele?

> Compara mis rutinas con lo que de verdad hago. ¿Hay ejercicios que me salto
> siempre o series que nunca completo?

## Y las carreras, ¿qué?

Las carreras están en Zepp. Hay tres caminos y ninguno es perfecto:

1. **Zepp → Apple Salud → export XML → importar en la app.** Oficial en los
   dos saltos y **sin credenciales**, pero manual: hay que exportar desde
   Salud cada pocas semanas. Es lo que la app ya soporta, y así las carreras
   salen en este mismo `entrenos.json`.

2. **Un MCP de Zepp, en paralelo a este.** Lo más cómodo: Claude lee las
   carreras directamente, sin pasos manuales. Hay varios de comunidad
   ([amazfit-mcp](https://github.com/fjuliofontes/amazfit-mcp),
   [zepp-mcp](https://github.com/DhavalBhimani44/zepp-mcp),
   [frankherchet/zepp-mcp](https://github.com/frankherchet/zepp-mcp)), pero
   **todos envuelven endpoints de ingeniería inversa y piden tu token o
   contraseña de Zepp**. No están auditados aquí; revísalos tú antes de darles
   tu cuenta. Con MCP puedes tener los dos servidores a la vez y Claude ve
   ambos.

3. **La exportación oficial de Zepp no sirve** para esto: el archivo del
   «Export data» de su página de privacidad **no incluye los
   entrenamientos**. Las carreras solo se pueden sacar una a una en `.gpx`.

La opción 1 es la única sin ceder credenciales. La 2 es la cómoda. Es tu
decisión, no la mía.

## Privacidad

Este servidor **lee un archivo local y nada más**: no hace peticiones de red,
no guarda nada aparte de una caché en memoria, y no tiene credenciales de
ningún servicio. Todo ocurre en tu Mac.
