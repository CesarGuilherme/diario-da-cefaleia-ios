//
//  Senha.swift
//  Diario da Cefaleia
//
//  Espelha src/senha.ts: mesmas cinco regras, mesma ordem, mesmos rótulos em
//  português. Só a UI — quem barra senha fraca de fato é a política de senha do
//  Supabase Auth (ver supabase/migracao-politica-senha.sql no app web).
//

import Foundation

nonisolated struct RegraSenha: Identifiable {
    let id: String
    let label: String
    let ok: (String) -> Bool
}

nonisolated let REGRAS_SENHA: [RegraSenha] = [
    RegraSenha(id: "len", label: "8 caracteres") { $0.count >= 8 },
    RegraSenha(id: "A", label: "Maiúscula") { $0.contains { $0.isUppercase } },
    RegraSenha(id: "a", label: "Minúscula") { $0.contains { $0.isLowercase } },
    RegraSenha(id: "n", label: "Número") { $0.contains { $0.isNumber } },
    RegraSenha(id: "s", label: "Caractere especial") { s in
        s.contains { !$0.isLetter && !$0.isNumber }
    },
]

nonisolated func falhasSenha(_ s: String) -> [String] {
    REGRAS_SENHA.filter { !$0.ok(s) }.map { $0.label.lowercased() }
}

nonisolated func senhaValida(_ s: String) -> Bool {
    falhasSenha(s).isEmpty
}
