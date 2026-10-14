import SwiftUI

/// Los colores de la interfaz, por lo que significan y no por cómo se ven.
///
/// Existe por dos motivos. El primero es que `Color.green` y compañía son
/// valores fijos: no responden a «Aumentar contraste» ni cambian entre claro y
/// oscuro, mientras que los colores de sistema (`UIColor.systemGreen`) sí, y
/// Apple pide explícitamente no codificar a mano sus valores porque los ajusta
/// entre versiones.
///
/// El segundo es que el mismo verde significaba tres cosas distintas repartido
/// por once archivos —serie hecha, objetivo cumplido, importación correcta— y
/// cambiar cualquiera de ellas obligaba a buscar cuál de los `Color.green` era.
/// Aquí un color significa una cosa.
enum Paleta {

    // MARK: - Estado

    /// Hecho, cumplido, correcto: una serie marcada, un objetivo alcanzado.
    static let logrado = Color(.systemGreen)

    /// A medio camino, o un aviso que no impide seguir.
    static let aviso = Color(.systemOrange)

    /// Error, o por debajo de lo que toca.
    static let insuficiente = Color(.systemRed)

    /// Récord personal. El único dorado de la app, y por eso se nota.
    static let record = Color(.systemYellow)

    // MARK: - Contenido

    /// Series de calentamiento: no cuentan para el volumen ni para la cuenta
    /// semanal, así que no comparten el color de «hecho».
    static let calentamiento = Color(.systemOrange)

    /// Sugerencia de progresión. Todas comparten color a propósito: son la
    /// misma clase de información, y pintar cada acción de un color distinto
    /// repartía cinco acentos por la pantalla sin decir nada más.
    static let progresion = Color.accentColor

    /// Carpetas de rutinas.
    static let carpeta = Color(.systemIndigo)

    /// Carreras importadas de Apple Salud. No es un estado: distingue el
    /// cardio de la fuerza en una lista donde conviven.
    static let carrera = Color(.systemOrange)

    /// Escala de molestia de 0 a 10. Tres tramos, y el color NO va solo: la
    /// vista pinta además el número y un símbolo, porque quien no distingue el
    /// rojo del verde se quedaría sin la información.
    static func molestia(_ valor: Int) -> Color {
        if valor >= 7 { return insuficiente }
        if valor >= 4 { return aviso }
        return logrado
    }

    // MARK: - Grupos musculares

    /// Color de una región del cuerpo.
    ///
    /// Se colorea por región y no por grupo uno a uno a propósito. Los colores
    /// de sistema que quedan libres son nueve, y los grupos son dieciséis: con
    /// uno por grupo habría repeticiones arbitrarias —pecho y glúteo del mismo
    /// color— que no significarían nada. Por región sí significa: en la gráfica
    /// semanal se ve de un golpe si la semana se ha ido en torso y la pierna se
    /// ha quedado corta, que es la pregunta que se le hace a esa gráfica.
    ///
    /// Y se mantienen fuera los cuatro colores de estado —verde, naranja, rojo
    /// y amarillo—, porque un grupo muscular no es un estado y teñir una
    /// barra de rojo por ser pierna diría «vas mal» sin querer. Y fuera el
    /// azul del acento, para que un punto de región no se confunda con algo
    /// que se puede tocar.
    static func region(_ region: RegionCorporal) -> Color {
        switch region {
        case .torso: return Color(.systemPink)
        case .hombro: return Color(.systemCyan)
        case .brazo: return Color(.systemIndigo)
        case .pierna: return Color(.systemTeal)
        case .sinClasificar: return Color(.systemGray)
        }
    }

    /// Color de un grupo muscular: el de su región.
    static func grupo(_ grupo: GrupoMuscular) -> Color {
        region(grupo.region)
    }
}
