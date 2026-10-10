#!/usr/bin/env node
/**
 * Servidor MCP que expone tu historial de entrenamiento a Claude.
 *
 * Lee el `entrenos.json` que escribe la app Entrenos en la carpeta que le
 * indicaste, y lo sirve en consultas estructuradas en lugar de obligar a
 * tragarse el archivo entero: así Claude puede preguntar "¿cómo va mi press
 * banca?" sin cargar dos años de series.
 *
 * Sin dependencias a propósito. Solo hace falta `node`, nada de `npm install`.
 *
 * Uso:
 *   ENTRENOS_JSON=/ruta/a/entrenos.json node servidor-entrenos.mjs
 *   node servidor-entrenos.mjs /ruta/a/entrenos.json
 */

import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'

const VERSION = '1.1.0'
const PESO_SECUNDARIO = 0.5

// ─── Localizar el archivo ────────────────────────────────────────────────────

function rutasCandidatas() {
  const explicita = process.env.ENTRENOS_JSON || process.argv[2]
  if (explicita) return [explicita]
  const icloud = join(homedir(), 'Library', 'Mobile Documents', 'com~apple~CloudDocs')
  return [
    join(icloud, 'Entrenos', 'entrenos.json'),
    join(icloud, 'entrenos.json'),
    join(homedir(), 'Entrenos', 'entrenos.json'),
    'entrenos.json',
  ]
}

let cache = { ruta: null, mtime: 0, datos: null }

function cargarDatos() {
  for (const ruta of rutasCandidatas()) {
    let info
    try {
      info = statSync(ruta)
    } catch {
      continue
    }
    const mtime = info.mtimeMs
    if (cache.ruta === ruta && cache.mtime === mtime && cache.datos) {
      return cache.datos
    }
    const datos = JSON.parse(readFileSync(ruta, 'utf8'))
    cache = { ruta, mtime, datos }
    return datos
  }
  throw new Error(
    'No encuentro entrenos.json. Pásame la ruta con la variable de entorno ' +
      'ENTRENOS_JSON o como primer argumento. Busqué en: ' +
      rutasCandidatas().join(', ')
  )
}

// ─── Utilidades ──────────────────────────────────────────────────────────────

/** Lunes a las 00:00 de la semana en que cae la fecha. */
function inicioSemana(fecha) {
  const d = new Date(fecha)
  d.setHours(0, 0, 0, 0)
  // getDay(): 0 = domingo. Se desplaza para que el lunes sea el día 0.
  const desplazamiento = (d.getDay() + 6) % 7
  d.setDate(d.getDate() - desplazamiento)
  return d
}

/** YYYY-MM-DD de una fecha en hora LOCAL. */
function fechaLocalISO(d) {
  // No se usa toISOString(): convierte a UTC, y en zonas al este de Greenwich
  // el lunes 00:00 local es el domingo en UTC, con lo que todas las semanas
  // saldrían empezando en domingo.
  const año = d.getFullYear()
  const mes = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${año}-${mes}-${dia}`
}

function claveSemana(fecha) {
  return fechaLocalISO(inicioSemana(fecha))
}

/** 1RM estimado por Epley. */
function epley(peso, reps) {
  if (!(peso > 0) || !(reps >= 1)) return null
  if (reps === 1) return peso
  return peso * (1 + reps / 30)
}

function redondear(valor, decimales = 1) {
  if (valor === null || valor === undefined || !isFinite(valor)) return null
  const factor = 10 ** decimales
  return Math.round(valor * factor) / factor
}

/** Series que cuentan: completadas y no de calentamiento. */
function seriesEfectivas(ejercicio) {
  return (ejercicio.series || []).filter((s) => !s.calentamiento)
}

function volumenDeEjercicio(ejercicio) {
  return seriesEfectivas(ejercicio).reduce((suma, s) => suma + s.peso * s.repeticiones, 0)
}

function volumenDeEntreno(entreno) {
  return (entreno.ejercicios || []).reduce((suma, e) => suma + volumenDeEjercicio(e), 0)
}

function contarSeries(entreno) {
  return (entreno.ejercicios || []).reduce((suma, e) => suma + seriesEfectivas(e).length, 0)
}

/** Series por grupo muscular: el principal suma 1 y cada secundario 0,5. */
function seriesPorGrupo(entrenos) {
  const cuenta = {}
  for (const entreno of entrenos) {
    for (const ejercicio of entreno.ejercicios || []) {
      const n = seriesEfectivas(ejercicio).length
      if (n === 0) continue
      const principal = ejercicio.grupoPrincipal
      if (principal) cuenta[principal] = (cuenta[principal] || 0) + n
      const secundarios = new Set(ejercicio.gruposSecundarios || [])
      secundarios.delete(principal)
      for (const grupo of secundarios) {
        cuenta[grupo] = (cuenta[grupo] || 0) + n * PESO_SECUNDARIO
      }
    }
  }
  return Object.fromEntries(
    Object.entries(cuenta)
      .map(([g, v]) => [g, redondear(v)])
      .sort((a, b) => b[1] - a[1])
  )
}

function normalizar(texto) {
  return (texto || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
}

function duracionMin(entreno) {
  if (!entreno.fechaFin) return null
  const ms = new Date(entreno.fechaFin) - new Date(entreno.fechaInicio)
  return redondear(ms / 60000, 0)
}

/** Ritmo como "5:00 /km". Se redondea el total ANTES de dividir, o 359,6
 *  s/km saldría como "5:60". */
function textoRitmo(segundosPorKm) {
  if (!(segundosPorKm > 0) || !isFinite(segundosPorKm)) return null
  const total = Math.round(segundosPorKm)
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')} /km`
}

