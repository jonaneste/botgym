# Cartera de valor

Herramienta personal para llevar la cartera de acciones y analizarla con
criterios de inversión en valor. Es un proyecto aparte de la app Entrenos que
comparte repositorio: no toca nada fuera de `inversiones/` salvo el paso de
verificación en `Herramientas/verificar.sh` y en CI.

El [README](README.md) explica cómo se instala y se usa. Esto es lo que hay
que saber antes de tocar código.

## Reglas que no se pueden romper

**La cartera real no se versiona.** El repositorio es público. `cartera.json`
y `panel-datos/` están en `.gitignore`; solo se sube `cartera.ejemplo.json`
con datos inventados y empresas que no son las de la persona. Tampoco van al
repo la URL del panel ni importes reales en tests, commits o PR.

**No se conecta a ningún broker.** No hay API pública de Trade Republic: las
que circulan son de ingeniería inversa, piden las credenciales y violan sus
condiciones. La cartera es un JSON que se edita a mano o con
`registrar_operacion`. No se piden ni se guardan credenciales de nada.

**No se inventan cifras.** Si falta un dato, la métrica sale `null` y se dice
por qué. Los archivos de `datos/fundamentales/` llevan una nota con la fuente
de cada cifra, y cualquier supuesto elegido a mano dice que lo es.

**Sin dependencias.** Solo `node` 18 o posterior. Nada de `npm install`.

**Las pruebas no usan la red.** `mcp/fixtures/` tiene recortes reales de la
SEC; los casos nuevos se construyen a mano en `prueba.mjs`.

## Trampas de los datos que ya han mordido

Cada una tiene su prueba en `mcp/prueba.mjs`.

- **Splits.** La SEC guarda cada ejercicio como se presentó por última vez:
  los recientes vienen reexpresados y los antiguos no. El 10 por 1 de KLA
  parecía una emisión del 900 %. `ajustarSplits` lo deshace en la serie, y
  los splits de Yahoo posteriores a la portada ajustan el número de acciones.
- **Etiquetas abandonadas.** KLA dejó `OperatingIncomeLoss` en 2015, y como
  era su única etiqueta de EBIT salía «la más reciente». Un TTM que acaba más
  de 200 días antes del balance se descarta.
- **Portadas viejas.** Comcast dejó de servir `EntityCommonStockSharesOutstanding`
  sin dimensión en 2009. Una portada de más de 200 días no vale.
- **`LongTermDebt` no significa lo mismo en todas.** En NVIDIA incluye la
  parte corriente y en Adobe no. Si no hay no corriente explícita se suma la
  corriente: se prefiere sobrestimar deuda.
- **Sin resultado operativo.** Zoetis no publica `OperatingIncomeLoss`; el
  EBIT se aproxima con antes de impuestos más intereses y sale una alerta.
- **Cíclicas.** Un margen que sube desde pérdidas (Uber) no es un ciclo; lo
  es uno que cae desde un pico con beneficio, o dos caídas de ingresos de
  más del 15 %. La pandemia sola no cuenta.

## Criterios de valoración

Están en `mcp/valoracion.mjs` y la skill `inversion-en-valor` los explica.
Si cambias uno, cambia también la skill y el texto `como` de la puntuación:
Claude razona con lo que dice la skill, no con el código.

- Flujo que se valora: libre menos remuneración en acciones (conservador).
  El flujo del propietario se enseña al lado cuando el capex supera 1,5
  veces la amortización.
- DCF a 10 años, descuento 9 %, terminal 2,5 %, crecimiento base = el menor
  de los crecimientos de ingresos a 3 y 5 años, recortado a [−5 %, 12 %].
- Escenario pesimista = deja de crecer.
- La propuesta de aportación nunca vende.

## Cómo verificar

```sh
node inversiones/mcp/prueba.mjs     # sin red, en segundos
./Herramientas/verificar.sh         # todo el repo
```

Con red, una prueba de humo real:

```sh
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"analizar_empresa","arguments":{"ticker":"ADBE"}}}' \
  | node inversiones/mcp/servidor-inversiones.mjs
```

Detrás de un proxy (un contenedor en la nube), `fetch` de Node no lo usa por
defecto: `NODE_USE_ENV_PROXY=1`.

## Convenciones

Como el resto del repo: identificadores, comentarios, commits y PR en
español, y los comentarios explican el porqué.
