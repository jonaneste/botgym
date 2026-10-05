# Esquema JSON para importar rutinas

> Este documento describe el formato que leerá el importador de la **fase 3**.
> Se publica ya para que quede fijado el contrato.

La idea es que puedas pedirle a una IA una rutina y pegarla en la app sin
tocar nada. Pégale a la IA este documento entero y te devolverá algo válido.

## Ejemplo mínimo

```json
{
  "version": 1,
  "carpeta": "Bloque otoño",
  "rutinas": [
    {
      "nombre": "Lunes – Empuje",
      "ejercicios": [
        { "nombre": "Press banca con barra", "series": 4, "reps": "8-10", "rir": "2-3", "descanso": 150 },
        { "nombre": "Elevaciones laterales", "series": 4, "reps": "12-15", "descanso": 60 }
      ]
    }
  ]
}
```

## Campos

### Raíz

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `version` | entero | sí | Siempre `1` por ahora. |
| `carpeta` | texto | no | Carpeta donde caen las rutinas. Si no existe se crea. Si se omite, van sueltas. |
| `rutinas` | lista | sí | Al menos una rutina. |

### Rutina

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `nombre` | texto | sí | Nombre de la rutina. |
| `notas` | texto | no | Notas libres. |
| `ejercicios` | lista | sí | Al menos un ejercicio. El orden de la lista es el orden en la rutina. |

### Ejercicio

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `nombre` | texto | sí | Se busca en tu biblioteca ignorando mayúsculas y acentos. |
| `series` | entero | sí | Entre 1 y 20. |
| `reps` | texto | no | Rango objetivo. Ver abajo. Si se omite, son series libres. |
| `rir` | texto | no | Repeticiones en reserva objetivo: `"2"` o `"2-3"`. Si se omite se usa el valor por defecto de Ajustes. |
| `descanso` | entero | no | Segundos de descanso. Por defecto 90. |
| `notas` | texto | no | Notas del ejercicio dentro de esta rutina. |
| `superserie` | texto | no | Etiqueta de agrupación. Ver abajo. |

## El campo `reps`

Es un texto, no un número, porque tiene que expresar rangos y segundos:

| Valor | Significado |
|---|---|
| `"8-10"` | De 8 a 10 repeticiones. |
| `"15"` | 15 repeticiones exactas. |
| `"30-45s"` | De 30 a 45 **segundos**. La `s` final marca que es tiempo. |
| `"45s"` | 45 segundos exactos. |
| omitido | Series libres, sin objetivo. |

Si el ejercicio existe en tu biblioteca como *repeticiones por lado* (landmine
press, remo unilateral), el rango se entiende **por lado** automáticamente; no
hay que indicarlo en el JSON.

## Superseries

Los ejercicios **consecutivos** que comparten la misma etiqueta en
`superserie` se agrupan. La etiqueta en sí no se muestra, solo sirve para
agrupar:

```json
"ejercicios": [
  { "nombre": "Curl inclinado",                 "series": 3, "reps": "10-12", "descanso": 90, "superserie": "A" },
  { "nombre": "Extensión de tríceps sobre la cabeza", "series": 3, "reps": "10-12", "descanso": 90, "superserie": "A" },
  { "nombre": "Curl predicador",                "series": 3, "reps": "10-12", "descanso": 90, "superserie": "B" },
  { "nombre": "Press francés",                  "series": 3, "reps": "10-12", "descanso": 90, "superserie": "B" }
]
```

Eso son dos superseries de dos ejercicios cada una.

## Ejercicios que no existen todavía

Si un nombre no está en tu biblioteca, la importación **no falla**: se para y
te lista los nombres desconocidos, con los parecidos que haya encontrado, para
que elijas entre crearlos nuevos o mapearlos a uno que ya tengas.

## Errores

La validación devuelve mensajes concretos con la ruta del problema, por
ejemplo:

```
rutinas[0].ejercicios[2].reps: "8 a 10" no es un rango válido.
Usa "8-10", "15" o "30-45s".
```