function textoSerie(serie, tipo) {
  if (tipo === 'tiempo') {
    const t = `${serie.segundos ?? 0} s`
    return serie.peso > 0 ? `${serie.peso} kg × ${t}` : t
  }
  const base = serie.peso > 0 ? `${serie.peso} kg × ${serie.repeticiones}` : `× ${serie.repeticiones}`
  return serie.rir !== null && serie.rir !== undefined ? `${base} (RIR ${serie.rir})` : base
}

// ─── El buzón de ida: rutinas que Claude deja para la app ────────────────────
// La carpeta elegida en la app ya traía los datos en una dirección. Esto la
// usa en la otra: Claude escribe un JSON en `rutinas-de-claude/` y la app lo
// encuentra ahí y lo importa de un toque, sin pegar texto ni buscar archivos.
//
// Lo que se escribe es el MISMO formato que lee el importador de la app
// (docs/ESQUEMA-RUTINA-JSON.md), y se valida aquí con los mismos límites que
// allí: lo que no pase por aquí no llega al teléfono, donde el error ya solo
// se puede leer con el móvil en la mano.

const NOMBRE_BUZON = 'rutinas-de-claude'

const LIMITES = { version: 1, maxSeries: 20, maxDescanso: 1800, maxObjetivo: 1000 }

/** Carpeta donde la app busca lo que deja Claude. */
function carpetaBuzon() {
  if (process.env.ENTRENOS_RUTINAS_DIR) return process.env.ENTRENOS_RUTINAS_DIR
  for (const ruta of rutasCandidatas()) {
    try {
      statSync(ruta)
      return join(dirname(ruta), NOMBRE_BUZON)
    } catch {
      continue
    }
  }
  // Puede que la carpeta esté elegida pero la app no haya exportado todavía:
  // si la ruta vino dada, su carpeta vale igual.
  const dada = process.env.ENTRENOS_JSON || process.argv[2]
  if (dada) return join(dirname(dada), NOMBRE_BUZON)
  throw new Error(
    'No sé en qué carpeta dejar la rutina. Es la misma donde la app escribe ' +
      'entrenos.json: pásala en ENTRENOS_JSON, o en ENTRENOS_RUTINAS_DIR si es otra.'
  )
}

/** Los datos, o `null` si todavía no hay archivo. */
function datosOpcionales() {
  try {
    return cargarDatos()
  } catch {
    return null
  }
}

function fallo(ruta, mensaje) {
  return new Error(ruta ? `${ruta}: ${mensaje}` : mensaje)
}

/** JSON no distingue 3 de 3.0, así que un entero puede llegar como decimal. */
function enteroDe(valor) {
  if (typeof valor === 'number') return Number.isInteger(valor) ? valor : null
  if (typeof valor === 'string' && /^-?\d+$/.test(valor.trim())) return Number(valor.trim())
  return null
}

/** Lee "8-10", "15", "30-45s" o "45s", igual que el importador de la app. */
function validarRango(texto, ruta, { permitirSegundos = true, maximo = LIMITES.maxObjetivo } = {}) {
  let limpio = String(texto).trim().toLowerCase().replace(/\s+/g, '')
  if (!limpio) throw fallo(ruta, 'Está vacío. Usa "8-10", "15" o "30-45s".')

  if (limpio.endsWith('s')) {
    if (!permitirSegundos) throw fallo(ruta, 'Aquí no se admiten segundos: usa "2" o "2-3".')
    limpio = limpio.slice(0, -1)
  }
  // Se acepta el guion normal y los que meten los editores de texto.
  limpio = limpio.replace(/[\u2013\u2014a]/g, '-')

  const malRango = `«${texto}» no es un rango válido. Usa "8-10", "15" o "30-45s", con números entre 0 y ${maximo}.`
  const trozos = limpio.split('-')
  if (trozos.length > 2) throw fallo(ruta, malRango)

  const numeros = trozos.map((trozo) => {
    const valor = enteroDe(trozo)
    if (valor === null || valor < 0 || valor > maximo) throw fallo(ruta, malRango)
    return valor
  })
  if (numeros.length === 2 && numeros[0] > numeros[1]) {
    throw fallo(ruta, `«${texto}» tiene el mínimo por encima del máximo.`)
  }
}

