import Foundation

/// La rutina de 5 días, tal y como se precarga en la primera apertura.
///
/// Donde la rutina no fijaba un RIR objetivo, `rirMin`/`rirMax` quedan a `nil`
/// y el cargador pone el valor por defecto de Ajustes (1-2). Solo el press
/// banca del lunes lleva uno explícito.
enum SemillaRutinas {

    static let nombreCarpeta = "Rutina 5 días"

    struct ElementoDef {
        let ejercicio: String
        let series: Int
        let objetivoMin: Int?
        let objetivoMax: Int?
        let rirMin: Int?
        let rirMax: Int?
        let descanso: Int
        /// Etiqueta de superserie: los consecutivos con la misma se agrupan.
        let superserie: String?

        init(
            _ ejercicio: String,
            _ series: Int,
            _ objetivoMin: Int? = nil,
            _ objetivoMax: Int? = nil,
            descanso: Int,
            rir: (Int, Int)? = nil,
            superserie: String? = nil
        ) {
            self.ejercicio = ejercicio
            self.series = series
            self.objetivoMin = objetivoMin
            self.objetivoMax = objetivoMax
            self.rirMin = rir?.0
            self.rirMax = rir?.1
            self.descanso = descanso
            self.superserie = superserie
        }
    }

    struct RutinaDef {
        let nombre: String
        let elementos: [ElementoDef]
    }

    static let rutinas: [RutinaDef] = [

        RutinaDef(nombre: "Lunes – Empuje", elementos: [
            ElementoDef("Press banca con barra", 4, 8, 10, descanso: 150, rir: (2, 3)),
            ElementoDef("Press inclinado con mancuernas", 3, 8, 10, descanso: 120),
            ElementoDef("Landmine press", 3, 8, 10, descanso: 90),
            ElementoDef("Elevaciones laterales", 4, 12, 15, descanso: 60),
            ElementoDef("Press cerrado (o flexiones agarre cerrado)", 3, 10, 12, descanso: 90),
            ElementoDef("Extensión de tríceps en polea", 3, 10, 12, descanso: 60),
        ]),

        RutinaDef(nombre: "Martes – Tirón", elementos: [
            ElementoDef("Dominadas agarre neutro (o jalón)", 4, 6, 8, descanso: 150),
            ElementoDef("Remo con barra", 3, 8, 10, descanso: 120),
            ElementoDef("Remo en polea sentado", 3, 10, 12, descanso: 90),
            ElementoDef("Face pull", 3, 12, 15, descanso: 60),
            ElementoDef("Curl con barra", 3, 8, 10, descanso: 90),
            ElementoDef("Curl martillo", 3, 10, 12, descanso: 60),
        ]),

        RutinaDef(nombre: "Miércoles – Pierna + core", elementos: [
            ElementoDef("Sentadilla a cajón (o prensa)", 3, 8, 10, descanso: 150),
            ElementoDef("Peso muerto rumano", 3, 6, 8, descanso: 150),
            ElementoDef("Hip thrust", 3, 8, 10, descanso: 120),
            ElementoDef("Curl femoral", 3, 10, 12, descanso: 90),
            ElementoDef("Gemelo de pie", 3, 10, 15, descanso: 60),
            // Ejercicio de tiempo: el rango son segundos, no repeticiones.
            ElementoDef("Isométrico extensión de cuádriceps a 60°", 4, 30, 45, descanso: 60),
            // Sin rango: series libres.
            ElementoDef("Rueda abdominal", 3, descanso: 60),
        ]),

        RutinaDef(nombre: "Jueves – Torso", elementos: [
            ElementoDef("Press inclinado con mancuernas, agarre neutro", 3, 8, 10, descanso: 120),
            ElementoDef("Jalón con agarre neutro", 3, 8, 10, descanso: 120),
            ElementoDef("Aperturas en polea", 3, 12, 15, descanso: 60),
            ElementoDef("Remo unilateral con mancuerna", 3, 8, 10, descanso: 90),
            ElementoDef("Elevaciones laterales en polea", 3, 12, 15, descanso: 60),
            ElementoDef("Pájaros", 3, 15, 15, descanso: 60),
        ]),

        RutinaDef(nombre: "Viernes – Hombro y brazos", elementos: [
            ElementoDef("Press de hombro en máquina", 3, 10, 12, descanso: 120),
            ElementoDef("Elevaciones laterales", 4, 12, 15, descanso: 60),
            ElementoDef("Rotación externa en polea", 3, 15, 15, descanso: 45),
            ElementoDef("Curl inclinado", 3, 10, 12, descanso: 90, superserie: "A"),
            ElementoDef("Extensión de tríceps sobre la cabeza", 3, 10, 12, descanso: 90, superserie: "A"),
            ElementoDef("Curl predicador", 3, 10, 12, descanso: 90, superserie: "B"),
            ElementoDef("Press francés", 3, 10, 12, descanso: 90, superserie: "B"),
        ]),
    ]
}
