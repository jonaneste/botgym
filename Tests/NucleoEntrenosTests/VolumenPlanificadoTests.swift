import XCTest
@testable import NucleoEntrenos

final class VolumenPlanificadoTests: XCTestCase {

    private func elemento(
        _ grupo: GrupoMuscular,
        secundarios: [GrupoMuscular] = [],
        series: Int
    ) -> ElementoPlanificado {
        ElementoPlanificado(grupoPrincipal: grupo, gruposSecundarios: secundarios, series: series)
    }

    func testElGrupoPrincipalSumaUnaSeriePorSerie() {
        let cuenta = VolumenPlanificado.seriesPorGrupo([elemento(.pecho, series: 4)])
        XCTAssertEqual(cuenta[.pecho], 4)
    }

    func testCadaSecundarioSumaMedia() {
        // Misma regla que el recuento real: si no, el objetivo que sale de la
        // rutina no se podría comparar con lo que luego cuenta la semana.
        let cuenta = VolumenPlanificado.seriesPorGrupo([
            elemento(.pecho, secundarios: [.triceps, .hombroAnterior], series: 4)
        ])
        XCTAssertEqual(cuenta[.pecho], 4)
        XCTAssertEqual(cuenta[.triceps], 2)
        XCTAssertEqual(cuenta[.hombroAnterior], 2)
    }

    func testUnSecundarioRepetidoNoSumaDosVeces() {
        let cuenta = VolumenPlanificado.seriesPorGrupo([
            elemento(.pecho, secundarios: [.triceps, .triceps], series: 4)
        ])
        XCTAssertEqual(cuenta[.triceps], 2)
    }

    func testUnSecundarioIgualAlPrincipalNoSumaAparte() {
        let cuenta = VolumenPlanificado.seriesPorGrupo([
            elemento(.pecho, secundarios: [.pecho], series: 3)
        ])
        XCTAssertEqual(cuenta[.pecho], 3)
    }

    func testLoQueNoCuentaEnVolumenNoApareceNunca() {
        let cuenta = VolumenPlanificado.seriesPorGrupo([
            elemento(.sinClasificar, secundarios: [.sinClasificar], series: 5)
        ])
        XCTAssertTrue(cuenta.isEmpty)
    }

    func testVariosEjerciciosDelMismoGrupoSeSuman() {
        let cuenta = VolumenPlanificado.seriesPorGrupo([
            elemento(.espalda, series: 4),
            elemento(.espalda, series: 3),
            elemento(.dorsal, secundarios: [.espalda], series: 4),
        ])
        XCTAssertEqual(cuenta[.espalda], 4 + 3 + 2)
        XCTAssertEqual(cuenta[.dorsal], 4)
    }

    func testCeroSeriesNoSuma() {
        XCTAssertTrue(VolumenPlanificado.seriesPorGrupo([elemento(.pecho, series: 0)]).isEmpty)
    }

    // MARK: - Objetivos

    func testElObjetivoRedondeaHaciaAbajo() {
        // 1 × 0,5 = 0,5 de tríceps: redondear a 1 dejaría la semana sin
        // cumplir haciendo exactamente el plan.
        let objetivos = VolumenPlanificado.objetivos([
            elemento(.pecho, secundarios: [.triceps], series: 3)
        ])
        XCTAssertEqual(objetivos[.pecho], 3)
        XCTAssertEqual(objetivos[.triceps], 1)
    }

    func testUnGrupoQueNoLlegaAUnaSerieNoSeSigue() {
        // Medio serie de antebrazo no es un objetivo: sería una fila más en
        // rojo sin decir nada.
        let objetivos = VolumenPlanificado.objetivos([
            elemento(.biceps, secundarios: [.antebrazo], series: 1)
        ])
        XCTAssertEqual(objetivos[.biceps], 1)
        XCTAssertNil(objetivos[.antebrazo])
    }

    func testUnaSemanaCompletaDaObjetivosCreibles() {
        // La semana que se le dejó cargada a Jon, en corto: cuatro sesiones.
        let semana: [ElementoPlanificado] = [
            // Tirón
            elemento(.dorsal, secundarios: [.biceps], series: 4),
            elemento(.espalda, secundarios: [.biceps], series: 4),
            elemento(.dorsal, series: 3),
            elemento(.espalda, series: 3),
            elemento(.biceps, series: 6),
            // Empuje
            elemento(.pecho, secundarios: [.triceps], series: 4),
            elemento(.pecho, series: 6),
            elemento(.triceps, series: 6),
        ]
        let objetivos = VolumenPlanificado.objetivos(semana)
        XCTAssertEqual(objetivos[.dorsal], 7)
        XCTAssertEqual(objetivos[.espalda], 7)
        XCTAssertEqual(objetivos[.pecho], 10)
        // Bíceps: 6 directas más la media de dos ejercicios de 4 = 10. El
        // trabajo indirecto cuenta, que es justo lo que se olvida al poner un
        // objetivo a ojo y acaba en codos sobrecargados.
        XCTAssertEqual(objetivos[.biceps], 10)
        XCTAssertEqual(objetivos[.triceps], 8)
    }

    func testSinElementosNoHayObjetivos() {
        XCTAssertTrue(VolumenPlanificado.objetivos([]).isEmpty)
    }
}
