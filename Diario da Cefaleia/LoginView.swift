//
//  LoginView.swift
//  Diario da Cefaleia
//
//  Espelha Login.jsx: Apple (nativo), Google (OAuth via ASWebAuthenticationSession) e
//  e-mail/senha, com o mesmo toggle entrar<->cadastrar.
//

import AuthenticationServices
import SwiftUI

private let redirectURL = URL(string: "com.digitalbsb.Diario-da-Cefaleia://login-callback")!

struct LoginView: View {
    private enum Modo { case entrar, cadastrar }

    @State private var modo: Modo = .entrar
    @State private var email = ""
    @State private var senha = ""
    @State private var mensagem: (erro: Bool, texto: String)?
    @State private var ocupado = false

    private var verbo: String { modo == .entrar ? "Entrar" : "Criar conta" }
    private var formValido: Bool { !email.isEmpty && senha.count >= 6 }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Diário da Cefaléia").font(.system(size: 30, weight: .bold))
                Text("Registre as crises e descubra o gatilho.")
                    .font(.system(size: 14)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.55))
            }

            VStack(spacing: 10) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    Task { await entrarComApple(result) }
                }
                .signInWithAppleButtonStyle(.white)
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
                .background(Color.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18)))

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
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .campo()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(texto: "Senha")
                        SecureField("mínimo 6 caracteres", text: $senha)
                            .textContentType(modo == .entrar ? .password : .newPassword)
                            .campo()
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

    private func entrarComApple(_ result: Result<ASAuthorization, Error>) async {
        mensagem = nil
        do {
            guard case .success(let auth) = result,
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) })
            else { return }
            try await supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken))
        } catch {
            mensagem = (true, error.localizedDescription)
        }
    }

    private func entrarComGoogle() async {
        mensagem = nil
        do {
            try await supabase.auth.signInWithOAuth(provider: .google, redirectTo: redirectURL)
        } catch {
            mensagem = (true, error.localizedDescription)
        }
    }

    private func porEmail() async {
        mensagem = nil
        ocupado = true
        do {
            if modo == .entrar {
                try await supabase.auth.signIn(email: email, password: senha)
                // No modo entrar, o authStateChanges do ContentView troca a tela sozinho.
            } else {
                try await supabase.auth.signUp(email: email, password: senha, redirectTo: redirectURL)
                mensagem = (false, "Confira seu e-mail para confirmar a conta.")
            }
        } catch {
            mensagem = (true, error.localizedDescription)
        }
        ocupado = false
    }
}
