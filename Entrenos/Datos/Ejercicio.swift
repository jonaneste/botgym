import Foundation
import SwiftData

/// Un ejercicio de la biblioteca.
///
/// Los enums se guardan como `String` crudo con un accesor calculado encima.
/// Es más verboso que almacenar el enum directamente, pero en iOS 17 SwiftData
/// no filtra ni ordena de forma fiable por propiedades de tipo enum, y una
/// migración futura sobre `String` es trivial.
@Model
final class Ejercicio {
    /// Identificador estable propio, independiente del `PersistentIdentifier`.
    /// Se usa para denormalizar referencias y poder filtrar con `#Predicate`.
    var idPublico: UUID = UUID()
    var nombre: String = ""
    var notas: String = ""
    /// `true` si lo creó el usuario, `false` si viene de la semilla inicial.
    var esPersonalizado: Bool = false
    var fechaCreacion: Date = Date()

    var grupoPrincipalRaw: String = GrupoMuscular.pecho.rawValue
    var gruposSecundariosRaw: [String] = []
    var materialRaw: String = Material.otro.rawValue
    var tipoRegistroRaw: String = TipoRegistro.repeticiones.rawValue

    @Relationship(deleteRule: .nullify, inverse: \ElementoRutina.ejercicio)
    var elementosRutina: [ElementoRutina] = []

    init(
        nombre: String,
        grupoPrincipal: GrupoMuscular,
        gruposSecundarios: [GrupoMuscular] = [],
        material: Material,
        tipoRegistro: TipoRegistro = .repeticiones,
        notas: String = "",
        esPersonalizado: Bool = false
    ) {
        self.idPublico = UUID()
        self.nombre = nombre
        self.notas = notas
        self.esPersonalizado = esPersonalizado
        self.fechaCreacion = Date()
        self.grupoPrincipalRaw = grupoPrincipal.rawValue
        self.gruposSecundariosRaw = gruposSecundarios.map(\.rawValue)
        self.materialRaw = material.rawValue
        self.tipoRegistroRaw = tipoRegistro.rawValue
    }

    // MARK: - Accesores con tipo

    var grupoPrincipal: GrupoMuscular {
        get { GrupoMuscular(rawValue: grupoPrincipalRaw) ?? .pecho }
        set { grupoPrincipalRaw = newValue.rawValue }
    }

    var gruposSecundarios: [GrupoMuscular] {
        get { gruposSecundariosRaw.compactMap(GrupoMuscular.init(rawValue:)) }
        set { gruposSecundariosRaw = newValue.map(\.rawValue) }
    }

    var material: Material {
        get { Material(rawValue: materialRaw) ?? .otro }
        set { materialRaw = newValue.rawValue }
    }

    var tipoRegistro: TipoRegistro {
        get { TipoRegistro(rawValue: tipoRegistroRaw) ?? .repeticiones }
        set { tipoRegistroRaw = newValue.rawValue }
    }

    // MARK: - Derivados

    /// Subtítulo para las listas: "Pecho · Barra".
    var descripcionCorta: String {
        "\(grupoPrincipal.nombre) · \(material.nombre)"
    }

    /// Nombre normalizado para buscar y para casar nombres en la importación
    /// JSON: sin mayúsculas, sin acentos y sin espacios de sobra.
    var nombreNormalizado: String {
        Ejercicio.normalizar(nombre)
    }

    static func normalizar(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
