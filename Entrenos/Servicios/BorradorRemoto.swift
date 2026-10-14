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

        var huboAlgo: Bool { !carpetas.isEmpty || !rutinas.isEmpty || entrenos > 0 }
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
