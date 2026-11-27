---
name: cazar-infravaloradas
description: Busca las acciones más infravaloradas de un universo de empresas con el MCP cartera-de-valor y separa las oportunidades de las trampas de valor. Úsala cuando pidan ideas de inversión, qué acciones están baratas, una criba o screener, candidatas para la lista de vigilancia, o alternativas a una posición.
---

# Cazar infravaloradas

La criba encuentra lo que está barato según las cuentas. Casi todo lo que
está muy barato lo está por una razón; la parte que vale es descartar bien.

## 1. Criba

`cribar`. Sin `tickers` usa la cartera, la vigilancia y `universo.json`
(unas setenta empresas grandes de EE. UU. de todos los sectores). Si la
persona quiere otro terreno, pásale la lista. Si la respuesta trae
`pendientes`, vuelve a llamar: lo descargado queda en caché.

Quédate con las que tengan puntuación ≥ 70 y señal «infravalorada» o
«atractiva». Aparta:

- «cíclica en pico»: barata sobre beneficios que no se repetirán;
- «sin valoración»: flujo libre negativo, a menudo por inversión masiva;
  mira `flujoPropietario` antes de descartarla del todo;
- cualquiera con deuda neta > 3× EBITDA, salvo que la persona pida riesgo.

## 2. Agrupa por motivo

Antes de mirar empresa a empresa, mira si las baratas comparten causa. Si
salen cinco empresas de software a la vez, la pregunta no es cuál es la mejor
sino si el mercado tiene razón sobre el sector. Esa respuesta vale para todas
y evita meter la misma apuesta cinco veces.

## 3. A fondo, las cinco mejores

Para cada una, la skill `inversion-en-valor`: por qué está barata, trampas,
precio con margen. Resume en una tabla:

| Empresa | Señal | Puntuación | Crec. implícito vs histórico | Margen base | Por qué está barata | ¿Trampa? |
|---|---|---|---|---|---|---|

## 4. Encaje con la cartera

Con `ver_cartera`:

- ¿Repite sector o motivo con lo que ya hay? Una cartera con NVIDIA y tres
  empresas de software no está diversificada aunque tenga cuatro nombres.
- ¿Cabe bajo el peso máximo con la próxima aportación?
- ¿Cotiza en dólares? Toda la exposición al dólar sube o baja junta.

## 5. Propón

Hasta tres candidatas para `vigilancia` en `cartera.json`, cada una con su
tesis en una frase y el precio por debajo del cual compraría. No las añadas
sin que la persona diga que sí.

## Límites que hay que decir

- Solo empresas de EE. UU. de forma automática. Las europeas necesitan su
  archivo en `datos/fundamentales/`.
- Bancos y aseguradoras se valoran distinto; compáralas entre sí.
- La puntuación es absoluta y mecánica: sirve para ordenar, no para decidir.
