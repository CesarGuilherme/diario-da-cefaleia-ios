//
//  PainelView.swift
//  Diario da Cefaleia Mac
//
//  Casca do Mac: dashboard fixo de 3 colunas, espelha src/Painel.tsx (breakpoint
//  desktop da web). Reusa as mesmas telas do telefone — só a moldura muda.
//  Só este target: sem `#if os(macOS)`, o arquivo simplesmente não entra no
//  target iOS.
//

import Supabase
import SwiftUI

private enum PainelSheet: Identifiable {
    case nova
    case andamento
    case paciente(FormPacienteAlvo)

    var id: String {
        switch self {
        case .nova: return "nova"
        case .andamento: return "andamento"
        case .paciente(let alvo): return "paciente-\(alvo.id)"
        }
    }
}

// A janela de Ajustes (cena `Settings`, aberta por ⌘,) roda separada desta
// janela principal e não recebe `user`/`diario` por parâmetro — só por isto
// existe este holder compartilhado.
// ponytail: singleton para uma janela só; se o app ganhar múltiplas janelas, mover para o Environment.
@Observable
@MainActor
final class ContaMac {
    static let shared = ContaMac()
    private init() {}
    var user: User?
    var diario: Diario?
}

struct PainelView: View {
    let user: User
    let diario: Diario
    @State private var sheet: PainelSheet?

