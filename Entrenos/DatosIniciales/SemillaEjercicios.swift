import Foundation

/// Catálogo de ejercicios que se precarga en la primera apertura.
///
/// Cubre todos los de la rutina de 5 días más los alternativos habituales,
/// para no tener que crearlos a mano el día que cambies algo.
enum SemillaEjercicios {

    struct Definicion {
        let nombre: String
        let principal: GrupoMuscular
        let secundarios: [GrupoMuscular]
        let material: Material
        let tipo: TipoRegistro

        init(
            _ nombre: String,
            _ principal: GrupoMuscular,
            _ secundarios: [GrupoMuscular] = [],
            _ material: Material,
            _ tipo: TipoRegistro = .repeticiones
        ) {
            self.nombre = nombre
            self.principal = principal
            self.secundarios = secundarios
            self.material = material
            self.tipo = tipo
        }
    }

    static let todos: [Definicion] = [

        // MARK: Empuje — pecho

        Definicion("Press banca con barra", .pecho, [.hombroAnterior, .triceps], .barra),
        Definicion("Press inclinado con mancuernas", .pecho, [.hombroAnterior, .triceps], .mancuerna),
        Definicion("Press inclinado con mancuernas, agarre neutro", .pecho, [.hombroAnterior, .triceps], .mancuerna),
        Definicion("Press cerrado (o flexiones agarre cerrado)", .triceps, [.pecho, .hombroAnterior], .barra),
        Definicion("Aperturas en polea", .pecho, [.hombroAnterior], .polea),
        Definicion("Máquina de pecho", .pecho, [.hombroAnterior, .triceps], .maquina),
        Definicion("Flexiones", .pecho, [.triceps, .hombroAnterior], .pesoCorporal),

        // MARK: Empuje — hombro

        Definicion("Landmine press", .hombroAnterior, [.pecho, .triceps], .barra, .repeticionesPorLado),
        Definicion("Press de hombro en máquina", .hombroAnterior, [.triceps], .maquina),
        Definicion("Press militar con mancuernas", .hombroAnterior, [.triceps], .mancuerna),
        Definicion("Elevaciones laterales", .hombroLateral, [], .mancuerna),
        Definicion("Elevaciones laterales en polea", .hombroLateral, [], .polea),
        Definicion("Elevaciones frontales en polea", .hombroAnterior, [], .polea),
        Definicion("Pájaros", .hombroPosterior, [.trapecio], .mancuerna),
        Definicion("Face pull", .hombroPosterior, [.trapecio], .polea),
        Definicion("Rotación externa en polea", .hombroPosterior, [], .polea, .repeticionesPorLado),

        // MARK: Empuje — tríceps

        Definicion("Extensión de tríceps en polea", .triceps, [], .polea),
        Definicion("Extensión de tríceps sobre la cabeza", .triceps, [], .polea),
        Definicion("Press francés", .triceps, [], .barra),
        Definicion("Extensión unilateral con polea", .triceps, [], .polea, .repeticionesPorLado),

        // MARK: Tirón — espalda

        Definicion("Dominadas agarre neutro (o jalón)", .dorsal, [.biceps, .espalda], .pesoCorporal),
        Definicion("Jalón con agarre neutro", .dorsal, [.biceps, .espalda], .polea),
        Definicion("Jalón al pecho", .dorsal, [.biceps, .espalda], .polea),
        Definicion("Remo con barra", .espalda, [.dorsal, .biceps, .lumbar], .barra),
        Definicion("Remo en polea sentado", .espalda, [.dorsal, .biceps], .polea),
        Definicion("Remo unilateral con mancuerna", .espalda, [.dorsal, .biceps], .mancuerna, .repeticionesPorLado),
        Definicion("Peso muerto", .espalda, [.isquios, .gluteo, .lumbar, .trapecio], .barra),

        // MARK: Tirón — bíceps

        Definicion("Curl con barra", .biceps, [.antebrazo], .barra),
        Definicion("Curl martillo", .biceps, [.antebrazo], .mancuerna),
        Definicion("Curl inclinado", .biceps, [], .mancuerna),
        Definicion("Curl predicador", .biceps, [], .barra),
        Definicion("Curl araña", .biceps, [], .mancuerna),
        Definicion("Curl arrastre en polea", .biceps, [], .polea),

        // MARK: Pierna

        Definicion("Sentadilla a cajón (o prensa)", .cuadriceps, [.gluteo, .isquios], .barra),
        Definicion("Sentadilla", .cuadriceps, [.gluteo, .isquios, .lumbar], .barra),
        Definicion("Prensa", .cuadriceps, [.gluteo, .isquios], .maquina),
        Definicion("Peso muerto rumano", .isquios, [.gluteo, .lumbar], .barra),
        Definicion("Hip thrust", .gluteo, [.isquios], .barra),
        Definicion("Curl femoral", .isquios, [], .maquina),
        Definicion("Extensión de cuádriceps", .cuadriceps, [], .maquina),
        Definicion("Gemelo de pie", .gemelo, [], .maquina),
        Definicion("Isométrico extensión de cuádriceps a 60°", .cuadriceps, [], .maquina, .tiempo),

        // MARK: Core

        Definicion("Rueda abdominal", .core, [.lumbar], .pesoCorporal),
        Definicion("Pallof press", .core, [], .polea, .repeticionesPorLado),
        Definicion("Plancha", .core, [], .pesoCorporal, .tiempo),
    ]
}
