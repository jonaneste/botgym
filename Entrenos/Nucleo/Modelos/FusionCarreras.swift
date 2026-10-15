import Foundation

/// Fusiona carreras que llegan por los caminos posibles.
///
/// Hay tres: HealthKit, que necesita cuenta de pago y da el UUID real de la
/// muestra; el `exportar.xml` de la app de Salud, que es el camino gratuito y
/// **no trae UUID**, así que `InterpreteHealth` compone uno sintético a partir
/// de la fecha; y las que el usuario escribe a mano, que existen porque con un
/// Apple ID gratuito puede que no llegue ninguna de las otras dos.
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

    /// Prefijo de las que escribe el usuario a mano.
    public static let prefijoManual = "manual-"

    /// Cuánto puede separarse una carrera escrita a mano de la misma carrera
    /// medida para que se entiendan como la misma.
    ///
    /// Hora y media, y no el segundo exacto que vale entre Salud y el archivo:
    /// quien la escribe a mano pone «esta mañana» y el reloj pone las 9:37:12.
    /// Sin esta ventana, la del reloj y la escrita se contaban las dos y el
    /// resumen semanal salía con el doble de kilómetros, que es justo el fallo
    /// que este fichero existe para evitar.
    ///
    /// Y no se estira a todo el día a propósito: quien corre por la mañana y
    /// otra vez por la tarde tiene dos carreras, no una.
    public static let ventanaManualSegundos = 90 * 60

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
        let fusionadas = porInstante.values.sorted { $0.fechaInicio > $1.fechaInicio }
        return sinManualesDuplicadas(fusionadas)
    }

    /// Quita las escritas a mano que ya están medidas.
    ///
    /// La escrita a mano es un apaño para cuando el reloj no llega: en cuanto
    /// llega la medida, la de verdad es la medida, con su ritmo y su pulso.
    /// No se borra nada: solo deja de contarse, y en la lista de carreras a
    /// mano sigue estando por si se quiere revisar.
    static func sinManualesDuplicadas(_ carreras: [Carrera]) -> [Carrera] {
        let medidas = carreras.filter { !esManual($0) }
        guard !medidas.isEmpty else { return carreras }
        return carreras.filter { carrera in
            guard esManual(carrera) else { return true }
            return !medidas.contains { medida in
                abs(medida.fechaInicio.timeIntervalSince(carrera.fechaInicio))
                    <= Double(ventanaManualSegundos)
            }
        }
    }

    public static func esManual(_ carrera: Carrera) -> Bool {
        carrera.id.hasPrefix(prefijoManual)
    }

    /// De dos lecturas de la misma carrera gana la mejor medida: Salud antes
    /// que el archivo, y cualquiera de las dos antes que lo escrito a mano.
    /// A igualdad de origen, lo escrito después.
    static func preferida(_ previa: Carrera, _ nueva: Carrera) -> Carrera {
        let rangoPrevia = calidad(previa)
        let rangoNueva = calidad(nueva)
        if rangoPrevia != rangoNueva {
            return rangoPrevia > rangoNueva ? previa : nueva
        }
        return nueva
    }

    /// Cuánto fiarse de cada origen: 2 Salud, 1 el archivo, 0 lo escrito a
    /// mano.
    private static func calidad(_ carrera: Carrera) -> Int {
        if esManual(carrera) { return 0 }
        if carrera.id.hasPrefix(prefijoExport) { return 1 }
        return 2
    }

    /// Segundo en que empezó la carrera. Una fecha absurda cae en 0 en lugar
    /// de atrapar al convertir a `Int`.
    static func instante(_ fecha: Date) -> Int {
        LimitesEntrada.entero(fecha.timeIntervalSince1970)
    }
}
