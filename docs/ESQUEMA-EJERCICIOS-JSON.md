# Esquema JSON para ampliar la biblioteca

El cuarto formato de la carpeta compartida, y el más simple: añade ejercicios
al catálogo **sin rutina de por medio**. Antes, la única forma de meter un
ejercicio desde fuera era inventarse una rutina que lo nombrara y que luego no
se iba a hacer.

Se distingue de [las rutinas](ESQUEMA-RUTINA-JSON.md), [el
plan](ESQUEMA-PLAN-JSON.md) y [el borrado](ESQUEMA-BORRADO-JSON.md) por su
clave: `ejercicios`.

## Ejemplo

```json
{
  "version": 1,
  "ejercicios": [
    { "nombre": "Remo en T", "grupo": "espalda", "gruposSecundarios": ["biceps"], "material": "barra", "notas": "Pecho apoyado." },
    { "nombre": "Plancha lateral", "grupo": "core", "material": "pesoCorporal", "tipo": "tiempo" }
  ]
}
```

## Campos

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `nombre` | texto | sí | Si ya existe uno con ese nombre, **no se toca**: lo que tienes configurado manda. |
| `grupo` | texto | **sí** | Grupo muscular principal. |
| `gruposSecundarios` | lista de texto | no | Cuentan media serie cada uno. |
| `material` | texto | no | `barra`, `mancuerna`, `polea`, `maquina`, `pesoCorporal` u `otro`. Por defecto `otro`. |
| `tipo` | texto | no | `repeticiones`, `tiempo` o `repeticionesPorLado`. Por defecto `repeticiones`. |
| `notas` | texto | no | Lo que convenga recordar del ejercicio. |

Como mucho 300 por archivo.

## Por qué el grupo es obligatorio aquí

En una rutina no lo es, porque el ejercicio puede existir ya en la biblioteca y
entonces manda lo que tengas configurado. Aquí no hay nada a lo que agarrarse:
un ejercicio sin grupo nace como `sinClasificar`, que **no suma series en
ningún recuento**, así que entraría roto y en silencio. Por eso el archivo que
no lo declare se rechaza, y un grupo que no exista en el catálogo de la app
hace que ese ejercicio no entre: es preferible que falte a que cuente en el
grupo equivocado.

Es la misma regla que el resto del proyecto: no se adivinan datos que cambian
un recuento.
