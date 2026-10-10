#!/usr/bin/env node
/**
 * Prueba del servidor MCP: le habla el protocolo real por stdio y comprueba
 * las respuestas.
 *
 * Sin dependencias, como el servidor. Se ejecuta con:
 *   node mcp/prueba.mjs
 */

import { spawn } from 'node:child_process'
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const aqui = dirname(fileURLToPath(import.meta.url))
const SERVIDOR = join(aqui, 'servidor-entrenos.mjs')
const EJEMPLO = join(aqui, 'ejemplo', 'entrenos.json')

// ─── Fixture generado, no fijo ───────────────────────────────────────────────
// Las fechas se calculan a partir de HOY. Con fechas absolutas, las
// comprobaciones sobre "las últimas N semanas" dejan de cumplirse al pasar el
// tiempo y la prueba empieza a fallar sola, sin que nadie haya tocado nada.

function inicioSemanaLocal(fecha) {
  const d = new Date(fecha)
  d.setHours(0, 0, 0, 0)
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
  return d
}

function sinZona(d) {
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(
    d.getMinutes()
  )}:00Z`
}

/** Lunes de hace `semanasAtras` semanas, a la hora indicada. */
function diaDeSemana(semanasAtras, diaDentroDeLaSemana = 0, hora = 18) {
  const d = inicioSemanaLocal(new Date())
  d.setDate(d.getDate() - semanasAtras * 7 + diaDentroDeLaSemana)
  d.setHours(hora, 0, 0, 0)
  return d
}

function serie(orden, peso, repeticiones, { rir = 2, calentamiento = false, segundos = null } = {}) {
  return { orden, peso, repeticiones, segundos, rir, calentamiento }
}

function generarFixture() {
  // Tres semanas de press banca progresando: 60 kg, luego 60 a más reps, luego 62,5.
  const progresion = [
    { semanasAtras: 2, peso: 60, repes: [9, 9, 8, 8], notas: '' },
    { semanasAtras: 1, peso: 60, repes: [10, 10, 10, 10], notas: 'Buenas sensaciones' },
    { semanasAtras: 0, peso: 62.5, repes: [8, 8, 8, 7], notas: '' },
  ]

  const entrenos = progresion.map(({ semanasAtras, peso, repes, notas }, i) => {
    const inicio = diaDeSemana(semanasAtras)
    const fin = new Date(inicio.getTime() + 72 * 60000)
    return {
      id: `00000000-0000-0000-0000-00000000000${i}`,
      nombre: 'Lunes – Empuje',
      fechaInicio: sinZona(inicio),
      fechaFin: sinZona(fin),
      rutinaOrigen: 'Lunes – Empuje',
      notas,
      // La molestia solo en el más reciente, que es el que lee la prueba.
      molestiaHombro: semanasAtras === 0 ? 3 : null,
      molestiaRodilla: null,
      ejercicios: [
        {
          nombre: 'Press banca con barra',
          grupoPrincipal: 'pecho',
          gruposSecundarios: ['hombroAnterior', 'triceps'],
          tipoRegistro: 'repeticiones',
          notas: '',
          superserie: null,
          // Calentamiento de 40 kg × 15: tiene que quedar fuera de todo.
          series: [
            serie(0, 40, 15, { calentamiento: true }),
            ...repes.map((r, j) => serie(j + 1, peso, r)),
          ],
        },
        {
          nombre: 'Elevaciones laterales',
          grupoPrincipal: 'hombroLateral',
          gruposSecundarios: [],
          tipoRegistro: 'repeticiones',
          notas: '',
          superserie: null,
          series: [0, 1, 2, 3].map((j) => serie(j, 10, 14)),
        },
      ],
    }
  })

  // Una carrera por semana, el miércoles, siempre a 5:00 /km exactos.
  const carreras = [2, 1, 0].map((semanasAtras, i) => {
    const km = 6 + i * 0.4
    const segundos = km * 300
    return {
      id: `run-${i}`,
      fecha: sinZona(diaDeSemana(semanasAtras, 2, 9)),
      duracionSegundos: segundos,
      distanciaKm: km,
      ritmoSegundosPorKm: 300,
      pulsoMedio: 150 - i,
      calorias: 420,
      origen: 'Zepp',
    }
  })

  return {
    version: 1,
    generado: sinZona(new Date()),
    app: 'Entrenos',
    ejercicios: [
      {
        id: '11111111-1111-1111-1111-111111111111',
        nombre: 'Press banca con barra',
        grupoPrincipal: 'pecho',
        gruposSecundarios: ['hombroAnterior', 'triceps'],
        material: 'barra',
        tipoRegistro: 'repeticiones',
        esPersonalizado: false,
        notas: '',
      },
    ],
    carpetas: [
      {
        nombre: 'Rutina 5 días',
        rutinas: [
          {
            nombre: 'Lunes – Empuje',
            notas: '',
            ejercicios: [
              { nombre: 'Press banca con barra', series: 4, reps: '8-10', rir: '2-3', descanso: 150, notas: '', superserie: null },
              { nombre: 'Elevaciones laterales', series: 4, reps: '12-15', rir: '1-2', descanso: 60, notas: '', superserie: null },
            ],
          },
        ],
      },
    ],
    entrenos,
    carreras,
  }
}

const carpetaTemporal = mkdtempSync(join(tmpdir(), 'entrenos-prueba-'))
const DATOS = join(carpetaTemporal, 'entrenos.json')
writeFileSync(DATOS, JSON.stringify(generarFixture(), null, 2), 'utf8')

const fallos = []
let comprobaciones = 0

function comprobar(condicion, descripcion) {
  comprobaciones++
  if (!condicion) fallos.push(descripcion)
}

function hablarConElServidor(mensajes, entornoExtra = {}) {
  return new Promise((resolve, reject) => {
    const proceso = spawn('node', [SERVIDOR], {
      env: { ...process.env, ENTRENOS_JSON: DATOS, ...entornoExtra },
      stdio: ['pipe', 'pipe', 'pipe'],
    })
    let salida = ''
    let errores = ''
    proceso.stdout.on('data', (d) => (salida += d))
    proceso.stderr.on('data', (d) => (errores += d))
    proceso.on('error', reject)
    proceso.on('close', () => {
      const respuestas = salida
        .trim()
        .split('\n')
        .filter(Boolean)
        .map((l) => JSON.parse(l))
      resolve({ respuestas, errores })
    })
    proceso.stdin.write(mensajes.map((m) => JSON.stringify(m) + '\n').join(''))
    proceso.stdin.end()
  })
}

function llamar(id, nombre, argumentos = {}) {
  return { jsonrpc: '2.0', id, method: 'tools/call', params: { name: nombre, arguments: argumentos } }
}

function contenido(respuesta) {
  return JSON.parse(respuesta.result.content[0].text)
}

// ─── Pruebas ─────────────────────────────────────────────────────────────────

const { respuestas, errores } = await hablarConElServidor([
  { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {} } },
  { jsonrpc: '2.0', method: 'notifications/initialized' },
  { jsonrpc: '2.0', id: 2, method: 'tools/list' },
  { jsonrpc: '2.0', id: 3, method: 'ping' },
  llamar(4, 'resumen_general'),
  llamar(5, 'resumen_semanal', { semanas: 4 }),
  llamar(6, 'historial_ejercicio', { nombre: 'press banca' }),
  llamar(7, 'records'),
  llamar(8, 'ultimos_entrenos', { limite: 2 }),
  llamar(9, 'rutinas'),
  llamar(10, 'carreras', { semanas: 4 }),
  llamar(11, 'no_existe'),
  llamar(12, 'historial_ejercicio', { nombre: 'ejercicio inventado' }),
  { jsonrpc: '2.0', id: 13, method: 'metodo/inventado' },
  llamar(14, 'ejercicios_disponibles'),
  llamar(15, 'ejercicios_disponibles', { material: 'mancuerna' }),
  llamar(16, 'ejercicios_disponibles', { grupo: 'inventado' }),
  llamar(17, 'ajustes'),
])

const por = Object.fromEntries(respuestas.map((r) => [r.id, r]))

// Una notificación no se responde: 14 mensajes, 13 respuestas.
comprobar(respuestas.length === 13, `se esperaban 13 respuestas, llegaron ${respuestas.length}`)
comprobar(
  respuestas.every((r) => r.jsonrpc === '2.0'),
  'alguna respuesta no lleva jsonrpc 2.0'
)

// initialize devuelve la versión que pidió el cliente.
comprobar(por[1].result.protocolVersion === '2025-06-18', 'initialize no devuelve la versión pedida')
comprobar(por[1].result.serverInfo.name === 'entrenos', 'serverInfo.name inesperado')
comprobar(por[1].result.capabilities.tools !== undefined, 'no declara capability de tools')

// tools/list: todas con descripción y esquema de objeto.
const herramientas = por[2].result.tools
comprobar(herramientas.length === 7, `se esperaban 7 herramientas, hay ${herramientas.length}`)
for (const t of herramientas) {
  comprobar(typeof t.description === 'string' && t.description.length > 20, `${t.name}: descripción pobre`)
  comprobar(t.inputSchema?.type === 'object', `${t.name}: inputSchema no es object`)
}

comprobar(JSON.stringify(por[3].result) === '{}', 'ping no responde vacío')

// resumen_general sobre los datos de ejemplo: 3 entrenos, 3 carreras.
const general = contenido(por[4])
comprobar(general.entrenos === 3, `resumen_general.entrenos = ${general.entrenos}, esperado 3`)
comprobar(general.carreras === 3, `resumen_general.carreras = ${general.carreras}, esperado 3`)
comprobar(general.ejerciciosDistintos === 2, `ejerciciosDistintos = ${general.ejerciciosDistintos}`)
// Series efectivas: por entreno, 4 de press + 4 de laterales = 8; el
// calentamiento no cuenta. Tres entrenos → 24.
comprobar(general.seriesTotales === 24, `seriesTotales = ${general.seriesTotales}, esperado 24`)

// resumen_semanal: 4 semanas, y los secundarios cuentan 0,5.
const semanal = contenido(por[5])
comprobar(Array.isArray(semanal) && semanal.length === 4, `semanal tiene ${semanal.length} semanas`)
const conDatos = semanal.filter((s) => s.entrenos > 0)
comprobar(conDatos.length === 3, `semanas con entrenos = ${conDatos.length}, esperado 3`)
const grupos = conDatos[0].seriesPorGrupo
comprobar(grupos.pecho.series === 4, `pecho = ${grupos.pecho.series}, esperado 4`)
comprobar(grupos.triceps.series === 2, `triceps = ${grupos.triceps.series}, esperado 2 (4 series × 0,5)`)
comprobar(grupos.hombroLateral.series === 4, `hombroLateral = ${grupos.hombroLateral.series}, esperado 4`)

// El objetivo se cruza desde los ajustes: 4 de 12 no está cumplido.
comprobar(grupos.pecho.objetivo === 12, `objetivo de pecho = ${grupos.pecho.objetivo}, esperado 12`)
comprobar(grupos.pecho.cumplido === false, 'pecho sale como cumplido con 4 de 12')
// Un grupo con objetivo y sin ninguna serie tiene que aparecer igualmente:
// es justo la semana que te saltaste ese grupo.
comprobar(
  grupos.cuadriceps && grupos.cuadriceps.series === 0 && grupos.cuadriceps.cumplido === false,
  'un grupo con objetivo y cero series no aparece'
)
// Y uno sin objetivo configurado no se inventa ninguno.
comprobar(
  grupos.hombroLateral.objetivo === undefined,
  'se inventa un objetivo para un grupo que no lo tiene'
)

// El calentamiento de 40 kg × 15 no debe aparecer en el historial.
const historial = contenido(por[6])
comprobar(Array.isArray(historial) && historial.length === 1, 'historial_ejercicio no encuentra uno solo')
const sesiones = historial[0].sesiones
comprobar(sesiones.length === 3, `sesiones = ${sesiones.length}, esperado 3`)
comprobar(
  sesiones.every((s) => s.series.length === 4),
  'alguna sesión incluye el calentamiento'
)
comprobar(
  sesiones.every((s) => !s.series.some((t) => t.startsWith('40 kg'))),
  'el calentamiento de 40 kg aparece en las series'
)
// Más reciente primero, y en esa sesión el peso fue 62,5.
comprobar(sesiones[0].pesoMaximoKg === 62.5, `pesoMaximoKg más reciente = ${sesiones[0].pesoMaximoKg}`)
comprobar(
  new Date(sesiones[0].fecha) > new Date(sesiones[1].fecha),
  'las sesiones no van de más reciente a más antigua'
)
// Epley: 60 × 10 = 80 es mejor que 62,5 × 8 = 79,17.
const mejor = Math.max(...sesiones.map((s) => s.unRMEstimado))
comprobar(Math.abs(mejor - 80) < 0.05, `mejor 1RM = ${mejor}, esperado 80`)

// records
const records = contenido(por[7])
const press = records.find((r) => r.ejercicio === 'Press banca con barra')
comprobar(press !== undefined, 'records no incluye el press banca')
comprobar(press.pesoMaximoKg === 62.5, `record de peso = ${press.pesoMaximoKg}, esperado 62,5`)
comprobar(Math.abs(press.mejorUnRM - 80) < 0.05, `record de 1RM = ${press.mejorUnRM}, esperado 80`)

// ultimos_entrenos trae notas y molestias.
const ultimos = contenido(por[8])
comprobar(ultimos.length === 2, `ultimos_entrenos devolvió ${ultimos.length}, esperado 2`)
comprobar(ultimos[0].molestiaHombro === 3, `molestiaHombro = ${ultimos[0].molestiaHombro}, esperado 3`)
comprobar(ultimos[0].duracionMinutos === 72, `duracionMinutos = ${ultimos[0].duracionMinutos}`)

// rutinas trae los objetivos.
const rutinas = contenido(por[9])
comprobar(rutinas[0].carpeta === 'Rutina 5 días', 'la carpeta de la rutina no coincide')
comprobar(rutinas[0].rutinas[0].ejercicios[0].reps === '8-10', 'el rango objetivo no coincide')

// carreras, con ritmo formateado.
const carreras = contenido(por[10])
comprobar(carreras.carreras.length === 3, `carreras = ${carreras.carreras.length}, esperado 3`)
comprobar(/^\d+:\d{2} \/km$/.test(carreras.carreras[0].ritmo), `ritmo mal formateado: ${carreras.carreras[0].ritmo}`)

// Errores: herramienta desconocida y método desconocido.
comprobar(por[11].error?.code === -32602, 'una herramienta desconocida no da -32602')
comprobar(por[13].error?.code === -32601, 'un método desconocido no da -32601')

// Un ejercicio que no existe no es un error de protocolo: se responde con
// contenido útil para que Claude pueda decir qué sí hay.
comprobar(por[12].result !== undefined, 'un ejercicio inexistente rompe el protocolo')
const vacio = contenido(por[12])
comprobar(vacio.error !== undefined, 'no explica que no encontró el ejercicio')
comprobar(Array.isArray(vacio.ejerciciosConHistorial), 'no sugiere qué ejercicios sí existen')

// Sin archivo: error manejado, no caída.
const sinArchivo = await hablarConElServidor(
  [
    { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {} } },
    llamar(2, 'resumen_general'),
  ],
  { ENTRENOS_JSON: '/ruta/que/no/existe.json' }
)
const respSinArchivo = sinArchivo.respuestas.find((r) => r.id === 2)
comprobar(respSinArchivo?.result?.isError === true, 'sin archivo no marca isError')
comprobar(
  respSinArchivo?.result?.content?.[0]?.text?.includes('No encuentro'),
  'el error de archivo ausente no se explica'
)

comprobar(errores.trim() === '', `el servidor escribió en stderr: ${errores.trim().slice(0, 120)}`)

// El ejemplo estático al que apunta el README tiene que seguir siendo un JSON
// con la forma que emite la app: se usa en la documentación, así que si deja de
// parsearse la primera prueba que haga el usuario fallará.
const ejemplo = JSON.parse(readFileSync(EJEMPLO, 'utf8'))
comprobar(ejemplo.version === 1, 'el ejemplo del README no declara version 1')
comprobar(Array.isArray(ejemplo.entrenos) && ejemplo.entrenos.length > 0, 'el ejemplo no tiene entrenos')
for (const entreno of ejemplo.entrenos) {
  for (const ejercicio of entreno.ejercicios) {
    for (const s of ejercicio.series) {
      comprobar(
        typeof s.peso === 'number' && typeof s.repeticiones === 'number' && typeof s.orden === 'number',
        `el ejemplo tiene una serie con campos de tipo incorrecto: ${JSON.stringify(s)}`
      )
    }
    // El calentamiento del ejemplo es el de 40 kg: si se descoloca, la
    // comprobación de que no contamina el historial se vuelve vacua.
    const calentamientos = ejercicio.series.filter((s) => s.calentamiento)
    for (const c of calentamientos) {
      comprobar(c.peso === 40 && c.repeticiones === 15, `calentamiento del ejemplo mal formado: ${JSON.stringify(c)}`)
    }
  }
}

// ─── Las herramientas nuevas: catálogo y ajustes ─────────────────────────────

// El catálogo lista TODOS los ejercicios, también los que nunca se han hecho.
// Eso es lo que lo distingue de `historial_ejercicio`, y lo que permite
// proponer una rutina sin inventarse ejercicios que no existen en la app.
const catalogo = contenido(por[14])
comprobar(catalogo.total === 3, `catálogo con ${catalogo.total} ejercicios, esperado 3`)
const curl = catalogo.ejercicios.find((e) => e.nombre === 'Curl martillo')
comprobar(curl !== undefined, 'el catálogo no incluye un ejercicio sin historial')
comprobar(curl && curl.ultimaVez === null, 'un ejercicio nunca hecho tiene fecha de última vez')
const press = catalogo.ejercicios.find((e) => e.nombre === 'Press banca con barra')
comprobar(press && press.ultimaVez !== null, 'un ejercicio con historial no trae su última vez')
comprobar(
  catalogo.ejercicios.every((e, i, a) => i === 0 || a[i - 1].nombre.localeCompare(e.nombre, 'es') <= 0),
  'el catálogo no viene ordenado por nombre'
)

const mancuernas = contenido(por[15])
comprobar(mancuernas.total === 2, `filtro por material devuelve ${mancuernas.total}, esperado 2`)
comprobar(
  mancuernas.ejercicios.every((e) => e.material === 'mancuerna'),
  'el filtro por material deja pasar otro material'
)

// Con un filtro sin resultados hay que decirlo, porque el error caro es
// inventarse un ejercicio para rellenar el hueco.
const vacio = contenido(por[16])
comprobar(vacio.total === 0, `filtro inventado devuelve ${vacio.total}, esperado 0`)
comprobar(typeof vacio.nota === 'string' && vacio.nota.length > 0, 'un filtro sin resultados no avisa')

const ajustes = contenido(por[17])
comprobar(ajustes.disponible === true, 'los ajustes del ejemplo no se leen')
comprobar(ajustes.objetivosSemanales.pecho === 12, `objetivo de pecho = ${ajustes.objetivosSemanales.pecho}`)
comprobar(ajustes.incrementos.barraKg === 2.5, `incremento de barra = ${ajustes.incrementos.barraKg}`)
comprobar(ajustes.pesoCorporalKg === 78.5, `peso corporal = ${ajustes.pesoCorporalKg}`)
// Es el dato por el que existe la herramienta: entre 20 y 22,5 no hay nada.
comprobar(
  ajustes.mancuernasDisponiblesKg.includes(22.5) && !ajustes.mancuernasDisponiblesKg.includes(21),
  'las mancuernas disponibles no son las del ejemplo'
)

// ─── Resultado ───────────────────────────────────────────────────────────────

if (fallos.length > 0) {
  console.error(`FALLO: ${fallos.length} de ${comprobaciones} comprobaciones\n`)
  for (const f of fallos) console.error(`  - ${f}`)
  process.exit(1)
}
console.log(`OK: ${comprobaciones} comprobaciones del servidor MCP`)
