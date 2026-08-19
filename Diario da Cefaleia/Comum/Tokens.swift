//
//  Tokens.swift
//  Diario da Cefaleia
//
//  Tokens de design (cores/gradientes copiados verbatim de src/tokens.js) e a
//  conversão form <-> banco (src/tokens.js:63-84). Os dois ficam juntos pelo mesmo
//  motivo de lá: para não divergirem.
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Vocabulários

let INTENSIDADES = ["Leve", "Moderada", "Intensa"]
let LOCALIZACOES = ["Esq.", "Dir.", "Bilateral"]
let CARATERES = ["Pulsátil", "Pressão"]
let ALIVIOS = ["Não", "Parcial", "Total"]
let SINTOMAS = ["Náusea", "Vômito", "Fotofobia", "Fonofobia", "Aura"]

/// (rótulo exibido, valor gravado, placeholder do detalhe).
/// O banco guarda só a chave curta; o placeholder ensina a separar por vírgula, que é
/// o que torna os itens comparáveis entre crises sem nenhuma heurística de linguagem.
let GATILHOS: [(label: String, valor: String, dica: String)] = [
    ("Estresse", "Estresse", "Ex.: prova, briga, apresentação"),
    ("Alimentação", "Alimentação", "Ex.: leite, chocolate, queijo"),
    ("Mudança climática", "Mudança climática", "Ex.: calor forte, chuva, frente fria"),
]

// MARK: - Cores por intensidade (Segmented de Intensidade + dot/chip do Histórico)

struct PaletaIntensidade {
    var dot: Color
    var glow: Color
    var chipFg: Color
    var chipBg: Color
}

let INT: [String: PaletaIntensidade] = [
    "Leve": PaletaIntensidade(
        dot: Color(hex: 0x30d158), glow: Color(hex: 0x30d158, opacity: 0.6),
        chipFg: Color(hex: 0xa9f0cd), chipBg: Color(hex: 0x30d158, opacity: 0.15)),
    "Moderada": PaletaIntensidade(
        dot: Color(hex: 0xff9f0a), glow: Color(hex: 0xff9f0a, opacity: 0.6),
        chipFg: Color(hex: 0xffd9a3), chipBg: Color(hex: 0xff9f0a, opacity: 0.16)),
    "Intensa": PaletaIntensidade(
        dot: Color(hex: 0xff453a), glow: Color(hex: 0xff453a, opacity: 0.7),
        chipFg: Color(hex: 0xffb5b0), chipBg: Color(hex: 0xff453a, opacity: 0.16)),
]

// Usado pelo Segmented de Intensidade (form e crise em andamento) — evita
// recriar o dicionário a cada avaliação do body.
let INT_DOTS = INT.mapValues(\.dot)
let INT_PADRAO = INT["Moderada"]!  // fallback igual ao `INT[c.intensidade] ?? INT['Moderada']` da web

// MARK: - Chip de gatilho no card do Histórico

struct PaletaChip {
    var fg: Color
    var bg: Color
    var bd: Color
}

let GATCHIP: [String: PaletaChip] = [
    "Estresse": PaletaChip(fg: Color(hex: 0xa9f0cd), bg: Color(hex: 0x30d158, opacity: 0.15), bd: Color(hex: 0x30d158, opacity: 0.3)),
    "Mudança climática": PaletaChip(fg: Color(hex: 0xb8e4fd), bg: Color(hex: 0x38bdf8, opacity: 0.15), bd: Color(hex: 0x38bdf8, opacity: 0.3)),
    "Alimentação": PaletaChip(fg: Color(hex: 0xffd9a3), bg: Color(hex: 0xff9f0a, opacity: 0.16), bd: Color(hex: 0xff9f0a, opacity: 0.3)),
]
let GATCHIP_PADRAO = GATCHIP["Estresse"]!

// MARK: - Paleta do alívio (tela de crise em andamento)

/// Cor sólida por opção — vira o tint do `.buttonStyle(.glass(...))` no `Segmented`
/// selecionado; o próprio material Liquid Glass resolve contraste e vibrância.
let ALIVIO_PAL: [String: Color] = [
    "Não": Color(hex: 0xff453a),
    "Parcial": Color(hex: 0x30d158),
    "Total": Color(hex: 0x30d158),
]

