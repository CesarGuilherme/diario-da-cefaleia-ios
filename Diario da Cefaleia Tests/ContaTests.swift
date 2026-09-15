//
//  ContaTests.swift
//  Diario da Cefaleia Tests
//
//  Porta test/conta.test.mts do app web: mesmos casos, mesmo comportamento esperado.
//

import Testing

@testable import Diario_da_Cefaleia

@Suite struct ContaTests {
    @Test func temSenhaQuandoExisteIdentidadeDeEmail() {
        #expect(temSenha(identidades: ["email"], provedores: [], provedor: nil))
        #expect(temSenha(identidades: ["google", "email"], provedores: [], provedor: nil))
    }

    @Test func contaSoSocialNaoTemSenhaParaTrocar() {
        #expect(!temSenha(identidades: ["google"], provedores: [], provedor: nil))
        #expect(!temSenha(identidades: ["apple"], provedores: [], provedor: nil))
    }

    @Test func semIdentitiesCaiNoAppMetadataDoJWT() {
        #expect(temSenha(identidades: [], provedores: ["email"], provedor: nil))
        #expect(!temSenha(identidades: [], provedores: ["google"], provedor: nil))
        #expect(temSenha(identidades: [], provedores: [], provedor: "email"))
        #expect(!temSenha(identidades: [], provedores: [], provedor: nil))
    }

    @Test func oNomeVemDoMetadataSemEspacoEmVolta() {
        #expect(nomeDoUsuario("  César  ") == "César")
        #expect(nomeDoUsuario(nil) == "")
        #expect(nomeDoUsuario(42) == "")
    }

    @Test func quemJaEstaMarcadoEVoceMesmoComOutroNome() {
        let ps = [P("Manu"), P("Zé", true)]
        #expect(pacienteQueSouEu(ps, nome: "César")?.nome == "Zé")
    }

    @Test func semMarcaOHomomimoEVoceENaoViraUmSegundoPaciente() {
        #expect(pacienteQueSouEu([P("Manu"), P("César")], nome: "César")?.nome == "César")
        #expect(pacienteQueSouEu([P("cesar")], nome: "César")?.nome == "cesar")
        #expect(pacienteQueSouEu([P("  CÉSAR ")], nome: "cesar")?.nome == "  CÉSAR ")
    }

    @Test func semHomomimoNaoHaQuemMarcar() {
        #expect(pacienteQueSouEu([P("Manu"), P("João")], nome: "César") == nil)
        #expect(pacienteQueSouEu([P](), nome: "César") == nil)
    }

    @Test func semNomeSoAMarcaConta() {
        #expect(pacienteQueSouEu([P("Manu")], nome: "") == nil)
        #expect(pacienteQueSouEu([P("Manu"), P("Zé", true)], nome: "   ")?.nome == "Zé")
    }

    @Test func aListaDeQuemVoceAcompanhaSaiEmPortugues() {
        #expect(listar(["Manu"]) == "Manu")
        #expect(listar(["Manu", "João"]) == "Manu e João")
        #expect(listar(["Manu", "João", "Ana"]) == "Manu, João e Ana")
    }
}

private struct P: SouEu {
    let nome: String
    let souEu: Bool
    init(_ nome: String, _ souEu: Bool = false) {
        self.nome = nome
        self.souEu = souEu
    }
}
