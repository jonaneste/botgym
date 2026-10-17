import SwiftUI
import SwiftData

/// Pestaña de entreno: reanuda el abierto, o deja empezar uno nuevo.
struct VistaEntrenoInicio: View {
    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.modelContext) private var contexto

    @Query(sort: \CarpetaRutinas.orden) private var carpetas: [CarpetaRutinas]
    @Query(sort: \Rutina.orden) private var rutinas: [Rutina]
    @Query(sort: \DiaPlanificado.fecha) private var diasDePlan: [DiaPlanificado]

    @State private var ajustes: Ajustes?

    var body: some View {
        NavigationStack {
            Group {
                if let entreno = controlador.entreno, let ajustes {
                    VistaEntrenoEnCurso(entreno: entreno, ajustes: ajustes)
                } else {
                    pantallaInicio
                }
            }
        }
        .onAppear {
            if ajustes == nil { ajustes = Ajustes.cargar(en: contexto) }
            controlador.reanudarSiProcede()
        }
    }

    private var pantallaInicio: some View {
        List {
            Section {
                CabeceraInicio()
                    .filaDesnuda(arriba: 8, abajo: 4)
            }

            if let hoy = diaDeHoy {
                Section {
                    TarjetaHoy(dia: hoy, rutina: rutinaDelDia(hoy)) { rutina in
                        controlador.empezar(desde: rutina)
                    }
                    .filaDesnuda(arriba: 8, abajo: 4)
                }

                Section {
                    NavigationLink {
                        VistaPlan()
                    } label: {
                        HStack {
                            Label("Ver el plan completo", systemImage: "calendar")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            // La cuenta atrás, aquí y no solo dentro del plan:
                            // es el número que mueve todo lo demás, y escondido
                            // tras un toque no mueve nada.
                            if let faltan = diasHastaLaCompeticion {
                                Text(faltan == 0 ? "¡Hoy!" : "faltan \(faltan) días")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Paleta.carrera)
                            }
                        }
                    }
                    .filaDesnuda(arriba: 0, abajo: 8)
                }
            }

            // Secundario a propósito: empezar un entreno vacío es lo que se
            // hace de vez en cuando, y en azul gigante era lo más llamativo de
            // la pantalla por delante de las rutinas, que es lo que se usa.
            Section {
                Button {
                    controlador.empezarVacio()
                } label: {
                    Label("Entreno vacío", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .filaDesnuda(arriba: 6, abajo: 6)
            }

            ForEach(carpetas) { carpeta in
                if !carpeta.rutinas.isEmpty {
                    Section(carpeta.nombre) {
                        ForEach(carpeta.rutinasOrdenadas) { rutina in
                            filaRutina(rutina)
                        }
                    }
                }
            }

            let sueltas = rutinas.filter { $0.carpeta == nil }
            if !sueltas.isEmpty {
                Section("Sin carpeta") {
                    ForEach(sueltas) { rutina in
                        filaRutina(rutina)
                    }
                }
            }

            if carpetas.isEmpty && rutinas.isEmpty {
                ContentUnavailableView(
                    "Sin rutinas",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Ve a la pestaña Rutinas para crear la primera, o empieza un entreno vacío.")
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Entrenar")
    }

    /// Días hasta la competición del plan, si hay una y no ha pasado ya.
    /// Color de la rutina: el de la región que más series se lleva. Sin
    /// ejercicios reconocibles queda el acento, que no dice nada pero tampoco
    /// miente.
    private func colorDe(_ rutina: Rutina) -> Color {
        var porRegion: [RegionCorporal: Int] = [:]
        for elemento in rutina.elementos {
            guard let ejercicio = elemento.ejercicio else { continue }
            porRegion[ejercicio.grupoPrincipal.region, default: 0] += elemento.seriesObjetivo
        }
        guard let mayor = porRegion.max(by: { $0.value < $1.value })?.key else {
            return Paleta.acento
        }
        return Paleta.region(mayor)
    }

    private var diasHastaLaCompeticion: Int? {
        guard let dia = diasDePlan.last(where: { $0.tipo == .competicion }) else { return nil }
        let faltan = ResumenPlan.diasHasta(dia.fecha)
        return faltan >= 0 ? faltan : nil
    }

    private var diaDeHoy: DiaPlanificado? {
        diasDePlan.first { CalendarioEntrenos.es.isDate($0.fecha, inSameDayAs: Date()) }
    }

    /// La rutina que cubre la parte de gimnasio del día, buscada por nombre:
    /// el plan se escribe fuera de la app, donde no se conocen los UUID.
    private func rutinaDelDia(_ dia: DiaPlanificado) -> Rutina? {
        guard dia.tipo.tieneGimnasio, let nombre = dia.nombreRutina else { return nil }
        return Rutina.buscar(nombre: nombre, en: rutinas)
    }

    /// Una rutina, como tarjeta con su botón de empezar.
    ///
    /// Era una fila de lista con una flecha pequeña a la derecha: lo mismo que
    /// un ajuste cualquiera, cuando es la acción con la que arranca todo lo
    /// que hace la app. El disco de play va a la derecha y grande porque es
    /// donde cae el pulgar sosteniendo el móvil con una mano.
    private func filaRutina(_ rutina: Rutina) -> some View {
        Button {
            controlador.empezar(desde: rutina)
        } label: {
            HStack(spacing: 12) {
                // El filo dice de qué es la rutina sin tener que leerla: el
                // color de la región que más series se lleva.
                Capsule()
                    .fill(colorDe(rutina))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(rutina.nombre)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(rutina.resumen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                // El disco va en el acento y no en el color de la región: es
                // un control, y la propia `Paleta` dice que el color de una
                // región no puede confundirse con algo que se toca. Con el
                // rosa del torso, además, el botón de empezar parecía el de
                // grabar.
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Paleta.acento, in: .circle)
            }
            .frame(minHeight: 44)
            .tarjeta(relleno: 12)
            .contentShape(.rect)
        }
        .buttonStyle(BotonPulsable())
        .filaDesnuda(arriba: 3, abajo: 3)
    }
}
