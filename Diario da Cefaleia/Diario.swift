//
//  Diario.swift
//  Diario da Cefaleia
//
//  Store unindo pacientes e crises — o paciente selecionado é o filtro de tudo que o
//  app mostra, por isso os dois vivem juntos aqui (espelha usePacientes + useCrises).
//

import Foundation
import Observation

@MainActor
@Observable
final class Diario {
    let userId: UUID

    private(set) var pacientes: [Paciente] = []
    private(set) var crises: [Crise] = []
    private(set) var carregandoPacientes = true
    private(set) var carregandoCrises = true
    var erro: String?

    private var pacienteSelecionadoId: UUID?
    private var chaveLocal: String { "paciente:\(userId.uuidString)" }

    init(userId: UUID) {
        self.userId = userId
        pacienteSelecionadoId = UserDefaults.standard.string(forKey: chaveLocal).flatMap(UUID.init)
        Task { await carregarPacientes() }
    }

    // Se o id guardado não existe mais (apagado em outro dispositivo), cai no primeiro.
    var paciente: Paciente? {
        pacientes.first { $0.id == pacienteSelecionadoId } ?? pacientes.first
    }

    // A crise em andamento é simplesmente a linha sem `fim` — não existe um segundo
    // conceito de "ativa" para divergir do histórico.
    var ativa: Crise? { crises.first { $0.fim == nil } }
    var encerradas: [Crise] { crises.filter { $0.fim != nil } }

    func carregarPacientes() async {
        do {
            let dados: [Paciente] = try await supabase.from("pacientes")
                .select().order("criado_em").execute().value
            pacientes = dados
        } catch {
            erro = error.localizedDescription
        }
        carregandoPacientes = false
        await recarregarCrises()
    }

    func escolher(_ id: UUID) {
        pacienteSelecionadoId = id
        UserDefaults.standard.set(id.uuidString, forKey: chaveLocal)
        Task { await recarregarCrises() }
    }

    private func recarregarCrises() async {
        guard let pid = paciente?.id else {
            crises = []
            carregandoCrises = false
            return
        }
        carregandoCrises = true
        do {
            crises = try await supabase.from("crises")
                .select().eq("paciente_id", value: pid)
                .order("inicio", ascending: false)
                .execute().value
        } catch {
            erro = error.localizedDescription
        }
        carregandoCrises = false
    }

    func criarPaciente(nome: String, dataNascimento: String?) async -> Bool {
        do {
            let novo: Paciente = try await supabase.from("pacientes")
                .insert(PacienteInput(nome: nome, dataNascimento: dataNascimento))
                .select().single().execute().value
            pacientes.append(novo)
            escolher(novo.id)
            return true
        } catch {
            erro = error.localizedDescription
            return false
        }
    }

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

    func encerrar(_ id: UUID, alivio: String?) async -> Bool {
        await atualizar(id, CrisePatch(fim: Date(), alivio: alivio))
    }

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
}
