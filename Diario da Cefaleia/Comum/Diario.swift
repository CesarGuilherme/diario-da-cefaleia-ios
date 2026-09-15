//
//  Diario.swift
//  Diario da Cefaleia
//
//  Store unindo pacientes e crises — o paciente selecionado é o filtro de tudo que o
//  app mostra, por isso os dois vivem juntos aqui (espelha usePacientes + useCrises).
//

import Foundation
import Helpers
import Observation
import PostgREST
import Realtime
import Supabase

@MainActor
@Observable
final class Diario {
    let userId: UUID

    private(set) var pacientes: [Paciente] = []
    private(set) var crises: [Crise] = [] {
        didSet {
            ativa = crises.first { $0.fim == nil }
            encerradas = crises.filter { $0.fim != nil }
        }
    }
    // Derivados armazenados, não computados: com @Observable, um `ativa` computado
    // faria toda view que o lê depender do array `crises` inteiro — cada patch de
    // sintoma invalidaria aurora, casca das abas e relatório de uma vez.
    private(set) var ativa: Crise?
    private(set) var encerradas: [Crise] = []
    private(set) var carregandoPacientes = true
    private(set) var carregandoCrises = true
    var erro: String?

    private var pacienteSelecionadoId: UUID?
    private var chaveLocal: String { "paciente:\(userId.uuidString)" }
    @ObservationIgnored private var taskCrises: Task<Void, Never>?
    @ObservationIgnored private var canalCrises: RealtimeChannelV2?
    @ObservationIgnored private var canalPacientes: RealtimeChannelV2?
    @ObservationIgnored private var escutaCrises: Task<Void, Never>?
    @ObservationIgnored private var escutaPacientes: Task<Void, Never>?

    // Sem efeitos no init: quem dispara a carga é o `.task` da DiarioRootView, que o
    // SwiftUI cancela ao desmontar — trocar de conta não deixa um Diario órfão vivo
    // esperando a rede.
    init(userId: UUID) {
        self.userId = userId
        pacienteSelecionadoId = UserDefaults.standard.string(forKey: chaveLocal).flatMap(UUID.init)
    }

    // Trocar de conta descarta o Diario via `.id(userId)` — sem isto, a busca em
    // voo segurava a instância antiga viva até a resposta da rede chegar.
    deinit {
        taskCrises?.cancel()
        escutaCrises?.cancel()
        escutaPacientes?.cancel()
    }

    /// Carga inicial + canais do Realtime. O `.task` da casca cancela isto ao desmontar.
    func iniciarSync() async {
        await carregarPacientes()
        await escutarPacientes()
        await trocarCanalCrises()
    }

    func pararSync() {
        escutaCrises?.cancel()
        escutaPacientes?.cancel()
        let crises = canalCrises
        let pacientes = canalPacientes
        canalCrises = nil
        canalPacientes = nil
        Task {
            if let crises { await supabase.removeChannel(crises) }
            if let pacientes { await supabase.removeChannel(pacientes) }
        }
    }

    /// O iOS mata o websocket em segundo plano — reconsulta ao voltar, como o
    /// `visibilitychange` da web.
    func voltarAoPrimeiroPlano() async {
        await recarregarPacientesSomente()
        await recarregarCrises()
    }

    // Se o id guardado não existe mais (apagado em outro dispositivo), cai no primeiro.
    var paciente: Paciente? {
        pacientes.first { $0.id == pacienteSelecionadoId } ?? pacientes.first
    }

    func carregarPacientes() async {
        await recarregarPacientesSomente()
        carregandoPacientes = false
        await recarregarCrises()
    }

    private func recarregarPacientesSomente() async {
        do {
            let dados: [Paciente] = try await supabase.from("pacientes")
                .select().order("criado_em").execute().value
            pacientes = dados
        } catch {
            guard !(error is CancellationError) else { return }
            erro = error.localizedDescription
        }
    }

    func escolher(_ id: UUID) {
        pacienteSelecionadoId = id
        UserDefaults.standard.set(id.uuidString, forKey: chaveLocal)
        // Cancela a busca do paciente anterior em vez de deixá-la voar; o guard de
        // resposta obsoleta em recarregarCrises segue como cinto de segurança.
        taskCrises?.cancel()
        taskCrises = Task {
            await recarregarCrises()
            await trocarCanalCrises()
        }
    }

    private func recarregarCrises() async {
        guard let pid = paciente?.id else {
            crises = []
            carregandoCrises = false
            return
        }
        carregandoCrises = true
        do {
            let dados: [Crise] = try await supabase.from("crises")
                .select().eq("paciente_id", value: pid)
                .order("inicio", ascending: false)
                .execute().value
            // Trocou de paciente enquanto esta busca voava? A resposta é de outro
            // paciente — descarta, a busca dele já está a caminho.
            guard pid == paciente?.id else { return }
            crises = dados
        } catch {
            guard !(error is CancellationError), pid == paciente?.id else { return }
            erro = error.localizedDescription
        }
        carregandoCrises = false
    }

