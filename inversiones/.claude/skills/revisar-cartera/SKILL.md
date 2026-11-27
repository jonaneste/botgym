---
name: revisar-cartera
description: Revisión periódica de la cartera con el MCP cartera-de-valor. Valora las posiciones, revisa la tesis de cada una, propone dónde poner la siguiente aportación respetando concentración y fiscalidad española, y actualiza el panel. Úsala cuando pidan revisar, repasar o actualizar la cartera, decidir qué comprar con dinero nuevo, rebalancear, o apuntar una compra o venta.
---

# Revisar la cartera

Una revisión acaba con decisiones concretas y apuntadas, no con un informe.
Hazla en este orden, y si la persona solo pide una parte, haz solo esa.

## 1. Foto

`ver_cartera`. Cuenta en dos líneas el valor, la plusvalía y lo que más
pesa. Después, las `alertas`:

- **Participaciones estimadas**: pide las reales (en la app del broker, al
  tocar cada posición) y corrígelas en `cartera.json` antes de seguir
  sacando conclusiones de importes.
- **Peso por encima del máximo** (25 % por defecto): es el riesgo principal
  de una cartera pequeña. Di cuánto dinero nuevo haría falta para diluirlo.
- **Diversificación efectiva** por debajo de 5: la cartera depende de una o
  dos empresas aunque tenga más.

## 2. Tesis de cada posición

`cribar` sin argumentos analiza cartera, vigilancia y universo; con
`tickers` solo lo que pases. Para cada posición en cartera, una línea:

> **Adobe** — infravalorada, 98/100. El precio descuenta −3 % anual frente a
> +10 % histórico. Mantener; la tesis falla si los ingresos recurrentes caen
> dos trimestres seguidos.

Si una posición sale «exigente» o con alertas graves, abre la skill
`inversion-en-valor` para ella antes de opinar. Que una acción haya bajado
no es motivo para vender, y que haya subido tampoco: lo es que la tesis se
haya roto o que el precio supere con holgura el valor optimista.

## 3. Dinero nuevo

`proponer_aportacion` con el importe. La herramienta:

- reparte entre las mejor puntuadas que quepan bajo el peso máximo,
- una por sector en cada aportación,
- descarta señales «exigente», «cíclica en pico» y «sin valoración»,
- **nunca propone vender**.

Revisa la propuesta antes de enseñarla: si una candidata tiene una trampa de
valor que la puntuación no ve (declive estructural, por ejemplo), quítala y
dilo. Si la persona va a aportar cada mes, un plan de ahorro periódico suele
ser gratis donde una orden suelta cuesta comisión.

## 4. Vender: solo con la fiscalidad delante

Rebalancear vendiendo tiene coste en España. Antes de sugerir una venta,
explica:

- **Las ganancias tributan** en la base del ahorro: 19 % hasta 6.000 €,
  21 % hasta 50.000 €, 23 % hasta 200.000 €, 27 % hasta 300.000 € y 30 % a
  partir de ahí (tramos vigentes desde 2025). Diluir con aportaciones no
  tributa.
- **FIFO**: Hacienda considera vendidas primero las acciones más antiguas.
  `registrar_operacion` calcula el resultado por precio medio, que es lo que
  enseña el broker; para la declaración vale su informe fiscal.
- **Regla de los dos meses**: si vendes con pérdidas y recompras el mismo
  valor dos meses antes o después, la pérdida no se puede compensar hasta
  que vendas esas nuevas acciones.
- **Las pérdidas compensan ganancias** del mismo año y de los cuatro
  siguientes.
- **Dividendos de EE. UU.**: retención del 15 % allí con el W-8BEN; se
  deduce en la declaración española hasta el límite de lo que tributaría
  aquí.
- **Fondos y acciones no son lo mismo**: el traspaso entre fondos de
  inversión no tributa; entre acciones o ETF, sí.

Si la duda es de cuantía o de situación personal, recomienda un asesor
fiscal en lugar de afinar tú.

## 5. Apuntar

Cuando la persona confirme una operación hecha, `registrar_operacion` con
fecha, participaciones, importe y comisión. Confirma los datos antes de
escribir: la herramienta toca `cartera.json`.

Si cambia la lista de vigilancia, edita `vigilancia` en `cartera.json`.

## 6. Actualizar el panel

La URL del panel está en `cartera.json`, en `panel`. Si existe y tienes las
herramientas `Artifact` y `ArtifactData`:

1. `exportar_panel`. Escribe cinco archivos JSON en `inversiones/panel-datos/`
   y apunta la foto del día en el histórico.
2. Sube cada archivo al panel con `Artifact` (`asset: true`, `url` del panel,
   `file_path` del archivo). Cada subida devuelve una URL `/_blob/…`.
3. Lee `datasets/<id>` del panel con `ArtifactData` y actualízalo con
   `update`: `source.url` a la nueva URL y `updated: {at, by}` con la fecha
   de ahora. Los ids son `resumen`, `posiciones`, `valoracion`, `historico`
   y `alertas`, como los archivos.

Si no hay panel o faltan las herramientas, dilo y deja los archivos
exportados.

## Cierre

Termina con una lista corta: qué se ha decidido, qué queda pendiente (por
ejemplo, poner las participaciones reales) y cuándo conviene la siguiente
revisión: tras los resultados trimestrales de las posiciones o si una cae
más de un 20 % sin noticia que lo explique.
