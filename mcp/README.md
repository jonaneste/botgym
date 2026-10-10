# Servidor MCP de Entrenos

Expone tu historial de entrenamiento a Claude para que pueda leerlo y darte
consejos, sin subir nada a ningún servidor y sin pedir credenciales de nada.

```
app Entrenos (iPhone) ──► entrenos.json en iCloud Drive ──► tu Mac ──► este MCP ──► Claude
                     ◄── rutinas-de-claude/*.json ◄────────────────────────────────┘
```

La carpeta va en las dos direcciones. Claude lee tu historial, y cuando le
pides una rutina la deja escrita en `rutinas-de-claude/` dentro de esa misma
carpeta: en el teléfono aparece en **Datos → Rutinas de Claude** y se añade de
un toque, sin copiar ni pegar nada. Nada entra en la app hasta que lo
confirmas en la pantalla de siempre, y el historial no se toca nunca.

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
| `ejercicios` | La biblioteca: grupo muscular, material y tipo de registro |
| `objetivos` | Tus objetivos semanales por grupo, con lo hecho y lo que falta |
| `proponer_rutina` | **Escribe** una rutina en la carpeta, para importarla en la app |
| `propuestas_pendientes` | Qué propuestas están esperando a importarse |

Son consultas estructuradas y no el archivo entero a propósito: así Claude
puede preguntar «¿cómo va mi press banca?» sin tragarse dos años de series.

### La única que escribe

`proponer_rutina` es la única herramienta que no es de lectura, y lo único que
hace es dejar un archivo en `rutinas-de-claude/`:

- **No modifica la app.** Lo escrito no es una rutina todavía: es una
  propuesta. Entra cuando la confirmas en el teléfono, en la pantalla de
  importar de siempre, con sus ejercicios desconocidos y todo.
- **Se valida aquí**, con los mismos límites que la app (series de 1 a 20,
  descanso de 0 a 1800 s, rangos como `"8-10"` o `"30-45s"`). Un error se ve
  en la conversación y no con el móvil en la mano.
- **Dice qué ejercicios no tienes.** Uno que no esté en tu biblioteca la app lo
  crea al importar, pero sin grupo muscular ni material, porque adivinarlos
  falsearía el recuento semanal en silencio. La respuesta los lista para que
  Claude te lo advierta antes.
- **Para corregir una propuesta**, se vuelve a llamar con el mismo
  `nombre_archivo` que devolvió `propuestas_pendientes`: así se reemplaza en
  lugar de acumular dos.

Al importarla, la app aparta el archivo a `rutinas-de-claude/importadas/` en
vez de borrarlo, así que `propuestas_pendientes` deja de verla y el original
sigue ahí.

Si quieres el buzón en otra carpeta, pásala en `ENTRENOS_RUTINAS_DIR`. Por
defecto es la de `entrenos.json`, que es la que la app ya tiene permiso para
leer.

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

> Mi hombro viene molestando. Hazme una rutina de empuje que lo cuide, con los
> ejercicios que ya tengo en la app, y déjamela puesta para importar.

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

Este servidor **no hace peticiones de red y no tiene credenciales de ningún
servicio**. Lee el `entrenos.json` de tu carpeta y, con `proponer_rutina`,
escribe archivos dentro de `rutinas-de-claude/` en esa misma carpeta: nada
más, y nada fuera de ahí. El nombre del archivo se sanea, así que una ruta con
`../` no escribe en otro sitio. Todo ocurre en tu Mac.
