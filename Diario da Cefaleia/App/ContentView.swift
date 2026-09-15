//
//  ContentView.swift
//  Diario da Cefaleia
//
//  Casca do app: aurora, gate de sessão e a composição em abas. Espelha App.jsx.
//

import Auth
import Supabase
import SwiftUI

// Hoisted: até quatro `Aurora`s ficam vivas ao mesmo tempo (uma por página do
// TabView, mais a externa), e cada uma reconstruía estes quatro gradientes a
// cada avaliação do body. Valores fixos, então valem como `let` de arquivo.
private let auroraGrad1 = RadialGradient(
    colors: [Color(hex: 0x7c6cf6, opacity: 0.38), .clear],
    center: UnitPoint(x: 0.15, y: 0.08), startRadius: 0, endRadius: 260)
private let auroraGrad2 = RadialGradient(
    colors: [Color(hex: 0x38bdf8, opacity: 0.20), .clear],
    center: UnitPoint(x: 0.9, y: 0.25), startRadius: 0, endRadius: 280)
private let auroraGrad3 = RadialGradient(
    colors: [Color(hex: 0x7c6cf6, opacity: 0.18), .clear],
    center: UnitPoint(x: 0.6, y: 0.95), startRadius: 0, endRadius: 300)
private let auroraGradAtiva = RadialGradient(
    colors: [Color(hex: 0xff453a, opacity: 0.30), .clear],
    center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 300)

/// O 4º gradiente só aparece com crise aberta — junto com a aba vermelha, é o aviso do app.
private struct Aurora: View {
    var ativa = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(hex: 0x0a0a13)
            auroraGrad1
            auroraGrad2
            auroraGrad3
            if ativa {
                auroraGradAtiva
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
    case logado(User)
}

/// Continuação da launch screen do sistema: o UIKit derruba a launch screen real
/// no primeiro frame renderizado, então nenhuma transição do SwiftUI atravessa
/// essa borda. Isto mostra a mesma imagem/fundo e desaparece com fade — a costura
/// vira invisível e a troca claro→escuro acontece dentro do app, animada.
private struct LaunchContinuationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visivel = true

    var body: some View {
        if visivel {
            ZStack {
                Color("LaunchBackground").ignoresSafeArea()
                Image("cefaleia-launch-ok")
                    .resizable()
                    .scaledToFit()
                    .padding(32)
            }
            .transition(.opacity)
            .task {
                if reduceMotion {
                    visivel = false
                } else {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.easeOut(duration: 0.4)) { visivel = false }
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var estado: EstadoSessao = .carregando
    // Separado do EstadoSessao, não uma dobra a mais nele: um TOKEN_REFRESHED no meio da
    // recuperação não deve devolver a Diario por baixo do formulário de senha nova — só
    // PASSWORD_RECOVERY liga isto, só SIGNED_OUT ou onOk desligam. Espelha o par
    // sessao/recuperando de App.tsx, que são dois estados independentes pelo mesmo motivo.
    @State private var recuperandoSenha = false

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
                case .logado(let user):
                    if recuperandoSenha {
                        ZStack { Aurora(); RedefinirSenhaView(onOk: { recuperandoSenha = false }) }
                    } else {
                        // .id força estado novo se o uid trocar sem passar por .deslogado —
                        // @State ignora o initialValue depois da primeira inserção.
                        DiarioRootView(user: user).id(user.id)
                    }
                }
            }
        }
        .task {
            guard !faltaConfig else { return }
            observarRevogacaoAppleID()
            await checarRevogacaoAppleID()
            for await (evento, sessao) in supabase.auth.authStateChanges {
                if evento == .passwordRecovery { recuperandoSenha = true }
                if evento == .signedOut { recuperandoSenha = false }
                // emitLocalSessionAsInitialSession manda a sessão local direto, mesmo expirada,
                // e só tenta o refresh depois em background — sem o isExpired aqui a UI piscaria
                // "logado" antes do refresh falhar e derrubar de volta pro login.
                if let sessao, !sessao.isExpired {
                    estado = .logado(sessao.user)
                } else if sessao == nil {
                    estado = .deslogado
                }
            }
        }
        // A paleta inteira é escura — sem isso o texto segue o esquema claro/escuro
        // do sistema e fica ilegível sobre a aurora.
        .preferredColorScheme(.dark)
        .overlay { LaunchContinuationView() }
    }
}

/// A casca é a mesma sempre: aurora, banner de erro e os dados do Diario.
/// As abas são `TabView` nativo — Liquid Glass do sistema.
private struct DiarioRootView: View {
    let user: User
    @State private var diario: Diario

    init(user: User) {
        self.user = user
        _diario = State(initialValue: Diario(userId: user.id))
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            AuroraFundo(diario: diario)
            TelefoneView(user: user, diario: diario)
        }
        .task {
            await diario.iniciarSync()
            defer { diario.pararSync() }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3_600))
            }
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { Task { await diario.voltarAoPrimeiroPlano() } }
        }
    }
}

/// Só este body lê `diario.ativa` para a aurora — quando a crise abre/fecha, a
/// invalidação fica confinada aqui em vez de reavaliar a casca inteira da aba.
private struct AuroraFundo: View {
    let diario: Diario
    var body: some View { Aurora(ativa: diario.ativa != nil) }
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
    case nova, historico, relatorio, ajustes
}

private struct TelefoneView: View {
    let user: User
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
                        // Fora do AbaScroll: o Histórico é um List (células recicladas,
                        // swipe nativo) e List dentro de ScrollView não rola.
                        ZStack {
                            AuroraFundo(diario: diario)
                            HistoricoView(diario: diario) {
                                BarraPacienteView(
                                    pacientes: diario.pacientes, selecionado: paciente,
                                    escolher: diario.escolher,
                                    onNovo: { editando = .novo },
                                    onEditar: { editando = .existente(paciente) }
                                )
                            }
                        }
                    }

                    Tab("Relatório", systemImage: "chart.bar", value: Aba.relatorio) {
                        AbaScroll(diario: diario, paciente: paciente, editando: $editando) {
                            RelatorioView(diario: diario, paciente: paciente)
                        }
                    }

                    Tab("Ajustes", systemImage: "gearshape", value: Aba.ajustes) {
                        AbaScroll(diario: diario, paciente: paciente, editando: $editando, mostraBarra: false) {
                            AjustesView(user: user, diario: diario)
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
    var mostraBarra = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Cada página de TabView pinta seu próprio fundo opaco por baixo —
        // a aurora do ZStack de fora não passa. Repetir a aurora aqui dentro
        // é o jeito que funciona: um ZStack por página, não em volta do TabView.
        ZStack {
            AuroraFundo(diario: diario)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if mostraBarra {
                        BarraPacienteView(
                            pacientes: diario.pacientes, selecionado: paciente,
                            escolher: diario.escolher,
                            onNovo: { editando = .novo },
                            onEditar: { editando = .existente(paciente) }
                        )
                    }
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
