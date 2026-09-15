//
//  AjustesView.swift
//  Diario da Cefaleia
//
//  Espelha screens/Ajustes.tsx: nome, quem é você, senha, sair e exclusão.
//  Sair/excluir saíram do Relatório — aqui é o único lugar que fala da conta.
//

import Auth
import Helpers
import Supabase
import SwiftUI

struct AjustesView: View {
    @State private var user: User
    let diario: Diario

    init(user: User, diario: Diario) {
        _user = State(initialValue: user)
        self.diario = diario
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                SubEyebrow(texto: user.email ?? "")
                Titulo(texto: "Ajustes")
            }

            PerfilSecao(user: $user, diario: diario)
            QuemSouEuSecao(user: user, diario: diario)
            SenhaSecao(user: user)

            Button("Sair da conta") {
                Task {
                    do {
                        try await supabase.auth.signOut(scope: .local)
                    } catch {
                        diario.erro = error.localizedDescription
                    }
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
            .frame(maxWidth: .infinity)

            ExcluirContaSecao(user: user, diario: diario)
        }
    }
}

private struct SecaoAjustes<Content: View>: View {
    let nome: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(texto: nome)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartao(padding: 18)
        }
    }
}

private struct Recado: View {
    let erro: Bool
    let texto: String
    var body: some View {
        Text(texto)
            .font(.system(size: 13))
            .foregroundStyle(erro ? Color(hex: 0xffb5b0) : Color(hex: 0xa9f0cd))
    }
}

private let avisoNome = "Aparece só para você. O nome do paciente é outro campo."

private struct PerfilSecao: View {
    @Binding var user: User
    let diario: Diario
    @State private var nome = ""
    @State private var ocupado = false
    @State private var msg: (erro: Bool, texto: String)?

    private var salvo: String { nomeDoUsuario(user) }
    private var limpo: String { nome.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        SecaoAjustes(nome: "Seu nome") {
            TextField("Como podemos te chamar", text: $nome)
                .textContentType(.name)
                .campo()
                .onChange(of: nome) { _, _ in msg = nil }
            Text(avisoNome)
                .font(.system(size: 13)).foregroundStyle(textoFraco)
            BotaoPrimario(
                titulo: "Salvar nome",
                desabilitado: ocupado || limpo == salvo,
                acao: { Task { await salvar() } })
            if let msg { Recado(erro: msg.erro, texto: msg.texto) }
        }
        .onAppear { nome = salvo }
    }

    private func salvar() async {
        ocupado = true
        msg = nil
        do {
            user = try await supabase.auth.update(user: UserAttributes(data: ["nome": .string(limpo)]))
            if let eu = diario.pacientes.first(where: { $0.souEu }), !limpo.isEmpty, eu.nome != limpo {
                _ = await diario.salvarPaciente(eu.id, nome: limpo, dataNascimento: eu.dataNascimento)
            }
            msg = (false, "Nome salvo.")
        } catch {
            msg = (true, error.localizedDescription)
        }
        ocupado = false
    }
}

private struct QuemSouEuSecao: View {
    let user: User
    let diario: Diario
    @State private var ocupado = false

    private var nome: String { nomeDoUsuario(user) }
    private var eu: Paciente? { diario.pacientes.first { $0.souEu } }
    private var quem: String { nome.isEmpty ? (eu?.nome ?? "Você") : nome }
    private var acompanhados: [String] { diario.pacientes.filter { !$0.souEu }.map(\.nome) }
    private var labelAcompanha: String {
        acompanhados.isEmpty
            ? "\(quem) — acompanhando outra pessoa"
            : "\(quem) — acompanhando \(listar(acompanhados))"
    }
    private var aviso: String {
        if let eu {
            return "Suas crises entram em \(eu.nome), junto com as de quem mais você acompanhar."
        }
        if !nome.isEmpty {
            return "A segunda opção é para quando as crises registradas também são suas."
        }
        return "Preencha seu nome acima para poder se cadastrar como paciente."
    }

