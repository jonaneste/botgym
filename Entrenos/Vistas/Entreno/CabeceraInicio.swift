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
    @Environment(\.dynamicTypeSize) private var tamañoTexto

    @Query(
        filter: #Predicate<Entreno> { $0.estadoRaw == rawEntrenoFinalizado },
        sort: \Entreno.fechaInicio,
        order: .reverse
    )
    private var entrenos: [Entreno]

    @Query(sort: \DiaPlanificado.fecha) private var dias: [DiaPlanificado]

    @State private var kilometros: Double = 0
    @State private var nombre: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saludo)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(Formato.capitalizarPrimera(Formato.fechaLarga(Date())))
                        .font(.caption)
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
                    .background(.white.opacity(0.28), in: .capsule)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Faltan \(faltan) días para la competición")
                }
            }

            Divider()
                .overlay(.white.opacity(0.3))
                .padding(.vertical, 14)

            // La tira y su separador van juntos: sin plan no hay tira, y el
            // separador suelto dejaba dos líneas con un hueco vacío en medio.
            tiraDeLaSemana

            // A tamaños de accesibilidad las tres cifras no caben en fila: los
            // números crecen y se quedaban encogidos al 60 %. Ahí se apilan,
            // igual que hace la fila de serie.
            if tamañoTexto.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    cifraEnFila("\(entrenosEstaSemana)", etiqueta(entrenosEstaSemana, "entreno", "entrenos"))
                    cifraEnFila(Formato.numeroCorto(kilometros), "km")
                    cifraEnFila("\(seriesEstaSemana)", etiqueta(seriesEstaSemana, "serie", "series"))
                }
            } else {
                HStack(spacing: 0) {
                    cifra("\(entrenosEstaSemana)", etiqueta(entrenosEstaSemana, "entreno", "entrenos"))
                    separador
                    cifra(Formato.numeroCorto(kilometros), "km")
                    separador
                    cifra("\(seriesEstaSemana)", etiqueta(seriesEstaSemana, "serie", "series"))
                }
                .frame(minHeight: 50)
            }
        }
        // Bloque de color entero y no un tinte pálido: es la cabecera de la
        // app, lo primero que se ve, y un degradado al 18 % sobre gris se leía
        // como un elemento desactivado.
        .foregroundStyle(.white)
        .padding(18)
        .background {
            // El degradado va de oscuro a más oscuro, y no de claro a oscuro.
            // Medido: el azul con un 18 % de blanco encima daba 3,49:1 con
            // texto blanco —y 2,63:1 con el blanco al 75 % que había en la
            // fecha—, por debajo del 4,5:1 que pide la HIG para texto de hasta
            // 17 pt. Así la esquina peor queda en 5,69:1 y el resto sube hasta
            // 9,2:1, con el texto en blanco puro.
            //
            // El relieve se hace con negro translúcido y no con `Color.mix`,
            // que es de iOS 18: la app compila contra el SDK con el que va CI.
            RoundedRectangle(cornerRadius: 22)
                .fill(Paleta.acento)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.12), .black.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(.rect(cornerRadius: 22))
        }
        .shadow(color: Paleta.acento.opacity(0.3), radius: 10, y: 4)
        .onAppear {
            kilometros = kilometrosDeLaSemana()
            nombre = Ajustes.cargar(en: contexto).nombre
        }
    }

    /// Los siete días de la semana, con lo que toca y lo que llevas hecho.
    ///
    /// Es lo que hace que esta cabecera sea de esta app y no de cualquier
    /// otra: un número grande sobre una etiqueta pequeña lo tiene medio App
    /// Store. Aquí lo que se mira al abrir es si la semana va cuadrada, y eso
    /// es una fila de siete días, no un total.
    ///
    /// Relleno es hecho, hueco es pendiente, y el día de hoy lleva anillo.
    /// El color nunca va solo: el hecho lleva además el relleno, y el de hoy
    /// el anillo, así que se distinguen sin distinguir colores.
    @ViewBuilder
    private var tiraDeLaSemana: some View {
        if !diasDeLaSemana.isEmpty {
            HStack(spacing: 0) {
                ForEach(diasDeLaSemanaOrdenados, id: \.fecha) { dia in
                    VStack(spacing: 5) {
                        Text(Formato.diaSemanaCorto(dia.fecha).prefix(1).uppercased())
                            .font(.system(size: 11, weight: .semibold))
                        ZStack {
                            Circle()
                                .fill(dia.hecho ? Color.white : .white.opacity(0.25))
                                .frame(width: 22, height: 22)
                            if dia.hecho {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(Paleta.acento)
                            }
                            if esHoy(dia) {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .frame(width: 30, height: 30)
                            }
                        }
                        .frame(height: 30)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Formato.capitalizarPrimera(Formato.nombreDiaSemana(dia.fecha)))
                    .accessibilityValue(
                        dia.hecho ? "\(dia.titulo), hecho" : "\(dia.titulo), pendiente"
                    )
                }
            }
            .padding(.top, 14)

            Divider()
                .overlay(.white.opacity(0.3))
                .padding(.top, 14)
        }
    }

    private func esHoy(_ dia: DiaPlanificado) -> Bool {
        CalendarioEntrenos.es.isDate(dia.fecha, inSameDayAs: Date())
    }

    /// Los días exigibles de la semana más los de descanso, en orden: la tira
    /// tiene que enseñar la semana entera, no solo lo que se puede cumplir.
    private var diasDeLaSemanaOrdenados: [DiaPlanificado] {
        let fin = CalendarioEntrenos.inicioDeSemanaSiguiente(de: Date())
        return dias
            .filter { $0.fecha >= inicioDeSemana && $0.fecha < fin }
            .sorted { $0.fecha < $1.fecha }
    }

    private func cifraEnFila(_ valor: String, _ etiqueta: String) -> some View {
        HStack(spacing: 8) {
            Text(valor)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animacion(Muelles.cifra, value: valor)
            Text(etiqueta)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
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
                .contentTransition(.numericText())
                .animacion(Muelles.cifra, value: valor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(etiqueta)
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Piezas

    // MARK: - Cuentas

    private var saludo: String {
        let hora = CalendarioEntrenos.es.component(.hour, from: Date())
        let base: String
        switch hora {
        case 6..<13: base = "Buenos días"
        case 13..<21: base = "Buenas tardes"
        default: base = "Buenas noches"
        }
        // Sin nombre no se pone la coma colgando: quien lo borre en Ajustes
        // quiere que no salga, no un saludo cortado.
        return nombre.isEmpty ? base : "\(base), \(nombre)"
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

    private var diasHastaLaCompeticion: Int? {
        guard let dia = dias.last(where: { $0.tipo == .competicion }) else { return nil }
        let faltan = ResumenPlan.diasHasta(dia.fecha)
        return faltan >= 0 ? faltan : nil
    }
}
