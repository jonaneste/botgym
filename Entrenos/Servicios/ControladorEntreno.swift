import Foundation
import Observation
import SwiftData

/// Dueño del entreno en curso.
///
/// Concentra todas las mutaciones del entreno activo para que las vistas no
/// tengan lógica dentro. El entreno vive en SwiftData desde el primer
/// instante, así que "guardar" no es un paso aparte: cerrar la app a mitad de
/// una serie no pierde nada.
@MainActor
@Observable
final class ControladorEntreno {

    private(set) var entreno: Entreno?
    let temporizador = TemporizadorDescanso()

    /// Récord recién batido, para el aviso que aparece sobre el entreno.
    var avisoRecord: AvisoRecord?
    /// Todos los récords batidos en este entreno, para el resumen final, cada
    /// uno con el ejercicio en que ocurrió.
    ///
    /// El ejercicio tiene que viajar con el récord: guardando solo
    /// `[RecordBatido]`, el resumen de cierre no tenía de dónde sacar el
    /// nombre y etiquetaba todos los récords con el nombre del ENTRENO, así
    /// que dos récords en ejercicios distintos salían como dos filas
    /// idénticas tituladas "Lunes – Empuje".
    private(set) var recordsDelEntreno: [RecordDeEjercicio] = []

    private var contexto: ModelContext
    private var repositorio: RepositorioEntrenos
    private var progreso: RepositorioProgreso

    /// Récords previos por ejercicio. Se cachean porque consultarlos en cada
    /// toque significaría recorrer el historial entero, y porque al batir uno
    /// hay que incorporarlo para no avisar dos veces de lo mismo.
    private var recordsPrevios: [UUID: RecordsEjercicio] = [:]

    /// La serie que arrancó el descanso que está corriendo ahora mismo.
    ///
    /// Solo vive en memoria: si la app se cierra y se reanuda, el descanso se
    /// reconstruye desde la fecha guardada y ya no se sabe de qué serie salió.
    /// Desmarcar entonces no lo para, que es lo correcto: a esas alturas el
    /// descanso es del entreno, no del toque.
    private var serieQueArrancoElDescanso: UUID?

    init(contexto: ModelContext) {
        self.contexto = contexto
        self.repositorio = RepositorioEntrenos(contexto: contexto)
        self.progreso = RepositorioProgreso(contexto: contexto)
        temporizador.alTerminar = { [weak self] in
            self?.descansoTerminado()
        }
    }

    var hayEntrenoActivo: Bool { entreno != nil }

    // MARK: - Arranque

    /// Busca un entreno abierto y lo retoma, reconstruyendo el descanso.
    func reanudarSiProcede() {
        guard entreno == nil else { return }
        guard let abierto = repositorio.entrenoEnCurso() else { return }
        entreno = abierto

        if let hasta = abierto.descansoHasta, hasta > Date() {
            temporizador.reanudar(
                hasta: hasta,
                duracionTotal: TimeInterval(abierto.descansoDuracion ?? 90),
                nombreEjercicio: ""
            )
        } else {
            abierto.descansoHasta = nil
            abierto.descansoDuracion = nil
        }
    }

