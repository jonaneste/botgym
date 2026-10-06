import Foundation

/// Lo que la app sugiere hacer hoy en un ejercicio.
public struct SugerenciaProgresion: Equatable, Sendable {

    public enum Accion: Equatable, Sendable {
        /// No hay historial de este ejercicio.
        case primeraVez
        /// El ejercicio no tiene rango objetivo, así que no hay nada que
        /// comparar. Son series libres.
        case sinRango
        /// Subir la carga.
        case subirPeso(nuevoPeso: Double)
        /// Subir el objetivo de tiempo, en isométricos.
        case subirTiempo(nuevosSegundos: Int)
        /// Mantener el peso e intentar llegar a `objetivo` repeticiones.
        case mantener(peso: Double, objetivo: Int)
        /// A peso corporal y sin lastre, con todas las series en el tope del
        /// rango: ya no se progresa con kilos. Toca subir el rango o añadir
        /// lastre.
        case ampliarRango
    }

    public var accion: Accion
    /// Explicación corta para pintar debajo del ejercicio.
    public var motivo: String

    public init(accion: Accion, motivo: String) {
        self.accion = accion
        self.motivo = motivo
    }
}

/// Doble progresión.
///
/// La regla, tal y como la pidió el usuario: si en la última sesión completó
/// todas las series objetivo en el tope del rango, se sugiere subir la carga
/// (2,5 kg en barra, siguiente par de mancuernas, el paso configurado en
/// polea y máquina). Si no, se mantiene el peso y se intenta sumar
/// repeticiones.
public enum ServicioProgresion {

    /// Calcula la sugerencia a partir de la última sesión del ejercicio.
    ///
    /// - Parameters:
    ///   - seriesAnteriores: series de la última sesión, en orden.
    ///   - objetivo: lo que pide la rutina.
    ///   - material: decide cuánto sube la carga.
    ///   - tipo: decide si se comparan repeticiones o segundos.
    ///   - reglas: incrementos configurados en Ajustes.
    public static func sugerencia(
        seriesAnteriores: [SerieValor],
        objetivo: ObjetivoEjercicio,
        material: Material,
        tipo: TipoRegistro,
        reglas: ReglasIncremento = .porDefecto
    ) -> SugerenciaProgresion {

        // Sin rango no hay doble progresión posible.
        guard let tope = objetivo.tope, !objetivo.sinRango else {
            return SugerenciaProgresion(
                accion: .sinRango,
                motivo: "Series libres: sin rango objetivo que comparar."
            )
        }

        // Solo cuentan las series completadas que no son calentamiento.
        let efectivas = seriesAnteriores.filter(\.esEfectiva)
        guard !efectivas.isEmpty else {
            return SugerenciaProgresion(
                accion: .primeraVez,
                motivo: "Primera vez con este ejercicio: elige un peso que puedas mover en el rango."
            )
        }

        // Solo se juzgan las series de TRABAJO, no todas las efectivas. Con
        // una serie de descarga al final, que es práctica normal, juzgarlas
        // todas rompía de dos formas opuestas:
        //
        //   3×8-10 con 70×10, 70×10, 70×10 y una cuarta de 50×12 daba
        //   pesoBase = mínimo = 50 y sugería "sube a 52,5 kg". Aplicado a las
        //   series pendientes de hoy, eso es una regresión de 17,5 kg en el
        //   ejercicio principal, de un solo toque.
        //
        //   La misma cuarta serie a 50×7 hacía `todasEnElTope` falso, así que
        //   quien había completado 3×10 a 70 no progresaba nunca.
        //
        // Dentro de las de trabajo el peso base sigue siendo el MÍNIMO, que es
        // la decisión documentada: la sugerencia significa "haz todas tus
        // series a este peso", y en una pirámide descendente de 70/65/60 el
        // único peso que se sostuvo en las tres es 60.
        let deTrabajo = seriesDeTrabajo(efectivas, series: objetivo.series, tipo: tipo)
        let logros = deTrabajo.map { $0.logro(tipo: tipo) }
        let completoLasSeries = efectivas.count >= objetivo.series
        let todasEnElTope = logros.allSatisfy { $0 >= tope }
        let pesoBase = deTrabajo.map(\.peso).min() ?? 0

        guard completoLasSeries && todasEnElTope else {
            let menorLogro = logros.min() ?? 0
            let siguienteObjetivo = min(tope, menorLogro + 1)
            return SugerenciaProgresion(
                accion: .mantener(peso: pesoBase, objetivo: siguienteObjetivo),
                motivo: motivoMantener(
                    completoLasSeries: completoLasSeries,
                    objetivo: objetivo,
                    efectivas: efectivas.count,
                    siguienteObjetivo: siguienteObjetivo,
                    tipo: tipo
                )
            )
        }

        // Toca subir.
        if tipo.esTiempo {
            let nuevos = IncrementoCarga.siguienteTiempo(desde: tope, reglas: reglas)
            return SugerenciaProgresion(
                accion: .subirTiempo(nuevosSegundos: nuevos),
                motivo: "Aguantaste \(tope) s en todas las series. Prueba \(nuevos) s."
            )
        }

        // Peso corporal sin lastre: subir kilos no es una opción.
        if material == .pesoCorporal && pesoBase <= 0 {
            return SugerenciaProgresion(
                accion: .ampliarRango,
                motivo: "Completaste \(objetivo.series) × \(tope) a peso corporal. Sube el rango o añade lastre."
            )
        }

        let nuevoPeso = IncrementoCarga.siguientePeso(
            desde: pesoBase,
            material: material,
            reglas: reglas
        )

        // En mancuernas, si ya estás en la más pesada del gimnasio, el
        // siguiente peso es el mismo: no tiene sentido sugerir una subida.
        guard nuevoPeso > pesoBase else {
            return SugerenciaProgresion(
                accion: .ampliarRango,
                motivo: "Completaste el rango con \(textoPeso(pesoBase)), y no hay carga mayor configurada. Sube el rango o revisa las mancuernas en Ajustes."
            )
        }

        return SugerenciaProgresion(
            accion: .subirPeso(nuevoPeso: nuevoPeso),
            motivo: "Completaste \(objetivo.series) × \(tope) con \(textoPeso(pesoBase)). Sube a \(textoPeso(nuevoPeso))."
        )
    }

