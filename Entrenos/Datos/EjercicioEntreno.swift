import Foundation
import SwiftData

/// Un ejercicio tal y como se hizo dentro de un entreno concreto.
///
/// Los objetivos vienen **copiados** de la rutina en lugar de referenciados. Si
/// dentro de dos meses cambias el rango de 8-10 a 6-8, el historial de hoy
/// sigue diciendo lo que tocaba hoy.
///
/// También hay tres campos denormalizados (`idEjercicio`, `fechaEntreno`,
/// `entrenoFinalizado`). Se podrían deducir de las relaciones, pero en iOS 17
/// los `#Predicate` que atraviesan relaciones fallan, y buscar "lo que hice la
/// última vez en este ejercicio" tiene que ser una consulta directa y rápida.
@Model
final class EjercicioEntreno {
    var idPublico: UUID = UUID()
    var orden: Int = 0
    var notas: String = ""

    var ejercicio: Ejercicio?
    var entreno: Entreno?

    /// Copias denormalizadas para poder consultar sin atravesar relaciones.
    var idEjercicio: UUID = UUID()
    var fechaEntreno: Date = Date()
    var entrenoFinalizado: Bool = false

    /// Nombre copiado, para que el historial sobreviva al borrado del ejercicio.
    var nombreEjercicio: String = ""

    /// Objetivos copiados de la rutina en el momento de empezar.
    var seriesObjetivo: Int = 3
    var objetivoMin: Int?
    var objetivoMax: Int?
    var rirMin: Int?
    var rirMax: Int?
    var descansoSegundos: Int = 90
    var idSuperserie: UUID?

    var tipoRegistroRaw: String = TipoRegistro.repeticiones.rawValue

    @Relationship(deleteRule: .cascade, inverse: \SerieRegistrada.ejercicioEntreno)
    var series: [SerieRegistrada] = []

    init(
        ejercicio: Ejercicio?,
        orden: Int,
        fechaEntreno: Date,
        seriesObjetivo: Int = 3,
        objetivoMin: Int? = nil,
        objetivoMax: Int? = nil,
        rirMin: Int? = nil,
        rirMax: Int? = nil,
        descansoSegundos: Int = 90,
        notas: String = "",
        idSuperserie: UUID? = nil
    ) {
        self.idPublico = UUID()
        self.ejercicio = ejercicio
        self.orden = orden
        self.fechaEntreno = fechaEntreno
        self.entrenoFinalizado = false
        self.idEjercicio = ejercicio?.idPublico ?? UUID()
        self.nombreEjercicio = ejercicio?.nombre ?? "Ejercicio"
        self.tipoRegistroRaw = (ejercicio?.tipoRegistro ?? .repeticiones).rawValue
        self.seriesObjetivo = seriesObjetivo
        self.objetivoMin = objetivoMin
        self.objetivoMax = objetivoMax
        self.rirMin = rirMin
        self.rirMax = rirMax
        self.descansoSegundos = descansoSegundos
        self.notas = notas
        self.idSuperserie = idSuperserie
    }

    /// Crea el ejercicio del entreno a partir de un elemento de rutina,
    /// copiando sus objetivos.
    convenience init(desde elemento: ElementoRutina, fechaEntreno: Date) {
        self.init(
            ejercicio: elemento.ejercicio,
            orden: elemento.orden,
            fechaEntreno: fechaEntreno,
            seriesObjetivo: elemento.seriesObjetivo,
            objetivoMin: elemento.objetivoMin,
            objetivoMax: elemento.objetivoMax,
            rirMin: elemento.rirMin,
            rirMax: elemento.rirMax,
            descansoSegundos: elemento.descansoSegundos,
            notas: elemento.notas,
            idSuperserie: elemento.idSuperserie
        )
    }

    var tipoRegistro: TipoRegistro {
        get { TipoRegistro(rawValue: tipoRegistroRaw) ?? .repeticiones }
        set { tipoRegistroRaw = newValue.rawValue }
    }

    var seriesOrdenadas: [SerieRegistrada] {
        series.sorted { $0.orden < $1.orden }
    }

    var objetivo: ObjetivoEjercicio {
        ObjetivoEjercicio(
            series: seriesObjetivo,
            objetivoMin: objetivoMin,
            objetivoMax: objetivoMax,
            rirMin: rirMin,
            rirMax: rirMax,
            descansoSegundos: descansoSegundos
        )
    }

    // MARK: - Derivados

    var seriesEfectivas: [SerieRegistrada] {
        seriesOrdenadas.filter(\.esEfectiva)
    }

    var seriesCompletadas: Int {
        series.filter(\.completada).count
    }

    var volumen: Double {
        seriesEfectivas.reduce(0) { $0 + $1.volumen }
    }

    /// Las series como tipos valor, para la lógica del núcleo.
    var seriesValor: [SerieValor] {
        seriesOrdenadas.map(\.valor)
    }

    var resumenObjetivo: String {
        var partes = ["\(seriesObjetivo) × \(objetivo.textoRango(tipo: tipoRegistro))"]
        let rir = objetivo.textoRIR
        if !rir.isEmpty { partes.append(rir) }
        return partes.joined(separator: " · ")
    }
}
