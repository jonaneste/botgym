import Foundation

/// Cuánto sube la carga en cada material cuando toca progresar.
///
/// Las mancuernas no suman una cantidad fija: salta al siguiente par
/// disponible en el gimnasio, porque entre la de 20 y la de 22,5 no hay nada.
public struct ReglasIncremento: Codable, Hashable, Sendable {
    public var incrementoBarra: Double
    public var incrementoPolea: Double
    public var incrementoMaquina: Double
    public var incrementoTiempo: Int
    /// Pesos de mancuerna disponibles, en kg. Se ordenan al construir.
    public var mancuernasDisponibles: [Double]

    public init(
        incrementoBarra: Double = 2.5,
        incrementoPolea: Double = 2.5,
        incrementoMaquina: Double = 2.5,
        incrementoTiempo: Int = 5,
        mancuernasDisponibles: [Double] = ReglasIncremento.mancuernasHabituales
    ) {
        self.incrementoBarra = incrementoBarra
        self.incrementoPolea = incrementoPolea
        self.incrementoMaquina = incrementoMaquina
        self.incrementoTiempo = incrementoTiempo
        self.mancuernasDisponibles = mancuernasDisponibles.sorted()
    }

    /// Juego de mancuernas típico de un gimnasio comercial.
    public static let mancuernasHabituales: [Double] = [
        2, 4, 6, 8, 10, 12, 14, 16, 18, 20,
        22.5, 25, 27.5, 30, 32.5, 35, 40, 45, 50,
    ]

    public static let porDefecto = ReglasIncremento()
}

/// Calcula el siguiente peso a usar según el material.
public enum IncrementoCarga {

    /// Siguiente carga por encima de `pesoActual` para este material.
    ///
    /// A peso corporal sin lastre devuelve el mismo peso: ahí no se progresa
    /// subiendo kilos sino repeticiones. Si ya hay lastre, se trata como barra.
    public static func siguientePeso(
        desde pesoActual: Double,
        material: Material,
        reglas: ReglasIncremento = .porDefecto
    ) -> Double {
        switch material {
        case .barra:
            return pesoActual + reglas.incrementoBarra
        case .polea:
            return pesoActual + reglas.incrementoPolea
        case .maquina:
            return pesoActual + reglas.incrementoMaquina
        case .mancuerna:
            return siguienteMancuerna(desde: pesoActual, disponibles: reglas.mancuernasDisponibles)
        case .pesoCorporal:
            // Sin lastre no se progresa con kilos, sino con repeticiones.
            // Con lastre (cinturón, chaleco) se añaden discos como en barra.
            return pesoActual > 0 ? pesoActual + reglas.incrementoBarra : pesoActual
        case .otro:
            return pesoActual + reglas.incrementoBarra
        }
    }

    /// Siguiente mancuerna estrictamente mayor que la actual.
    ///
    /// Si ya estás en la más pesada del gimnasio, devuelve esa misma: no tiene
    /// sentido sugerir algo que no existe en la sala.
    public static func siguienteMancuerna(desde pesoActual: Double, disponibles: [Double]) -> Double {
        let ordenadas = disponibles.sorted()
        guard let primera = ordenadas.first else { return pesoActual }
        // Con un peso por debajo del juego disponible, empieza por la más ligera.
        guard pesoActual >= primera else { return primera }
        // Margen de tolerancia para no tropezar con los decimales de 22,5 y 27,5.
        if let siguiente = ordenadas.first(where: { $0 > pesoActual + 0.001 }) {
            return siguiente
        }
        return ordenadas.last ?? pesoActual
    }

    /// Siguiente objetivo de tiempo para un ejercicio isométrico.
    public static func siguienteTiempo(
        desde segundosActuales: Int,
        reglas: ReglasIncremento = .porDefecto
    ) -> Int {
        segundosActuales + reglas.incrementoTiempo
    }
}
