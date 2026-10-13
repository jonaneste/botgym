import SwiftUI
import SwiftData

/// El plan completo, semana a semana.
struct VistaPlan: View {
    @Environment(\.modelContext) private var contexto
    @Environment(ControladorEntreno.self) private var controlador

    @Query(sort: \DiaPlanificado.fecha) private var dias: [DiaPlanificado]
    @Query(sort: \Rutina.orden) private var rutinas: [Rutina]

    @State private var diaAAnotar: DiaPlanificado?

    var body: some View {
        List {
            if let objetivo = diaObjetivo {
                Section {
                    cuentaAtras(objetivo)
                }
            }

            ForEach(semanas) { semana in
                Section {
                    ForEach(semana.dias) { dia in
                        FilaDiaPlan(
                            dia: dia,
                            esHoy: esHoy(dia),
                            alMarcar: { marcar(dia) },
                            alAnotarKm: { diaAAnotar = dia },
                            alEmpezar: rutinaDe(dia).map { rutina in { empezar(rutina) } }
                        )
                    }
                } header: {
                    cabeceraSemana(semana)
                }
            }

            if dias.isEmpty {
                ContentUnavailableView(
                    "Sin plan todavía",
                    systemImage: "calendar",
                    description: Text("Pídele a Claude el plan y aparecerá aquí solo, igual que las rutinas.")
                )
            }
        }
        .navigationTitle("Plan")
        .sheet(item: $diaAAnotar) { dia in
            VistaAnotarCarrera(dia: dia) { kilometros in
                RepositorioPlan(contexto: contexto).marcar(dia, hecho: true, kilometros: kilometros)
            }
        }
    }

    // MARK: - Cuenta atrás

