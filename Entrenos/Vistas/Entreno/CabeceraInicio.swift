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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saludo)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(Formato.capitalizarPrimera(Formato.fechaLarga(Date())))
                        .font(.caption)
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
                if let faltan = diasHastaLaCompeticion {
                    // La cuenta atrás como pastilla y no como dos líneas
                    // sueltas: es un dato de otra naturaleza que el resto de
                    // la tarjeta, y así no compite con el saludo.
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.caption2)
                        Text(faltan == 0 ? "¡Hoy!" : "\(faltan) días")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.22), in: .capsule)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Faltan \(faltan) días para la competición")
                }
            }

            Divider()
                .overlay(.white.opacity(0.3))
                .padding(.vertical, 14)

            HStack(spacing: 0) {
                cifra("\(entrenosEstaSemana)", etiqueta(entrenosEstaSemana, "entreno", "entrenos"))
                separador
                cifra(Formato.numeroCorto(kilometros), "km")
                separador
                cifra("\(seriesEstaSemana)", etiqueta(seriesEstaSemana, "serie", "series"))
                if diasExigibles > 0 {
                    separador
                    anilloDeSemana
                }
            }
            .frame(minHeight: 50)
        }
        // Bloque de color entero y no un tinte pálido: es la cabecera de la
        // app, lo primero que se ve, y un degradado al 18 % sobre gris se leía
        // como un elemento desactivado.
        .foregroundStyle(.white)
        .padding(18)
        .background {
            // El relieve se hace con blanco y negro translúcidos encima del
            // acento, y no con `Color.mix`, que es de iOS 18: la app tiene
            // que seguir compilando contra el SDK con el que va CI.
            RoundedRectangle(cornerRadius: 22)
                .fill(Paleta.acento)
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.18), .black.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(.rect(cornerRadius: 22))
        }
        .shadow(color: Paleta.acento.opacity(0.3), radius: 10, y: 4)
        .onAppear { kilometros = kilometrosDeLaSemana() }
    }

    private var separador: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(width: 1, height: 34)
    }

    private func cifra(_ valor: String, _ etiqueta: String) -> some View {
        VStack(spacing: 1) {
            Text(valor)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(etiqueta)
                .font(.caption2.weight(.medium))
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Piezas

    /// El anillo dice qué parte de lo que tocaba esta semana está hecha. Sin
    /// plan cargado no hay contra qué medir, así que no se enseña: un anillo
    /// vacío al 0 % se lee como ir mal, y no es que vayas mal, es que no hay
    /// plan.
    @ViewBuilder
    private var anilloDeSemana: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(1, Double(diasCumplidos) / Double(diasExigibles)))
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: diasCumplidos)
            Text("\(diasCumplidos)/\(diasExigibles)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: 46, height: 46)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Esta semana")
        .accessibilityValue("\(diasCumplidos) de \(diasExigibles) días del plan cumplidos")
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
