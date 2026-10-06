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
                // Se filtra como en `CampoEntero`, que sí lo hacía. El teclado
                // decimal no impide pegar, ni dictar, ni un teclado físico, y
                // `Double(_:)` acepta "inf" y "1e400" tan contento.
                let filtrado = Self.filtrar(nuevo)
                if filtrado != nuevo { texto = filtrado; return }

                let normalizado = filtrado.replacingOccurrences(of: ",", with: ".")
                if normalizado.isEmpty {
                    if valor != 0 { valor = 0; alEditar?() }
                    return
                }
                guard let numero = Double(normalizado) else { return }

                // Y se recorta en el sitio. Un peso imposible guardado en una
                // serie no rompía solo esta pantalla: aguas abajo hay varias
                // conversiones a `Int`, que ATRAPAN fuera del rango de Int64 y
                // cierran la app, y con un infinito el JSON de exportación
                // fallaba para siempre sin forma de encontrar la serie
                // culpable desde la interfaz.
                let limitado = LimitesEntrada.peso(numero)
                if limitado != numero {
                    texto = Self.aTexto(limitado)
                    return
                }
                if limitado != valor {
                    valor = limitado
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

    /// Deja pasar dígitos y un único separador decimal.
    ///
    /// `isNumber` por sí solo acepta dígitos de otros alfabetos, que `Double`
    /// luego no sabe leer, así que se exige además ASCII.
    static func filtrar(_ entrada: String) -> String {
        var resultado = ""
        var yaHaySeparador = false
        for caracter in entrada {
            if caracter.isASCII && caracter.isNumber {
                resultado.append(caracter)
            } else if (caracter == "," || caracter == ".") && !yaHaySeparador {
                yaHaySeparador = true
                resultado.append(caracter)
            }
        }
        return resultado
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
                    return
                }
                // Veinte dígitos no caben en un `Int`, así que `Int(filtrado)`
                // devolvía nil y el campo se quedaba mostrando un número que
                // no era el valor guardado. Se recorta al tope en su lugar.
                let numero = Int(filtrado) ?? LimitesEntrada.enteroMaximo
                let limitado = LimitesEntrada.recortar(numero)
                if limitado != numero {
                    texto = "\(limitado)"
                    return
                }
                if limitado != valor {
                    valor = limitado
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
                    return
                }
                let numero = Int(filtrado) ?? LimitesEntrada.enteroMaximo
                let limitado = LimitesEntrada.recortar(numero)
                if limitado != numero {
                    texto = "\(limitado)"
                    return
                }
                if limitado != valor {
                    valor = limitado
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