    @discardableResult
    func criarPaciente(nome: String, dataNascimento: String?, souEu: Bool = false) async -> Bool {
        do {
            let novo: Paciente = try await supabase.from("pacientes")
                .insert(PacienteInput(nome: nome, dataNascimento: dataNascimento, souEu: souEu ? true : nil))
                .select().single().execute().value
            pacientes.append(novo)
            escolher(novo.id)
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

    /// Quem, entre os pacientes da conta, é o próprio dono dela. `nil` = ninguém.
    /// Marcar vai pela função do banco (troca as duas linhas numa transação só); desmarcar
    /// é um update comum, porque limpar não pode cruzar com o índice único.
    @discardableResult
    func definirSouEu(_ pid: UUID?) async -> Bool {
        do {
            if let pid {
                try await supabase.rpc("definir_sou_eu", params: DefinirSouEuParams(pid: pid)).execute()
            } else {
                try await supabase.from("pacientes")
                    .update(PacienteSouEuPatch(souEu: false))
                    .eq("sou_eu", value: true)
                    .execute()
            }
            let dados: [Paciente] = try await supabase.from("pacientes")
                .select().order("criado_em").execute().value
            pacientes = dados
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func salvarPaciente(_ id: UUID, nome: String, dataNascimento: String?) async -> Bool {
        do {
            let atualizado: Paciente = try await supabase.from("pacientes")
                .update(PacienteInput(nome: nome, dataNascimento: dataNascimento))
                .eq("id", value: id)
                .select().single().execute().value
            if let idx = pacientes.firstIndex(where: { $0.id == id }) { pacientes[idx] = atualizado }
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

    // Sem update otimista de propósito: é registro médico, uma escrita que falha calada
    // é dado perdido. Espera o servidor e usa a linha que ele devolveu.
    // ponytail: carrega tudo de uma vez; paginar se alguém passar de ~500 crises.
    @discardableResult
    func iniciar(_ form: NovaCriseInput) async -> Bool {
        do {
            let nova: Crise = try await supabase.from("crises")
                .insert(form).select().single().execute().value
            crises.insert(nova, at: 0)
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func atualizar(_ id: UUID, _ patch: CrisePatch) async -> Bool {
        do {
            let atualizada: Crise = try await supabase.from("crises")
                .update(patch).eq("id", value: id)
                .select().single().execute().value
            if let idx = crises.firstIndex(where: { $0.id == id }) { crises[idx] = atualizada }
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func encerrar(_ id: UUID, alivio: String?, medicacao: String? = nil) async -> Bool {
        await atualizar(id, CrisePatch(medicacao: medicacao, fim: Date(), alivio: alivio))
    }

    @discardableResult
    func apagar(_ id: UUID) async -> Bool {
        do {
            try await supabase.from("crises").delete().eq("id", value: id).execute()
            crises.removeAll { $0.id == id }
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

    // MARK: - Realtime

    private func escutarPacientes() async {
        guard canalPacientes == nil else { return }
        let canal = supabase.channel("pacientes:\(userId.uuidString.lowercased())")
        let stream = canal.postgresChange(AnyAction.self, table: "pacientes")
        canalPacientes = canal
        escutaPacientes = Task {
            for await _ in stream {
                await recarregarPacientesSomente()
            }
        }
        try? await canal.subscribeWithError()
    }

    private func trocarCanalCrises() async {
        escutaCrises?.cancel()
        escutaCrises = nil
        if let antigo = canalCrises {
            canalCrises = nil
            await supabase.removeChannel(antigo)
        }
        guard let pid = paciente?.id else { return }

        let canal = supabase.channel("crises:\(pid.uuidString.lowercased())")
        let stream = canal.postgresChange(
            AnyAction.self, table: "crises",
            filter: .eq("paciente_id", value: pid))
        canalCrises = canal
        escutaCrises = Task { [pid] in
            for await action in stream {
                guard pid == paciente?.id else { continue }
                receberCrise(action)
            }
        }
        try? await canal.subscribeWithError()
        await recarregarCrises()
    }

    private func receberCrise(_ action: AnyAction) {
        let decoder = AnyJSON.decoder
        switch action {
        case .insert(let a):
            guard let linha = try? a.decodeRecord(as: Crise.self, decoder: decoder) else { return }
            crises = aplicar(crises, .inserir(linha))
        case .update(let a):
            guard let linha = try? a.decodeRecord(as: Crise.self, decoder: decoder) else { return }
            crises = aplicar(crises, .atualizar(linha))
        case .delete(let a):
            let id = try? a.decodeOldRecord(as: IdLinha.self, decoder: decoder).id
            crises = aplicar(crises, .apagar(id))
        }
    }
}

private struct IdLinha: Decodable {
    let id: UUID
}
