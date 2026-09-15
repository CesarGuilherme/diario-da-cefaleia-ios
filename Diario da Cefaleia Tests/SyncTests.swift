//
//  SyncTests.swift
//  Diario da Cefaleia Tests
//
//  Porta test/sync.test.mts: o que acontece com a lista quando chega um
//  evento do Realtime do outro celular.
//

import Foundation
import Testing

@testable import Diario_da_Cefaleia

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func data(_ isoStr: String) -> Date { iso.date(from: isoStr)! }

private let pid = UUID()
private let idA = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
private let idB = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
private let idC = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!

private func crise(_ id: UUID, _ inicio: String, fim: Date? = nil, alivio: String? = nil, medicacao: String = "", sonoHoras: Double = 8) -> Crise {
    Crise(
        id: id, pacienteId: pid, inicio: data(inicio), fim: fim,
        intensidade: "Moderada", localizacao: "Bilateral", carater: "Pulsátil",
        sintomas: [], sonoHoras: sonoHoras, gatilhos: [], detalhes: [:],
        medicacao: medicacao, alivio: alivio)
}

private let A = crise(idA, "2025-08-05T18:00:00Z")
private let B = crise(idB, "2025-08-01T14:00:00Z")

@Suite struct SyncTests {
    @Test func criseCriadaNoOutroAparelhoEntraNaListaNaOrdem() {
        let nova = crise(idC, "2025-08-10T09:00:00Z")
        #expect(aplicar([A, B], .inserir(nova)).map(\.id) == [idC, idA, idB])
    }

    @Test func criseAntigaChegandoPorInsertNaoVaiPararNoTopo() {
        let antiga = crise(idC, "2025-07-01T09:00:00Z")
        #expect(aplicar([A, B], .inserir(antiga)).map(\.id) == [idA, idB, idC])
    }

    @Test func oEcoDaNossaEscritaNaoDuplica() {
        #expect(aplicar([A, B], .inserir(A)).map(\.id) == [idA, idB])
    }

    @Test func updateTrocaALinhaEMantemOResto() {
        let encerrada = crise(idA, "2025-08-05T18:00:00Z", fim: data("2025-08-05T21:00:00Z"), alivio: "Parcial")
        let depois = aplicar([A, B], .atualizar(encerrada))
        #expect(depois.map(\.id) == [idA, idB])
        #expect(depois[0].fim == data("2025-08-05T21:00:00Z"))
        #expect(depois[1].fim == nil)
    }

    @Test func updateDeCriseDesconhecidaEntra() {
        let nuncaVista = crise(idC, "2025-08-10T09:00:00Z", medicacao: "Dipirona")
        #expect(aplicar([A], .atualizar(nuncaVista)).map(\.id) == [idC, idA])
    }

    @Test func deleteRemovePeloId() {
        #expect(aplicar([A, B], .apagar(idA)).map(\.id) == [idB])
    }

    @Test func deleteDeCriseQueNaoTemosNaoMexe() {
        #expect(aplicar([A, B], .apagar(UUID())).map(\.id) == [idA, idB])
    }

    @Test func oMesmoEventoDuasVezesDaOMesmoResultado() {
        let nova = crise(idC, "2025-08-10T09:00:00Z")
        let uma = aplicar([A, B], .inserir(nova))
        #expect(aplicar(uma, .inserir(nova)) == uma)
    }
}
