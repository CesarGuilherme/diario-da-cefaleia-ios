//
//  Conta.swift
//  Diario da Cefaleia
//
//  Espelha src/conta.ts: o que dá para saber do usuário sem perguntar ao servidor.
//  Fora das views de propósito — testável sem o cliente do Supabase nem SwiftUI.
//

import Auth
import Foundation

/// Esta conta tem senha para trocar? Quem entrou só pelo Google ou Apple não tem:
/// o GoTrue guarda uma identidade por provedor, e a senha pertence à identidade `email`.
nonisolated func temSenha(identidades: [String], provedores: [String], provedor: String?) -> Bool {
    if !identidades.isEmpty { return identidades.contains("email") }
    if !provedores.isEmpty { return provedores.contains("email") }
    return provedor == "email"
}

/// O nome que o usuário escolheu para si nos Ajustes. Vazio = nunca preencheu.
nonisolated func nomeDoUsuario(_ valor: Any?) -> String {
    guard let s = valor as? String else { return "" }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

nonisolated protocol SouEu {
    var nome: String { get }
    var souEu: Bool { get }
}

/// Qual das linhas de `pacientes` é o próprio dono da conta.
/// A marca vale mais que o nome; sem marca, um homônimo do nome da conta é ele.
nonisolated func pacienteQueSouEu<T: SouEu>(_ pacientes: [T], nome: String) -> T? {
    let marcado = pacientes.first { $0.souEu }
    if marcado != nil || nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return marcado
    }
    return pacientes.first { chaveComparavel($0.nome) == chaveComparavel(nome) }
}

/// "Manu", "Manu e João", "Manu, João e Ana" — locale travado em pt-BR.
nonisolated func listar(_ nomes: [String]) -> String {
    let f = ListFormatter()
    f.locale = Locale(identifier: "pt_BR")
    return f.string(from: nomes) ?? nomes.joined(separator: ", ")
}

nonisolated func temSenha(_ user: User) -> Bool {
    let identidades = user.identities?.map(\.provider) ?? []
    let provedores = (user.appMetadata["providers"]?.value as? [Any])?.compactMap { $0 as? String } ?? []
    let provedor: String?
    if case .string(let s) = user.appMetadata["provider"] { provedor = s } else { provedor = nil }
    return temSenha(identidades: identidades, provedores: provedores, provedor: provedor)
}

nonisolated func nomeDoUsuario(_ user: User) -> String {
    nomeDoUsuario(user.userMetadata["nome"]?.value)
}
