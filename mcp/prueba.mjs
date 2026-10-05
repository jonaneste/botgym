#!/usr/bin/env node
/**
 * Prueba del servidor MCP: le habla el protocolo real por stdio y comprueba
 * las respuestas.
 *
 * Sin dependencias, como el servidor. Se ejecuta con:
 *   node mcp/prueba.mjs
 */

import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const aqui = dirname(fileURLToPath(import.meta.url))
const SERVIDOR = join(aqui, 'servidor-entrenos.mjs')
const DATOS = join(aqui, 'ejemplo', 'entrenos.json')

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
comprobar(grupos.pecho === 4, `pecho = ${grupos.pecho}, esperado 4`)
comprobar(grupos.triceps === 2, `triceps = ${grupos.triceps}, esperado 2 (4 series × 0,5)`)
comprobar(grupos.hombroLateral === 4, `hombroLateral = ${grupos.hombroLateral}, esperado 4`)

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

// ─── Resultado ───────────────────────────────────────────────────────────────

if (fallos.length > 0) {
  console.error(`FALLO: ${fallos.length} de ${comprobaciones} comprobaciones\n`)
  for (const f of fallos) console.error(`  - ${f}`)
  process.exit(1)
}
console.log(`OK: ${comprobaciones} comprobaciones del servidor MCP`)
