import Foundation
import SwiftData

/// Aplica un borrado pedido desde la carpeta compartida.
///
/// Vive aparte del importador de rutinas porque lo que hace es lo contrario, y
/// mezclarlo haría que un archivo de rutinas pudiera borrar por descuido.
@MainActor
struct BorradorRemoto {
    let contexto: ModelContext

    /// Lo que se borró de verdad, para poder contarlo en el aviso.
    struct Resultado: Equatable {
        var carpetas: [String] = []
        var rutinas: [String] = []
        var entrenos: Int = 0
        var ejercicios: [String] = []

        var huboAlgo: Bool {
            !carpetas.isEmpty || !rutinas.isEmpty || entrenos > 0 || !ejercicios.isEmpty
        }
    }

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    @discardableResult
    func aplicar(_ borrado: BorradoImportado) -> Resultado {
        var resultado = Resultado()

        // Las carpetas primero: al irse se llevan sus rutinas, así que lo que
        // quede en la lista de rutinas ya no las encontrará.
        for nombre in borrado.carpetas {
            for carpeta in carpetas(llamadas: nombre) {
                resultado.carpetas.append(carpeta.nombre)
                // Las rutinas se borran a mano y no por regla de cascada: la
                // relación es `.nullify`, así que borrar solo la carpeta
                // dejaría las rutinas sueltas y el usuario vería aparecer
                // cinco rutinas en «Sin carpeta» justo al limpiar.
                for rutina in carpeta.rutinasOrdenadas {
                    resultado.rutinas.append(rutina.nombre)
                    contexto.delete(rutina)
                }
                contexto.delete(carpeta)
            }
        }

        for nombre in borrado.rutinas {
            for rutina in rutinas(llamadas: nombre) {
                resultado.rutinas.append(rutina.nombre)
                contexto.delete(rutina)
            }
        }

        if borrado.entrenosVacios {
            for entreno in entrenosVacios() {
                resultado.entrenos += 1
                contexto.delete(entreno)
            }
        }

        if borrado.ejerciciosDuplicados {
            for ejercicio in duplicadosSinHistorial() {
                resultado.ejercicios.append(ejercicio.nombre)
                contexto.delete(ejercicio)
            }
        }

        if resultado.huboAlgo {
            try? contexto.save()
        }
        return resultado
    }

    // MARK: - Búsquedas

    /// Se compara con `Ejercicio.normalizar`, el mismo criterio que usa la
    /// importación: quien escribe el archivo no tiene por qué acertar con los
    /// acentos ni con las mayúsculas.
    private func carpetas(llamadas nombre: String) -> [CarpetaRutinas] {
        let buscado = Ejercicio.normalizar(nombre)
        let descriptor = FetchDescriptor<CarpetaRutinas>()
        let todas = (try? contexto.fetch(descriptor)) ?? []
        return todas.filter { Ejercicio.normalizar($0.nombre) == buscado }
    }

    private func rutinas(llamadas nombre: String) -> [Rutina] {
        let buscado = Ejercicio.normalizar(nombre)
        let descriptor = FetchDescriptor<Rutina>()
        let todas = (try? contexto.fetch(descriptor)) ?? []
        return todas.filter { Ejercicio.normalizar($0.nombre) == buscado }
    }

    /// Los ejercicios repetidos que sobran.
    ///
    /// De cada nombre repetido se queda **uno**, y nunca se borra el que tiene
    /// historial: eso partiría sus gráficas y sus récords. Si varios lo
    /// tienen, no se toca ninguno; decidir cuál sobrevive no es algo que deba
    /// hacer un archivo, y fundirlos es otra cosa que esto no hace.
    private func duplicadosSinHistorial() -> [Ejercicio] {
        let todos = (try? contexto.fetch(FetchDescriptor<Ejercicio>())) ?? []
        var porNombre: [String: [Ejercicio]] = [:]
        for ejercicio in todos {
            porNombre[Ejercicio.normalizar(ejercicio.nombre), default: []].append(ejercicio)
        }

        var sobran: [Ejercicio] = []
        for (_, repetidos) in porNombre where repetidos.count > 1 {
            let conHistorial = repetidos.filter { tieneHistorial($0) }
            // Más de uno con historial: se quedan los dos. Menos es peor que
            // de más, porque lo de menos no se puede recuperar.
            guard conHistorial.count <= 1 else { continue }
            let superviviente = conHistorial.first ?? repetidos.min { $0.nombre < $1.nombre }
            sobran += repetidos.filter { $0 !== superviviente }
        }
        return sobran
    }

    private func tieneHistorial(_ ejercicio: Ejercicio) -> Bool {
        let id = ejercicio.idPublico
        var descriptor = FetchDescriptor<EjercicioEntreno>(
            predicate: #Predicate<EjercicioEntreno> { $0.idEjercicio == id }
        )
        descriptor.fetchLimit = 1
        return ((try? contexto.fetch(descriptor))?.isEmpty == false)
    }

    /// Entrenos finalizados sin ninguna serie con algo anotado.
    ///
    /// Se filtra en Swift: lo que decide es `RevisionSerie.estaVacia`, que
    /// depende del tipo de registro del ejercicio, y eso no se puede expresar
    /// en un `#Predicate`.
    private func entrenosVacios() -> [Entreno] {
        let descriptor = FetchDescriptor<Entreno>(
            predicate: #Predicate<Entreno> { $0.estadoRaw == rawEntrenoFinalizado }
        )
        let todos = (try? contexto.fetch(descriptor)) ?? []
        return todos.filter(\.sinNadaRegistrado)
    }
}
