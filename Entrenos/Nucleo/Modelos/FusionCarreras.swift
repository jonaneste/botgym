import Foundation

/// Fusiona carreras que llegan por los dos caminos posibles.
///
/// Hay dos: HealthKit, que necesita cuenta de pago y da el UUID real de la
/// muestra, y el `exportar.xml` de la app de Salud, que es el camino gratuito
/// y **no trae UUID**, así que `InterpreteHealth` compone uno sintético a
/// partir de la fecha.
///
/// Fusionar por identificador contaba dos veces cada carrera que se hubiese
/// leído por los dos caminos: el doble de kilómetros en el resumen semanal, la
/// carrera repetida en el historial, y el doble también en el `entrenos.json`
/// que lee el servidor MCP, que es donde más daño hace porque ahí nadie lo ve.
///
/// Se identifica por instante de inicio redondeado al segundo, que es el mismo
/// dato por los dos caminos porque es la misma muestra de Salud.
public enum FusionCarreras {

    /// Prefijo de los identificadores sintéticos del archivo de exportación.
    public static let prefijoExport = "export-"

    /// Las dos listas en una, sin carreras repetidas, de más reciente a más
    /// antigua.
    public static func fusionar(_ existentes: [Carrera], con nuevas: [Carrera]) -> [Carrera] {
        var porInstante: [Int: Carrera] = [:]
        for carrera in existentes + nuevas {
            let clave = instante(carrera.fechaInicio)
            if let previa = porInstante[clave] {
                porInstante[clave] = preferida(previa, carrera)
            } else {
                porInstante[clave] = carrera
            }
        }
        return porInstante.values.sorted { $0.fechaInicio > $1.fechaInicio }
    }

    /// De dos lecturas de la misma carrera, la de Salud gana a la del archivo
    /// porque trae el UUID real y lo escrito después gana a lo anterior.
    static func preferida(_ previa: Carrera, _ nueva: Carrera) -> Carrera {
        let previaEsDeArchivo = previa.id.hasPrefix(prefijoExport)
        let nuevaEsDeArchivo = nueva.id.hasPrefix(prefijoExport)
        if previaEsDeArchivo != nuevaEsDeArchivo {
            return previaEsDeArchivo ? nueva : previa
        }
        return nueva
    }

    /// Segundo en que empezó la carrera. Una fecha absurda cae en 0 en lugar
    /// de atrapar al convertir a `Int`.
    static func instante(_ fecha: Date) -> Int {
        LimitesEntrada.entero(fecha.timeIntervalSince1970)
    }
}
