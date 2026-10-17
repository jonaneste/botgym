# Esquema JSON para cargar un plan

Un **plan** es el calendario: qué toca cada día hasta una fecha objetivo. Es el
hermano de [las rutinas](ESQUEMA-RUTINA-JSON.md) y entra por el mismo sitio —la
carpeta `propuestas/` de iCloud Drive—, así que la app lo recoge sola y avisa
de lo que ha entrado.

Los dos formatos se distinguen por lo que llevan dentro, no por el nombre del
archivo: con la clave `plan` es un plan, con `rutinas` son rutinas.

Un plan **no lleva series ni pesos**. La parte de gimnasio apunta a una rutina
por su nombre, porque los pesos los decide la progresión mirando el historial y
no un archivo escrito hace dos meses.

## Ejemplo

```json
{
  "version": 1,
  "plan": {
    "nombre": "Media maratón Vitoria-Gasteiz",
    "objetivo": "2026-12-20",
    "dias": [
      { "fecha": "2026-10-13", "tipo": "gimnasioYCarrera", "titulo": "Pecho y tríceps", "km": 4, "rutina": "Martes – Pecho y tríceps", "notas": "18:30h" },
      { "fecha": "2026-10-14", "tipo": "descanso" },
      { "fecha": "2026-10-18", "tipo": "carrera", "titulo": "Tirada larga", "km": 6 },
      { "fecha": "2026-12-20", "tipo": "competicion", "titulo": "Media maratón Vitoria-Gasteiz", "km": 21.1 }
    ]
  }
}
```

## Campos

### Raíz

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `version` | entero | sí | Siempre `1` por ahora. |
| `plan` | objeto | sí | El plan. |

### Plan

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `nombre` | texto | sí | Cómo se llama el plan. |
| `objetivo` | texto | no | Fecha de la competición, `"2026-12-20"`. |
| `dias` | lista | sí | Entre 1 y 800 días. Pueden venir desordenados: se ordenan al leerlos. |

### Día

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `fecha` | texto | sí | `"2026-12-20"`. Un día no puede aparecer dos veces. |
| `tipo` | texto | sí | Uno de los de abajo. |
| `titulo` | texto | no | Lo que se lee en la fila. Si falta, se usa el nombre del tipo. |
| `notas` | texto | no | La hora, el sitio, lo que sea. |
| `km` | número | no | Kilómetros previstos. Solo en los tipos que corren. Admite coma decimal. |
| `rutina` | texto | no | Nombre de la rutina que cubre el gimnasio de ese día. |

### Tipos

| `tipo` | Qué es | Lleva `km` | Se puede marcar |
|---|---|---|---|
| `gimnasio` | Solo pesas | no | sí |
| `gimnasioYCarrera` | Pesas y rodaje | sí | sí |
| `carrera` | Solo correr | sí | sí |
| `competicion` | El día de la carrera | sí | sí |
| `turismo` | Se mueve, pero no entrena | no | sí |
| `descanso` | Nada | no | **no**: descansar no se cumple |

Unos `km` en un día que no corre se rechazan, porque casi siempre significa que
el tipo está mal puesto, y un descanso con una tirada dentro no se enseñaría en
ningún sitio.

## Qué pasa al cargarlo

- Los días que ya existían se **actualizan**; no se borra y se vuelve a crear.
  Así una versión nueva del archivo no se lleva por delante lo que ya habías
  marcado como hecho.
- La `rutina` se busca por nombre, ignorando mayúsculas y acentos. Si no existe
  todavía, el día se carga igual y el botón de empezar no aparece: carga antes
  las rutinas y el plan las encontrará.
- Lo que marcas en la app —si el día se hizo y los kilómetros que corriste de
  verdad— no viene del archivo y no se pierde nunca al recargar el plan.

## Dónde se ve

El día de hoy sale arriba en **Entrenar**, con el botón de empezar su rutina y
el de anotar la carrera. El plan completo está debajo, en **Ver el plan
completo**, por semanas, con la cuenta atrás hasta la competición.

El plan también viaja en el volcado `entrenos.json`, así que el servidor MCP lo
ve: la herramienta `plan` dice qué toca, qué se ha saltado y cuántos kilómetros
llevas frente a los previstos.
