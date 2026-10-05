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
    }
}
