import SwiftUI
import Charts

/// Barras de series totales por semana.
struct GraficaSeriesSemanales: View {
    let datos: [SeriesDeSemana]

    var body: some View {
        Chart(datos) { semana in
            BarMark(
                x: .value("Semana", semana.inicioSemana, unit: .weekOfYear),
                y: .value("Series", semana.series)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(4)
            // Cada barra se anuncia sola, para poder recorrerlas una a una
            // en lugar de oír solo el resumen del conjunto.
            .accessibilityLabel(Formato.diaYMes(semana.inicioSemana))
            .accessibilityValue("\(Formato.numeroCorto(semana.series)) series")
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { valor in
                AxisGridLine()
                AxisValueLabel {
                    if let fecha = valor.as(Date.self) {
                        Text(Formato.diaYMes(fecha))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .accessibilityLabel("Series por semana")
        .accessibilityValue(resumenAccesible)
    }

    private var resumenAccesible: String {
        guard let ultima = datos.last else { return "Sin datos todavía" }
        let total = datos.reduce(0.0) { $0 + $1.series }
        let media = total / Double(datos.count)
        return "\(datos.count) semanas, esta semana \(Formato.numeroCorto(ultima.series)) series, media \(Formato.numeroCorto(media))"
    }
}