function validarEjercicio(crudo, ruta) {
  if (crudo === null || typeof crudo !== 'object' || Array.isArray(crudo)) {
    throw fallo(ruta, 'Se esperaba un objeto con «nombre» y «series».')
  }

  const nombre = typeof crudo.nombre === 'string' ? crudo.nombre.trim() : ''
  if (!nombre) throw fallo(`${ruta}.nombre`, 'Falta el nombre del ejercicio.')

  const series = enteroDe(crudo.series)
  if (series === null) throw fallo(`${ruta}.series`, 'Falta el número de series, o no es un entero.')
  if (series < 1 || series > LIMITES.maxSeries) {
    throw fallo(
      `${ruta}.series`,
      `${series} está fuera de rango. Tiene que estar entre 1 y ${LIMITES.maxSeries}.`
    )
  }

  const salida = { nombre, series }

  if (crudo.reps !== undefined && crudo.reps !== null) {
    if (typeof crudo.reps !== 'string') {
      throw fallo(`${ruta}.reps`, 'Tiene que ser texto entre comillas, como "8-10" o "30-45s".')
    }
    validarRango(crudo.reps, `${ruta}.reps`)
    salida.reps = crudo.reps.trim()
  }

  if (crudo.rir !== undefined && crudo.rir !== null) {
    let texto
    if (typeof crudo.rir === 'string') {
      texto = crudo.rir
    } else {
      const numero = enteroDe(crudo.rir)
      if (numero === null) throw fallo(`${ruta}.rir`, 'Tiene que ser texto como "2" o "2-3".')
      texto = String(numero)
    }
    validarRango(texto, `${ruta}.rir`, { permitirSegundos: false, maximo: 10 })
    salida.rir = texto.trim()
  }

  if (crudo.descanso !== undefined && crudo.descanso !== null) {
    const descanso = enteroDe(crudo.descanso)
    if (descanso === null) throw fallo(`${ruta}.descanso`, 'Tiene que ser un número de segundos.')
    if (descanso < 0 || descanso > LIMITES.maxDescanso) {
      throw fallo(
        `${ruta}.descanso`,
        `${descanso} s está fuera de rango. Tiene que estar entre 0 y ${LIMITES.maxDescanso}.`
      )
    }
    salida.descanso = descanso
  }

  if (typeof crudo.notas === 'string' && crudo.notas.trim()) salida.notas = crudo.notas.trim()

  if (crudo.superserie !== undefined && crudo.superserie !== null) {
    if (typeof crudo.superserie !== 'string') {
      throw fallo(`${ruta}.superserie`, 'Tiene que ser texto: una etiqueta como "A".')
    }
    const etiqueta = crudo.superserie.trim()
    if (etiqueta) salida.superserie = etiqueta
  }

  return salida
}

/** Valida la propuesta y devuelve el documento tal cual se va a escribir. */
function validarPropuesta({ rutinas, carpeta } = {}) {
  if (!Array.isArray(rutinas)) throw fallo('rutinas', 'Tiene que ser una lista de rutinas.')
  if (rutinas.length === 0) {
    throw fallo('rutinas', 'La lista está vacía: hace falta al menos una rutina.')
  }

  const validadas = rutinas.map((cruda, indice) => {
    const ruta = `rutinas[${indice}]`
    if (cruda === null || typeof cruda !== 'object' || Array.isArray(cruda)) {
      throw fallo(ruta, 'Se esperaba un objeto con «nombre» y «ejercicios».')
    }

    const nombre = typeof cruda.nombre === 'string' ? cruda.nombre.trim() : ''
    if (!nombre) throw fallo(`${ruta}.nombre`, 'Falta el nombre de la rutina.')

    if (!Array.isArray(cruda.ejercicios)) {
      throw fallo(`${ruta}.ejercicios`, 'Tiene que ser una lista.')
    }
    if (cruda.ejercicios.length === 0) {
      throw fallo(`${ruta}.ejercicios`, `La rutina «${nombre}» no tiene ejercicios.`)
    }

    const salida = {
      nombre,
      ejercicios: cruda.ejercicios.map((ejercicio, j) =>
        validarEjercicio(ejercicio, `${ruta}.ejercicios[${j}]`)
      ),
    }
    if (typeof cruda.notas === 'string' && cruda.notas.trim()) salida.notas = cruda.notas.trim()
    return salida
  })

  const documento = { version: LIMITES.version, rutinas: validadas }
  if (typeof carpeta === 'string' && carpeta.trim()) documento.carpeta = carpeta.trim()
  return documento
}

/**
 * Nombre de archivo seguro. Solo sobreviven letras sin acento, dígitos y
 * guiones, así que no hay forma de escribir fuera del buzón pasando «../».
 */
function nombreDeArchivo(propuesto, rutinas) {
  const base = propuesto || `${fechaLocalISO(new Date())}-${rutinas[0].nombre}`
  const limpio = base
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\.json$/, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
  return `${limpio || 'rutina'}.json`
}

// ─── Herramientas ────────────────────────────────────────────────────────────

