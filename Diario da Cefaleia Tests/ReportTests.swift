//
//  ReportTests.swift
//  Diario da Cefaleia Tests
//
//  Porta test/report.test.mjs do app web: mesma fixture, mesmos números esperados.
//  Se um número aqui divergir do teste web, o port de Report.swift está errado.
//

import Foundation
import Testing

@testable import Diario_da_Cefaleia

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func data(_ iso: String) -> Date { isoFormatter.date(from: iso)! }

private func dataLocal(ano: Int, mes: Int, dia: Int, hora: Int = 0, minuto: Int = 0) -> Date {
    var comp = DateComponents()
    comp.year = ano
    comp.month = mes
    comp.day = dia
    comp.hour = hora
    comp.minute = minuto
    return Calendar.current.date(from: comp)!
}

private func crise(
    _ inicio: String, _ fim: String?,
    intensidade: String = "Moderada", localizacao: String = "Bilateral", carater: String = "Pulsátil",
    sintomas: [String] = [], sonoHoras: Double = 8, gatilhos: [String] = [],
    detalhes: [String: [String]] = [:], medicacao: String = "", alivio: String? = nil
) -> Crise {
    Crise(
        id: UUID(), pacienteId: UUID(), inicio: data(inicio), fim: fim.map(data),
        intensidade: intensidade, localizacao: localizacao, carater: carater,
        sintomas: sintomas, sonoHoras: sonoHoras, gatilhos: gatilhos,
        detalhes: detalhes, medicacao: medicacao, alivio: alivio)
}

private let SEEDS: [Crise] = [
    crise(
        "2025-08-05T18:21:00Z", "2025-08-05T21:05:00Z",
        intensidade: "Intensa", localizacao: "Bilateral", carater: "Pulsátil",
        sintomas: ["Náusea", "Fotofobia"], sonoHoras: 6.5, gatilhos: ["Estresse"],
        medicacao: "Ibuprofeno 400 mg", alivio: "Parcial"),
    crise(
        "2025-08-01T14:10:00Z", "2025-08-01T15:20:00Z",
        intensidade: "Moderada", localizacao: "Dir.", carater: "Pressão",
        sintomas: ["Fonofobia"], sonoHoras: 7.5, gatilhos: ["Estresse"],
        medicacao: "Dipirona 500 mg", alivio: "Total"),
    crise(
        "2025-07-27T09:40:00Z", "2025-07-27T10:25:00Z",
        intensidade: "Leve", localizacao: "Esq.", carater: "Pulsátil",
        sonoHoras: 8, gatilhos: ["Mudança climática"]),
    crise(
        "2025-07-23T19:00:00Z", "2025-07-23T22:10:00Z",
        intensidade: "Moderada", localizacao: "Bilateral", carater: "Pressão",
        sintomas: ["Fotofobia", "Náusea"], sonoHoras: 5.5, gatilhos: ["Estresse", "Alimentação"],
        medicacao: "Ibuprofeno 400 mg", alivio: "Parcial"),
]

// O caso do César: 3 crises de Alimentação, "leite" em 2 delas.
private let ALIMENTACAO: [Crise] = [
    crise(
        "2025-08-05T18:00:00Z", "2025-08-05T19:00:00Z",
        intensidade: "Leve", localizacao: "Esq.", carater: "Pressão", sonoHoras: 8,
        gatilhos: ["Alimentação"],
        detalhes: ["Alimentação": ["sopa", "alho", "frango", "milho", "batata"]]),
    crise(
        "2025-08-03T18:00:00Z", "2025-08-03T19:00:00Z",
        intensidade: "Leve", localizacao: "Esq.", carater: "Pressão", sonoHoras: 8,
        gatilhos: ["Alimentação"],
        detalhes: ["Alimentação": ["sucrilhos", "leite"]]),
    crise(
        "2025-08-01T18:00:00Z", "2025-08-01T19:00:00Z",
        intensidade: "Leve", localizacao: "Esq.", carater: "Pressão", sonoHoras: 8,
        gatilhos: ["Alimentação"],
        detalhes: ["Alimentação": ["Leite", "chocolate"]]),
]

struct ReportTests {

    @Test("gatilhos batem com o screenshot 04-relatorio.png")
    func gatilhosBatem() {
        let esperado: [(String, Int)] = [
            ("Estresse", 75), ("Sono < 7h", 50), ("Mudança climática", 25), ("Alimentação", 25),
        ]
        let a = analisar(SEEDS)
        #expect(a.gatilhos.count == esperado.count)
        for (g, e) in zip(a.gatilhos, esperado) {
            #expect(g.label == e.0)
            #expect(g.pct == e.1)
        }
    }

