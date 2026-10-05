import Foundation
import SwiftData

/// Construye los archivos de exportación a partir de SwiftData.
@MainActor
struct ServicioExportacion {
    let contexto: ModelContext

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    // MARK: - Construir el modelo de exportación

    func construir() -> ExportacionCompleta {
        let repositorio = RepositorioEntrenos(contexto: contexto)

        let ejercicios = repositorio.ejercicios().map { ejercicio in
            EjercicioExportado(
                id: ejercicio.idPublico,
                nombre: ejercicio.nombre,
                grupoPrincipal: ejercicio.grupoPrincipal.rawValue,
                gruposSecundarios: ejercicio.gruposSecundarios.map(\.rawValue),
                material: ejercicio.material.rawValue,
                tipoRegistro: ejercicio.tipoRegistro.rawValue,
                esPersonalizado: ejercicio.esPersonalizado,
                notas: ejercicio.notas
            )
        }

        let carpetas = repositorio.carpetas().map { carpeta in
            CarpetaExportada(
                nombre: carpeta.nombre,
                rutinas: carpeta.rutinasOrdenadas.map(exportar(rutina:))
            )
        }

        // Las rutinas sin carpeta van en una carpeta sintética, para que el
        // formato tenga una sola forma y el importador no necesite dos ramas.
        let sueltas = repositorio.rutinasSueltas()
        let todasLasCarpetas = sueltas.isEmpty
            ? carpetas
            : carpetas + [CarpetaExportada(nombre: "Sin carpeta", rutinas: sueltas.map(exportar(rutina:)))]

        let entrenos = repositorio.entrenosFinalizados().map(exportar(entreno:))

        // Las carreras salen del caché, que es lo que haya llegado de Salud
        // o del archivo importado.
        CacheCarreras.compartida.cargarSiHaceFalta()
        let carreras = CacheCarreras.compartida.carreras.map(CarreraExportada.init(de:))

        return ExportacionCompleta(
            ejercicios: ejercicios,
            carpetas: todasLasCarpetas,
            entrenos: entrenos,
            carreras: carreras
        )
    }

    private func exportar(rutina: Rutina) -> RutinaExportada {
        // Las etiquetas de superserie se renumeran a A, B, C: los UUID
        // internos no significan nada fuera de la app.
        var etiquetas: [UUID: String] = [:]
        let letras = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for (indice, id) in rutina.gruposSuperserie.enumerated() {
            etiquetas[id] = indice < letras.count ? String(letras[indice]) : "G\(indice + 1)"
        }

        return RutinaExportada(
            nombre: rutina.nombre,
            notas: rutina.notas,
            ejercicios: rutina.elementosOrdenados.map { elemento in
                ElementoExportado(
                    nombre: elemento.ejercicio?.nombre ?? "Ejercicio borrado",
                    series: elemento.seriesObjetivo,
                    reps: SerializadorExportacion.textoReps(
                        min: elemento.objetivoMin,
                        max: elemento.objetivoMax,
                        esTiempo: elemento.tipoRegistro.esTiempo
                    ),
                    rir: SerializadorExportacion.textoRIR(min: elemento.rirMin, max: elemento.rirMax),
                    descanso: elemento.descansoSegundos,
                    notas: elemento.notas,
                    superserie: elemento.idSuperserie.flatMap { etiquetas[$0] }
                )
            }
        )
    }

