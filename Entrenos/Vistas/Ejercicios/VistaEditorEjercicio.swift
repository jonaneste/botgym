import SwiftUI
import SwiftData

/// Crea o edita un ejercicio de la biblioteca.
struct VistaEditorEjercicio: View {
    /// `nil` para crear uno nuevo.
    let ejercicio: Ejercicio?
    var alGuardar: ((Ejercicio) -> Void)?

    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto

    @State private var nombre = ""
    @State private var grupoPrincipal: GrupoMuscular = .pecho
    @State private var gruposSecundarios: Set<GrupoMuscular> = []
    @State private var material: Material = .barra
    @State private var tipoRegistro: TipoRegistro = .repeticiones
    @State private var notas = ""

    private var esNuevo: Bool { ejercicio == nil }

    private var puedeGuardar: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Press banca con barra", text: $nombre)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Grupo muscular principal") {
                    Picker("Principal", selection: $grupoPrincipal) {
                        ForEach(GrupoMuscular.allCases, id: \.self) { grupo in
                            Text(grupo.nombre).tag(grupo)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    ForEach(GrupoMuscular.allCases, id: \.self) { grupo in
                        if grupo != grupoPrincipal {
                            Button {
                                if gruposSecundarios.contains(grupo) {
                                    gruposSecundarios.remove(grupo)
                                } else {
                                    gruposSecundarios.insert(grupo)
                                }
                            } label: {
                                HStack {
                                    Text(grupo.nombre)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if gruposSecundarios.contains(grupo) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Grupos secundarios")
                } footer: {
                    Text("Cuentan como media serie en el recuento semanal por grupo muscular.")
                }

                Section("Material") {
                    Picker("Material", selection: $material) {
                        ForEach(Material.allCases, id: \.self) { opcion in
                            Label(opcion.nombre, systemImage: opcion.icono).tag(opcion)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Picker("Tipo", selection: $tipoRegistro) {
                        ForEach(TipoRegistro.allCases, id: \.self) { opcion in
                            Text(opcion.nombre).tag(opcion)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Cómo se anota")
                } footer: {
                    Text(explicacionTipo)
                }

                Section("Notas") {
                    TextField("Técnica, altura del banco, lo que sea", text: $notas, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(esNuevo ? "Nuevo ejercicio" : "Editar ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { guardar() }
                        .fontWeight(.semibold)
                        .disabled(!puedeGuardar)
                }
            }
            .onAppear(perform: cargar)
        }
    }

    private var explicacionTipo: String {
        switch tipoRegistro {
        case .repeticiones:
            return "Se anotan peso y repeticiones."
        case .tiempo:
            return "Se anotan peso y segundos. Para isométricos y planchas."
        case .repeticionesPorLado:
            return "Las repeticiones se entienden por cada lado."
        }
    }

    private func cargar() {
        guard let ejercicio else { return }
        nombre = ejercicio.nombre
        grupoPrincipal = ejercicio.grupoPrincipal
        gruposSecundarios = Set(ejercicio.gruposSecundarios)
        material = ejercicio.material
        tipoRegistro = ejercicio.tipoRegistro
        notas = ejercicio.notas
    }

    private func guardar() {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombreLimpio.isEmpty else { return }

        // El principal no puede estar además entre los secundarios.
        let secundarios = gruposSecundarios.filter { $0 != grupoPrincipal }

        if let existente = ejercicio {
            existente.nombre = nombreLimpio
            existente.grupoPrincipal = grupoPrincipal
            existente.gruposSecundarios = Array(secundarios)
            existente.material = material
            existente.tipoRegistro = tipoRegistro
            existente.notas = notas
            try? contexto.save()
            alGuardar?(existente)
        } else {
            let nuevo = Ejercicio(
                nombre: nombreLimpio,
                grupoPrincipal: grupoPrincipal,
                gruposSecundarios: Array(secundarios),
                material: material,
                tipoRegistro: tipoRegistro,
                notas: notas,
                esPersonalizado: true
            )
            contexto.insert(nuevo)
            try? contexto.save()
            alGuardar?(nuevo)
        }
        cerrar()
    }
}