    /// Empieza un entreno a partir de una rutina, copiando sus objetivos y
    /// precargando el peso de la última vez.
    func empezar(desde rutina: Rutina) {
        guard entreno == nil else { return }
        let ahora = Date()
        let nuevo = Entreno(
            nombre: rutina.nombre,
            fechaInicio: ahora,
            nombreRutinaOrigen: rutina.nombre,
            idRutinaOrigen: rutina.idPublico
        )
        contexto.insert(nuevo)

        for elemento in rutina.elementosOrdenados {
            // Un elemento cuyo ejercicio se borró de la biblioteca se salta.
            // La relación es `.nullify`, así que esos elementos sobreviven con
            // `ejercicio == nil`, y antes se creaba con ellos una fila de
            // historial llamada literalmente "Ejercicio" y con un `idEjercicio`
            // recién inventado: las series que el usuario anotara ahí no
            // casaban con nada. No aparecían en "Anterior:", la progresión
            // volvía a "primera vez" cada sesión, no contaban en el volumen
            // semanal y no salían en Progreso, todo sin un solo aviso.
            guard let ejercicio = EjercicioEntreno(desde: elemento, fechaEntreno: ahora) else {
                continue
            }
            contexto.insert(ejercicio)
            ejercicio.entreno = nuevo

            let anterior = elemento.ejercicio.flatMap {
                repositorio.ultimaActuacion(idEjercicio: $0.idPublico)
            }
            let seriesAnteriores = anterior?.seriesEfectivas ?? []

            // Las de calentamiento van delante, y su peso se copia de los
            // calentamientos de la última vez: el de trabajo no vale, que es
            // justo lo que no se levanta para calentar.
            let calentamientosAnteriores = anterior?.seriesOrdenadas.filter(\.esCalentamiento) ?? []
            let calentamiento = max(0, elemento.seriesCalentamiento)

            for indice in 0..<(calentamiento + max(1, elemento.seriesObjetivo)) {
                let serie = SerieRegistrada(orden: indice)

                if indice < calentamiento {
                    serie.esCalentamiento = true
                    if indice < calentamientosAnteriores.count {
                        serie.peso = calentamientosAnteriores[indice].peso
                    } else if let ultimo = calentamientosAnteriores.last {
                        serie.peso = ultimo.peso
                    }
                } else {
                    // Precargar el peso de la misma serie de trabajo de la
                    // última sesión. El índice se desplaza: las anteriores que
                    // se guardaron son solo las efectivas.
                    let posicion = indice - calentamiento
                    if posicion < seriesAnteriores.count {
                        serie.peso = seriesAnteriores[posicion].peso
                    } else if let ultima = seriesAnteriores.last {
                        serie.peso = ultima.peso
                    }
                }

                contexto.insert(serie)
                serie.ejercicioEntreno = ejercicio
            }
        }

        entreno = nuevo
        Haptica.ligera()
        guardar()
    }

    /// Empieza un entreno en blanco.
    func empezarVacio() {
        guard entreno == nil else { return }
        let nuevo = Entreno(nombre: "Entreno libre")
        contexto.insert(nuevo)
        entreno = nuevo
        guardar()
    }

    // MARK: - Ejercicios

    func añadirEjercicio(_ ejercicio: Ejercicio, ajustes: Ajustes) {
        guard let entreno else { return }
        let orden = (entreno.ejercicios.map(\.orden).max() ?? -1) + 1
        let nuevo = EjercicioEntreno(
            ejercicio: ejercicio,
            orden: orden,
            fechaEntreno: entreno.fechaInicio,
            seriesObjetivo: 3,
            rirMin: ajustes.rirPorDefectoMin,
            rirMax: ajustes.rirPorDefectoMax,
            descansoSegundos: ajustes.descansoPorDefecto
        )
        contexto.insert(nuevo)
        nuevo.entreno = entreno

        let anterior = repositorio.ultimaActuacion(idEjercicio: ejercicio.idPublico)
        let pesoAnterior = anterior?.seriesEfectivas.first?.peso ?? 0

        for indice in 0..<3 {
            let serie = SerieRegistrada(orden: indice, peso: pesoAnterior)
            contexto.insert(serie)
            serie.ejercicioEntreno = nuevo
        }
        guardar()
    }

    func quitarEjercicio(_ ejercicio: EjercicioEntreno) {
        guard let entreno else { return }
        let restantes = entreno.ejerciciosOrdenados.filter { $0 !== ejercicio }
        contexto.delete(ejercicio)
        // Recompactar el orden para que no queden huecos.
        for (indice, restante) in restantes.enumerated() {
            restante.orden = indice
        }
        guardar()
    }

    // MARK: - Series

    /// Añade una serie al final. Con `calentamiento` nace marcada, para que no
    /// cuente en volumen, récords ni series semanales.
    func añadirSerie(a ejercicio: EjercicioEntreno, calentamiento: Bool = false) {
        let orden = (ejercicio.series.map(\.orden).max() ?? -1) + 1
        // Se copia el peso de la última del mismo tipo: una serie de
        // aproximación que nace con el peso de trabajo no sirve de nada.
        let ultima = ejercicio.seriesOrdenadas.last { $0.esCalentamiento == calentamiento }
        let serie = SerieRegistrada(
            orden: orden,
            peso: ultima?.peso ?? 0,
            repeticiones: 0,
            segundos: ejercicio.tipoRegistro.esTiempo ? 0 : nil,
            esCalentamiento: calentamiento
        )
        contexto.insert(serie)
        serie.ejercicioEntreno = ejercicio
        guardar()
    }

