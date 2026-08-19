//
//  Report.swift
//  Diario da Cefaleia
//
//  Toda a lógica do Relatório, pura e sem SwiftUI — é a única coisa não-trivial do app,
//  e é o que ReportTests.swift cobre. Espelha src/report.js do app web, número a número.
//

import Foundation

private struct GatilhoDef {
    let label: String
    let chave: String?  // nil = "Sono < 7h", que é numérico e não tem itens
}

private let DEFS: [GatilhoDef] = [
    GatilhoDef(label: "Sono < 7h", chave: nil),
    GatilhoDef(label: "Estresse", chave: "Estresse"),
    GatilhoDef(label: "Mudança climática", chave: "Mudança climática"),
    GatilhoDef(label: "Alimentação", chave: "Alimentação"),
]

private func presente(_ chave: String?, _ c: Crise) -> Bool {
    guard let chave else { return c.sonoHoras < 7 }
    return c.gatilhos.contains(chave)
}

/// Compara ignorando caixa e acento, para "Leite" e "leite" contarem como o mesmo item.
private func chaveComparavel(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
}

struct Recorrente: Equatable, Identifiable {
    var item: String
    var n: Int
    var de: Int
    var id: String { item }
}

/// Itens que se repetem entre as crises de um gatilho — o "leite em 2 de 3".
/// Conta uma vez por crise (repetir na mesma crise não vira recorrência).
func recorrentes(_ crises: [Crise], _ gatilho: String?) -> [Recorrente] {
    guard let gatilho else { return [] }
    let comGatilho = crises.filter { presente(gatilho, $0) }

    var conta: [String: (item: String, n: Int)] = [:]
    for c in comGatilho {
        var vistos = Set<String>()
        for item in c.detalhes[gatilho] ?? [] {
            let k = chaveComparavel(item)
            guard !k.isEmpty, !vistos.contains(k) else { continue }
            vistos.insert(k)
            var e = conta[k] ?? (item: item.trimmingCharacters(in: .whitespacesAndNewlines), n: 0)
            e.n += 1
            conta[k] = e
        }
    }

    return
        conta.values
        .filter { $0.n >= 2 }
        .sorted { $0.n != $1.n ? $0.n > $1.n : $0.item.localizedCompare($1.item) == .orderedAscending }
        .map { Recorrente(item: $0.item, n: $0.n, de: comGatilho.count) }
}

struct MesInfo: Equatable, Identifiable {
    var mes: String
    var com: Int
    var sem: Int
    var total: Int
    var id: String { mes }
}

/// Dias com e sem crise, mês a mês, do mês da primeira crise até o mês corrente
/// (meses vazios no meio entram com 0 — é justamente o mês bom que o médico quer ver).
/// ponytail: conta o dia do `inicio`; crise que atravessa a meia-noite conta 1 dia só.
func porMes(_ crises: [Crise], hoje: Date = Date()) -> [MesInfo] {
    guard !crises.isEmpty else { return [] }
    let cal = calendarioBR

    var dias: [String: Set<Int>] = [:]  // "ano-mês" -> dias do mês com crise
    var primeira: Date?
    for c in crises {
        if primeira == nil || c.inicio < primeira! { primeira = c.inicio }
        let comp = cal.dateComponents([.year, .month, .day], from: c.inicio)
        dias["\(comp.year!)-\(comp.month!)", default: []].insert(comp.day!)
    }

    var curComp = cal.dateComponents([.year, .month], from: primeira!)
    curComp.day = 1
    var cur = cal.date(from: curComp)!

    let hojeComp = cal.dateComponents([.year, .month, .day], from: hoje)
    let ultimo = cal.date(from: DateComponents(year: hojeComp.year, month: hojeComp.month, day: 1))!

    var meses: [MesInfo] = []
    while cur <= ultimo {
        let comp = cal.dateComponents([.year, .month], from: cur)
        // Mês corrente conta só os dias já vividos, senão "sem crise" vira promessa de futuro.
        let total =
            cur == ultimo
            ? hojeComp.day!
            : cal.range(of: .day, in: .month, for: cur)!.count
        let com = dias["\(comp.year!)-\(comp.month!)"]?.count ?? 0
        meses.append(MesInfo(mes: fmtMes(cur), com: com, sem: total - com, total: total))
        cur = cal.date(byAdding: .month, value: 1, to: cur)!
    }
    return meses
}

struct DiaInfo: Equatable, Identifiable {
    var dia: Date
    var n: Int
    var id: Date { dia }
}

/// Uma entrada por dia, da primeira crise até hoje. Dias sem crise entram com n=0
/// para a linha mostrar o chão. Duas crises no mesmo dia somam (ao contrário de porMes).
func porDia(_ crises: [Crise], hoje: Date = Date()) -> [DiaInfo] {
    guard !crises.isEmpty else { return [] }
    let cal = calendarioBR
    var conta: [Date: Int] = [:]
    var primeira: Date?
    for c in crises {
        let dia = cal.startOfDay(for: c.inicio)
        conta[dia, default: 0] += 1
        if primeira == nil || dia < primeira! { primeira = dia }
    }
    let inicio = primeira!
    let fim = cal.startOfDay(for: hoje)
    var out: [DiaInfo] = []
    var cur = inicio
    while cur <= fim {
        out.append(DiaInfo(dia: cur, n: conta[cur] ?? 0))
        cur = cal.date(byAdding: .day, value: 1, to: cur)!
    }
    return out
}

struct GatilhoAnalise: Equatable, Identifiable {
    var label: String
    var pct: Int
    var recorrentes: [Recorrente]
    var id: String { label }
}

