import SwiftUI
import SwiftData

/// Edita los objetivos de un ejercicio dentro del entreno en curso: rango,
/// RIR y descanso. No toca la rutina de origen.
struct VistaEditarObjetivoEjercicio: View {
    let ejercicio: EjercicioEntreno

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(ejercicio.nombreEjercicio)
                        .font(.headline)
                }

                Section {
                    Stepper(
                        "Series objetivo: \(ejercicio.seriesObjetivo)",
                        value: Binding(
                            get: { ejercicio.seriesObjetivo },
                            set: { ejercicio.seriesObjetivo = $0 }
                        ),
                        in: 1...12
                    )
                } header: {
                    Text("Series")
                }

                Section {
                    EditorRango(
                        minimo: Binding(get: { ejercicio.objetivoMin }, set: { ejercicio.objetivoMin = $0 }),
                        maximo: Binding(get: { ejercicio.objetivoMax }, set: { ejercicio.objetivoMax = $0 }),
                        esTiempo: ejercicio.tipoRegistro.esTiempo
                    )
                } header: {
                    Text(ejercicio.tipoRegistro.esTiempo ? "Rango de segundos" : "Rango de repeticiones")
                } footer: {
                    Text("Déjalo vacío para series libres, sin objetivo.")
                }

                Section("RIR objetivo") {
                    EditorRango(
                        minimo: Binding(get: { ejercicio.rirMin }, set: { ejercicio.rirMin = $0 }),
                        maximo: Binding(get: { ejercicio.rirMax }, set: { ejercicio.rirMax = $0 }),
                        esTiempo: false
                    )
                }

                Section("Descanso") {
                    SelectorDescanso(segundos: Binding(
                        get: { ejercicio.descansoSegundos },
                        set: { ejercicio.descansoSegundos = $0 }
                    ))
                }
            }
            .navigationTitle("Objetivo")
            .navigationBarTitleDisplayMode(.inline)
            .conBotonHecho()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hecho") { cerrar() }.fontWeight(.semibold)
                }
            }
        }
    }
}

/// Dos campos para un rango "de X a Y".
struct EditorRango: View {
    @Binding var minimo: Int?
    @Binding var maximo: Int?
    let esTiempo: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Desde").font(.caption).foregroundStyle(.secondary)
                CampoEnteroOpcional(marcador: esTiempo ? "s" : "reps", valor: $minimo)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Hasta").font(.caption).foregroundStyle(.secondary)
                CampoEnteroOpcional(marcador: esTiempo ? "s" : "reps", valor: $maximo)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
            }
        }
    }
}

/// Selector de descanso con los valores habituales más uno libre.
struct SelectorDescanso: View {
    @Binding var segundos: Int

    private let opciones = [0, 30, 45, 60, 90, 120, 150, 180, 240]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(segundos == 0 ? "Sin descanso automático" : Formato.descanso(segundos))
                .font(.system(.title3, design: .rounded, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(opciones, id: \.self) { opcion in
                        Button {
                            segundos = opcion
                        } label: {
                            Text(opcion == 0 ? "Sin" : Formato.descanso(opcion))
                                .font(.subheadline.weight(segundos == opcion ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    segundos == opcion ? Color.accentColor : Color(.secondarySystemFill),
                                    in: .capsule
                                )
                                .foregroundStyle(segundos == opcion ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