    @ViewBuilder
    private func cuentaAtras(_ objetivo: DiaPlanificado) -> some View {
        let faltan = ResumenPlan.diasHasta(objetivo.fecha)
        VStack(alignment: .leading, spacing: 8) {
            Text(objetivo.titulo)
                .font(.headline)
            HStack(spacing: 0) {
                CifraDestacada(
                    valor: faltan > 0 ? "\(faltan)" : (faltan == 0 ? "Hoy" : "—"),
                    etiqueta: faltan == 1 ? "Día" : "Días",
                    color: Paleta.carrera
                )
                Divider().frame(height: 28)
                CifraDestacada(
                    valor: "\(diasHechos)/\(diasQueCuentan)",
                    etiqueta: "Cumplidos",
                    color: Paleta.logrado
                )
                Divider().frame(height: 28)
                CifraDestacada(
                    valor: Formato.numeroCorto(kilometrosHechos),
                    etiqueta: "km hechos"
                )
            }
            .frame(minHeight: 44)

            if racha.actual > 0 || racha.mejor > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Paleta.calentamiento)
                    Text(racha.actual == 1 ? "1 día seguido" : "\(racha.actual) días seguidos")
                        .fontWeight(.semibold)
                    if racha.mejor > racha.actual {
                        Text("· mejor: \(racha.mejor)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
    }

    private func cabeceraSemana(_ semana: SemanaPlan) -> some View {
        HStack {
            Text(semana.titulo)
            Spacer()
            if semana.kilometros > 0 {
                Text("\(Formato.numeroCorto(semana.kilometros)) km")
                    .foregroundStyle(Paleta.carrera)
            }
        }
        .font(.caption.weight(.semibold))
    }

    // MARK: - Acciones

    private func marcar(_ dia: DiaPlanificado) {
        // Una carrera pide los kilómetros en vez de darse por hecha a secas:
        // el plan dice 12 y el cuerpo dice lo que dice, y sin el número la
        // marca no sirve para nada después.
        if dia.tipo.tieneCarrera, !dia.hecho {
            diaAAnotar = dia
            return
        }
        RepositorioPlan(contexto: contexto).marcar(dia, hecho: !dia.hecho)
    }

    private func empezar(_ rutina: Rutina) {
        controlador.empezar(desde: rutina)
    }

    private func rutinaDe(_ dia: DiaPlanificado) -> Rutina? {
        guard dia.tipo.tieneGimnasio, !dia.hecho, controlador.entreno == nil else { return nil }
        guard let nombre = dia.nombreRutina else { return nil }
        let buscado = Ejercicio.normalizar(nombre)
        return rutinas.first { Ejercicio.normalizar($0.nombre) == buscado }
    }

    // MARK: - Cuentas

    private func esHoy(_ dia: DiaPlanificado) -> Bool {
        CalendarioEntrenos.es.isDate(dia.fecha, inSameDayAs: Date())
    }

    private var diaObjetivo: DiaPlanificado? {
        dias.last { $0.tipo == .competicion }
    }

    /// Los días que se pueden cumplir: descansar no se cumple.
    private var diasQueCuentan: Int {
        dias.filter { !$0.tipo.esDescanso && $0.tipo != .turismo }.count
    }

    private var diasHechos: Int {
        dias.filter(\.hecho).count
    }

    private var kilometrosHechos: Double {
        dias.compactMap(\.kilometrosHechos).reduce(0, +)
    }

    /// El descanso y el turismo no son exigibles: no se pueden cumplir, así
    /// que no entran en la racha ni para romperla ni para alargarla.
    private var racha: RachaPlan {
        ResumenPlan.racha(
            de: dias.map {
                (
                    fecha: $0.fecha,
                    esExigible: !$0.tipo.esDescanso && $0.tipo != .turismo,
                    hecho: $0.hecho
                )
            }
        )
    }

    private var semanas: [SemanaPlan] {
        let agrupados = Dictionary(grouping: dias) {
            CalendarioEntrenos.inicioDeSemana(de: $0.fecha)
        }
        return agrupados.keys.sorted().map { lunes in
            let delaSemana = (agrupados[lunes] ?? []).sorted { $0.fecha < $1.fecha }
            return SemanaPlan(
                inicio: lunes,
                dias: delaSemana,
                kilometros: delaSemana.compactMap(\.kilometrosAEnseñar).reduce(0, +)
            )
        }
    }
}

/// Una semana del plan, para la cabecera de sección.
struct SemanaPlan: Identifiable {
    var id: Date { inicio }
    let inicio: Date
    let dias: [DiaPlanificado]
    let kilometros: Double

    var titulo: String {
        "Semana del \(Formato.diaYMes(inicio))"
    }
}

/// Una fila del plan.
struct FilaDiaPlan: View {
    let dia: DiaPlanificado
    let esHoy: Bool
    let alMarcar: () -> Void
    let alAnotarKm: () -> Void
    /// `nil` si este día no tiene una rutina que empezar ahora mismo.
    let alEmpezar: (() -> Void)?

    private var color: Color {
        switch dia.tipo {
        case .competicion: return Paleta.record
        case .carrera, .gimnasioYCarrera: return Paleta.carrera
        case .gimnasio: return .accentColor
        case .descanso, .turismo: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(Formato.diaSemanaCorto(dia.fecha))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(esHoy ? Color.accentColor : .secondary)
                    .textCase(.uppercase)
                Text("\(CalendarioEntrenos.es.component(.day, from: dia.fecha))")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(esHoy ? Color.accentColor : .primary)
            }
            .frame(width: 38)

            Image(systemName: dia.tipo.icono)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.16), in: .rect(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(dia.titulo)
                    .font(.subheadline.weight(esHoy ? .bold : .medium))
                    // Tachado además del verde: el estado no puede decirse
                    // solo con color.
                    .strikethrough(dia.hecho, color: .secondary)
                    .foregroundStyle(dia.hecho ? .secondary : .primary)

                HStack(spacing: 6) {
                    if let km = dia.kilometrosAEnseñar {
                        Text("\(Formato.numeroCorto(km)) km")
                            .foregroundStyle(Paleta.carrera)
                            .fontWeight(.semibold)
                    }
                    if !dia.notas.isEmpty {
                        Text(dia.notas)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .font(.caption)

                if let alEmpezar {
                    Button("Empezar este entreno", action: alEmpezar)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            if !dia.tipo.esDescanso {
                Button(action: alMarcar) {
                    Image(systemName: dia.hecho ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(dia.hecho ? Paleta.logrado : Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dia.hecho ? "Hecho" : "Marcar como hecho")
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(esHoy ? Color.accentColor.opacity(0.08) : nil)
        .swipeActions(edge: .trailing) {
            if dia.tipo.tieneCarrera {
                Button {
                    alAnotarKm()
                } label: {
                    Label("Kilómetros", systemImage: "figure.run")
                }
                .tint(Paleta.carrera)
            }
        }
    }
}

/// Hoja para anotar los kilómetros de una carrera del plan.
struct VistaAnotarCarrera: View {
    let dia: DiaPlanificado
    let alGuardar: (Double) -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var kilometros: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Kilómetros")
                        Spacer()
                        CampoDecimal(marcador: "km", valor: $kilometros)
                            .frame(maxWidth: 110)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
                    }
                } header: {
                    Text(dia.titulo)
                } footer: {
                    if let previstos = dia.kilometros {
                        Text("El plan pone \(Formato.numeroCorto(previstos)) km. Anota los que hayas hecho de verdad.")
                    }
                }

                Section {
                    Button {
                        alGuardar(kilometros)
                        cerrar()
                    } label: {
                        Text("Guardar")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(kilometros <= 0)
                }
            }
            .navigationTitle("Anotar carrera")
            .navigationBarTitleDisplayMode(.inline)
            .conBotonHecho()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear {
                // Se precarga lo previsto: casi siempre es lo que se ha hecho,
                // y así anotar la tirada es confirmar y no teclear.
                if kilometros == 0 { kilometros = dia.kilometrosHechos ?? dia.kilometros ?? 0 }
            }
        }
    }
}
