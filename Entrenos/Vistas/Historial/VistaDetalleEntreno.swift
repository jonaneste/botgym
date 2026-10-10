import SwiftUI
import SwiftData

/// Detalle de un entreno pasado, editable.
struct VistaDetalleEntreno: View {
    let entreno: Entreno

    @Environment(\.modelContext) private var contexto
    @State private var editando = false

    var body: some View {
        List {
            Section {
                resumen
            }

            ForEach(gruposVisuales) { grupo in
                Section {
                    ForEach(grupo.ejercicios) { ejercicio in
                        bloqueEjercicio(ejercicio)
                    }
                } header: {
                    if grupo.esSuperserie {
                        Label("Superserie", systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }

            if entreno.molestiaHombro != nil || entreno.molestiaRodilla != nil {
                Section("Molestia articular") {
                    if let hombro = entreno.molestiaHombro {
                        filaMolestia("Hombro", hombro)
                    }
                    if let rodilla = entreno.molestiaRodilla {
                        filaMolestia("Rodilla", rodilla)
                    }
                }
            }

            Section("Notas") {
                if editando {
                    TextField("Notas del entreno", text: Binding(
                        get: { entreno.notas },
                        set: { entreno.notas = $0 }
                    ), axis: .vertical)
                    .lineLimit(2...8)
                } else if entreno.notas.isEmpty {
                    Text("Sin notas")
                        .foregroundStyle(.secondary)
                } else {
                    Text(entreno.notas)
                }
            }
        }
        .navigationTitle(entreno.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .conBotonHecho()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editando ? "Hecho" : "Editar") {
                    if editando { try? contexto.save() }
                    withAnimation { editando.toggle() }
                }
                .fontWeight(editando ? .semibold : .regular)
            }
        }
    }

    // MARK: - Resumen

    private var resumen: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Formato.fechaLarga(entreno.fechaInicio)) · \(Formato.hora(entreno.fechaInicio))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                columna("Duración", Formato.duracionLarga(entreno.duracionFinal ?? 0))
                Divider()
                columna("Series", "\(entreno.seriesCompletadas)")
                Divider()
                columna("Volumen", Formato.volumen(entreno.volumenTotal))
            }
            .frame(height: 42)

            if let origen = entreno.nombreRutinaOrigen, origen != entreno.nombre {
                Label("Desde la rutina «\(origen)»", systemImage: "list.bullet.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func columna(_ titulo: String, _ valor: String) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func filaMolestia(_ zona: String, _ valor: Int) -> some View {
        HStack {
            Text(zona)
            Spacer()
            Text("\(valor)/10")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Paleta.molestia(valor))
        }
    }

    // MARK: - Ejercicio

    @ViewBuilder
    private func bloqueEjercicio(_ ejercicio: EjercicioEntreno) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ejercicio.nombreEjercicio)
                .font(.headline)
            HStack(spacing: 8) {
                Text("\(ejercicio.seriesEfectivas.count) series")
                Text("·")
                Text(Formato.volumen(ejercicio.volumen))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !ejercicio.notas.isEmpty {
                Text(ejercicio.notas)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)

        ForEach(ejercicio.seriesOrdenadas) { serie in
            if editando {
                filaSerieEditable(serie, ejercicio: ejercicio)
            } else {
                filaSerieLectura(serie, ejercicio: ejercicio)
            }
        }
    }

    private func filaSerieLectura(_ serie: SerieRegistrada, ejercicio: EjercicioEntreno) -> some View {
        HStack(spacing: 10) {
            if serie.esCalentamiento {
                Image(systemName: "flame")
                    .font(.caption)
                    .foregroundStyle(Paleta.calentamiento)
                    .frame(width: 22)
            } else {
                Text("\(serie.orden + 1)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }

            Text(Formato.resumenSerie(
                peso: serie.peso,
                repeticiones: serie.repeticiones,
                segundos: serie.segundos,
                tipo: ejercicio.tipoRegistro
            ))
            .font(.system(.body, design: .rounded))

            Spacer()

            if let rir = serie.rir {
                Text("RIR \(rir)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func filaSerieEditable(_ serie: SerieRegistrada, ejercicio: EjercicioEntreno) -> some View {
        HStack(spacing: 8) {
            Text("\(serie.orden + 1)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            CampoDecimal(marcador: "kg", valor: Binding(
                get: { serie.peso }, set: { serie.peso = $0 }
            ))
            .frame(minWidth: 58)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))

            Text("×").foregroundStyle(.secondary)

            if ejercicio.tipoRegistro.esTiempo {
                CampoEntero(marcador: "s", valor: Binding(
                    get: { serie.segundos ?? 0 }, set: { serie.segundos = $0 }
                ))
                .frame(minWidth: 52)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
            } else {
                CampoEntero(marcador: "reps", valor: Binding(
                    get: { serie.repeticiones }, set: { serie.repeticiones = $0 }
                ))
                .frame(minWidth: 52)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
            }

            CampoEnteroOpcional(marcador: "RIR", valor: Binding(
                get: { serie.rir }, set: { serie.rir = $0 }
            ))
            .frame(minWidth: 44)
            .padding(.vertical, 6)
            .background(Color(.quaternarySystemFill), in: .rect(cornerRadius: 8))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                let restantes = ejercicio.seriesOrdenadas.filter { $0 !== serie }
                contexto.delete(serie)
                for (indice, otra) in restantes.enumerated() { otra.orden = indice }
                try? contexto.save()
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }

    // MARK: - Superseries

    private var gruposVisuales: [GrupoEjercicios] {
        var grupos: [GrupoEjercicios] = []
        for ejercicio in entreno.ejerciciosOrdenados {
            if let id = ejercicio.idSuperserie,
               let ultimo = grupos.last,
               ultimo.idSuperserie == id {
                grupos[grupos.count - 1].ejercicios.append(ejercicio)
            } else {
                grupos.append(
                    GrupoEjercicios(
                        id: ejercicio.idPublico,
                        idSuperserie: ejercicio.idSuperserie,
                        ejercicios: [ejercicio]
                    )
                )
            }
        }
        return grupos
    }
}
