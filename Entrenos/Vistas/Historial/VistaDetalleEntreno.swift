import SwiftUI
import SwiftData

/// Detalle de un entreno pasado, editable.
struct VistaDetalleEntreno: View {
    let entreno: Entreno

    @Environment(\.modelContext) private var contexto
    @State private var editando = false

    var body: some View {
        List {
            resumen

            ForEach(gruposVisuales) { grupo in
                // La etiqueta de superserie va como fila y no como cabecera de
                // sección: con la lista en estilo llano, una cabecera se queda
                // pegada arriba al desplazar y se lee como si todo lo de
                // debajo fuese superserie.
                if grupo.esSuperserie {
                    Label("Superserie", systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .filaDesnuda(arriba: 14, abajo: 0)
                }

                ForEach(grupo.ejercicios) { ejercicio in
                    bloqueEjercicio(ejercicio)
                }
            }

            if entreno.molestiaHombro != nil || entreno.molestiaRodilla != nil {
                Section("Molestia articular") {
                    VStack(spacing: 10) {
                        if let hombro = entreno.molestiaHombro {
                            filaMolestia("Hombro", hombro)
                        }
                        if let rodilla = entreno.molestiaRodilla {
                            filaMolestia("Rodilla", rodilla)
                        }
                    }
                    .tarjeta()
                    .filaDesnuda(arriba: 4, abajo: 4)
                }
            }

            Section("Notas") {
                notas
                    .tarjeta()
                    .filaDesnuda(arriba: 4, abajo: 28)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("\(Formato.fechaLarga(entreno.fechaInicio)) · \(Formato.hora(entreno.fechaInicio))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                CifraDestacada(
                    valor: Formato.duracionLarga(entreno.duracionFinal ?? 0),
                    etiqueta: "Duración"
                )
                divisor
                CifraDestacada(
                    valor: "\(entreno.seriesCompletadas)",
                    etiqueta: "Series"
                )
                divisor
                CifraDestacada(
                    valor: Formato.volumen(entreno.volumenTotal),
                    etiqueta: "Volumen"
                )
            }

            if let origen = entreno.nombreRutinaOrigen, origen != entreno.nombre {
                Label("Desde la rutina «\(origen)»", systemImage: "list.bullet.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
        .filaDesnuda(arriba: 10, abajo: 4)
    }

    private var divisor: some View {
        Divider().frame(height: 28)
    }

    @ViewBuilder
    private var notas: some View {
        if editando {
            TextField("Notas del entreno", text: Binding(
                get: { entreno.notas },
                set: { entreno.notas = $0 }
            ), axis: .vertical)
            .lineLimit(2...8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if entreno.notas.isEmpty {
            Text("Sin notas")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(entreno.notas)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    /// En lectura, el ejercicio y sus series comparten una tarjeta: son un
    /// bloque que se lee de arriba abajo. Editando no pueden, porque cada
    /// serie necesita ser su propia fila de `List` para conservar el gesto de
    /// deslizar para borrar, que solo existe dentro de una lista.
    @ViewBuilder
    private func bloqueEjercicio(_ ejercicio: EjercicioEntreno) -> some View {
        if editando {
            cabeceraEjercicio(ejercicio)
                .tarjeta()
                .filaDesnuda(arriba: 10, abajo: 4)

            ForEach(ejercicio.seriesOrdenadas) { serie in
                filaSerieEditable(serie, ejercicio: ejercicio)
                    .tarjeta(relleno: 12, radio: 12)
                    .filaDesnuda(arriba: 2, abajo: 2)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            borrar(serie, de: ejercicio)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
            }
        } else {
            tarjetaEjercicio(ejercicio)
                .filaDesnuda(arriba: 6, abajo: 2)
        }
    }

    private func tarjetaEjercicio(_ ejercicio: EjercicioEntreno) -> some View {
        let series = ejercicio.seriesOrdenadas
        return VStack(spacing: 0) {
            cabeceraEjercicio(ejercicio)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if !series.isEmpty {
                Divider()
            }

            ForEach(series) { serie in
                filaSerieLectura(serie, ejercicio: ejercicio)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                // El separador se salta la última serie, y se mete 48 puntos
                // para que arranque donde arranca el texto y no debajo del
                // número de serie.
                if serie.idPublico != series.last?.idPublico {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .tarjeta(relleno: 0)
    }

    private func cabeceraEjercicio(_ ejercicio: EjercicioEntreno) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ejercicio.nombreEjercicio)
                .font(.headline)
            HStack(spacing: 6) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func filaSerieLectura(_ serie: SerieRegistrada, ejercicio: EjercicioEntreno) -> some View {
        HStack(spacing: 10) {
            if serie.esCalentamiento {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(Paleta.calentamiento)
                    .frame(width: 22)
            } else {
                Text("\(serie.orden + 1)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }

            Text(Formato.resumenSerie(
                peso: serie.peso,
                repeticiones: serie.repeticiones,
                segundos: serie.segundos,
                tipo: ejercicio.tipoRegistro
            ))
            .font(.system(.body, design: .rounded, weight: .medium))

            Spacer()

            if let rir = serie.rir {
                Pastilla(texto: "RIR \(rir)", color: .secondary)
            }
        }
    }

    private func filaSerieEditable(_ serie: SerieRegistrada, ejercicio: EjercicioEntreno) -> some View {
        HStack(spacing: 8) {
            Text("\(serie.orden + 1)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
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
        .frame(maxWidth: .infinity)
    }

    /// Las series que quedan se copian a un array antes de borrar: mutar la
    /// relación mientras se recorre corrompe el recorrido a mitad.
    private func borrar(_ serie: SerieRegistrada, de ejercicio: EjercicioEntreno) {
        let restantes = ejercicio.seriesOrdenadas.filter { $0 !== serie }
        contexto.delete(serie)
        for (indice, otra) in restantes.enumerated() { otra.orden = indice }
        try? contexto.save()
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