    // MARK: - Series de trabajo

    /// Las series que cuentan para la doble progresión: las `series` de más
    /// peso de la sesión, y entre las de igual peso las de mejor logro.
    ///
    /// Con tantas series efectivas como pide la rutina, o menos, devuelve
    /// todas: no hay nada que descartar. Las de más se entienden como
    /// descarga, aproximación no marcada como calentamiento o series extra, y
    /// no pueden decidir ni el peso base ni si se completó el rango.
    ///
    /// En isométricos y en peso corporal sin lastre todos los pesos valen
    /// igual, así que manda el logro: de 60 s, 60 s, 60 s y 30 s elige las
    /// tres de 60 esté la corta donde esté.
    static func seriesDeTrabajo(
        _ efectivas: [SerieValor],
        series: Int,
        tipo: TipoRegistro
    ) -> [SerieValor] {
        guard series > 0, efectivas.count > series else { return efectivas }
        let ordenadas = efectivas.sorted { izquierda, derecha in
            if izquierda.peso != derecha.peso { return izquierda.peso > derecha.peso }
            return izquierda.logro(tipo: tipo) > derecha.logro(tipo: tipo)
        }
        return Array(ordenadas.prefix(series))
    }

    // MARK: - Textos

    private static func motivoMantener(
        completoLasSeries: Bool,
        objetivo: ObjetivoEjercicio,
        efectivas: Int,
        siguienteObjetivo: Int,
        tipo: TipoRegistro
    ) -> String {
        if !completoLasSeries {
            return "La última vez hiciste \(efectivas) de \(objetivo.series) series. Mantén el peso y complétalas."
        }
        let unidad = tipo.esTiempo ? "s" : "reps"
        return "Mantén el peso e intenta llegar a \(siguienteObjetivo) \(unidad) en todas las series."
    }

    /// Peso con coma decimal española y sin ceros de más: "62,5 kg".
    ///
    /// El núcleo no puede usar el formateador de la capa de vistas, así que
    /// esto es deliberadamente mínimo.
    static func textoPeso(_ kg: Double) -> String {
        if kg == kg.rounded() {
            // `LimitesEntrada.entero` y no `Int(kg)`: convertir un Double
            // fuera del rango de Int64 es una trampa en tiempo de ejecución, y
            // aquí llega el peso que el usuario escribió a mano.
            return "\(LimitesEntrada.entero(kg)) kg"
        }
        let texto = String(format: "%.1f", kg).replacingOccurrences(of: ".", with: ",")
        return "\(texto) kg"
    }
}