    var body: some View {
        Group {
            if !diario.carregandoPacientes, diario.paciente == nil {
                ScrollView {
                    FormPacienteView(
                        inicial: nil, primeiro: true,
                        onSalvar: { nome, nasc in await diario.criarPaciente(nome: nome, dataNascimento: nasc) },
                        onCancelar: nil
                    )
                    .padding(24)
                    .frame(maxWidth: 520)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let paciente = diario.paciente {
                VStack(spacing: 0) {
                    BannerErro(erro: diario.erro) { diario.erro = nil }
                        .padding(.horizontal, 24).padding(.top, 16)

                    HStack(alignment: .top, spacing: 20) {
                        SidebarView(
                            diario: diario, paciente: paciente,
                            onNovaCrise: { sheet = .nova },
                            onAbrirAndamento: { sheet = .andamento },
                            onNovoPaciente: { sheet = .paciente(.novo) },
                            onEditarPaciente: { sheet = .paciente(.existente(paciente)) }
                        )
                        .frame(width: 240)

                        ScrollView {
                            RelatorioView(diario: diario, paciente: paciente, desktop: true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        // HistoricoView é uma List — já rola por conta própria, não
                        // pode entrar dentro de outra ScrollView.
                        HistoricoView(diario: diario) { EmptyView() }
                            .frame(width: 420, alignment: .top)
                    }
                    .padding(24)
                }
                .frame(maxWidth: 1480)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Espelha o `iniciar` do web: o sheet "nova" só fecha quando o servidor
        // confirma a crise (diario.ativa vira não-nil); "andamento" fecha ao encerrar.
        .onChange(of: diario.ativa != nil) { _, temCriseAtiva in
            if temCriseAtiva, case .nova = sheet { sheet = nil }
            if !temCriseAtiva, case .andamento = sheet { sheet = nil }
        }
        .sheet(item: $sheet) { item in sheetConteudo(item) }
        .onAppear {
            ContaMac.shared.user = user
            ContaMac.shared.diario = diario
        }
        .onDisappear {
            ContaMac.shared.user = nil
            ContaMac.shared.diario = nil
        }
    }

    @ViewBuilder
    private func sheetConteudo(_ item: PainelSheet) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch item {
                case .nova:
                    NovaCriseView(diario: diario)
                case .andamento:
                    if let ativa = diario.ativa {
                        CriseAndamentoView(diario: diario, ativa: ativa, irParaHistorico: { sheet = nil })
                    }
                case .paciente(let alvo):
                    FormPacienteView(
                        inicial: alvo.pacienteExistente, primeiro: diario.paciente == nil,
                        onSalvar: { nome, nasc in
                            if let existente = alvo.pacienteExistente {
                                return await diario.salvarPaciente(existente.id, nome: nome, dataNascimento: nasc)
                            } else {
                                return await diario.criarPaciente(nome: nome, dataNascimento: nasc)
                            }
                        },
                        onCancelar: diario.paciente != nil ? { sheet = nil } : nil
                    )
                }

                Button("Fechar (Esc)") { sheet = nil }
                    .keyboardShortcut(.cancelAction)
                    .fonte(13, relativaA: .footnote)
                    .foregroundStyle(textoFraco)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 320, idealHeight: 480)
    }
}

/// Coluna esquerda: marca, lista de pacientes e ação primária. Ajustes da conta
/// vive na cena `Settings` (⌘,), fora desta janela.
/// Substitui a `BarraPacienteView` do telefone — no desktop o paciente mora aqui.
private struct SidebarView: View {
    let diario: Diario
    let paciente: Paciente
    let onNovaCrise: () -> Void
    let onAbrirAndamento: () -> Void
    let onNovoPaciente: () -> Void
    let onEditarPaciente: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                SubEyebrow(texto: "Diário da")
                Text("Cefaléia").fonte(24, peso: .bold, relativaA: .title2).tracking(0.2)
            }

            VStack(spacing: 4) {
                ForEach(diario.pacientes) { p in
                    ItemPacienteView(paciente: p, selecionado: p.id == paciente.id) {
                        diario.escolher(p.id)
                    }
                }
                HStack(spacing: 8) {
                    Button("+ Paciente", action: onNovoPaciente)
                        .frame(maxWidth: .infinity, minHeight: 34)
                    Button(action: onEditarPaciente) { Image(systemName: "pencil") }
                        .frame(width: 34, height: 34)
                }
                .fonte(13, peso: .semibold, relativaA: .footnote)
                .buttonStyle(.glass)
                .padding(.top, 4)
            }
            .cartao(cornerRadius: 20, padding: 8)

            if let ativa = diario.ativa {
                EmCursoView(ativa: ativa, onTap: onAbrirAndamento)
            } else {
                BotaoPrimario(titulo: "+ Nova crise", acao: onNovaCrise)
            }
        }
    }
}

private struct ItemPacienteView: View {
    let paciente: Paciente
    let selecionado: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(selecionado ? Color(hex: 0x8b7cfc) : Color(hex: 0x787880, opacity: 0.5))
                    .frame(width: 8, height: 8)
                    .shadow(color: selecionado ? Color(hex: 0x8b7cfc, opacity: 0.8) : .clear, radius: 4)
                Text(paciente.souEu ? "\(paciente.nome) · você" : paciente.nome)
                    .fonte(14, peso: .semibold, relativaA: .subheadline)
                    .lineLimit(1)
                Spacer()
                if let anos = idade(paciente.dataNascimento) {
                    Text("\(anos)a").fonte(12, relativaA: .caption).foregroundStyle(textoFraco2)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(selecionado ? Color.white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

/// Card vermelho com o cronômetro ao vivo — equivalente ao `EmCurso` de Painel.tsx.
private struct EmCursoView: View {
    let ativa: Crise
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulso = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("● Crise em andamento")
                    .fonte(13, peso: .bold, relativaA: .footnote)
                    .foregroundStyle(Color(hex: 0xffb5b0))
                    .opacity(reduceMotion ? 1 : (pulso ? 1 : 0.55))
                TimelineView(.periodic(from: ativa.inicio, by: 1)) { contexto in
                    Text(fmtDecorrido(contexto.date.timeIntervalSince(ativa.inicio) * 1000))
                        .fonte(26, peso: .bold, relativaA: .title2)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                Text("abrir para atualizar ou encerrar")
                    .fonte(12, relativaA: .caption)
                    .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(Color(hex: 0xff453a, opacity: 0.18), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0xff453a, opacity: 0.35)))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulso = true }
        }
    }
}

/// Conteúdo da cena `Settings` (⌘,/menu Ajustes) — janela própria, sem acesso
/// direto a `PainelView`. Divide nome e senha em abas, em vez do texto único
/// que existia sob "+ Nova crise".
struct AjustesMacView: View {
    @State private var conta = ContaMac.shared

    var body: some View {
        Group {
            if let user = conta.user, let diario = conta.diario {
                TabView {
                    Tab("Perfil", systemImage: "person.crop.circle") {
                        ScrollView {
                            AjustesView(user: user, diario: diario, parte: .perfil)
                                .padding(24)
                        }
                    }
                    Tab("Senha", systemImage: "key") {
                        ScrollView {
                            AjustesView(user: user, diario: diario, parte: .senha)
                                .padding(24)
                        }
                    }
                }
                .id(user.id)
            } else {
                Text("Entre na sua conta para ver os ajustes.")
                    .foregroundStyle(textoFraco)
                    .padding(40)
            }
        }
        .frame(width: 520, height: 560)
        .background(Color(hex: 0x0a0a13))
        .preferredColorScheme(.dark)
    }
}
