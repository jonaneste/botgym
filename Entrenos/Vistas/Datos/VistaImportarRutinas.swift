import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Importa rutinas desde JSON, pegado o desde archivo.
struct VistaImportarRutinas: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var texto = ""
    @State private var error: ErrorImportacion?
    @State private var revision: ImportadorRutinas.Revision?
    @State private var mapeo: [String: Ejercicio] = [:]
    @State private var resultado: ImportadorRutinas.Resultado?
    @State private var mostrarSelectorArchivo = false

    var body: some View {
        NavigationStack {
            Group {
                if let resultado {
                    pantallaHecho(resultado)
                } else if let revision, !revision.todoResuelto {
                    pantallaDesconocidos(revision)
                } else if let revision {
                    pantallaConfirmar(revision)
                } else {
                    pantallaPegar
                }
            }
            .navigationTitle("Importar rutinas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { cerrar() }
                }
            }
            .fileImporter(
                isPresented: $mostrarSelectorArchivo,
                allowedContentTypes: [.json, .text],
                allowsMultipleSelection: false
            ) { salida in
                cargarArchivo(salida)
            }
        }
    }

    // MARK: - Pegar

    private var pantallaPegar: some View {
        Form {
            Section {
                TextEditor(text: $texto)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 180)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("JSON")
            } footer: {
                if let error {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(error.ruta.isEmpty ? "Error" : error.ruta, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(error.mensaje)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Pega aquí lo que te dé la IA, o usa el botón de archivo.")
                }
            }

            Section {
                Button {
                    if let pegado = UIPasteboard.general.string {
                        texto = pegado
                        error = nil
                    }
                } label: {
                    Label("Pegar del portapapeles", systemImage: "doc.on.clipboard")
                }

                Button {
                    mostrarSelectorArchivo = true
                } label: {
                    Label("Elegir archivo", systemImage: "folder")
                }
            }

            Section {
                Button {
                    revisar()
                } label: {
                    Text("Revisar")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Ejemplo") {
                Text(Self.ejemplo)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button {
                    texto = Self.ejemplo
                    error = nil
                } label: {
                    Label("Usar el ejemplo", systemImage: "wand.and.stars")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Nombres desconocidos

    private func pantallaDesconocidos(_ revision: ImportadorRutinas.Revision) -> some View {
        Form {
            Section {
                Text("\(revision.desconocidos.count) \(revision.desconocidos.count == 1 ? "ejercicio no está" : "ejercicios no están") en tu biblioteca. Elige uno existente o déjalo para crearlo nuevo.")
                    .font(.subheadline)
            }

            ForEach(revision.desconocidos) { desconocido in
                Section(desconocido.nombre) {
                    Button {
                        mapeo[desconocido.nombre] = nil
                    } label: {
                        HStack {
                            Text("Crear uno nuevo")
                                .foregroundStyle(.primary)
                            Spacer()
                            if mapeo[desconocido.nombre] == nil {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }

                    ForEach(desconocido.parecidos) { candidato in
                        Button {
                            mapeo[desconocido.nombre] = candidato
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidato.nombre)
                                        .foregroundStyle(.primary)
                                    Text(candidato.descripcionCorta)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if mapeo[desconocido.nombre]?.idPublico == candidato.idPublico {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }

                    if desconocido.parecidos.isEmpty {
                        Text("Sin parecidos en la biblioteca.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    importar(revision)
                } label: {
                    Text("Importar")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
            } footer: {
                Text("Los ejercicios nuevos se crean sin grupo muscular ni material: no se adivinan a partir del nombre, porque una suposición mala falsearía el recuento semanal en silencio. Quedan marcados para que los completes.")
            }
        }
    }

    // MARK: - Confirmar

    private func pantallaConfirmar(_ revision: ImportadorRutinas.Revision) -> some View {
        Form {
            Section("Se va a importar") {
                if let carpeta = revision.rutinas.carpeta {
                    Label(carpeta, systemImage: "folder")
                }
                ForEach(Array(revision.rutinas.rutinas.enumerated()), id: \.offset) { _, rutina in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rutina.nombre)
                            .font(.body.weight(.medium))
                        Text("\(rutina.ejercicios.count) ejercicios · \(rutina.ejercicios.reduce(0) { $0 + $1.series }) series")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    importar(revision)
                } label: {
                    Text("Importar")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
            } footer: {
                Text("Todos los ejercicios existen ya en tu biblioteca.")
            }
        }
    }

    // MARK: - Hecho

    private func pantallaHecho(_ resultado: ImportadorRutinas.Resultado) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("\(resultado.rutinasCreadas) \(resultado.rutinasCreadas == 1 ? "rutina importada" : "rutinas importadas")")
                .font(.headline)
            if let carpeta = resultado.carpeta {
                Text("En la carpeta «\(carpeta)»")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if resultado.ejerciciosCreados > 0 {
                Text("Se han creado \(resultado.ejerciciosCreados) ejercicios nuevos. Revisa su grupo muscular y material en la biblioteca.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Hecho") { cerrar() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Acciones

    private func revisar() {
        error = nil
        do {
            let rutinas = try LectorRutinasJSON.leer(texto)
            let importador = ImportadorRutinas(contexto: contexto)
            let nueva = importador.revisar(rutinas)
            mapeo = [:]
            revision = nueva
        } catch let fallo as ErrorImportacion {
            error = fallo
        } catch {
            // `error` sin `self` es el error capturado, que es un `let`:
            // asignarle no compila.
            self.error = ErrorImportacion(ruta: "", mensaje: error.localizedDescription)
        }
    }

    private func importar(_ revision: ImportadorRutinas.Revision) {
        let importador = ImportadorRutinas(contexto: contexto)
        resultado = importador.importar(revision.rutinas, mapeo: mapeo)
    }

    private func cargarArchivo(_ salida: Result<[URL], Error>) {
        switch salida {
        case .failure(let fallo):
            error = ErrorImportacion(ruta: "", mensaje: fallo.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            let concedido = url.startAccessingSecurityScopedResource()
            defer { if concedido { url.stopAccessingSecurityScopedResource() } }
            do {
                texto = try String(contentsOf: url, encoding: .utf8)
                error = nil
            } catch {
                self.error = ErrorImportacion(
                    ruta: "",
                    mensaje: "No se pudo leer el archivo: \(error.localizedDescription)"
                )
            }
        }
    }

    static let ejemplo = """
    {
      "version": 1,
      "carpeta": "Bloque otoño",
      "rutinas": [
        {
          "nombre": "Lunes – Empuje",
          "ejercicios": [
            { "nombre": "Press banca con barra", "series": 4,
              "reps": "8-10", "rir": "2-3", "descanso": 150 },
            { "nombre": "Elevaciones laterales", "series": 4,
              "reps": "12-15", "descanso": 60 }
          ]
        }
      ]
    }
    """
}
