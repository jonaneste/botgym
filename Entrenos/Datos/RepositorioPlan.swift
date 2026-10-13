import Foundation
import SwiftData

/// Consultas y escrituras del plan.
@MainActor
struct RepositorioPlan {
    let contexto: ModelContext

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    /// Todos los días, de más antiguo a más reciente.
    func todos() -> [DiaPlanificado] {
        let descriptor = FetchDescriptor<DiaPlanificado>(
            sortBy: [SortDescriptor(\.fecha, order: .forward)]
        )
        return (try? contexto.fetch(descriptor)) ?? []
    }

    /// El día de hoy, si el plan lo cubre.
    func hoy(_ ahora: Date = Date()) -> DiaPlanificado? {
        dia(ahora)
    }

    func dia(_ fecha: Date) -> DiaPlanificado? {
        let inicio = CalendarioEntrenos.es.startOfDay(for: fecha)
        // El rango se compara con dos fechas sueltas y no con un `Range` en el
        // predicado: en iOS 17 `#Predicate` con rangos de fechas da resultados
        // raros, y una comparación simple no.
        let siguiente = CalendarioEntrenos.es.date(byAdding: .day, value: 1, to: inicio) ?? inicio
        var descriptor = FetchDescriptor<DiaPlanificado>(
            predicate: #Predicate<DiaPlanificado> { $0.fecha >= inicio && $0.fecha < siguiente }
        )
        descriptor.fetchLimit = 1
        return (try? contexto.fetch(descriptor))?.first
    }

    /// Los próximos días a partir de hoy, incluido hoy.
    func proximos(_ cuantos: Int, desde ahora: Date = Date()) -> [DiaPlanificado] {
        let inicio = CalendarioEntrenos.es.startOfDay(for: ahora)
        var descriptor = FetchDescriptor<DiaPlanificado>(
            predicate: #Predicate<DiaPlanificado> { $0.fecha >= inicio },
            sortBy: [SortDescriptor(\.fecha, order: .forward)]
        )
        descriptor.fetchLimit = cuantos
        return (try? contexto.fetch(descriptor)) ?? []
    }

    /// Mete un plan importado, sustituyendo los días que ya estuvieran.
    ///
    /// Se sustituye día a día y no borrando el plan entero a propósito: lo que
    /// el usuario ya marcó como hecho no lo puede perder porque llegue una
    /// versión nueva del archivo, y es justo lo que pasaría borrando y
    /// volviendo a crear.
    @discardableResult
    func guardar(_ plan: PlanImportado) -> Int {
        let existentes = Dictionary(
            todos().map { ($0.fecha, $0) },
            uniquingKeysWith: { primero, _ in primero }
        )

        for dia in plan.dias {
            if let existente = existentes[dia.fecha] {
                existente.tipo = dia.tipo
                existente.titulo = dia.titulo
                existente.notas = dia.notas
                existente.kilometros = dia.kilometros
                existente.nombreRutina = dia.nombreRutina
                existente.nombrePlan = plan.nombre
            } else {
                let nuevo = DiaPlanificado(
                    fecha: dia.fecha,
                    tipo: dia.tipo,
                    titulo: dia.titulo,
                    notas: dia.notas,
                    kilometros: dia.kilometros,
                    nombreRutina: dia.nombreRutina,
                    nombrePlan: plan.nombre
                )
                contexto.insert(nuevo)
            }
        }

        try? contexto.save()
        return plan.dias.count
    }

    /// Marca o desmarca un día. Los kilómetros hechos solo se tocan si se dan.
    func marcar(_ dia: DiaPlanificado, hecho: Bool, kilometros: Double? = nil) {
        dia.hecho = hecho
        if let kilometros {
            // Recortado aquí y no en el campo porque también entra por la
            // exportación: un infinito o un disparate guardado rompería el
            // JSON para siempre, igual que pasaba con los pesos.
            let limpio = kilometros.isFinite ? min(max(kilometros, 0), LectorPlanJSON.maxKilometros) : 0
            dia.kilometrosHechos = limpio > 0 ? limpio : nil
        }
        // Desmarcar borra lo que se anotó: dejar unos kilómetros en un día que
        // dice no haberse hecho es una contradicción que luego se exporta.
        if !hecho { dia.kilometrosHechos = nil }
        try? contexto.save()
    }

    /// Borra el plan entero. Es lo único que hace falta para empezar otro.
    func borrarTodo() {
        // Se recoge en un array antes de borrar: mutar la colección que se
        // está recorriendo corrompe el recorrido a mitad.
        for dia in todos() {
            contexto.delete(dia)
        }
        try? contexto.save()
    }
}
