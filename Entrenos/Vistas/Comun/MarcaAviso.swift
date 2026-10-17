import SwiftUI

extension View {
    /// Pone un triángulo de aviso en la esquina de un campo o de un texto.
    ///
    /// Lo usan la fila del entreno en curso y la del historial, para señalar
    /// la misma cifra con la misma marca: lo que se avisa al escribirlo tiene
    /// que seguir avisando cuando se vuelve a mirar días después.
    @ViewBuilder
    func marcaDeAviso(_ sospecha: SospechaSerie?) -> some View {
        if let sospecha {
            overlay(alignment: .topTrailing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Paleta.aviso)
                    .offset(x: 3, y: -3)
                    .accessibilityLabel(sospecha.aviso)
            }
        } else {
            self
        }
    }
}