    /// Cambia una serie de trabajo a calentamiento y al revés.
    ///
    /// Tiene que pasar por aquí y no mutarse desde la vista: sin `guardar()`,
    /// SwiftData deja el cambio en memoria y cerrar la app a mitad de serie lo
    /// perdía, que es justo lo que no puede pasar en esta app.
    func alternarCalentamiento(_ serie: SerieRegistrada) {
        serie.esCalentamiento.toggle()
        guardar()
    }

    func quitarSerie(_ serie: SerieRegistrada, de ejercicio: EjercicioEntreno) {
        let restantes = ejercicio.seriesOrdenadas.filter { $0 !== serie }
        contexto.delete(serie)
        for (indice, restante) in restantes.enumerated() {
            restante.orden = indice
        }
        guardar()
    }

    /// Marca o desmarca una serie. Al marcarla arranca el descanso.
    func alternarCompletada(_ serie: SerieRegistrada, de ejercicio: EjercicioEntreno, ajustes: Ajustes) {
        serie.completada.toggle()

        if serie.completada {
            serie.fechaCompletada = Date()
            comprobarRecords(de: serie, en: ejercicio, ajustes: ajustes)
            if ajustes.vibrarFinDescanso && avisoRecord == nil { Haptica.serieCompletada() }
            if ajustes.descansoAutomatico && ejercicio.descansoSegundos > 0 {
                empezarDescanso(segundos: ejercicio.descansoSegundos, ejercicio: ejercicio, ajustes: ajustes)
                serieQueArrancoElDescanso = serie.idPublico
            }
        } else {
            serie.fechaCompletada = nil
            // Desmarcar para el descanso que arrancó esa misma serie.
            //
            // La casilla es grande y está pegada al campo de RIR, así que se
            // toca sin querer. Al deshacerlo, el descanso seguía corriendo y
            // dos minutos después vibraba y saltaba la notificación en la
            // pantalla bloqueada por una serie que nunca se hizo. Solo se para
            // el que salió de esta serie: uno puesto a mano, o el de otra
            // serie, no se toca.
            if serieQueArrancoElDescanso == serie.idPublico, temporizador.activo {
                saltarDescanso()
            }
        }
        guardar()
    }

    /// Copia peso y repeticiones de lo que se hizo la última vez en esta
    /// misma serie.
    func copiarDeAnterior(_ serie: SerieRegistrada, de ejercicio: EjercicioEntreno) {
        guard let anterior = actuacionAnterior(de: ejercicio) else { return }
        let series = anterior.seriesEfectivas
        guard !series.isEmpty else { return }
        let origen = serie.orden < series.count ? series[serie.orden] : series[series.count - 1]
        serie.peso = origen.peso
        if ejercicio.tipoRegistro.esTiempo {
            serie.segundos = origen.segundos
        } else {
            serie.repeticiones = origen.repeticiones
        }
        Haptica.ligera()
        guardar()
    }

    // MARK: - Récords y sugerencias

    /// Récords previos de un ejercicio, excluyendo el entreno en curso.
    ///
    /// Hay que excluirlo: si el entreno de hoy contara, la serie que acaba de
    /// batir el récord ya estaría dentro y el aviso nunca saltaría.
    private func recordsDe(_ ejercicio: EjercicioEntreno) -> RecordsEjercicio {
        if let cacheados = recordsPrevios[ejercicio.idEjercicio] {
            return cacheados
        }
        let calculados = progreso.recordsPrevios(
            idEjercicio: ejercicio.idEjercicio,
            tipo: ejercicio.tipoRegistro,
            excluyendoEntreno: entreno?.idPublico
        )
        recordsPrevios[ejercicio.idEjercicio] = calculados
        return calculados
    }

