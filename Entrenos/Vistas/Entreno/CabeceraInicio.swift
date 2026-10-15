import SwiftUI
import SwiftData

/// Lo primero que se ve al abrir la app: cómo va la semana.
///
/// Antes la pestaña abría con un botón de «empezar entreno vacío» y una lista
/// de rutinas, que es un menú, no un resumen. La pregunta con la que se abre
/// una app de entrenos no es «¿qué rutinas tengo?», es «¿cómo voy?», y eso
/// hasta ahora había que ir a buscarlo a otra pestaña.
struct CabeceraInicio: View {
    @Environment(\.modelContext) private var contexto

    @Query(
        filter: #Predicate<Entreno> { $0.estadoRaw == rawEntrenoFinalizado },
        sort: \Entreno.fechaInicio,
        order: .reverse
    )
    private var entrenos: [Entreno]

    @Query(sort: \DiaPlanificado.fecha) private var dias: [DiaPlanificado]

    @State private var kilometros: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saludo)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(Formato.capitalizarPrimera(Formato.fechaLarga(Date())))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let faltan = diasHastaLaCompeticion {
                    VStack(spacing: 0) {
                        Text("\(faltan)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Paleta.carrera)
                        Text(faltan == 1 ? "día" : "días")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Faltan \(faltan) días para la competición")
                }
            }

            HStack(spacing: 16) {
                anilloDeSemana

                VStack(alignment: .leading, spacing: 6) {
                    fila("dumbbell.fill", "\(entrenosEstaSemana)", etiqueta(entrenosEstaSemana, "entreno", "entrenos"), Paleta.acento)
                    fila("figure.run", Formato.numeroCorto(kilometros), "km", Paleta.carrera)
                    fila("flame.fill", "\(seriesEstaSemana)", etiqueta(seriesEstaSemana, "serie", "series"), Paleta.logrado)
                }

                Spacer(minLength: 0)
            }
        }
        .tarjetaDestacada(Paleta.acento)
        .onAppear { kilometros = kilometrosDeLaSemana() }
    }

    // MARK: - Piezas

    /// El anillo dice qué parte de lo que tocaba esta semana está hecha. Sin
    /// plan cargado no hay contra qué medir, así que no se enseña: un anillo
    /// vacío al 0 % se lee como ir mal, y no es que vayas mal, es que no hay
    /// plan.
    @ViewBuilder
    private var anilloDeSemana: some View {
        if diasExigibles > 0 {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(1, Double(diasCumplidos) / Double(diasExigibles)))
                    .stroke(
                        Paleta.logrado.gradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.5), value: diasCumplidos)
                VStack(spacing: 0) {
                    Text("\(diasCumplidos)/\(diasExigibles)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("semana")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 76, height: 76)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Esta semana")
            .accessibilityValue("\(diasCumplidos) de \(diasExigibles) días cumplidos")
        }
    }

    private func fila(_ icono: String, _ valor: String, _ unidad: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(valor)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(unidad)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cuentas

    private var saludo: String {
        switch CalendarioEntrenos.es.component(.hour, from: Date()) {
        case 0..<6: return "Buenas noches"
        case 6..<13: return "Buenos días"
        case 13..<21: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private func etiqueta(_ cuantos: Int, _ singular: String, _ plural: String) -> String {
        cuantos == 1 ? singular : plural
    }

    private var inicioDeSemana: Date { CalendarioEntrenos.inicioDeSemana(de: Date()) }

    private var entrenosDeLaSemana: [Entreno] {
        entrenos.filter { $0.fechaInicio >= inicioDeSemana }
    }

    private var entrenosEstaSemana: Int { entrenosDeLaSemana.count }

    private var seriesEstaSemana: Int {
        entrenosDeLaSemana.reduce(0) { $0 + $1.seriesCompletadas }
    }

    private func kilometrosDeLaSemana() -> Double {
        RepositorioCarreras(contexto: contexto)
            .todas()
            .filter { $0.fechaInicio >= inicioDeSemana }
            .reduce(0) { $0 + $1.distanciaKm }
    }

    /// Los días del plan de esta semana que se pueden cumplir: descansar y
    /// pasear por París no cuentan ni a favor ni en contra.
    private var diasDeLaSemana: [DiaPlanificado] {
        let fin = CalendarioEntrenos.inicioDeSemanaSiguiente(de: Date())
        return dias.filter {
            $0.fecha >= inicioDeSemana && $0.fecha < fin
                && !$0.tipo.esDescanso && $0.tipo != .turismo
        }
    }

    private var diasExigibles: Int { diasDeLaSemana.count }

    private var diasCumplidos: Int { diasDeLaSemana.filter(\.hecho).count }

    private var diasHastaLaCompeticion: Int? {
        guard let dia = dias.last(where: { $0.tipo == .competicion }) else { return nil }
        let faltan = ResumenPlan.diasHasta(dia.fecha)
        return faltan >= 0 ? faltan : nil
    }
}
