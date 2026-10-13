import SwiftUI
import SwiftData

/// Configura el objetivo de series semanales por grupo muscular.
struct VistaObjetivosSemanales: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Rutina.orden) private var rutinas: [Rutina]

    @State private var ajustes: Ajustes?
    @State private var objetivos: [GrupoMuscular: Int] = [:]

    var body: some View {
        List {
            Section {
                Text("Series semanales que quieres hacer de cada grupo. Déjalo en 0 para no seguir ese grupo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(regionesConGrupos, id: \.self) { region in
                Section(region.nombre) {
                    ForEach(gruposDe(region), id: \.self) { grupo in
                        Stepper(
                            value: Binding(
                                get: { objetivos[grupo] ?? 0 },
                                set: { nuevo in
                                    if nuevo <= 0 {
                                        objetivos[grupo] = nil
                                    } else {
                                        objetivos[grupo] = nuevo
                                    }
                                    guardar()
                                }
                            ),
                            in: 0...40
                        ) {
                            HStack {
                                Text(grupo.nombre)
                                Spacer()
                                Text(objetivos[grupo].map { "\($0)" } ?? "—")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(objetivos[grupo] == nil ? .secondary : .primary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }

            Section {
                // Primero el que sale de sus propias rutinas: un objetivo de
                // catálogo que el plan no alcanza pinta la semana en rojo para
                // siempre sin que nadie se haya saltado nada.
                if !objetivosDeMisRutinas.isEmpty {
                    Button("Usar las series de mis rutinas") {
                        objetivos = objetivosDeMisRutinas
                        guardar()
                    }
                }
                Button("Aplicar un plan de hipertrofia (10-16 por grupo)") {
                    aplicarPlanSugerido()
                }
                Button("Quitar todos los objetivos", role: .destructive) {
                    objetivos = [:]
                    guardar()
                }
            } footer: {
                if objetivosDeMisRutinas.isEmpty {
                    Text("El plan sugerido reparte entre 10 y 16 series semanales por grupo grande, que es el rango habitual para ganar masa, y menos en los pequeños.")
                } else {
                    Text("«Usar las series de mis rutinas» cuenta lo que suman tus \(rutinas.count) rutinas en una semana, contando media serie por cada grupo secundario. Es el objetivo que se cumple haciendo tu propio plan.")
                }
            }
        }
        .navigationTitle("Objetivos semanales")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let cargados = ajustes ?? Ajustes.cargar(en: contexto)
            ajustes = cargados
            objetivos = cargados.objetivosSemanales
        }
    }

    /// Solo las regiones que tienen algún grupo con objetivo posible, para no
    /// dibujar una sección vacía.
    private var regionesConGrupos: [RegionCorporal] {
        RegionCorporal.allCases.filter { !gruposDe($0).isEmpty }
    }

    /// `sinClasificar` no se ofrece: no suma series, así que su objetivo nunca
    /// se podría cumplir.
    private func gruposDe(_ region: RegionCorporal) -> [GrupoMuscular] {
        GrupoMuscular.allCases.filter { $0.region == region && $0.cuentaEnVolumen }
    }

    /// Lo que suman todas las rutinas en una semana.
    ///
    /// Se cuentan todas y no solo las de una carpeta: la app no sabe cuáles
    /// entran en la semana, y sumar de más es mejor que sumar de menos, que
    /// dejaría un objetivo por debajo de lo que ya se hace.
    private var objetivosDeMisRutinas: [GrupoMuscular: Int] {
        let elementos = rutinas.flatMap { rutina in
            rutina.elementosOrdenados.compactMap { elemento -> ElementoPlanificado? in
                guard let ejercicio = elemento.ejercicio else { return nil }
                return ElementoPlanificado(
                    grupoPrincipal: ejercicio.grupoPrincipal,
                    gruposSecundarios: ejercicio.gruposSecundarios,
                    series: elemento.seriesObjetivo
                )
            }
        }
        return VolumenPlanificado.objetivos(elementos)
    }

    private func aplicarPlanSugerido() {
        objetivos = [
            .pecho: 12, .espalda: 12, .dorsal: 12,
            .cuadriceps: 12, .isquios: 10, .gluteo: 10,
            .hombroLateral: 12, .hombroPosterior: 10, .hombroAnterior: 6,
            .biceps: 10, .triceps: 10,
            .gemelo: 8, .core: 6, .trapecio: 6, .lumbar: 4, .antebrazo: 4,
        ]
        guardar()
    }

    private func guardar() {
        ajustes?.objetivosSemanales = objetivos
        try? contexto.save()
    }
}