    private func comprobarRecords(de serie: SerieRegistrada, en ejercicio: EjercicioEntreno, ajustes: Ajustes) {
        let previos = recordsDe(ejercicio)
        let batidos = ServicioRecords.recordsBatidos(
            por: serie.valor,
            tipo: ejercicio.tipoRegistro,
            frenteA: previos
        )
        guard !batidos.isEmpty else { return }

        // Incorporar lo batido, para que la siguiente serie se compare contra
        // el valor nuevo y no vuelva a avisar de lo mismo.
        recordsPrevios[ejercicio.idEjercicio] = ServicioRecords.incorporando(
            serie.valor,
            tipo: ejercicio.tipoRegistro,
            en: previos,
            fecha: Date()
        )

        recordsDelEntreno.append(
            contentsOf: batidos.map {
                RecordDeEjercicio(nombreEjercicio: ejercicio.nombreEjercicio, batido: $0)
            }
        )
        avisoRecord = AvisoRecord(nombreEjercicio: ejercicio.nombreEjercicio, batidos: batidos)
        if ajustes.vibrarFinDescanso { Haptica.record() }
    }

    func descartarAvisoRecord() {
        avisoRecord = nil
    }

    /// Récords de volumen por ejercicio, calculados al cerrar el entreno.
    ///
    /// El volumen de una sesión solo se sabe cuando la sesión termina, así que
    /// este no se puede detectar serie a serie como los demás.
    func recordsDeVolumen() -> [RecordDeEjercicio] {
        guard let entreno else { return [] }
        return entreno.ejerciciosOrdenados.compactMap { ejercicio in
            guard let batido = ServicioRecords.recordDeVolumen(
                volumenSesion: ejercicio.volumen,
                frenteA: recordsDe(ejercicio)
            ) else { return nil }
            return RecordDeEjercicio(nombreEjercicio: ejercicio.nombreEjercicio, batido: batido)
        }
    }

    /// Récords batidos serie a serie durante el entreno, con su ejercicio.
    var resumenRecords: [RecordDeEjercicio] { recordsDelEntreno }

    /// Cómo ha ido comparado con la última vez que se hizo esta misma rutina.
    ///
    /// `nil` si no hay con qué comparar: un entreno libre, o la primera vez
    /// con esa rutina. «0 kg más que la última vez» sería mentira.
    func comparacionConLaUltimaVez() -> ComparacionSesion? {
        guard let entreno else { return nil }
        let anterior = repositorio.anteriorDeLaMismaRutina(entreno)
        return ComparadorSesiones.comparar(
            seriesAhora: entreno.seriesCompletadas,
            volumenAhora: entreno.volumenTotal,
            anterior: anterior.map {
                (fecha: $0.fechaInicio, series: $0.seriesCompletadas, volumen: $0.volumenTotal)
            }
        )
    }

    /// Sugerencia de carga para un ejercicio del entreno en curso.
    func sugerencia(para ejercicio: EjercicioEntreno, ajustes: Ajustes) -> SugerenciaProgresion {
        progreso.sugerencia(
            idEjercicio: ejercicio.idEjercicio,
            objetivo: ejercicio.objetivo,
            material: ejercicio.ejercicio?.material ?? .otro,
            tipo: ejercicio.tipoRegistro,
            reglas: ajustes.reglasIncremento,
            excluyendoEntreno: entreno?.idPublico
        )
    }

    /// Aplica un peso a todas las series del ejercicio que aún no están
    /// marcadas. Es el "aceptar la sugerencia" de un toque.
    func aplicarPeso(_ peso: Double, a ejercicio: EjercicioEntreno) {
        for serie in ejercicio.seriesOrdenadas where !serie.completada {
            serie.peso = peso
        }
        Haptica.ligera()
        guardar()
    }

    /// Aplica un objetivo de segundos a las series pendientes de un
    /// isométrico.
    func aplicarSegundos(_ segundos: Int, a ejercicio: EjercicioEntreno) {
        for serie in ejercicio.seriesOrdenadas where !serie.completada {
            serie.segundos = segundos
        }
        Haptica.ligera()
        guardar()
    }

    // MARK: - Descanso

    func empezarDescanso(segundos: Int, ejercicio: EjercicioEntreno?, ajustes: Ajustes) {
        // Un descanso nuevo no es de nadie hasta que quien lo arranca lo diga:
        // sin esto, la marca de una serie anterior seguiría puesta y
        // desmarcarla pararía un descanso que ya no es suyo.
        serieQueArrancoElDescanso = nil
        let fin = Date().addingTimeInterval(TimeInterval(segundos))
        entreno?.descansoHasta = fin
        entreno?.descansoDuracion = segundos
        temporizador.empezar(segundos: segundos, nombreEjercicio: ejercicio?.nombreEjercicio ?? "")

        if ajustes.notificarFinDescanso {
            let nombre = ejercicio?.nombreEjercicio ?? ""
            Task { await GestorNotificaciones.shared.programarFinDescanso(en: fin, nombreEjercicio: nombre) }
        }
        guardar()
    }

