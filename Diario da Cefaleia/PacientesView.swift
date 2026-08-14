//
//  PacientesView.swift
//  Diario da Cefaleia
//
//  Espelha Pacientes.jsx (FormPaciente + BarraPaciente). O hook usePacientes virou
//  parte de Diario — aqui só ficam as telas.
//

import SwiftUI

private func dataParaISO(_ d: Date) -> String {
    let comp = Calendar.current.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", comp.year!, comp.month!, comp.day!)
}

private func isoParaData(_ iso: String) -> Date? {
    let partes = iso.split(separator: "-").compactMap { Int($0) }
    guard partes.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2]))
}

/// Form de paciente. `inicial == nil` = criando; senão, editando.
struct FormPacienteView: View {
    let inicial: Paciente?
    let primeiro: Bool
    let onSalvar: (String, String?) async -> Bool
    let onCancelar: (() -> Void)?

    @State private var nome: String
    @State private var nascimento: Date?
    @State private var salvando = false

    init(
        inicial: Paciente?, primeiro: Bool,
        onSalvar: @escaping (String, String?) async -> Bool, onCancelar: (() -> Void)?
    ) {
        self.inicial = inicial
        self.primeiro = primeiro
        self.onSalvar = onSalvar
        self.onCancelar = onCancelar
        _nome = State(initialValue: inicial?.nome ?? "")
        _nascimento = State(initialValue: inicial?.dataNascimento.flatMap(isoParaData))
    }

    private var nomeValido: Bool { !nome.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                SubEyebrow(texto: primeiro ? "quem você vai acompanhar" : "paciente")
                Titulo(texto: inicial == nil ? "Novo paciente" : "Editar paciente")
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(texto: "Nome")
                    TextField("Ex.: Manu", text: $nome).campo()
                }
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(texto: "Nascimento (opcional)")
                    HStack {
                        DatePicker(
                            "", selection: Binding(get: { nascimento ?? Date() }, set: { nascimento = $0 }),
                            in: ...Date(), displayedComponents: .date
                        )
                        .labelsHidden()
                        if nascimento != nil {
                            Button("Limpar") { nascimento = nil }
                                .font(.system(size: 13)).foregroundStyle(Color(hex: 0x8b7cfc))
                        }
                        Spacer()
                    }
                }
            }
            .cartao()

            BotaoPrimario(
                titulo: inicial == nil ? "Começar a acompanhar" : "Salvar",
                desabilitado: !nomeValido || salvando, acao: enviar)

            if let onCancelar {
                Button("Cancelar", action: onCancelar)
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
            }
        }
    }

    private func enviar() {
        let nomeAparado = nome.trimmingCharacters(in: .whitespaces)
        guard !nomeAparado.isEmpty, !salvando else { return }
        salvando = true
        Task {
            let ok = await onSalvar(nomeAparado, nascimento.map(dataParaISO))
            if ok { onCancelar?() } else { salvando = false }
        }
    }
}

/// Troca de paciente. `Picker` nativo troca a roleta HTML da web; "+" e "✎" ficam
/// como botões dedicados em vez de um item dentro do dropdown.
struct BarraPacienteView: View {
    let pacientes: [Paciente]
    let selecionado: Paciente
    let escolher: (UUID) -> Void
    let onNovo: () -> Void
    let onEditar: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("Paciente", selection: Binding(get: { selecionado.id }, set: escolher)) {
                ForEach(pacientes) { p in Text(p.nome).tag(p.id) }
            }
            .pickerStyle(.menu)
            .campo()

            if let anos = idade(selecionado.dataNascimento) {
                Text("\(anos) anos").font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
            }

            Button(action: onNovo) { Image(systemName: "plus") }
                .frame(width: 40, height: 40).campo()
            Button(action: onEditar) { Image(systemName: "pencil") }
                .frame(width: 40, height: 40).campo()
        }
    }
}