struct Analise {
    var gatilhos: [GatilhoAnalise]
    var insight: String
    var frequencia: Int
    var duracaoMedia: Int?
}

func analisar(_ crises: [Crise]) -> Analise {
    let n = crises.count
    var gatilhos = DEFS.map { def -> GatilhoAnalise in
        let count = crises.filter { presente(def.chave, $0) }.count
        let pct = n == 0 ? 0 : Int((100.0 * Double(count) / Double(n)).rounded())
        return GatilhoAnalise(label: def.label, pct: pct, recorrentes: recorrentes(crises, def.chave))
    }
    gatilhos.sort { $0.pct > $1.pct }  // sort estável — empate mantém a ordem de DEFS

    let insight: String
    if let top = gatilhos.first, top.pct > 0 {
        insight =
            "\(top.pct)% das crises ocorreram com \"\(top.label)\" presente — o gatilho mais frequente do período."
    } else {
        insight = "Ainda sem um gatilho dominante — continue registrando."
    }

    // ponytail: frequência assume janela fixa de ~90 dias, igual ao iOS. Trocar por
    // bucket real de mês quando existir filtro de período (hoje "período" = tudo).
    let frequencia = max(1, Int((Double(n) / 3).rounded()))

    let duracoes = crises.compactMap(duracaoMin)
    let duracaoMedia =
        duracoes.isEmpty
        ? nil
        : Int((Double(duracoes.reduce(0, +)) / Double(duracoes.count)).rounded())

    return Analise(gatilhos: gatilhos, insight: insight, frequencia: frequencia, duracaoMedia: duracaoMedia)
}

// MARK: - Snapshot do link público

/// O que vai no link público é uma cópia congelada, não um espelho: o médico vê daqui a
/// 20 dias o mesmo relatório que você mandou, e crise nova não vaza para um link já enviado.
/// Sem ids e sem data_nascimento — só o que o relatório desenha. Espelha snapshotRelatorio
/// em report.js.
nonisolated struct SnapshotRelatorio: Encodable, Equatable {
    var versao: Int
    var geradoEm: Date
    var paciente: SnapshotPaciente
    var crises: [SnapshotCrise]

    enum CodingKeys: String, CodingKey {
        case versao
        case geradoEm = "gerado_em"
        case paciente, crises
    }
}

nonisolated struct SnapshotPaciente: Encodable, Equatable {
    var nome: String
    var idade: Int?
}

nonisolated struct SnapshotCrise: Encodable, Equatable {
    var inicio: Date
    var fim: Date?
    var intensidade: String
    var localizacao: String
    var carater: String
    var sintomas: [String]
    var sonoHoras: Double
    var gatilhos: [String]
    var detalhes: [String: [String]]
    var medicacao: String
    var alivio: String?

    enum CodingKeys: String, CodingKey {
        case inicio, fim, intensidade, localizacao, carater, sintomas
        case sonoHoras = "sono_horas"
        case gatilhos, detalhes, medicacao, alivio
    }
}

func snapshotRelatorio(
    _ encerradas: [Crise], paciente: Paciente, hoje: Date = Date()
) -> SnapshotRelatorio {
    SnapshotRelatorio(
        versao: 1,
        geradoEm: hoje,
        paciente: SnapshotPaciente(nome: paciente.nome, idade: idade(paciente.dataNascimento, hoje: hoje)),
        crises: encerradas.map {
            SnapshotCrise(
                inicio: $0.inicio, fim: $0.fim,
                intensidade: $0.intensidade, localizacao: $0.localizacao, carater: $0.carater,
                sintomas: $0.sintomas, sonoHoras: $0.sonoHoras,
                gatilhos: $0.gatilhos, detalhes: $0.detalhes,
                medicacao: $0.medicacao, alivio: $0.alivio)
        })
}

/// Texto compartilhado com o médico.
func textoRelatorio(_ crises: [Crise], paciente: Paciente? = nil) -> String {
    let a = analisar(crises)
    var linhas = ["Diário da Cefaléia — Relatório para o médico"]

    if let paciente {
        let anos = idade(paciente.dataNascimento)
        linhas.append("Paciente: \(paciente.nome)\(anos.map { " (\($0) anos)" } ?? "")")
    }

    linhas.append("")
    linhas.append("INSIGHT: \(a.insight)")
    linhas.append("")
    linhas.append("GATILHOS:")
    for g in a.gatilhos {
        linhas.append("  \(g.label): \(g.pct)%")
        linhas.append(contentsOf: g.recorrentes.map { "    recorrente: \($0.item) (\($0.n) de \($0.de))" })
    }

    linhas.append("")
    linhas.append("ESTATÍSTICAS:")
    linhas.append("  Frequência: \(a.frequencia)/mês")
    linhas.append("  Duração média: \(a.duracaoMedia.map(fmtDuracao) ?? "—")")

    linhas.append("")
    linhas.append("DIAS POR MÊS:")
    linhas.append(
        contentsOf: porMes(crises).map { "  \($0.mes): \($0.com) com crise, \($0.sem) sem (de \($0.total))" })

    linhas.append("")
    linhas.append("CRISES (\(crises.count)):")
    for c in crises {
        let dur = duracaoMin(c).map(fmtDuracao) ?? "em andamento"
        linhas.append("  \(fmtDataHist(c.inicio)) \(fmtHora(c.inicio)) — \(c.intensidade), \(dur)")
        if !c.medicacao.isEmpty {
            let alivio = c.alivio.map { " · alívio \($0.lowercased())" } ?? ""
            linhas.append("    ℞ \(c.medicacao)\(alivio)")
        }
    }

    return linhas.joined(separator: "\n")
}