    func ajustarDescanso(segundos: Int, ajustes: Ajustes) {
        temporizador.ajustar(segundos: segundos)
        entreno?.descansoHasta = temporizador.fechaFin
        // La duración también, y no solo la fecha de fin. Es lo que se usa al
        // reanudar para calcular el progreso de la barra: dejándola en el
        // valor original, tras cerrar y reabrir la app la barra de un descanso
        // alargado a mano iba mal el resto del descanso. Y cuando `ajustar`
        // acaba parando el temporizador hay que limpiarla, o quedaba un
        // descanso a medio borrar en la base.
        if temporizador.fechaFin == nil {
            serieQueArrancoElDescanso = nil
            entreno?.descansoDuracion = nil
        } else {
            entreno?.descansoDuracion = LimitesEntrada.entero(temporizador.duracionTotal)
        }
        if let fin = temporizador.fechaFin, ajustes.notificarFinDescanso {
            let nombre = temporizador.nombreEjercicio
            Task { await GestorNotificaciones.shared.programarFinDescanso(en: fin, nombreEjercicio: nombre) }
        } else {
            Task { await GestorNotificaciones.shared.cancelarFinDescanso() }
        }
        guardar()
    }

    func saltarDescanso() {
        serieQueArrancoElDescanso = nil
        temporizador.parar()
        entreno?.descansoHasta = nil
        entreno?.descansoDuracion = nil
        Task { await GestorNotificaciones.shared.cancelarFinDescanso() }
        guardar()
    }

    private func descansoTerminado() {
        serieQueArrancoElDescanso = nil
        entreno?.descansoHasta = nil
        entreno?.descansoDuracion = nil
        Haptica.finDescanso()
        guardar()
    }

    // MARK: - Consultas de apoyo

    /// Lo que se hizo la última vez en este ejercicio.
    func actuacionAnterior(de ejercicio: EjercicioEntreno) -> EjercicioEntreno? {
        repositorio.ultimaActuacion(
            idEjercicio: ejercicio.idEjercicio,
            excluyendo: entreno?.idPublico
        )
    }

    // MARK: - Cierre

    /// Cierra el entreno. Las series vacías se descartan para no ensuciar el
    /// historial, y se marca `entrenoFinalizado` en cada ejercicio porque es
    /// el campo por el que se busca "la última vez".
    func finalizar(molestiaHombro: Int?, molestiaRodilla: Int?, notas: String, ajustes: Ajustes) {
        guard let entreno else { return }

        var ejerciciosConSeries = 0

        // Se decide todo sobre copias tomadas antes de borrar nada: mutar una
        // relación de SwiftData mientras se recorre da resultados imprevisibles.
        for ejercicio in entreno.ejerciciosOrdenados {
            let tipo = ejercicio.tipoRegistro
            // Una casilla marcada sin nada anotado tampoco es una serie: no
            // suma volumen, pero sí contaba como serie del grupo muscular en
            // el objetivo semanal, que es el recuento que no se puede falsear
            // en silencio.
            let completadas = ejercicio.seriesOrdenadas.filter {
                $0.completada && !RevisionSerie.estaVacia($0.valor, tipo: tipo)
            }
            let sobrantes = ejercicio.seriesOrdenadas.filter {
                !$0.completada || RevisionSerie.estaVacia($0.valor, tipo: tipo)
            }

            for serie in sobrantes {
                contexto.delete(serie)
            }

            // Un ejercicio sin ninguna serie completada no aporta al historial.
            if completadas.isEmpty {
                contexto.delete(ejercicio)
                continue
            }

            for (indice, serie) in completadas.enumerated() {
                serie.orden = indice
            }
            ejercicio.entrenoFinalizado = true
            ejerciciosConSeries += 1
        }

        // Un entreno que se abrió y se dejó a medias no es un entreno de cero
        // series: es un entreno que no pasó. Guardarlo dejaba una fila en el
        // historial, con su duración y su hora, sin nada detrás.
        guard ejerciciosConSeries > 0 else {
            descartar()
            return
        }

        entreno.molestiaHombro = molestiaHombro
        entreno.molestiaRodilla = molestiaRodilla
        entreno.notas = notas
        entreno.fechaFin = Date()
        entreno.estado = .finalizado
        entreno.descansoHasta = nil
        entreno.descansoDuracion = nil

        temporizador.parar()
        Task { await GestorNotificaciones.shared.cancelarFinDescanso() }

        if ajustes.healthKitActivado {
            escribirEnSalud(entreno, ajustes: ajustes)
        }

        self.entreno = nil
        avisoRecord = nil
        recordsDelEntreno = []
        recordsPrevios = [:]
        // Cerrar un entreno es el final de algo: se nota, igual que marcar
        // una serie. Sin esto, el único momento de la app sin respuesta
        // física era justo el que más la pedía.
        Haptica.record()
        guardar()

        // El volcado del JSON va DESPUÉS de guardar, no antes: la consulta que
        // construye la exportación filtra por estado finalizado, y hasta que
        // no se guarda el entreno que acaba de cerrarse sigue en curso y se
        // quedaría fuera del archivo.
        ExportadorAutomatico.compartido.exportarSiProcede(contexto: contexto)
    }

