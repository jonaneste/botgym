# Esquema JSON para borrar desde fuera

El puente con iCloud nació **aditivo**: una rutina que llega no toca nada de lo
que ya hay, y si no la quieres la borras deslizando. Eso dejaba la limpieza
entera en manos del usuario, y con dos carpetas de rutinas viejas con nombres
casi iguales —«Lunes – Pierna y Core» y «Lunes – Pierna y core»— el plan podía
arrancar la rutina equivocada sin que nadie de fuera pudiera arreglarlo.

Este formato es la excepción, y por eso es el más estricto de los tres:

- **Solo borra lo que se nombra, uno a uno.** No hay comodines ni rangos de
  fechas.
- **No se puede vaciar el historial.** Lo único que se admite de los entrenos
  son los que no tienen ninguna serie con algo anotado, que no son datos: son
  una fila con su hora y nada detrás.
- **Un archivo que no nombra nada se rechaza**, en vez de aceptarse como «no
  hagas nada»: casi siempre es una clave mal escrita.
- La app **enseña qué borró**, con los nombres, en el aviso de la pantalla de
  inicio. Es lo único que no se puede deshacer, así que tiene que poder
  auditarse de un vistazo.

Va en la misma carpeta que [las rutinas](ESQUEMA-RUTINA-JSON.md) y [el
plan](ESQUEMA-PLAN-JSON.md), y se distingue de ellos por su clave: `borrar`.

## Ejemplo

```json
{
  "version": 1,
  "borrar": {
    "carpetas": ["Media maratón"],
    "rutinas": ["Lunes – Empuje"],
    "entrenosVacios": true
  }
}
```

## Campos

| Campo | Tipo | Descripción |
|---|---|---|
| `version` | entero | Siempre `1` por ahora. |
| `borrar.carpetas` | lista de texto | Carpetas a borrar. **Se llevan sus rutinas**, que si no quedarían sueltas en «Sin carpeta» justo al limpiar. |
| `borrar.rutinas` | lista de texto | Rutinas a borrar, estén donde estén. |
| `borrar.entrenosVacios` | booleano | Borra los entrenos finalizados sin ninguna serie anotada. |
| `borrar.ejerciciosDuplicados` | booleano | De cada nombre repetido en la biblioteca deja uno. **Nunca borra el que tiene historial**, y si varios lo tienen no toca ninguno. |

Hace falta al menos una de las cuatro, y como mucho 40 nombres por lista. Los
nombres se comparan ignorando mayúsculas y acentos, igual que al importar: quien
escribe el archivo no tiene por qué acertar con la tilde. Un nombre vacío se
rechaza, porque según cómo se compare casaría con cualquier cosa.

## Lo que no borra, y por qué

**Ejercicios con historial.** Borrar uno parte sus gráficas y sus récords. Por
eso `ejerciciosDuplicados` solo se lleva los repetidos que no tienen ni un
entreno detrás: si de dos «Elevaciones laterales en polea» una se ha usado y la
otra no, se va la que no. Si las dos se han usado, no se toca ninguna, porque
decidir cuál sobrevive no es algo que deba hacer un archivo y fundirlas es otra
cosa que esto no hace.

**Entrenos con series.** Son los datos. Para eso está deslizar en el historial,
donde se ve lo que se va a borrar antes de borrarlo.
