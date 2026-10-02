//
//  LoginView.swift
//  Diario da Cefaleia
//
//  Espelha Login.jsx: Google (OAuth) e e-mail/senha, com o mesmo toggle entrar<->cadastrar.
//

import Auth
import AuthenticationServices
import Supabase
import SwiftUI

// Tem de estar nas Redirect URLs do Dashboard (além da URL da Vercel). Sem isso o
// GoTrue descarta o redirectTo e o e-mail de confirmação abre o webapp.
// Lido do bundle, não fixo: o target Mac tem seu próprio bundle id e esquema de URL
// (ver Info.plist do target), então cada app volta para si mesmo depois do login.
private let redirectURL = URL(string: "\(Bundle.main.bundleIdentifier ?? "com.digitalbsb.Diario-da-Cefaleia")://login-callback")!

struct LoginView: View {
    private enum Modo { case entrar, cadastrar }

    @State private var modo: Modo = .entrar
    @State private var email = ""
    @State private var senha = ""
    @State private var mensagem: (erro: Bool, texto: String)?
    @State private var ocupado = false
    // Guardado entre onRequest e onCompletion: o bruto vai para o Supabase, só o hash
    // vai para a Apple. Ver AppleID.swift.
    @State private var nonceBruto = ""

    private var verbo: String { modo == .entrar ? "Entrar" : "Criar conta" }
    private var formValido: Bool {
        !email.isEmpty && (modo == .entrar ? !senha.isEmpty : senhaValida(senha))
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Diário da Cefaléia").font(.system(size: 30, weight: .bold))
                Text("Registre as crises e descubra o gatilho.")
                    .font(.system(size: 14)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.55))
            }

            VStack(spacing: 10) {
                // HIG "Sign in with Apple: Displaying buttons": não menor que os outros
                // botões de login, e acima deles — aqui, acima do Google.
                SignInWithAppleButton(modo == .entrar ? .signIn : .signUp) { request in
                    let nonce = gerarNonce()
                    nonceBruto = nonce
                    request.requestedScopes = [.email]  // minimização: o app não usa nome.
                    request.nonce = sha256(nonce)
                } onCompletion: { resultado in
                    Task { await completarComApple(resultado) }
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 52)
                .clipShape(Capsule())

                // "G" oficial fica pra quando houver asset — SF Symbol por ora.
                Button {
                    Task { await entrarComGoogle() }
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text("\(verbo) com Google")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .foregroundStyle(.white)
                .buttonStyle(.glass)

                HStack(spacing: 10) {
                    Rectangle().fill(Color.white.opacity(0.14)).frame(height: 0.5)
                    Text("ou com e-mail")
                        .font(.system(size: 12)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.4))
                    Rectangle().fill(Color.white.opacity(0.14)).frame(height: 0.5)
                }
                .padding(.vertical, 6)

                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(texto: "E-mail")
                        TextField("voce@exemplo.com", text: $email)
                            // .username, não .emailAddress: é o content type que pareia com
                            // o `webcredentials` do associated domain — AutoFill só acha a
                            // senha salva no Safari do webapp através dele.
                            .textContentType(.username)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            .campo()
                            .accessibilityLabel("E-mail")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(texto: "Senha")
                        SecureField(modo == .cadastrar ? "Aa1! · 8 caracteres" : "", text: $senha)
                            .textContentType(modo == .entrar ? .password : .newPassword)
                            .campo()
                            .accessibilityLabel("Senha")
                        if modo == .cadastrar {
                            ValidadorSenhaView(senha: senha)
                        }
                    }
                    BotaoPrimario(
                        titulo: verbo, desabilitado: ocupado || !formValido,
                        acao: { Task { await porEmail() } })
                }

                if let mensagem {
                    Text(mensagem.texto)
                        .font(.system(size: 13)).multilineTextAlignment(.center)
                        .foregroundStyle(mensagem.erro ? Color(hex: 0xffb5b0) : Color(hex: 0xa9f0cd))
                }

                Button {
                    Task { await recuperar() }
                } label: {
                    Text("Esqueci a senha")
                        .font(.system(size: 13)).foregroundStyle(Color(hex: 0x8b7cfc))
                }
                .disabled(ocupado)

                Button {
                    modo = modo == .entrar ? .cadastrar : .entrar
                    mensagem = nil
                } label: {
                    Text(modo == .entrar ? "Não tem conta? Criar uma" : "Já tem conta? Entrar")
                        .font(.system(size: 13)).foregroundStyle(Color(hex: 0x8b7cfc))
                }
            }
            .cartao()
        }
        .padding(32)
        .frame(maxWidth: 380)
    }

    private func completarComApple(_ resultado: Result<ASAuthorization, Error>) async {
        mensagem = nil
        switch resultado {
        case .success(let autorizacao):
            guard let credencial = autorizacao.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credencial.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                mensagem = (true, "Não foi possível concluir com a Apple.")
                return
            }
            do {
                try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: token, nonce: nonceBruto))
                salvarAppleUserID(credencial.user)
            } catch {
                mensagem = (true, mensagemErro(error, senao: "Não foi possível entrar com a Apple. Tente de novo."))
            }
        case .failure(let error):
            // Cancelar o painel da Apple não é erro — nem toda desistência precisa de mensagem.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            mensagem = (true, mensagemErro(error, senao: "Não foi possível entrar com a Apple. Tente de novo."))
        }
    }

    private func entrarComGoogle() async {
        mensagem = nil
        do {
            try await supabase.auth.signInWithOAuth(provider: .google, redirectTo: redirectURL)
        } catch {
            mensagem = (true, mensagemErro(error, senao: "Não foi possível entrar com o Google. Tente de novo."))
        }
    }

    private func recuperar() async {
        guard !email.isEmpty else {
            mensagem = (true, "Informe o e-mail para redefinir a senha.")
            return
        }
        mensagem = nil
        ocupado = true
        do {
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: redirectURL)
            mensagem = (false, "Se esta conta existir, enviamos um link para redefinir a senha.")
        } catch {
            mensagem = (true, mensagemErro(error, senao: "Não foi possível enviar o e-mail. Tente de novo."))
        }
        ocupado = false
    }

    private func porEmail() async {
        mensagem = nil
        if modo == .cadastrar {
            let falta = falhasSenha(senha)
            guard falta.isEmpty else {
                mensagem = (true, "A senha precisa de \(falta.joined(separator: ", ")).")
                return
            }
        }
        ocupado = true
        do {
            if modo == .entrar {
                try await supabase.auth.signIn(email: email, password: senha)
                // No modo entrar, o authStateChanges do ContentView troca a tela sozinho.
            } else {
                try await supabase.auth.signUp(email: email, password: senha, redirectTo: redirectURL)
                // Mesma frase para conta nova e e-mail já usado: o GoTrue devolve 200 nos dois
                // casos e "confira seu e-mail" denunciaria quem já tem cadastro.
                mensagem = (false, "Se este e-mail puder receber, enviamos um link. Já tem conta? Entre ou redefina a senha.")
            }
        } catch {
            let senao = modo == .entrar
                ? "Não foi possível entrar. Tente de novo."
                : "Não foi possível criar a conta. Tente de novo."
            mensagem = (true, mensagemErro(error, senao: senao))
        }
        ocupado = false
    }
}

/// Checklist ao vivo das regras de senha. Espelha `ValidadorSenha` de Login.jsx.
struct ValidadorSenhaView: View {
    let senha: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(REGRAS_SENHA) { regra in
                let ok = regra.ok(senha)
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(ok ? Color(hex: 0x30d158, opacity: 0.28) : Color(hex: 0x787880, opacity: 0.18))
                        Circle()
                            .strokeBorder(ok ? Color(hex: 0x30d158, opacity: 0.45) : Color.white.opacity(0.12), lineWidth: 0.5)
                        if ok {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color(hex: 0x30d158))
                        }
                    }
                    .frame(width: 14, height: 14)
                    Text(regra.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ok ? Color(hex: 0xa9f0cd) : Color(hex: 0xebebf5, opacity: 0.38))
                }
                .animation(.easeInOut(duration: 0.15), value: ok)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}
