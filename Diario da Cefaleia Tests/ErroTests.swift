//
//  ErroTests.swift
//  Diario da Cefaleia Tests
//

import Foundation
import Testing

@testable import Diario_da_Cefaleia

@Suite struct ErroTests {
    @Test func semRedeNaoMostraOTextoDoSistema() {
        let erro = URLError(.notConnectedToInternet)
        #expect(mensagemErro(erro) == "Sem conexão. Nada foi salvo.")
        #expect(mensagemErro(URLError(.timedOut), senao: "outra") == "Sem conexão. Nada foi salvo.")
    }

    @Test func redeDentroDeOutroErroTambemConta() {
        let causa = URLError(.networkConnectionLost)
        let embrulho = NSError(domain: "teste", code: 1, userInfo: [NSUnderlyingErrorKey: causa])
        #expect(mensagemErro(embrulho) == "Sem conexão. Nada foi salvo.")
    }

    @Test func oRestoUsaAFraseDaAcao() {
        struct Qualquer: Error {}
        #expect(mensagemErro(Qualquer()) == "Não foi possível salvar. Tente de novo.")
        #expect(mensagemErro(Qualquer(), senao: "Não foi possível entrar. Tente de novo.")
            == "Não foi possível entrar. Tente de novo.")
    }

    @Test func urlQueNaoERedeNaoViraSemConexao() {
        #expect(mensagemErro(URLError(.badURL)) == "Não foi possível salvar. Tente de novo.")
    }
}
