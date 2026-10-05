import Foundation
import SwiftData

/// Carpeta que agrupa rutinas, por ejemplo "Rutina 5 días" o "Bloque otoño".
@Model
final class CarpetaRutinas {
    var idPublico: UUID = UUID()
    var nombre: String = ""
    /// Posición en la lista. SwiftData no conserva el orden de las relaciones
    /// a muchos, así que el orden siempre es explícito y se ordena en Swift.
    var orden: Int = 0
    var fechaCreacion: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Rutina.carpeta)
    var rutinas: [Rutina] = []

    init(nombre: String, orden: Int = 0) {
        self.idPublico = UUID()
        self.nombre = nombre
        self.orden = orden
        self.fechaCreacion = Date()
    }

    /// Rutinas en su orden real.
    var rutinasOrdenadas: [Rutina] {
        rutinas.sorted { $0.orden < $1.orden }
    }
}
