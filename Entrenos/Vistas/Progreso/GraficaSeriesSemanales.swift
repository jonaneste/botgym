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
            // Sin esto VoiceOver anuncia «gráfico» y nada más: las barras no
            // llevan etiqueta propia y los ejes no se leen.
            .accessibilityLabel(Formato.diaYMes(semana.inicioSemana))
            .accessibilityValue("\(Formato.numeroCorto(semana.series)) series")
        }
        .accessibilityLabel("Series por semana")
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { valor in
                AxisGridLine()
                AxisValueLabel {
                    if let fecha = valor.as(Date.self) {
                        // Ocho semanas de «13 oct» a `.caption2` caben justas
                        // en el ancho de un móvil; al crecer el texto chocaban
                        // unas con otras en lugar de encogerse.
                        Text(Formato.diaYMes(fecha))
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}
