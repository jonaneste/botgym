import Foundation
import SwiftData

/// Una carrera escrita a mano.
///
/// Las carreras medidas no van a SwiftData a propósito: las escribe Zepp en
/// Salud, que es la fuente de verdad, y `CacheCarreras` solo guarda una copia.
/// Con estas es al revés —las escribe el usuario, así que la app **es** la
/// fuente— y por eso sí se persisten aquí, igual que el plan.
///
/// Existen porque con un Apple ID gratuito la capability de HealthKit no se
/// puede firmar, así que puede que no llegue ni una carrera por los otros dos
/// caminos. Sin esto, un plan de 180 km no tenía dónde registrarse.
@Model
final class CarreraManual {
    var idPublico: UUID = UUID()
    var fechaInicio: Date = Date()
    /// Metros, para hablar la misma unidad que Salud.
    var distanciaMetros: Double = 0
    var duracion: TimeInterval = 0
    var pulsoMedio: Double?
    var notas: String = ""

    init(
        fechaInicio: Date,
        distanciaMetros: Double,
        duracion: TimeInterval,
        pulsoMedio: Double? = nil,
        notas: String = ""
    ) {
        self.idPublico = UUID()
        self.fechaInicio = fechaInicio
        self.distanciaMetros = distanciaMetros
        self.duracion = duracion
        self.pulsoMedio = pulsoMedio
        self.notas = notas
    }

    /// Como la lee el resto de la app.
    ///
    /// El identificador lleva el prefijo que `FusionCarreras` usa para saber
    /// que es escrita a mano, y con él que una medida de la misma hora la
    /// tape: la escrita es un apaño para cuando el reloj no llega.
    var valor: Carrera {
        Carrera(
            id: FusionCarreras.prefijoManual + idPublico.uuidString,
            fechaInicio: fechaInicio,
            duracion: duracion,
            distanciaMetros: distanciaMetros,
            pulsoMedio: pulsoMedio,
            calorias: nil,
            origen: "A mano"
        )
    }
}
