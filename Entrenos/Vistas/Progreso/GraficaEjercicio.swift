import SwiftUI
import Charts

/// Qué métrica se pinta en la gráfica de un ejercicio.
enum MetricaGrafica: String, CaseIterable, Identifiable {
    case unRM
    case pesoMaximo
    case volumen

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .unRM: return "1RM estimado"
        case .pesoMaximo: return "Peso máximo"
        case .volumen: return "Volumen"
        }
    }

    var unidad: String {
        switch self {
        case .unRM, .pesoMaximo, .volumen: return "kg"
        }
    }
}

/// Evolución de un ejercicio en el tiempo.
struct GraficaEjercicio: View {
    let puntos: [PuntoGrafica]
    let metrica: MetricaGrafica

    var body: some View {
        Chart(puntosConValor, id: \.fecha) { punto in
            LineMark(
                x: .value("Fecha", punto.fecha),
                y: .value(metrica.nombre, valor(de: punto))
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            PointMark(
                x: .value("Fecha", punto.fecha),
                y: .value(metrica.nombre, valor(de: punto))
            )
            .foregroundStyle(Color.accentColor)
            .symbolSize(50)
        }
        .chartYScale(domain: dominioY)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { valor in
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

    /// Puntos que tienen valor para esta métrica. El 1RM no existe en los
    /// ejercicios de tiempo, y pintar ceros daría una gráfica engañosa.
    private var puntosConValor: [PuntoGrafica] {
        puntos.filter { punto in
            switch metrica {
            case .unRM: return punto.unRMEstimado != nil
            case .pesoMaximo: return punto.pesoMaximo > 0
            case .volumen: return punto.volumen > 0
            }
        }
    }

    private func valor(de punto: PuntoGrafica) -> Double {
        switch metrica {
        case .unRM: return punto.unRMEstimado ?? 0
        case .pesoMaximo: return punto.pesoMaximo
        case .volumen: return punto.volumen
        }
    }

    /// El eje Y no arranca en cero: con cargas de 60 a 70 kg, un eje desde 0
    /// aplanaría la línea y no se vería el progreso.
    private var dominioY: ClosedRange<Double> {
        let valores = puntosConValor.map(valor(de:))
        guard let minimo = valores.min(), let maximo = valores.max() else {
            return 0...1
        }
        guard minimo != maximo else {
            let margen = max(1, abs(minimo) * 0.1)
            return (minimo - margen)...(maximo + margen)
        }
        let margen = (maximo - minimo) * 0.15
        return max(0, minimo - margen)...(maximo + margen)
    }
}
