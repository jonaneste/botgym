---
name: inversion-en-valor
description: Analiza una empresa con criterios de inversión en valor (margen de seguridad, calidad, expectativas implícitas en el precio, trampas de valor) usando el MCP cartera-de-valor. Úsala cuando pregunten si una acción está barata o cara, si comprar, mantener o vender una empresa concreta, qué vale, o por qué ha caído, y antes de recomendar cualquier compra.
---

# Inversión en valor: analizar una empresa

Lo que la herramienta calcula es el punto de partida, no el veredicto. Tu
trabajo es explicar los números, buscar por qué el mercado ve otra cosa y
decir en qué condiciones compensa comprar. Las cifras salen de las cuentas
oficiales; las conclusiones son tuyas y tienen que poder discutirse.

## Reglas

- **No inventes cifras.** Cada número que des sale de una herramienta, de un
  documento que hayas leído en esta conversación o de una búsqueda que cites.
  Si falta algo, dilo y explica qué cambiaría.
- **Fecha y fuente siempre.** «PER 12,5 con el precio del 27-11-2026 y las
  cuentas a 28-08-2026 (SEC)». Los datos de la SEC llegan con el 10-Q, que
  sale semanas después de los resultados: si la empresa ya ha presentado
  resultados en un 8-K, búscalo y dilo.
- **Sin certezas.** Es análisis para que la persona decida, no una
  recomendación profesional. Dilo una vez y no lo repitas en cada párrafo.
- **Precio de compra, no «compra».** Termina con a qué precio tendría margen
  de seguridad y qué tendría que pasar para que la tesis fallase.

## Pasos

1. `analizar_empresa` con el ticker. Para empresas de fuera de EE. UU.
   necesita `datos/fundamentales/<TICKER>.json` (ver más abajo).
2. Lee la salida en este orden:
   - `alertas`: lo primero. Una sola puede invalidar todo lo demás.
   - `expectativas`: qué crecimiento descuenta el precio frente al que la
     empresa ha conseguido. Es lo más útil del análisis.
   - `valorIntrinseco`: tres escenarios. El pesimista es «deja de crecer».
     Si el precio está por debajo del pesimista, el mercado descuenta un
     declive y hay que averiguar si tiene razón.
   - `calidad` y `solidez`: ROIC, márgenes, Piotroski, deuda.
   - `puntuacion` y `senal`: resumen mecánico, nunca la conclusión.
3. Averigua **por qué está barata**. Busca noticias, resultados recientes y
   la guía de la empresa. Si no encuentras la razón, no has terminado: el
   mercado casi nunca regala nada sin motivo.
4. Pasa la lista de trampas de valor (abajo).
5. Escribe la ficha.

## Cómo leer cada pieza

| Campo | Qué es | Cuidado con |
|---|---|---|
| `multiplos.evEbit` | Precio del negocio entero sobre su beneficio operativo | Menos de 10 suele ser barato; en cíclicas en pico, engaña |
| `multiplos.rentabilidadFclPct` | Flujo libre menos remuneración en acciones, sobre capitalización | Si el capex es de crecimiento, sale deprimido: mira `flujoPropietario` |
| `calidad.roicPct` | Rentabilidad del capital invertido | Sale `null` si el capital invertido es casi cero o negativo (recompras); no es malo |
| `calidad.piotroski` | 9 comprobaciones de que el negocio mejora | Compara los dos últimos ejercicios; un año extraordinario lo hunde |
| `expectativas.crecimientoImplicitoPct` | Crecimiento anual del flujo durante 10 años que justifica el precio | Compáralo con el histórico y con lo que dice la empresa |
| `valorIntrinseco` | DCF a 10 años con descuento 9 % y crecimiento terminal 2,5 % | Muy sensible al crecimiento: cambia `crecimientoBasePct` y enseña el rango |
| `flujoPropietario` | Valoración dando por buena la inversión por encima de la amortización | Es la tesis optimista sobre ese capex |

Para discutir una hipótesis, vuelve a llamar a `analizar_empresa` con otros
`crecimientoBasePct`, `tasaDescuentoPct` o `crecimientoTerminalPct` y enseña
la diferencia. Si la empresa ha dado una guía de crecimiento, úsala como uno
de los escenarios y dilo.

## Trampas de valor

Antes de llamar «infravalorada» a una empresa, comprueba cada una:

1. **Cíclica en pico.** Márgenes en máximos de varios años (memoria,
   petróleo, química, transporte). El PER bajo es el aviso, no la
   oportunidad. Normaliza con el margen medio del ciclo.
2. **Negocio en declive estructural.** El precio está por debajo del
   escenario «deja de crecer» porque el mercado espera que decrezca.
   Pregunta qué tecnología o competidor le está quitando clientes y si los
   ingresos recientes ya lo muestran.
3. **Beneficio que no es caja.** Flujo operativo por debajo del beneficio
   varios años seguidos, o ganancias no operativas (venta de negocios,
   revalorización de participadas) inflando el PER.
4. **Dilución.** Acciones creciendo más de un 2 % al año, o remuneración en
   acciones que se come más de un cuarto del flujo libre.
5. **Deuda.** Más de 3 veces EBITDA en un negocio cíclico es peligroso;
   mira vencimientos si la cobertura de intereses baja de 4.
6. **Datos viejos o raros.** Una cifra que salta un orden de magnitud entre
   años suele ser un split, una escisión o una etiqueta mal puesta. Revisa
   antes de concluir.

## Financieras

Bancos, aseguradoras y brokers (SIC 6000-6799) salen con `tipo: financiera`:
sin EV, sin deuda neta y valorados por beneficio. Mira PER, precio sobre
valor contable y ROE, y pregunta cuánto del beneficio depende de los tipos de
interés.

## Empresas fuera de EE. UU.

La SEC solo tiene empresas que cotizan allí. Para el resto crea
`inversiones/datos/fundamentales/<TICKER>.json` con el formato de
`FTK.DE.json`: cifras en unidades (no millones), `moneda`,
`simboloCotizacion` de Yahoo, `fechaBalance` y **una nota por cifra con su
fuente**. Busca el informe anual y el último trimestral de la propia empresa;
si solo encuentras agregadores, dilo en las notas. Si no hay serie anual para
calcular el crecimiento, pon `supuestos.crecimientoBase` y explica por qué.

## Ficha

```
## <Empresa> (<ticker>) — <señal>, <puntuación>/100

Precio <x> (<fecha>) · cuentas a <fecha> (<fuente>)

**Qué descuenta el precio:** crecimiento implícito <x> % frente a <y> % histórico.
**Valor:** pesimista <a> · base <b> · optimista <c>. Margen de seguridad base <m> %.
**Calidad:** ROIC <r> %, margen bruto <g> %, Piotroski <p>/9, deuda neta/EBITDA <d>.
**Por qué está así:** <la razón del mercado, con fuente>.
**Trampas revisadas:** <cuáles aplican y por qué sí o no>.
**Tesis:** <dos o tres frases>.
**Precio con margen:** por debajo de <x> (<y> % bajo el valor base).
**La tesis falla si:** <hechos observables que la invalidarían>.
```
