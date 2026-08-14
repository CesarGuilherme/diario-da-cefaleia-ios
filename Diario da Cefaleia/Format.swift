//
//  Format.swift
//  Diario da Cefaleia
//
//  Formatação pt-BR. Espelha src/format.js do app web, byte a byte onde há teste —
//  por isso os nomes de dia/mês são tabelas fixas, não símbolos do sistema: garantem
//  a mesma string em qualquer versão do iOS, sem depender de como o ICU capitaliza.
//

import Foundation

private let diasAbrev = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
private let mesesAbrev = [
    "jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez",
]
private let mesesCompletos = [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
]

private let calendarioBR: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: "pt_BR")
    return cal
}()

// Calendar.component(.weekday) retorna 1=domingo…7=sábado — mesmo índice dos arrays acima.
private func diaSemana(_ d: Date) -> String { diasAbrev[calendarioBR.component(.weekday, from: d) - 1] }
private func mesAbrev(_ d: Date) -> String { mesesAbrev[calendarioBR.component(.month, from: d) - 1] }
private func mesCompleto(_ d: Date) -> String { mesesCompletos[calendarioBR.component(.month, from: d) - 1] }

/// "ter, 5 de agosto"
func fmtEyebrow(_ d: Date) -> String {
    "\(diaSemana(d)), \(calendarioBR.component(.day, from: d)) de \(mesCompleto(d))"
}

/// "ter, 5 ago"
func fmtDataHist(_ d: Date) -> String {
    "\(diaSemana(d)), \(calendarioBR.component(.day, from: d)) \(mesAbrev(d))"
}

/// "18:21"
func fmtHora(_ d: Date) -> String {
    String(
        format: "%02d:%02d",
        calendarioBR.component(.hour, from: d), calendarioBR.component(.minute, from: d))
}

/// 45 -> "45 min" | 164 -> "2h44" | 120 -> "2h"
func fmtDuracao(_ min: Int) -> String {
    if min < 60 { return "\(min) min" }
    let h = min / 60, mm = min % 60
    return mm == 0 ? "\(h)h" : "\(h)h\(String(format: "%02d", mm))"
}

/// 6.5 -> "6h30" | 8 -> "8h"
func fmtSono(_ v: Double) -> String {
    let h = Int(v.rounded(.down))
    return v.truncatingRemainder(dividingBy: 1) != 0 ? "\(h)h30" : "\(h)h"
}

/// Cronômetro: "12:34" abaixo de 1h, "2:05" (h:mm) depois.
func fmtDecorrido(_ ms: Double) -> String {
    let s = Int(max(0, ms) / 1000)
    if s >= 3600 { return "\(s / 3600):\(String(format: "%02d", (s % 3600) / 60))" }
    return "\(s / 60):\(String(format: "%02d", s % 60))"
}

/// "ago/25" — mês + ano, porque o gráfico mensal atravessa a virada do ano.
func fmtMes(_ d: Date) -> String {
    "\(mesAbrev(d))/\(String(format: "%02d", calendarioBR.component(.year, from: d) % 100))"
}

/// data_nascimento ('2014-03-22') -> 11
func idade(_ iso: String?, hoje: Date = Date()) -> Int? {
    guard let iso else { return nil }
    let partes = iso.split(separator: "-").compactMap { Int($0) }
    guard partes.count == 3 else { return nil }
    let (ano, mes, dia) = (partes[0], partes[1], partes[2])

    let h = calendarioBR.dateComponents([.year, .month, .day], from: hoje)
    guard let hAno = h.year, let hMes = h.month, let hDia = h.day else { return nil }

    var anos = hAno - ano
    if hMes < mes || (hMes == mes && hDia < dia) { anos -= 1 }
    return anos
}

func duracaoMin(_ crise: Crise) -> Int? {
    guard let fim = crise.fim else { return nil }
    return max(1, Int((fim.timeIntervalSince(crise.inicio) / 60).rounded()))
}
