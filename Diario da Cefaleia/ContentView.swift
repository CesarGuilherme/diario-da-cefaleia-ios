//
//  ContentView.swift
//  Diario da Cefaleia
//
//  Casca do app: aurora, gate de sessão e a composição em abas. Espelha App.jsx.
//

import Auth
import Supabase
import SwiftUI

/// O 4º gradiente só aparece com crise aberta — junto com a aba vermelha, é o aviso do app.
private struct Aurora: View {
    var ativa = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(hex: 0x0a0a13)
            RadialGradient(
                colors: [Color(hex: 0x7c6cf6, opacity: 0.38), .clear],
                center: UnitPoint(x: 0.15, y: 0.08), startRadius: 0, endRadius: 260)
            RadialGradient(
                colors: [Color(hex: 0x38bdf8, opacity: 0.20), .clear],
                center: UnitPoint(x: 0.9, y: 0.25), startRadius: 0, endRadius: 280)
            RadialGradient(
                colors: [Color(hex: 0x7c6cf6, opacity: 0.18), .clear],
                center: UnitPoint(x: 0.6, y: 0.95), startRadius: 0, endRadius: 300)
            if ativa {
                RadialGradient(
                    colors: [Color(hex: 0xff453a, opacity: 0.30), .clear],
                    center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 300)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: ativa)
    }
}

private struct ErroConfigView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("App não configurado").font(.system(size: 18, weight: .bold))
            Text("Faltam SUPABASE_URL e SUPABASE_ANON_KEY no Info.plist.")
                .font(.system(size: 14)).multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.7))
        }
        .padding(22)
        .frame(maxWidth: 420)
        .background(Color(hex: 0xff453a, opacity: 0.12), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color(hex: 0xff453a, opacity: 0.3)))
        .padding(32)
    }
}

private enum EstadoSessao {
    case carregando
    case deslogado
    case logado(userId: UUID)
}

struct ContentView: View {
    @State private var estado: EstadoSessao = .carregando

    var body: some View {
        Group {
            if faltaConfig {
                ZStack { Aurora(); ErroConfigView() }
            } else {
                switch estado {
                case .carregando:
                    Aurora()
                case .deslogado:
                    ZStack { Aurora(); LoginView() }
                case .logado(let userId):
                    DiarioRootView(userId: userId)
                }
            }
        }
        .task {
            guard !faltaConfig else { return }
            for await (_, sessao) in supabase.auth.authStateChanges {
                estado = sessao.map { .logado(userId: $0.user.id) } ?? .deslogado
            }
        }
        // A paleta inteira é escura — sem isso o texto segue o esquema claro/escuro
        // do sistema e fica ilegível sobre a aurora.
        .preferredColorScheme(.dark)
    }
}

/// A casca é a mesma sempre: aurora, banner de erro e os dados do Diario.
/// As abas são `TabView` nativo — Liquid Glass do sistema.
private struct DiarioRootView: View {
    let userId: UUID
    @State private var diario: Diario

    init(userId: UUID) {
        self.userId = userId
        _diario = State(initialValue: Diario(userId: userId))
    }

    var body: some View {
        ZStack {
            Aurora(ativa: diario.ativa != nil)
            TelefoneView(diario: diario)
        }
    }
}

private enum FormPacienteAlvo: Identifiable {
    case novo
    case existente(Paciente)

    var id: String {
        switch self {
        case .novo: return "novo"
        case .existente(let p): return p.id.uuidString
        }
    }

    var pacienteExistente: Paciente? {
        if case .existente(let p) = self { return p }
        return nil
    }
}

private enum Aba: Hashable {
    case nova, historico, relatorio
}

private struct TelefoneView: View {
    let diario: Diario
    @State private var tela: Aba = .nova
    @State private var editando: FormPacienteAlvo?

    // Paciente é obrigatório: sem nenhum cadastrado, o app é só o formulário.
    private var alvo: FormPacienteAlvo? {
        editando ?? (!diario.carregandoPacientes && diario.paciente == nil ? .novo : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            BannerErro(erro: diario.erro) { diario.erro = nil }
                .padding(.horizontal)

            if let alvo {
                ScrollView {
                    FormPacienteView(
                        inicial: alvo.pacienteExistente,
                        primeiro: diario.paciente == nil,
                        onSalvar: { nome, nasc in
                            if let existente = alvo.pacienteExistente {
                                await diario.salvarPaciente(existente.id, nome: nome, dataNascimento: nasc)
                            } else {
                                await diario.criarPaciente(nome: nome, dataNascimento: nasc)
                            }
                        },
                        onCancelar: diario.paciente != nil ? { editando = nil } : nil
                    )
                    .padding()
                }
            } else if let paciente = diario.paciente {
                TabView(selection: $tela) {
                    Tab(
                        diario.ativa != nil ? "Em curso" : "Nova",
                        systemImage: diario.ativa != nil ? "circle.fill" : "plus.circle",
                        value: Aba.nova
                    ) {
                        AbaScroll(diario: diario, paciente: paciente, editando: $editando) {
                            if let ativa = diario.ativa {
                                CriseAndamentoView(
                                    diario: diario, ativa: ativa,
                                    irParaHistorico: { tela = .historico })
                            } else {
                                NovaCriseView(diario: diario)
                            }
                        }
                    }

                    Tab("Histórico", systemImage: "clock", value: Aba.historico) {
                        AbaScroll(diario: diario, paciente: paciente, editando: $editando) {
                            HistoricoView(diario: diario)
                        }
                    }

                    Tab("Relatório", systemImage: "chart.bar", value: Aba.relatorio) {
                        AbaScroll(diario: diario, paciente: paciente, editando: $editando) {
                            RelatorioView(diario: diario, paciente: paciente)
                        }
                    }
                }
                .tint(diario.ativa != nil ? Color(hex: 0xff453a) : Color(hex: 0x8b7cfc))
                .tabBarMinimizeBehavior(.onScrollDown)
            }
        }
    }
}

/// Conteúdo de cada aba: o `TabView` nativo traz o Liquid Glass; o scroll
/// passa por baixo da barra, que é o que o sistema espera.
private struct AbaScroll<Content: View>: View {
    let diario: Diario
    let paciente: Paciente
    @Binding var editando: FormPacienteAlvo?
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Cada página de TabView pinta seu próprio fundo opaco por baixo —
        // a aurora do ZStack de fora não passa. Repetir a aurora aqui dentro
        // é o jeito que funciona: um ZStack por página, não em volta do TabView.
        ZStack {
            Aurora(ativa: diario.ativa != nil)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BarraPacienteView(
                        pacientes: diario.pacientes, selecionado: paciente,
                        escolher: diario.escolher,
                        onNovo: { editando = .novo },
                        onEditar: { editando = .existente(paciente) }
                    )
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
    }
}

#Preview {
    ContentView()
}