    var body: some View {
        SecaoAjustes(nome: "Quem é você nesta conta") {
            Picker("Quem é você nesta conta", selection: Binding(
                get: { eu != nil },
                set: { v in Task { await escolher(v) } }
            )) {
                Text(labelAcompanha).tag(false)
                if !nome.isEmpty || eu != nil {
                    Text("\(quem) — usuário e paciente").tag(true)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .font(.system(size: 16, weight: .semibold))
            .disabled(ocupado)
            Text(aviso)
                .font(.system(size: 13)).foregroundStyle(textoFraco)
        }
    }

    private func escolher(_ eu: Bool) async {
        ocupado = true
        if !eu {
            _ = await diario.definirSouEu(nil)
        } else if let meu = pacienteQueSouEu(diario.pacientes, nome: nome) {
            _ = await diario.definirSouEu(meu.id)
        } else {
            _ = await diario.criarPaciente(nome: nome, dataNascimento: nil, souEu: true)
        }
        ocupado = false
    }
}

private struct SenhaSecao: View {
    let user: User
    @State private var atual = ""
    @State private var nova = ""
    @State private var ocupado = false
    @State private var msg: (erro: Bool, texto: String)?

    var body: some View {
        SecaoAjustes(nome: "Senha") {
            if temSenha(user) {
                TextField("", text: .constant(user.email ?? ""))
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(texto: "Senha atual")
                    SecureField("", text: $atual)
                        .textContentType(.password)
                        .campo()
                }
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(texto: "Nova senha")
                    SecureField("Aa1! · 8 caracteres", text: $nova)
                        .textContentType(.newPassword)
                        .campo()
                    ValidadorSenhaView(senha: nova)
                }
                BotaoPrimario(
                    titulo: "Alterar senha",
                    desabilitado: ocupado || atual.isEmpty || !senhaValida(nova),
                    acao: { Task { await trocar() } })
                if let msg { Recado(erro: msg.erro, texto: msg.texto) }
            } else {
                Text("Você entra com a Apple ou o Google — esta conta não tem senha para trocar.")
                    .font(.system(size: 13)).foregroundStyle(textoFraco)
            }
        }
    }

    private func trocar() async {
        let falta = falhasSenha(nova)
        if !falta.isEmpty {
            msg = (true, "A senha precisa de \(falta.joined(separator: ", ")).")
            return
        }
        ocupado = true
        msg = nil
        do {
            try await supabase.auth.signIn(email: user.email ?? "", password: atual)
        } catch {
            ocupado = false
            msg = (true, "Senha atual incorreta.")
            return
        }
        do {
            _ = try await supabase.auth.update(user: UserAttributes(password: nova))
            atual = ""
            nova = ""
            msg = (false, "Senha alterada.")
        } catch {
            msg = (true, error.localizedDescription)
        }
        ocupado = false
    }
}

private struct ExcluirContaSecao: View {
    let user: User
    let diario: Diario
    @State private var confirmando = false
    @State private var alerta = false
    @State private var ocupado = false
    @State private var msg: (erro: Bool, texto: String)?

    var body: some View {
        if !confirmando {
            Button("Excluir conta", role: .destructive) { confirmando = true }
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0xff453a, opacity: 0.7))
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Excluir a conta?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: 0xffb5b0))
                Text("Some tudo, e não dá para desfazer: a conta, os pacientes, todas as crises registradas e os links já enviados ao médico. Não guardamos cópia.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.65))
                BotaoPrimario(
                    titulo: ocupado ? "Excluindo…" : "Excluir definitivamente",
                    desabilitado: ocupado,
                    acao: { alerta = true })
                Button("Cancelar") { confirmando = false }
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
                    .frame(maxWidth: .infinity)
                    .disabled(ocupado)
                if let msg { Recado(erro: msg.erro, texto: msg.texto) }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xff453a, opacity: 0.12), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color(hex: 0xff453a, opacity: 0.3)))
            .confirmationDialog(
                "Excluir a conta e apagar todas as crises? Isso não pode ser desfeito.",
                isPresented: $alerta, titleVisibility: .visible
            ) {
                Button("Excluir conta", role: .destructive) { Task { await excluir() } }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private func excluir() async {
        ocupado = true
        msg = nil
        do {
            try await supabase.functions.invoke("excluir-conta")
            UserDefaults.standard.removeObject(forKey: "paciente:\(user.id.uuidString)")
            try await supabase.auth.signOut(scope: .local)
        } catch {
            ocupado = false
            msg = (true, "Não foi possível excluir a conta: \(error.localizedDescription)")
        }
    }
}
