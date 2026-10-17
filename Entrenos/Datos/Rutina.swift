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

    /// Busca una rutina por nombre, ignorando mayúsculas y acentos.
    ///
    /// Si hay varias con el mismo nombre —pasa: las importaciones son
    /// aditivas, así que una carpeta vieja y una nueva pueden tener las dos
    /// «Lunes – Pierna y core»— gana **la más reciente**. El nombre viene de
    /// un plan escrito ahora, así que se refiere a la rutina de ahora, no a la
    /// que quedó de hace dos meses con la mitad de series.
    ///
    /// Sin esta regla el resultado dependía del orden de la lista, y el botón
    /// de «Empezar» del plan podía arrancar la rutina vieja sin decir nada.
    static func buscar(nombre: String, en rutinas: [Rutina]) -> Rutina? {
        let buscado = Ejercicio.normalizar(nombre)
        guard !buscado.isEmpty else { return nil }
        return rutinas
            .filter { Ejercicio.normalizar($0.nombre) == buscado }
            .max { $0.fechaCreacion < $1.fechaCreacion }
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