    private func exportar(entreno: Entreno) -> EntrenoExportado {
        var etiquetas: [UUID: String] = [:]
        let letras = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var siguiente = 0
        for ejercicio in entreno.ejerciciosOrdenados {
            guard let id = ejercicio.idSuperserie, etiquetas[id] == nil else { continue }
            etiquetas[id] = siguiente < letras.count ? String(letras[siguiente]) : "G\(siguiente + 1)"
            siguiente += 1
        }

        return EntrenoExportado(
            id: entreno.idPublico,
            nombre: entreno.nombre,
            fechaInicio: entreno.fechaInicio,
            fechaFin: entreno.fechaFin,
            rutinaOrigen: entreno.nombreRutinaOrigen,
            notas: entreno.notas,
            molestiaHombro: entreno.molestiaHombro,
            molestiaRodilla: entreno.molestiaRodilla,
            ejercicios: entreno.ejerciciosOrdenados.map { ejercicio in
                EjercicioEntrenoExportado(
                    nombre: ejercicio.nombreEjercicio,
                    grupoPrincipal: ejercicio.ejercicio?.grupoPrincipal.rawValue,
                    gruposSecundarios: ejercicio.ejercicio?.gruposSecundarios.map(\.rawValue) ?? [],
                    tipoRegistro: ejercicio.tipoRegistro.rawValue,
                    notas: ejercicio.notas,
                    superserie: ejercicio.idSuperserie.flatMap { etiquetas[$0] },
                    series: ejercicio.seriesOrdenadas.map { serie in
                        SerieExportada(
                            orden: serie.orden,
                            peso: serie.peso,
                            repeticiones: serie.repeticiones,
                            segundos: serie.segundos,
                            rir: serie.rir,
                            calentamiento: serie.esCalentamiento
                        )
                    }
                )
            }
        )
    }

    // MARK: - Escribir archivos

    /// Escribe el JSON en un archivo temporal y devuelve su URL, lista para la
    /// hoja de compartir.
    func archivoJSON() throws -> URL {
        let datos = try SerializadorExportacion.json(construir())
        return try escribir(datos, nombre: "entrenos-\(marcaDeTiempo()).json")
    }

    func archivoCSV() throws -> URL {
        let texto = GeneradorCSV.generar(construir())
        guard let datos = texto.data(using: .utf8) else {
            throw ErrorExportacion.noSePudoCodificar
        }
        return try escribir(datos, nombre: "entrenos-\(marcaDeTiempo()).csv")
    }

    /// Exporta solo las rutinas, en el formato que lee el importador. Sirve
    /// para pasarle tus rutinas a una IA y pedirle variaciones.
    func archivoRutinasJSON() throws -> URL {
        let completa = construir()
        var salida: [String: Any] = ["version": LectorRutinasJSON.versionSoportada]
        var rutinas: [[String: Any]] = []

        for carpeta in completa.carpetas {
            for rutina in carpeta.rutinas {
                var objeto: [String: Any] = ["nombre": rutina.nombre, "ejercicios": []]
                if !rutina.notas.isEmpty { objeto["notas"] = rutina.notas }
                objeto["ejercicios"] = rutina.ejercicios.map { elemento -> [String: Any] in
                    var salida: [String: Any] = ["nombre": elemento.nombre, "series": elemento.series]
                    if let reps = elemento.reps { salida["reps"] = reps }
                    if let rir = elemento.rir { salida["rir"] = rir }
                    salida["descanso"] = elemento.descanso
                    if !elemento.notas.isEmpty { salida["notas"] = elemento.notas }
                    if let superserie = elemento.superserie { salida["superserie"] = superserie }
                    return salida
                }
                rutinas.append(objeto)
            }
        }
        salida["rutinas"] = rutinas

        let datos = try JSONSerialization.data(
            withJSONObject: salida,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return try escribir(datos, nombre: "rutinas-\(marcaDeTiempo()).json")
    }

    private func escribir(_ datos: Data, nombre: String) throws -> URL {
        let carpeta = FileManager.default.temporaryDirectory
            .appendingPathComponent("Exportaciones", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let url = carpeta.appendingPathComponent(nombre)
        try datos.write(to: url, options: .atomic)
        return url
    }

    private func marcaDeTiempo() -> String {
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.dateFormat = "yyyy-MM-dd-HHmm"
        return formateador.string(from: Date())
    }
}

enum ErrorExportacion: LocalizedError {
    case noSePudoCodificar

    var errorDescription: String? {
        switch self {
        case .noSePudoCodificar:
            return "No se pudo codificar el archivo en UTF-8."
        }
    }
}
