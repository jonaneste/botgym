import SwiftUI

/// Campo de peso en kg.
///
/// Guarda el texto en estado local y lo sincroniza con el `Double` en ambas
/// direcciones, para que el teclado español pueda escribir "62,5" con coma y
/// para que el botón de copiar la serie anterior se refleje al instante.
struct CampoDecimal: View {
    let marcador: String
    @Binding var valor: Double
    var alEditar: (() -> Void)?

    @State private var texto: String = ""
    @FocusState private var enfocado: Bool

    var body: some View {
        TextField(marcador, text: $texto)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .focused($enfocado)
            .textFieldStyle(.plain)
            .onAppear { texto = Self.aTexto(valor) }
            .onChange(of: texto) { _, nuevo in
                let normalizado = nuevo
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespaces)
                if normalizado.isEmpty {
                    if valor != 0 { valor = 0; alEditar?() }
                } else if let numero = Double(normalizado), numero != valor {
                    valor = numero
                    alEditar?()
                }
            }
            .onChange(of: valor) { _, nuevo in
                // No pisar lo que el usuario está escribiendo.
                guard !enfocado else { return }
                let esperado = Self.aTexto(nuevo)
                if texto != esperado { texto = esperado }
            }
    }

    private static func aTexto(_ valor: Double) -> String {
        valor == 0 ? "" : Formato.numeroCorto(valor)
    }
}

/// Campo de repeticiones o segundos.
struct CampoEntero: View {
    let marcador: String
    @Binding var valor: Int
    var alEditar: (() -> Void)?

    @State private var texto: String = ""
    @FocusState private var enfocado: Bool

    var body: some View {
        TextField(marcador, text: $texto)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .focused($enfocado)
            .textFieldStyle(.plain)
            .onAppear { texto = valor == 0 ? "" : "\(valor)" }
            .onChange(of: texto) { _, nuevo in
                let filtrado = nuevo.filter(\.isNumber)
                if filtrado != nuevo { texto = filtrado; return }
                if filtrado.isEmpty {
                    if valor != 0 { valor = 0; alEditar?() }
                } else if let numero = Int(filtrado), numero != valor {
                    valor = numero
                    alEditar?()
                }
            }
            .onChange(of: valor) { _, nuevo in
                guard !enfocado else { return }
                let esperado = nuevo == 0 ? "" : "\(nuevo)"
                if texto != esperado { texto = esperado }
            }
    }
}

/// Campo opcional, para el RIR: vacío significa "no anotado".
struct CampoEnteroOpcional: View {
    let marcador: String
    @Binding var valor: Int?
    var alEditar: (() -> Void)?

    @State private var texto: String = ""
    @FocusState private var enfocado: Bool

    var body: some View {
        TextField(marcador, text: $texto)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded, weight: .medium))
            .focused($enfocado)
            .textFieldStyle(.plain)
            .onAppear { texto = valor.map(String.init) ?? "" }
            .onChange(of: texto) { _, nuevo in
                let filtrado = nuevo.filter(\.isNumber)
                if filtrado != nuevo { texto = filtrado; return }
                if filtrado.isEmpty {
                    if valor != nil { valor = nil; alEditar?() }
                } else if let numero = Int(filtrado), numero != valor {
                    valor = numero
                    alEditar?()
                }
            }
            .onChange(of: valor) { _, nuevo in
                guard !enfocado else { return }
                let esperado = nuevo.map(String.init) ?? ""
                if texto != esperado { texto = esperado }
            }
    }
}

/// Barra que cierra el teclado numérico, que no trae tecla de retorno.
struct BarraTeclado: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Hecho") {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    #endif
                }
                .fontWeight(.semibold)
            }
        }
    }
}

extension View {
    /// Añade el botón "Hecho" sobre el teclado numérico.
    func conBotonHecho() -> some View {
        modifier(BarraTeclado())
    }
}