    /// Guarda el entreno en Apple Health como entrenamiento de fuerza.
    ///
    /// Las calorías solo se escriben si están activadas en Ajustes y hay peso
    /// corporal: por defecto no se estiman, porque si entrenas con el reloj
    /// puesto el dato real lo escribe Zepp.
    ///
    /// Y antes de escribir se comprueba que no haya ya un entrenamiento de
    /// fuerza de otra app solapado. Sin esa comprobación, entrenar con el
    /// reloj daría dos entrenos el mismo día y contaría doble en los anillos.
    private func escribirEnSalud(_ entreno: Entreno, ajustes: Ajustes) {
        guard entreno.idHealthKit == nil else { return }
        guard let fin = entreno.fechaFin else { return }
        let inicio = entreno.fechaInicio
        let nombre = entreno.nombre
        let calorias = SincronizadorSalud.calorias(de: entreno, ajustes: ajustes)
        let resumen = SincronizadorSalud.resumen(de: entreno)
        let evitarDuplicados = ajustes.evitarDuplicadosEnSalud

        // Se reserva antes de lanzar el Task: hasta que Salud responda, el
        // entreno queda guardado con `idHealthKit == nil` y la subida manual
        // del historial lo vería pendiente y lo escribiría por segunda vez.
        let identificador = entreno.idPublico
        guard EscriturasEnSalud.reservar(identificador) else { return }

        Task { [weak self] in
            defer { EscriturasEnSalud.liberar(identificador) }

            if evitarDuplicados,
               await GestorHealthKit.shared.existeEntrenoDeFuerzaDeOtraApp(inicio: inicio, fin: fin) {
                // El reloj ya lo registró, con pulso real. El suyo es mejor.
                return
            }
            do {
                let uuid = try await GestorHealthKit.shared.guardarEntrenoDeFuerza(
                    inicio: inicio,
                    fin: fin,
                    nombre: nombre,
                    caloriasEstimadas: calorias,
                    resumen: resumen
                )
                entreno.idHealthKit = uuid
                self?.guardar()
            } catch {
                // Que Salud falle no puede perder el entreno: ya está guardado
                // en la base local, que es la fuente de verdad de la app.
                print("No se pudo escribir en Salud: \(error)")
            }
        }
    }

    /// Descarta el entreno en curso por completo.
    func descartar() {
        guard let entreno else { return }
        contexto.delete(entreno)
        temporizador.parar()
        Task { await GestorNotificaciones.shared.cancelarFinDescanso() }
        self.entreno = nil
        avisoRecord = nil
        recordsDelEntreno = []
        recordsPrevios = [:]
        guardar()
    }

    // MARK: - Persistencia

    private func guardar() {
        do {
            try contexto.save()
        } catch {
            // Con la base de datos local no hay un camino de recuperación útil
            // más allá de dejar rastro: la siguiente escritura lo reintenta.
            print("Error al guardar: \(error)")
        }
    }
}
