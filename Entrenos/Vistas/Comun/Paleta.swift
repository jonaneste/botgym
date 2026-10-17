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

    /// El mismo naranja, pero para texto sobre un fondo claro teñido de él.
    ///
    /// `systemOrange` sobre su propio relleno al 16 % se queda en 2,1:1 con el
    /// modo claro, muy por debajo del 4,5:1 que pide un texto de este tamaño.
    /// Apple no publica un naranja oscuro, así que aquí va uno a mano: es la
    /// excepción a «no codificar los colores del sistema», y solo para claro.
    /// En oscuro sigue siendo `systemOrange`, que ahí sí contrasta de sobra.
    static let calentamientoTexto = Color(UIColor { rasgos in
        rasgos.userInterfaceStyle == .dark
            ? UIColor.systemOrange
            : UIColor(red: 0.604, green: 0.310, blue: 0, alpha: 1)
    })

    /// El acento elegido en Ajustes.
    ///
    /// Es una variable y no una constante porque el tema se puede cambiar, y
    /// aquí hace falta fuera del entorno de SwiftUI: estas son funciones
    /// estáticas que no pueden leer `@Environment`. La escribe `VistaPrincipal`
    /// al arrancar y al volver del fondo, que son los dos únicos momentos en
    /// que el ajuste puede haber cambiado.
    @MainActor static var acento: Color = Tema.porDefecto.color

    /// Sugerencia de progresión. Todas comparten color a propósito: son la
    /// misma clase de información, y pintar cada acción de un color distinto
    /// repartía cinco acentos por la pantalla sin decir nada más.
    @MainActor static var progresion: Color { acento }

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

    /// El color de la región, pero para **texto**.
    ///
    /// Los de `region(_:)` son colores de relleno: valen para un punto, una
    /// barra o un filo, donde basta con distinguirse. Como texto sobre fondo
    /// claro no llegan: el teal del sistema se queda en 2,7:1 y el cian peor,
    /// cuando un texto de este tamaño pide 4,5:1. Y el nombre del grupo va en
    /// ese color en toda la biblioteca y en el selector de ejercicios.
    ///
    /// En oscuro se devuelven los del sistema tal cual, que ahí contrastan de
    /// sobra. Los de claro van a mano porque Apple no publica versiones
    /// oscuras de estos; están medidos sobre blanco y sobre el propio color
    /// al 14 %, que es el fondo de las pastillas de filtro.
    static func regionTexto(_ region: RegionCorporal) -> Color {
        Color(UIColor { rasgos in
            if rasgos.userInterfaceStyle == .dark {
                switch region {
                case .torso: return .systemPink
                case .hombro: return .systemCyan
                case .brazo: return .systemIndigo
                case .pierna: return .systemTeal
                case .sinClasificar: return .systemGray
                }
            }
            switch region {
            case .torso: return UIColor(red: 0.80, green: 0, blue: 0.27, alpha: 1)
            case .hombro: return UIColor(red: 0, green: 0.43, blue: 0.54, alpha: 1)
            // El índigo del sistema ya da 5,4:1 sobre blanco: no hace falta
            // tocarlo, y uno a mano se vería distinto del resto de la app.
            case .brazo: return .systemIndigo
            case .pierna: return UIColor(red: 0, green: 0.44, blue: 0.50, alpha: 1)
            case .sinClasificar: return UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1)
            }
        })
    }

    static func grupoTexto(_ grupo: GrupoMuscular) -> Color {
        regionTexto(grupo.region)
    }
}
