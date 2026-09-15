//
//  SenhaTests.swift
//  Diario da Cefaleia Tests
//
//  Porta test/senha.test.mts do app web: mesmos casos, mesmo comportamento esperado.
//

import Testing

@testable import Diario_da_Cefaleia

@Suite struct SenhaTests {
    @Test func rejeitaOQueFaltaEmCadaRegra() {
        #expect(falhasSenha("Aa1!xxx") == ["8 caracteres"])
        #expect(falhasSenha("aa1!xxxx").contains("maiúscula"))
        #expect(falhasSenha("AA1!XXXX").contains("minúscula"))
        #expect(falhasSenha("Aa!!xxxx").contains("número"))
        #expect(falhasSenha("Aa11xxxx").contains("caractere especial"))
    }

    @Test func aceitaUmaSenhaQueCumpreTudo() {
        #expect(senhaValida("Abcd123!"))
        #expect(falhasSenha("Abcd123!").isEmpty)
        #expect(REGRAS_SENHA.allSatisfy { $0.ok("Abcd123!") })
    }

    @Test func oChecklistMarcaRegraARegraEnquantoDigita() {
        func ids(_ s: String) -> [String] {
            REGRAS_SENHA.filter { $0.ok(s) }.map(\.id)
        }
        #expect(ids("") == [])
        #expect(ids("abcdefgh") == ["len", "a"])
        #expect(ids("Abcdefgh") == ["len", "A", "a"])
        #expect(ids("Abcdefg1") == ["len", "A", "a", "n"])
        #expect(ids("Abcdefg1!") == ["len", "A", "a", "n", "s"])
    }
}
