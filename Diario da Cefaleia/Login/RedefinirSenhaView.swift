//
//  RedefinirSenhaView.swift
//  Diario da Cefaleia
//
//  Sessão de PASSWORD_RECOVERY: o link do e-mail já autenticou, só falta a senha
//  nova. Espelha RedefinirSenha de Login.jsx.
//

import Supabase
import SwiftUI

struct RedefinirSenhaView: View {
    let onOk: () -> Void

    @State private var senha = ""
    @State private var ocupado = false
    @State private var mensagem: (erro: Bool, texto: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nova senha").font(.system(size: 18, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(texto: "Senha")
                SecureField("Aa1! · 8 caracteres", text: $senha)
                    .textContentType(.newPassword)
                    .campo()
                ValidadorSenhaView(senha: senha)
            }

            BotaoPrimario(
                titulo: "Salvar senha", desabilitado: ocupado || !senhaValida(senha),
                acao: { Task { await salvar() } })

            if let mensagem {
                Text(mensagem.texto)
                    .font(.system(size: 13)).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(mensagem.erro ? Color(hex: 0xffb5b0) : Color(hex: 0xa9f0cd))
            }
        }
        .cartao()
        .padding(32)
        .frame(maxWidth: 380)
    }

    private func salvar() async {
        let falta = falhasSenha(senha)
        guard falta.isEmpty else {
            mensagem = (true, "A senha precisa de \(falta.joined(separator: ", ")).")
            return
        }
        mensagem = nil
        ocupado = true
        do {
            _ = try await supabase.auth.update(user: UserAttributes(password: senha))
            onOk()
        } catch {
            mensagem = (true, error.localizedDescription)
        }
        ocupado = false
    }
}