const HERRAMIENTAS = [
  {
    name: 'resumen_general',
    description:
      'Visión de conjunto de todo el historial: cuántos entrenos, desde cuándo, ' +
      'volumen total, ejercicios distintos y carreras. Empieza por aquí para ' +
      'situarte antes de pedir detalle.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'resumen_semanal',
    description:
      'Semana a semana: entrenos, series, volumen, series por grupo muscular y ' +
      'kilómetros corridos. Es la vista para juzgar si el volumen sube, baja o ' +
      'está desequilibrado entre grupos.',
    inputSchema: {
      type: 'object',
      properties: {
        semanas: {
          type: 'integer',
          description: 'Cuántas semanas hacia atrás, incluida la actual. Por defecto 8.',
          minimum: 1,
          maximum: 104,
        },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'historial_ejercicio',
    description:
      'Todas las sesiones de un ejercicio, con sus series y el 1RM estimado de ' +
      'cada sesión. El nombre se busca ignorando mayúsculas y acentos, y por ' +
      'coincidencia parcial: "press banca" encuentra "Press banca con barra".',
    inputSchema: {
      type: 'object',
      properties: {
        nombre: { type: 'string', description: 'Nombre o parte del nombre del ejercicio.' },
        limite: {
          type: 'integer',
          description: 'Cuántas sesiones devolver, de más reciente a más antigua. Por defecto 20.',
          minimum: 1,
          maximum: 200,
        },
      },
      required: ['nombre'],
      additionalProperties: false,
    },
  },
  {
    name: 'records',
    description:
      'Récords personales por ejercicio: peso máximo, mejor 1RM estimado y mejor ' +
      'volumen en una sesión, cada uno con su fecha. Sin nombre, devuelve todos.',
    inputSchema: {
      type: 'object',
      properties: {
        nombre: { type: 'string', description: 'Opcional. Filtra a un ejercicio.' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'ultimos_entrenos',
    description:
      'Los últimos entrenos con todo el detalle: ejercicios, series, RIR, notas y ' +
      'la molestia de hombro y rodilla si se anotó. Es lo que hay que leer para ' +
      'comentar una sesión concreta.',
    inputSchema: {
      type: 'object',
      properties: {
        limite: { type: 'integer', description: 'Cuántos. Por defecto 3.', minimum: 1, maximum: 50 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'rutinas',
    description:
      'Las rutinas configuradas con sus objetivos: series, rango de repeticiones, ' +
      'RIR y descanso de cada ejercicio. Sirve para comparar lo planificado con lo ' +
      'que de verdad se hizo.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'carreras',
    description:
      'Carreras registradas, que llegan desde Zepp a través de Apple Salud: ' +
      'distancia, duración, ritmo y pulso medio, con resumen por semana.',
    inputSchema: {
      type: 'object',
      properties: {
        semanas: { type: 'integer', description: 'Por defecto 8.', minimum: 1, maximum: 104 },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'ejercicios',
    description:
      'La biblioteca de ejercicios de la app, con su grupo muscular, material y ' +
      'tipo de registro. Léela ANTES de proponer una rutina: un nombre que la app ' +
      'no tiene lo crea al importar, pero sin grupo muscular ni material, y eso ' +
      'falsea el recuento semanal por grupo sin avisar.',
    inputSchema: {
      type: 'object',
      properties: {
        grupo: {
          type: 'string',
          description: 'Opcional. Filtra por grupo muscular, principal o secundario.',
        },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'proponer_rutina',
    description:
      'Deja una o varias rutinas en la carpeta compartida para que la app las ' +
      'importe: en el teléfono aparecen en Datos → Rutinas de Claude y se añaden ' +
      'de un toque. No toca nada de lo que ya hay hasta que se importa, y el ' +
      'historial no se altera nunca. Se valida con los mismos límites que la app, ' +
      'así que un error se ve aquí y no con el móvil en la mano.',
    inputSchema: {
      type: 'object',
      properties: {
        rutinas: {
          type: 'array',
          minItems: 1,
          description: 'Las rutinas a proponer.',
          items: {
            type: 'object',
            properties: {
              nombre: { type: 'string', description: 'Nombre de la rutina. Obligatorio.' },
              notas: { type: 'string', description: 'Opcional. Nota de la rutina entera.' },
              ejercicios: {
                type: 'array',
                minItems: 1,
                items: {
                  type: 'object',
                  properties: {
                    nombre: {
                      type: 'string',
                      description:
                        'Nombre del ejercicio, tal como lo tiene la app. Mira «ejercicios» primero.',
                    },
                    series: { type: 'integer', minimum: 1, maximum: 20 },
                    reps: {
                      type: 'string',
                      description:
                        'Rango objetivo, como texto: "8-10", "15", o con segundos "30-45s". Omitir = series libres.',
                    },
                    rir: {
                      type: 'string',
                      description: 'RIR objetivo: "2" o "2-3". De 0 a 10.',
                    },
                    descanso: {
                      type: 'integer',
                      description: 'Descanso en segundos. Por defecto 90.',
                      minimum: 0,
                      maximum: 1800,
                    },
                    notas: { type: 'string' },
                    superserie: {
                      type: 'string',
                      description:
                        'Etiqueta de agrupación, como "A". Los ejercicios seguidos con la misma forman superserie.',
                    },
                  },
                  required: ['nombre', 'series'],
                  additionalProperties: false,
                },
              },
            },
            required: ['nombre', 'ejercicios'],
            additionalProperties: false,
          },
        },
        carpeta: {
          type: 'string',
          description: 'Opcional. Carpeta de rutinas donde van. Si no existe, la app la crea.',
        },
        nombre_archivo: {
          type: 'string',
          description:
            'Opcional. Para reemplazar una propuesta anterior en lugar de añadir otra: ' +
            'el mismo nombre que devolvió «propuestas_pendientes».',
        },
      },
      required: ['rutinas'],
      additionalProperties: false,
    },
  },
  {
    name: 'objetivos',
    description:
      'Los objetivos de series semanales por grupo muscular que hay puestos en ' +
      'la app, con lo hecho esta semana y la media de las ocho, y lo que falta ' +
      'para cumplirlos. Es la mitad que no se puede deducir del historial: sin ' +
      'esto se sabe cuántas series de pecho hay, pero no a cuántas se apuntaba. ' +
      'Léelo antes de proponer una rutina para que cubra lo que va corto.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'propuestas_pendientes',
    description:
      'Qué propuestas hay en la carpeta esperando a que se importen en la app. ' +
      'Mírala antes de proponer otra vez lo mismo, y para saber si ya se importó ' +
      'lo de antes: al importarla, la app retira el archivo.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
]

function entrenosOrdenados(datos) {
  return [...(datos.entrenos || [])].sort(
    (a, b) => new Date(b.fechaInicio) - new Date(a.fechaInicio)
  )
}

function buscarEjercicios(datos, nombre) {
  const buscado = normalizar(nombre)
  const encontrados = new Map()
  for (const entreno of datos.entrenos || []) {
    for (const ejercicio of entreno.ejercicios || []) {
      if (!normalizar(ejercicio.nombre).includes(buscado)) continue
      if (!encontrados.has(ejercicio.nombre)) encontrados.set(ejercicio.nombre, [])
      encontrados.get(ejercicio.nombre).push({ entreno, ejercicio })
    }
  }
  return encontrados
}

const EJECUTORES = {
  resumen_general() {
    const datos = cargarDatos()
    const entrenos = entrenosOrdenados(datos)
    const nombres = new Set()
    for (const e of entrenos) for (const ej of e.ejercicios || []) nombres.add(ej.nombre)
    const carreras = datos.carreras || []

    return {
      generado: datos.generado,
      entrenos: entrenos.length,
      primerEntreno: entrenos.at(-1)?.fechaInicio ?? null,
      ultimoEntreno: entrenos[0]?.fechaInicio ?? null,
      seriesTotales: entrenos.reduce((s, e) => s + contarSeries(e), 0),
      volumenTotalKg: redondear(entrenos.reduce((s, e) => s + volumenDeEntreno(e), 0), 0),
      ejerciciosDistintos: nombres.size,
      ejerciciosEnBiblioteca: (datos.ejercicios || []).length,
      rutinas: (datos.carpetas || []).reduce((s, c) => s + (c.rutinas || []).length, 0),
      carreras: carreras.length,
      kilometrosTotales: redondear(carreras.reduce((s, c) => s + c.distanciaKm, 0)),
    }
  },

  resumen_semanal({ semanas = 8 } = {}) {
    const datos = cargarDatos()
    const porSemana = new Map()

    const hoy = inicioSemana(new Date())
    for (let i = semanas - 1; i >= 0; i--) {
      const d = new Date(hoy)
      d.setDate(d.getDate() - i * 7)
      porSemana.set(fechaLocalISO(d), { entrenos: [], carreras: [] })
    }

    for (const entreno of datos.entrenos || []) {
      const clave = claveSemana(entreno.fechaInicio)
      if (porSemana.has(clave)) porSemana.get(clave).entrenos.push(entreno)
    }
    for (const carrera of datos.carreras || []) {
      const clave = claveSemana(carrera.fecha)
      if (porSemana.has(clave)) porSemana.get(clave).carreras.push(carrera)
    }

    return [...porSemana.entries()].map(([semana, { entrenos, carreras }]) => ({
      semanaDesde: semana,
      entrenos: entrenos.length,
      series: entrenos.reduce((s, e) => s + contarSeries(e), 0),
      volumenKg: redondear(entrenos.reduce((s, e) => s + volumenDeEntreno(e), 0), 0),
      seriesPorGrupo: seriesPorGrupo(entrenos),
      carreras: carreras.length,
      kilometros: redondear(carreras.reduce((s, c) => s + c.distanciaKm, 0)),
    }))
  },

  historial_ejercicio({ nombre, limite = 20 } = {}) {
    const datos = cargarDatos()
    const encontrados = buscarEjercicios(datos, nombre)

    if (encontrados.size === 0) {
      const todos = new Set()
      for (const e of datos.entrenos || []) for (const ej of e.ejercicios || []) todos.add(ej.nombre)
      return {
        error: `No hay historial de ningún ejercicio que contenga «${nombre}».`,
        ejerciciosConHistorial: [...todos].sort(),
      }
    }

    return [...encontrados.entries()].map(([nombreEjercicio, apariciones]) => {
      const sesiones = apariciones
        .sort((a, b) => new Date(b.entreno.fechaInicio) - new Date(a.entreno.fechaInicio))
        .slice(0, limite)
        .map(({ entreno, ejercicio }) => {
          const efectivas = seriesEfectivas(ejercicio)
          const estimaciones = efectivas
            .map((s) => epley(s.peso, s.repeticiones))
            .filter((v) => v !== null)
          return {
            fecha: entreno.fechaInicio,
            entreno: entreno.nombre,
            series: efectivas.map((s) => textoSerie(s, ejercicio.tipoRegistro)),
            pesoMaximoKg: efectivas.length ? Math.max(...efectivas.map((s) => s.peso)) : 0,
            unRMEstimado: estimaciones.length ? redondear(Math.max(...estimaciones)) : null,
            volumenKg: redondear(volumenDeEjercicio(ejercicio), 0),
            notas: ejercicio.notas || null,
          }
        })
      return {
        ejercicio: nombreEjercicio,
        grupoPrincipal: apariciones[0].ejercicio.grupoPrincipal ?? null,
        gruposSecundarios: apariciones[0].ejercicio.gruposSecundarios ?? [],
        tipoRegistro: apariciones[0].ejercicio.tipoRegistro,
        sesiones,
      }
    })
  },

  records({ nombre } = {}) {
    const datos = cargarDatos()
    const porEjercicio = new Map()

    for (const entreno of datos.entrenos || []) {
      for (const ejercicio of entreno.ejercicios || []) {
        if (nombre && !normalizar(ejercicio.nombre).includes(normalizar(nombre))) continue
        const efectivas = seriesEfectivas(ejercicio)
        if (efectivas.length === 0) continue

        if (!porEjercicio.has(ejercicio.nombre)) {
          porEjercicio.set(ejercicio.nombre, {
            ejercicio: ejercicio.nombre,
            pesoMaximoKg: null,
            fechaPesoMaximo: null,
            mejorUnRM: null,
            fechaMejorUnRM: null,
            mejorVolumenSesionKg: null,
            fechaMejorVolumen: null,
            mejorTiempoSegundos: null,
            fechaMejorTiempo: null,
          })
        }
        const r = porEjercicio.get(ejercicio.nombre)
        const fecha = entreno.fechaInicio

        const peso = Math.max(...efectivas.map((s) => s.peso))
        if (peso > 0 && (r.pesoMaximoKg === null || peso > r.pesoMaximoKg)) {
          r.pesoMaximoKg = peso
          r.fechaPesoMaximo = fecha
        }

        if (ejercicio.tipoRegistro !== 'tiempo') {
          const estimaciones = efectivas
            .map((s) => epley(s.peso, s.repeticiones))
            .filter((v) => v !== null)
          if (estimaciones.length) {
            const mejor = Math.max(...estimaciones)
            if (r.mejorUnRM === null || mejor > r.mejorUnRM) {
              // Se guarda el valor crudo y se redondea al final: comparar
              // contra el redondeado deja que una sesión peor robe la fecha.
              r.mejorUnRM = mejor
              r.fechaMejorUnRM = fecha
            }
          }
        } else {
          const segundos = Math.max(...efectivas.map((s) => s.segundos ?? 0))
          if (segundos > 0 && (r.mejorTiempoSegundos === null || segundos > r.mejorTiempoSegundos)) {
            r.mejorTiempoSegundos = segundos
            r.fechaMejorTiempo = fecha
          }
        }

        const volumen = volumenDeEjercicio(ejercicio)
        if (volumen > 0 && (r.mejorVolumenSesionKg === null || volumen > r.mejorVolumenSesionKg)) {
          r.mejorVolumenSesionKg = volumen
          r.fechaMejorVolumen = fecha
        }
      }
    }

    const lista = [...porEjercicio.values()]
      .map((r) => ({
        ...r,
        mejorUnRM: redondear(r.mejorUnRM),
        mejorVolumenSesionKg: redondear(r.mejorVolumenSesionKg, 0),
      }))
      .sort((a, b) => a.ejercicio.localeCompare(b.ejercicio, 'es'))
    return lista.length ? lista : { error: `Sin récords para «${nombre ?? ''}».` }
  },

  ultimos_entrenos({ limite = 3 } = {}) {
    const datos = cargarDatos()
    return entrenosOrdenados(datos)
      .slice(0, limite)
      .map((entreno) => ({
        fecha: entreno.fechaInicio,
        nombre: entreno.nombre,
        rutinaOrigen: entreno.rutinaOrigen ?? null,
        duracionMinutos: duracionMin(entreno),
        series: contarSeries(entreno),
        volumenKg: redondear(volumenDeEntreno(entreno), 0),
        molestiaHombro: entreno.molestiaHombro ?? null,
        molestiaRodilla: entreno.molestiaRodilla ?? null,
        notas: entreno.notas || null,
        ejercicios: (entreno.ejercicios || []).map((ejercicio) => ({
          nombre: ejercicio.nombre,
          grupoPrincipal: ejercicio.grupoPrincipal ?? null,
          superserie: ejercicio.superserie ?? null,
          notas: ejercicio.notas || null,
          series: seriesEfectivas(ejercicio).map((s) => textoSerie(s, ejercicio.tipoRegistro)),
        })),
      }))
  },

  rutinas() {
    const datos = cargarDatos()
    return (datos.carpetas || []).map((carpeta) => ({
      carpeta: carpeta.nombre,
      rutinas: (carpeta.rutinas || []).map((rutina) => ({
        nombre: rutina.nombre,
        notas: rutina.notas || null,
        seriesTotales: (rutina.ejercicios || []).reduce((s, e) => s + e.series, 0),
        ejercicios: (rutina.ejercicios || []).map((e) => ({
          nombre: e.nombre,
          series: e.series,
          reps: e.reps ?? 'libre',
          rir: e.rir ?? null,
          descansoSegundos: e.descanso,
          superserie: e.superserie ?? null,
          notas: e.notas || null,
        })),
      })),
    }))
  },

  carreras({ semanas = 8 } = {}) {
    const datos = cargarDatos()
    const todas = [...(datos.carreras || [])].sort((a, b) => new Date(b.fecha) - new Date(a.fecha))
    const limite = inicioSemana(new Date())
    limite.setDate(limite.getDate() - (semanas - 1) * 7)
    const recientes = todas.filter((c) => new Date(c.fecha) >= limite)

    const porSemana = new Map()
    for (const carrera of recientes) {
      const clave = claveSemana(carrera.fecha)
      if (!porSemana.has(clave)) porSemana.set(clave, { carreras: 0, km: 0, segundos: 0 })
      const s = porSemana.get(clave)
      s.carreras += 1
      s.km += carrera.distanciaKm
      s.segundos += carrera.duracionSegundos
    }

    return {
      carreras: recientes.map((c) => ({
        fecha: c.fecha,
        distanciaKm: redondear(c.distanciaKm, 2),
        duracionMinutos: redondear(c.duracionSegundos / 60, 0),
        ritmo: textoRitmo(c.ritmoSegundosPorKm),
        pulsoMedio: c.pulsoMedio ? redondear(c.pulsoMedio, 0) : null,
        origen: c.origen ?? null,
      })),
      porSemana: [...porSemana.entries()]
        .sort()
        .map(([semana, s]) => ({
          semanaDesde: semana,
          carreras: s.carreras,
          kilometros: redondear(s.km),
          ritmoMedio: s.km ? textoRitmo(s.segundos / s.km) : null,
        })),
    }
  },

  ejercicios({ grupo } = {}) {
    const datos = cargarDatos()
    const buscado = grupo ? normalizar(grupo) : null
    const coincide = (ejercicio) =>
      !buscado ||
      normalizar(ejercicio.grupoPrincipal) === buscado ||
      (ejercicio.gruposSecundarios || []).some((g) => normalizar(g) === buscado)

    return (datos.ejercicios || []).filter(coincide).map((e) => ({
      nombre: e.nombre,
      grupoPrincipal: e.grupoPrincipal,
      gruposSecundarios: e.gruposSecundarios || [],
      material: e.material,
      tipoRegistro: e.tipoRegistro,
      creadoPorMi: e.esPersonalizado === true,
    }))
  },

  proponer_rutina({ rutinas, carpeta, nombre_archivo } = {}) {
    const documento = validarPropuesta({ rutinas, carpeta })
    const destino = carpetaBuzon()
    mkdirSync(destino, { recursive: true })

    const archivo = nombreDeArchivo(nombre_archivo, documento.rutinas)
    writeFileSync(join(destino, archivo), `${JSON.stringify(documento, null, 2)}\n`, 'utf8')

    // Un nombre que la app no conoce no se descarta: lo crea al importar, pero
    // sin grupo muscular ni material, porque adivinarlos falsearía el recuento
    // semanal en silencio. Se devuelven para poder decirlo antes de importar.
    const datos = datosOpcionales()
    const conocidos = new Set((datos?.ejercicios || []).map((e) => normalizar(e.nombre)))
    const usados = [
      ...new Set(documento.rutinas.flatMap((r) => r.ejercicios.map((e) => e.nombre))),
    ]
    const desconocidos = conocidos.size === 0 ? [] : usados.filter((n) => !conocidos.has(normalizar(n)))

    return {
      archivo,
      carpeta: destino,
      rutinas: documento.rutinas.map((r) => ({
        nombre: r.nombre,
        ejercicios: r.ejercicios.length,
        seriesTotales: r.ejercicios.reduce((suma, e) => suma + e.series, 0),
      })),
      ejerciciosQueLaAppNoTiene: desconocidos,
      siguientePaso:
        'En la app: Datos → Rutinas de Claude. Ahí sale la propuesta y se añade de un toque.',
    }
  },

  objetivos() {
    const datos = cargarDatos()
    const puestos = datos.objetivosSemanales || {}

    const estaSemana = inicioSemana(new Date())
    const clave = fechaLocalISO(estaSemana)
    // Ocho semanas contando la actual, igual que la pestaña de Progreso.
    const SEMANAS = 8
    const desde = new Date(estaSemana)
    desde.setDate(desde.getDate() - (SEMANAS - 1) * 7)

    const deLaSemana = []
    const deLasOcho = []
    for (const entreno of datos.entrenos || []) {
      if (claveSemana(entreno.fechaInicio) === clave) deLaSemana.push(entreno)
      if (new Date(entreno.fechaInicio) >= desde) deLasOcho.push(entreno)
    }
    const ahora = seriesPorGrupo(deLaSemana)
    const media = seriesPorGrupo(deLasOcho)

    const grupos = []
    const sinObjetivo = []
    const todos = [
      ...new Set([...Object.keys(puestos), ...Object.keys(ahora), ...Object.keys(media)]),
    ].sort()

    for (const grupo of todos) {
      const series = ahora[grupo] || 0
      const mediaSemanal = redondear((media[grupo] || 0) / SEMANAS)
      // Un grupo sin objetivo no está «a cero»: no hay nada que cumplir, y
      // decir que falla sería inventarse un objetivo que nadie puso.
      if (puestos[grupo] === undefined) {
        sinObjetivo.push({ grupo, estaSemana: series, mediaSemanal })
        continue
      }
      const objetivo = puestos[grupo]
      grupos.push({
        grupo,
        objetivo,
        estaSemana: series,
        mediaSemanal,
        cumplido: series >= objetivo,
        faltan: redondear(Math.max(objetivo - series, 0)),
      })
    }

    return { semanaDesde: clave, semanasDeLaMedia: SEMANAS, grupos, sinObjetivo }
  },

  propuestas_pendientes() {
    const destino = carpetaBuzon()
    let archivos
    try {
      archivos = readdirSync(destino)
    } catch {
      // Sin buzón todavía no hay nada pendiente, que no es un error.
      return { carpeta: destino, pendientes: [] }
    }

    const pendientes = archivos
      .filter((nombre) => nombre.toLowerCase().endsWith('.json'))
      .sort()
      .map((nombre) => {
        try {
          const documento = JSON.parse(readFileSync(join(destino, nombre), 'utf8'))
          return {
            archivo: nombre,
            carpetaDestino: documento.carpeta ?? null,
            rutinas: (documento.rutinas || []).map((r) => r.nombre),
          }
        } catch (error) {
          return { archivo: nombre, ilegible: error.message }
        }
      })

    return { carpeta: destino, pendientes }
  },
}

// ─── Protocolo MCP sobre stdio ───────────────────────────────────────────────
// JSON-RPC 2.0, un mensaje por línea. stdout es SOLO protocolo: cualquier
// traza va a stderr, o el cliente se desincroniza.

function responder(id, resultado) {
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result: resultado }) + '\n')
}

function responderError(id, codigo, mensaje) {
  process.stdout.write(
    JSON.stringify({ jsonrpc: '2.0', id, error: { code: codigo, message: mensaje } }) + '\n'
  )
}

function manejar(mensaje) {
  const { id, method, params } = mensaje

  // Las notificaciones no llevan id y no se responden.
  const esNotificacion = id === undefined || id === null

  // Una notificación (sin id) nunca se responde. Sin esto, un `tools/list`
  // sin id recibía una respuesta sin id y el cliente perdía el hilo.
  if (esNotificacion && method !== 'notifications/initialized' && method !== 'initialized') {
    process.stderr.write(`Notificación ignorada: ${method}\n`)
    return
  }

  switch (method) {
    case 'initialize':
      // Se devuelve la versión que pide el cliente, si la manda: así el
      // servidor no se queda obsoleto cuando el protocolo avanza.
      responder(id, {
        protocolVersion: params?.protocolVersion || '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'entrenos', version: VERSION },
      })
      return

    case 'notifications/initialized':
    case 'initialized':
      return

    case 'ping':
      responder(id, {})
      return

    case 'tools/list':
      responder(id, { tools: HERRAMIENTAS })
      return

    case 'tools/call': {
      const nombre = params?.name
      const ejecutor = EJECUTORES[nombre]
      if (!ejecutor) {
        responderError(id, -32602, `Herramienta desconocida: ${nombre}`)
        return
      }
      try {
        const salida = ejecutor(params?.arguments || {})
        responder(id, {
          content: [{ type: 'text', text: JSON.stringify(salida, null, 2) }],
        })
      } catch (error) {
        // isError deja que Claude vea el fallo y lo explique, en lugar de
        // romper la conversación con un error de protocolo.
        responder(id, {
          content: [{ type: 'text', text: `Error: ${error.message}` }],
          isError: true,
        })
      }
      return
    }

    default:
      responderError(id, -32601, `Método no soportado: ${method}`)
  }
}

let pendiente = ''
process.stdin.setEncoding('utf8')
process.stdin.on('data', (trozo) => {
  pendiente += trozo
  let salto
  while ((salto = pendiente.indexOf('\n')) !== -1) {
    const linea = pendiente.slice(0, salto).trim()
    pendiente = pendiente.slice(salto + 1)
    if (!linea) continue
    try {
      manejar(JSON.parse(linea))
    } catch (error) {
      process.stderr.write(`Mensaje ilegible: ${error.message}\n`)
    }
  }
})
process.stdin.on('end', () => process.exit(0))
