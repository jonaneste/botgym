import SwiftUI
import SwiftData

/// Edita el objetivo de un ejercicio dentro de una rutina.
struct VistaEditorElementoRutina: View {
    let elemento: ElementoRutina

    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto

    private var esTiempo: Bool { elemento.tipoRegistro.esTiempo }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(elemento.ejercicio?.nombre ?? "Ejercicio borrado")
                            .font(.headline)
                        if let ejercicio = elemento.ejercicio {
                            Text(ejercicio.descripcionCorta)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Series") {
                    Stepper(
                        "\(elemento.seriesObjetivo) series",
                        value: Binding(
                            get: { elemento.seriesObjetivo },
                            set: { elemento.seriesObjetivo = $0 }
                        ),
                        in: 1...12
                    )
                }

                Section {
                    EditorRango(
                        minimo: Binding(get: { elemento.objetivoMin }, set: { elemento.objetivoMin = $0 }),
                        maximo: Binding(get: { elemento.objetivoMax }, set: { elemento.objetivoMax = $0 }),
                        esTiempo: esTiempo
                    )
                } header: {
                    Text(esTiempo ? "Rango de segundos" : "Rango de repeticiones")
                } footer: {
                    if elemento.tipoRegistro == .repeticionesPorLado {
                        Text("Este ejercicio se anota por lado: el rango se entiende por cada brazo o pierna.")
                    } else {
                        Text("Déjalo vacío para series libres, sin objetivo. La doble progresión necesita un rango para sugerir subidas.")
                    }
                }

                Section {
                    EditorRango(
                        minimo: Binding(get: { elemento.rirMin }, set: { elemento.rirMin = $0 }),
                        maximo: Binding(get: { elemento.rirMax }, set: { elemento.rirMax = $0 }),
                        esTiempo: false
                    )
                } header: {
                    Text("RIR objetivo")
                } footer: {
                    Text("Repeticiones que deberías poder hacer de más al acabar la serie.")
                }

                Section("Descanso") {
                    SelectorDescanso(segundos: Binding(
                        get: { elemento.descansoSegundos },
                        set: { elemento.descansoSegundos = $0 }
                    ))
                }

                Section("Notas") {
                    TextField("Altura del banco, agarre, lo que sea", text: Binding(
                        get: { elemento.notas },
                        set: { elemento.notas = $0 }
                    ), axis: .vertical)
                    .lineLimit(2...5)
                }
            }
            .navigationTitle("Objetivo")
            .navigationBarTitleDisplayMode(.inline)
            .conBotonHecho()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hecho") {
                        try? contexto.save()
                        cerrar()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
