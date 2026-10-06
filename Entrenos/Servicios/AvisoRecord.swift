import Foundation

/// Un récord recién batido, listo para pintar.
struct AvisoRecord: Identifiable, Equatable {
    let id = UUID()
    let nombreEjercicio: String
    let batidos: [RecordBatido]

    /// Texto principal: "¡Récord de peso máximo!" o "¡2 récords!".
    var titulo: String {
        if batidos.count == 1 {
            return "¡Récord de \(batidos[0].tipo.nombre.lowercased())!"
        }
        return "¡\(batidos.count) récords!"
    }

    /// Detalle con los valores: "65 kg, antes 60 kg".
    var detalle: String {
        batidos.map { batido in
            let valor = texto(batido.valor, tipo: batido.tipo)
            guard let anterior = batido.anterior else {
                return "\(batido.tipo.nombre): \(valor)"
            }
            return "\(batido.tipo.nombre): \(valor) (antes \(texto(anterior, tipo: batido.tipo)))"
        }
        .joined(separator: "\n")
    }

    private func texto(_ valor: Double, tipo: TipoRecord) -> String {
        switch tipo {
        case .peso, .unRM:
            return Formato.peso(valor)
        case .volumenSesion:
            return Formato.volumen(valor)
        case .tiempo:
            return "\(Int(valor)) s"
        }
    }
}

/// Un récord batido, atado al ejercicio en que ocurrió.
struct RecordDeEjercicio: Identifiable, Equatable {
    /// Compuesta, no un UUID nuevo por instancia: en un entreno hay como mucho
    /// un récord de cada tipo por ejercicio, así que esto identifica igual de
    /// bien, no cambia si la lista se vuelve a construir y hace que `Equatable`
    /// signifique algo.
    var id: String { "\(nombreEjercicio)-\(batido.tipo.rawValue)" }
    let nombreEjercicio: String
    let batido: RecordBatido
}
