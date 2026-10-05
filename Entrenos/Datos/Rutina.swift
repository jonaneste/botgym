import Foundation
import SwiftData

/// Una rutina: lista ordenada de ejercicios con sus objetivos.
@Model
final class Rutina {
    var idPublico: UUID = UUID()
    var nombre: String = ""
    var notas: String = ""
    var orden: Int = 0
    var fechaCreacion: Date = Date()

    var carpeta: CarpetaRutinas?

    @Relationship(deleteRule: .cascade, inverse: \ElementoRutina.rutina)
    var elementos: [ElementoRutina] = []

    init(nombre: String, notas: String = "", orden: Int = 0) {
        self.idPublico = UUID()
        self.nombre = nombre
        self.notas = notas
        self.orden = orden
        self.fechaCreacion = Date()
    }

    /// Elementos en su orden real.
    var elementosOrdenados: [ElementoRutina] {
        elementos.sorted { $0.orden < $1.orden }
    }

    var numeroSeriesTotales: Int {
        elementos.reduce(0) { $0 + $1.seriesObjetivo }
    }

    /// Resumen para la lista de rutinas: "6 ejercicios · 20 series".
    var resumen: String {
        let n = elementos.count
        let ejercicios = n == 1 ? "1 ejercicio" : "\(n) ejercicios"
        let series = numeroSeriesTotales == 1 ? "1 serie" : "\(numeroSeriesTotales) series"
        return "\(ejercicios) · \(series)"
    }

    /// Los grupos de superserie presentes, en orden de aparición.
    var gruposSuperserie: [UUID] {
        var vistos: [UUID] = []
        for elemento in elementosOrdenados {
            if let id = elemento.idSuperserie, !vistos.contains(id) {
                vistos.append(id)
            }
        }
        return vistos
    }
}
