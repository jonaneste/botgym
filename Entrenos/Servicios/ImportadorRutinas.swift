import Foundation
import SwiftData

/// Aplica a SwiftData unas rutinas ya leídas y validadas.
///
/// La validación del JSON vive en el núcleo. Aquí solo queda casar los nombres
/// de ejercicio con la biblioteca y escribir.
@MainActor
struct ImportadorRutinas {
    let contexto: ModelContext

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    /// Lo que hay que resolver antes de poder importar.
    struct Revision {
        var rutinas: RutinasImportadas
        /// Nombres que no están en la biblioteca, con sus parecidos.
        var desconocidos: [NombreDesconocido]

        var todoResuelto: Bool { desconocidos.isEmpty }
    }

    struct NombreDesconocido: Identifiable {
        var id: String { nombre }
        var nombre: String
        /// Ejercicios de la biblioteca con un nombre parecido.
        var parecidos: [Ejercicio]
    }

    /// Resultado de una importación.
    struct Resultado {
        var rutinasCreadas: Int
        var ejerciciosCreados: Int
        var carpeta: String?
    }

    // MARK: - Revisar

    /// Comprueba qué nombres de ejercicio no existen todavía.
    func revisar(_ rutinas: RutinasImportadas) -> Revision {
        let repositorio = RepositorioEntrenos(contexto: contexto)
        let biblioteca = repositorio.ejercicios()
        let indice = Dictionary(
            biblioteca.map { ($0.nombreNormalizado, $0) },
            uniquingKeysWith: { primero, _ in primero }
        )

        var desconocidos: [NombreDesconocido] = []
        for nombre in rutinas.nombresDeEjercicio {
            let clave = Ejercicio.normalizar(nombre)
            guard indice[clave] == nil else { continue }
            desconocidos.append(
                NombreDesconocido(nombre: nombre, parecidos: parecidos(a: clave, en: biblioteca))
            )
        }
        return Revision(rutinas: rutinas, desconocidos: desconocidos)
    }

    /// Ejercicios de la biblioteca cuyo nombre se parece al buscado.
    ///
    /// Se usa coincidencia por palabras y no distancia de edición: "press
    /// inclinado mancuernas" y "press inclinado con mancuernas" comparten tres
    /// palabras, que es la clase de diferencia que mete una IA al generar
    /// rutinas.
    private func parecidos(a clave: String, en biblioteca: [Ejercicio], maximo: Int = 3) -> [Ejercicio] {
        let palabrasBuscadas = Set(clave.split(separator: " ").map(String.init)).filter { $0.count > 2 }
        guard !palabrasBuscadas.isEmpty else { return [] }

        let puntuados = biblioteca.compactMap { ejercicio -> (Ejercicio, Int)? in
            let palabras = Set(ejercicio.nombreNormalizado.split(separator: " ").map(String.init))
            let comunes = palabrasBuscadas.intersection(palabras).count
            return comunes > 0 ? (ejercicio, comunes) : nil
        }

        return puntuados
            .sorted { izquierda, derecha in
                izquierda.1 != derecha.1
                    ? izquierda.1 > derecha.1
                    : izquierda.0.nombre < derecha.0.nombre
            }
            .prefix(maximo)
            .map(\.0)
    }

    // MARK: - Importar

    /// Escribe las rutinas.
    ///
    /// - Parameter mapeo: para cada nombre desconocido, el ejercicio existente
    ///   al que apuntarlo. Los que no estén en el mapeo se crean nuevos.
    @discardableResult
    func importar(_ rutinas: RutinasImportadas, mapeo: [String: Ejercicio] = [:]) -> Resultado {
        let repositorio = RepositorioEntrenos(contexto: contexto)
        let ajustes = Ajustes.cargar(en: contexto)

        var indice = Dictionary(
            repositorio.ejercicios().map { ($0.nombreNormalizado, $0) },
            uniquingKeysWith: { primero, _ in primero }
        )
        for (nombre, ejercicio) in mapeo {
            indice[Ejercicio.normalizar(nombre)] = ejercicio
        }

        var ejerciciosCreados = 0
        let carpeta = carpetaDestino(rutinas.carpeta, repositorio: repositorio)

        for (indiceRutina, definicion) in rutinas.rutinas.enumerated() {
            let orden = (carpeta?.rutinas.count ?? repositorio.rutinasSueltas().count) + indiceRutina
            let rutina = Rutina(nombre: definicion.nombre, notas: definicion.notas, orden: orden)
            contexto.insert(rutina)
            rutina.carpeta = carpeta

            var idsSuperserie: [String: UUID] = [:]

            for (posicion, elementoDef) in definicion.ejercicios.enumerated() {
                let clave = Ejercicio.normalizar(elementoDef.nombre)
                let ejercicio: Ejercicio
                if let existente = indice[clave] {
                    ejercicio = existente
                } else {
                    ejercicio = crear(nombre: elementoDef.nombre, esTiempo: elementoDef.esTiempo)
                    contexto.insert(ejercicio)
                    indice[clave] = ejercicio
                    ejerciciosCreados += 1
                }

                var idSuperserie: UUID?
                if let etiqueta = elementoDef.etiquetaSuperserie {
                    if let existente = idsSuperserie[etiqueta] {
                        idSuperserie = existente
                    } else {
                        let nuevo = UUID()
                        idsSuperserie[etiqueta] = nuevo
                        idSuperserie = nuevo
                    }
                }

                let elemento = ElementoRutina(
                    ejercicio: ejercicio,
                    orden: posicion,
                    seriesObjetivo: elementoDef.series,
                    objetivoMin: elementoDef.objetivoMin,
                    objetivoMax: elementoDef.objetivoMax,
                    rirMin: elementoDef.rirMin ?? ajustes.rirPorDefectoMin,
                    rirMax: elementoDef.rirMax ?? ajustes.rirPorDefectoMax,
                    descansoSegundos: elementoDef.descansoSegundos,
                    notas: elementoDef.notas,
                    idSuperserie: idSuperserie
                )
                contexto.insert(elemento)
                elemento.rutina = rutina
            }
        }

        try? contexto.save()

        return Resultado(
            rutinasCreadas: rutinas.rutinas.count,
            ejerciciosCreados: ejerciciosCreados,
            carpeta: carpeta?.nombre
        )
    }

    /// Un ejercicio nuevo nacido de una importación.
    ///
    /// No se intenta adivinar el grupo muscular ni el material a partir del
    /// nombre: una suposición mala contamina el recuento semanal en silencio.
    /// Se marca como personalizado para que destaque en la biblioteca y lo
    /// puedas completar.
    private func crear(nombre: String, esTiempo: Bool) -> Ejercicio {
        Ejercicio(
            nombre: nombre,
            grupoPrincipal: .core,
            gruposSecundarios: [],
            material: .otro,
            tipoRegistro: esTiempo ? .tiempo : .repeticiones,
            notas: "Creado al importar. Revisa el grupo muscular y el material.",
            esPersonalizado: true
        )
    }

    private func carpetaDestino(_ nombre: String?, repositorio: RepositorioEntrenos) -> CarpetaRutinas? {
        guard let nombre, !nombre.isEmpty else { return nil }
        let existentes = repositorio.carpetas()
        if let existente = existentes.first(where: {
            Ejercicio.normalizar($0.nombre) == Ejercicio.normalizar(nombre)
        }) {
            return existente
        }
        let nueva = CarpetaRutinas(nombre: nombre, orden: existentes.count)
        contexto.insert(nueva)
        return nueva
    }
}