// MARK: - Cores das barras de gatilho no Relatório (report.js DEFS)

struct PaletaGatilhoBarra {
    var grad: LinearGradient
    var valColor: Color
}

let GATILHO_CORES: [String: PaletaGatilhoBarra] = [
    "Sono < 7h": PaletaGatilhoBarra(
        grad: LinearGradient(colors: [Color(hex: 0x6c5ce7), Color(hex: 0x8b7cfc)], startPoint: .leading, endPoint: .trailing),
        valColor: Color(hex: 0x8b7cfc)),
    "Estresse": PaletaGatilhoBarra(
        grad: LinearGradient(colors: [Color(hex: 0x3f9bfd), Color(hex: 0x5ec8f8)], startPoint: .leading, endPoint: .trailing),
        valColor: Color(hex: 0xebebf5, opacity: 0.8)),
    "Mudança climática": PaletaGatilhoBarra(
        grad: LinearGradient(colors: [Color(hex: 0x2fb8a6), Color(hex: 0x5ee6c8)], startPoint: .leading, endPoint: .trailing),
        valColor: Color(hex: 0xebebf5, opacity: 0.8)),
    "Alimentação": PaletaGatilhoBarra(
        grad: LinearGradient(colors: [Color(hex: 0x8e8e93), Color(hex: 0xaeaeb2)], startPoint: .leading, endPoint: .trailing),
        valColor: Color(hex: 0xebebf5, opacity: 0.8)),
]

// MARK: - Formulário <-> banco

/// Campos de uma crise no formulário. `detalhes` aqui é texto cru por gatilho — a
/// UI edita texto livre; a conversão pra lista de itens só acontece na saída (paraBanco).
struct CriseForm: Equatable {
    var intensidade = "Moderada"
    var localizacao = "Bilateral"
    var carater = "Pulsátil"
    var sintomas: [String] = []
    var sonoHoras = 8.0
    var gatilhos: [String] = []
    var detalhes: [String: String] = [:]
    var medicacao = ""
}

let FORM_PADRAO = CriseForm()

/// "alho, frango,, batata " -> ["alho","frango","batata"]
func itensDe(_ texto: String?) -> [String] {
    (texto ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}

/// Detalhe de gatilho desligado é descartado.
private func detalhesBanco(_ form: CriseForm) -> [String: [String]] {
    var detalhes: [String: [String]] = [:]
    for g in form.gatilhos {
        let itens = itensDe(form.detalhes[g])
        if !itens.isEmpty { detalhes[g] = itens }
    }
    return detalhes
}

/// Campos do form -> insert de uma crise nova.
func paraNovaCriseInput(_ form: CriseForm, pacienteId: UUID) -> NovaCriseInput {
    NovaCriseInput(
        pacienteId: pacienteId, inicio: Date(),
        intensidade: form.intensidade, localizacao: form.localizacao, carater: form.carater,
        sintomas: form.sintomas, sonoHoras: form.sonoHoras, gatilhos: form.gatilhos,
        detalhes: detalhesBanco(form), medicacao: form.medicacao)
}

/// Campos do form -> patch de update (edição de uma crise já existente).
func paraCrisePatch(_ form: CriseForm) -> CrisePatch {
    CrisePatch(
        intensidade: form.intensidade, localizacao: form.localizacao, carater: form.carater,
        sintomas: form.sintomas, sonoHoras: form.sonoHoras, gatilhos: form.gatilhos,
        detalhes: detalhesBanco(form), medicacao: form.medicacao)
}

/// Crise do banco -> campos do form (só os editáveis; inicio/fim/alívio ficam de fora).
func paraForm(_ c: Crise) -> CriseForm {
    var detalhes: [String: String] = [:]
    for (g, itens) in c.detalhes { detalhes[g] = itens.joined(separator: ", ") }
    return CriseForm(
        intensidade: c.intensidade, localizacao: c.localizacao, carater: c.carater,
        sintomas: c.sintomas, sonoHoras: c.sonoHoras, gatilhos: c.gatilhos,
        detalhes: detalhes, medicacao: c.medicacao)
}