    @Test("insight cita o gatilho do topo")
    func insightCitaTopo() {
        #expect(
            analisar(SEEDS).insight
                == "75% das crises ocorreram com \"Estresse\" presente — o gatilho mais frequente do período.")
    }

    @Test("insight avisa quando nenhum gatilho aparece")
    func insightSemGatilho() {
        let semGatilho = SEEDS.map { c -> Crise in
            var c = c
            c.gatilhos = []
            c.sonoHoras = 8
            return c
        }
        #expect(analisar(semGatilho).insight == "Ainda sem um gatilho dominante — continue registrando.")
    }

    @Test("estatísticas: 1/mês e 1h57")
    func estatisticas() {
        let a = analisar(SEEDS)
        #expect(a.frequencia == 1)
        #expect(a.duracaoMedia == 117)  // (164+70+45+190)/4
        #expect(fmtDuracao(a.duracaoMedia!) == "1h57")
    }

    @Test("crise em andamento não entra na duração média")
    func crisaAbertaForaDaMedia() {
        var aberta = crise("2025-08-06T10:00:00Z", nil, intensidade: "Leve", localizacao: "Esq.", carater: "Pressão", sonoHoras: 8)
        aberta.fim = nil
        #expect(analisar(SEEDS + [aberta]).duracaoMedia == 117)
    }

    @Test("duração média é null quando nada foi encerrado")
    func duracaoMediaNulaSemEncerradas() {
        var a0 = SEEDS[0]
        a0.fim = nil
        var a1 = SEEDS[1]
        a1.fim = nil
        #expect(analisar([a0, a1]).duracaoMedia == nil)
    }

    @Test("formatação de duração e sono")
    func formatacaoDuracaoESono() {
        #expect(fmtDuracao(45) == "45 min")
        #expect(fmtDuracao(164) == "2h44")
        #expect(fmtDuracao(120) == "2h")
        #expect(fmtSono(6.5) == "6h30")
        #expect(fmtSono(8) == "8h")
    }

    @Test("datas pt-BR no formato do design (o ICU insere um \"de\" que o iOS não tem)")
    func datasPtBR() {
        let d = dataLocal(ano: 2025, mes: 8, dia: 5, hora: 18, minuto: 21)
        #expect(fmtDataHist(d) == "ter, 5 ago")
        #expect(fmtEyebrow(d) == "ter, 5 de agosto")
    }

    @Test("acha o item que se repete entre crises do mesmo gatilho")
    func achaItemRecorrente() {
        let r = recorrentes(ALIMENTACAO, "Alimentação")
        #expect(r.count == 1)
        #expect(r[0].item == "leite")
        #expect(r[0].n == 2)
        #expect(r[0].de == 3)
    }

    @Test("item que aparece uma vez só não é recorrência")
    func itemUnicoNaoRecorre() {
        let itens = Set(recorrentes(ALIMENTACAO, "Alimentação").map(\.item))
        for unico in ["sopa", "alho", "frango", "milho", "batata", "sucrilhos", "chocolate"] {
            #expect(!itens.contains(unico))
        }
    }

    @Test("repetir o item na mesma crise não vira recorrência")
    func repeticaoNaMesmaCriseNaoRecorre() {
        let uma = [
            crise(
                "2025-08-05T18:00:00Z", "2025-08-05T19:00:00Z",
                intensidade: "Leve", localizacao: "Esq.", carater: "Pressão", sonoHoras: 8,
                gatilhos: ["Alimentação"],
                detalhes: ["Alimentação": ["leite", "leite", "LEITE"]])
        ]
        #expect(recorrentes(uma, "Alimentação").isEmpty)
    }

    @Test("só conta crises em que o gatilho estava presente")
    func soContaCrisesComGatilho() {
        let misto =
            ALIMENTACAO + [
                crise(
                    "2025-07-20T18:00:00Z", "2025-07-20T19:00:00Z",
                    intensidade: "Leve", localizacao: "Esq.", carater: "Pressão", sonoHoras: 8,
                    gatilhos: ["Estresse"], detalhes: ["Estresse": ["prova"]])
            ]
        #expect(recorrentes(misto, "Alimentação")[0].de == 3)  // 3, não 4
    }

    @Test("Sono < 7h não tem itens (é numérico)")
    func sonoNaoTemItens() {
        #expect(recorrentes(ALIMENTACAO, nil).isEmpty)
        let sono = analisar(ALIMENTACAO).gatilhos.first { $0.label == "Sono < 7h" }
        #expect(sono?.recorrentes.isEmpty == true)
    }

    @Test("recorrentes aparecem no texto para o médico")
    func recorrentesNoTexto() {
        #expect(textoRelatorio(ALIMENTACAO).contains("Alimentação: 100%\n    recorrente: leite (2 de 3)"))
    }

    @Test("dias com e sem crise por mês")
    func diasPorMes() {
        // SEEDS: 23 e 27 de julho, 1 e 5 de agosto.
        let meses = porMes(SEEDS, hoje: dataLocal(ano: 2025, mes: 8, dia: 31))
        #expect(meses.map { ($0.mes, $0.com, $0.sem, $0.total) }.count == 2)
        #expect(meses[0].mes == "jul/25" && meses[0].com == 2 && meses[0].sem == 29 && meses[0].total == 31)
        #expect(meses[1].mes == "ago/25" && meses[1].com == 2 && meses[1].sem == 29 && meses[1].total == 31)
    }

    @Test("mês corrente conta só os dias já vividos")
    func mesCorrenteContaSoDiasVividos() {
        let ago = porMes(SEEDS, hoje: dataLocal(ano: 2025, mes: 8, dia: 10)).last!
        #expect(ago.mes == "ago/25")
        #expect(ago.com == 2)
        #expect(ago.sem == 8)
        #expect(ago.total == 10)
    }

    @Test("mês sem nenhuma crise entra com zero")
    func mesSemCriseEntraComZero() {
        var junho = SEEDS[3]
        junho.inicio = data("2025-06-10T12:00:00Z")
        let meses = porMes([SEEDS[0], junho], hoje: dataLocal(ano: 2025, mes: 8, dia: 31))
        #expect(meses.map { ($0.mes, $0.com) }.count == 3)
        #expect(meses[0].mes == "jun/25" && meses[0].com == 1)
        #expect(meses[1].mes == "jul/25" && meses[1].com == 0)
        #expect(meses[2].mes == "ago/25" && meses[2].com == 1)
    }

    @Test("duas crises no mesmo dia contam um dia só")
    func duasCrisesMesmoDiaContamUm() {
        var segunda = SEEDS[0]
        segunda.inicio = data("2025-08-05T22:00:00Z")
        let mesmoDia = [SEEDS[0], segunda]
        #expect(porMes(mesmoDia, hoje: dataLocal(ano: 2025, mes: 8, dia: 31))[0].com == 1)
    }

    @Test("sem crise nenhuma não há meses")
    func semCriseNaoHaMeses() {
        #expect(porMes([]).isEmpty)
    }

    @Test("idade sai do nascimento (sem contar o aniversário que não chegou)")
    func idadeSaiDoNascimento() {
        #expect(idade("2014-03-22", hoje: dataLocal(ano: 2026, mes: 2, dia: 10)) == 11)
        #expect(idade("2014-03-22", hoje: dataLocal(ano: 2026, mes: 3, dia: 22)) == 12)
    }

    @Test("porDia: dois dias distintos")
    func porDiaDoisDias() {
        var a = SEEDS[0]
        a.inicio = dataLocal(ano: 2025, mes: 8, dia: 1, hora: 10)
        var b = SEEDS[1]
        b.inicio = dataLocal(ano: 2025, mes: 8, dia: 5, hora: 14)
        let dias = porDia([a, b], hoje: dataLocal(ano: 2025, mes: 8, dia: 5))
        #expect(dias.first?.n == 1)
        #expect(dias.last?.n == 1)
        #expect(dias.map(\.n).reduce(0, +) == 2)
    }

    @Test("porDia: duas crises no mesmo dia somam")
    func porDiaDuasNoMesmoDia() {
        var a = SEEDS[0]
        a.inicio = dataLocal(ano: 2025, mes: 8, dia: 5, hora: 10)
        var b = SEEDS[1]
        b.inicio = dataLocal(ano: 2025, mes: 8, dia: 5, hora: 22)
        let dias = porDia([a, b], hoje: dataLocal(ano: 2025, mes: 8, dia: 5))
        #expect(dias.count == 1)
        #expect(dias[0].n == 2)
    }

    @Test("porDia: dia sem crise no meio entra com zero")
    func porDiaBuracoComZero() {
        var a = SEEDS[0]
        a.inicio = dataLocal(ano: 2025, mes: 8, dia: 1, hora: 10)
        var b = SEEDS[1]
        b.inicio = dataLocal(ano: 2025, mes: 8, dia: 3, hora: 10)
        let dias = porDia([a, b], hoje: dataLocal(ano: 2025, mes: 8, dia: 3))
        #expect(dias.count == 3)
        #expect(dias.map(\.n) == [1, 0, 1])
    }

    @Test("porDia: lista vazia")
    func porDiaVazio() {
        #expect(porDia([]).isEmpty)
    }
}
