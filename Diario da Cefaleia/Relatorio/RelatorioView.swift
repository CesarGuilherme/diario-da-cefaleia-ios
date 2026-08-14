//
//  RelatorioView.swift
//  Diario da Cefaleia
//
//  Espelha screens/Relatorio.jsx. Swift Charts troca a barra empilhada em CSS;
//  ShareLink troca navigator.share + fallback de clipboard inteiro.
//

import Auth
import Charts
import Supabase
import SwiftUI

/// Crises encerradas necessárias para o relatório dizer algo — regra única, mesma da web.
let MIN_CRISES_RELATORIO = 2

private struct Stat: View {
    let rotulo: String
    let valor: String
    var sufixo: String?
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rotulo).font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.55))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(valor).font(.system(size: 26, weight: .bold))
                if let sufixo {
                    Text(sufixo).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.55))
                }
            }
            Text(sub).font(.system(size: 12)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao(cornerRadius: 24)
    }
}

struct InsightView: View {
    let insight: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✦ Insight")
                .font(.system(size: 12, weight: .bold)).tracking(0.8)
                .foregroundStyle(Color(hex: 0xb9affe))
            Text(insight).font(.system(size: 18, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x8b7cfc, opacity: 0.32), Color(hex: 0x6c5ce7, opacity: 0.16)],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
        )
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.white.opacity(0.18)))
    }
}

struct GatilhosView: View {
    let gatilhos: [GatilhoAnalise]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Possíveis gatilhos").font(.system(size: 16, weight: .bold))
                Text("% das crises em que o fator estava presente")
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.5))
            }
            VStack(spacing: 13) {
                ForEach(gatilhos) { g in linha(g) }
            }
        }
        .cartao()
    }

    private func linha(_ g: GatilhoAnalise) -> some View {
        let cor = GATILHO_CORES[g.label]
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(g.label).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(g.pct)%").font(.system(size: 14, weight: .bold)).foregroundStyle(cor?.valColor ?? .white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0x787880, opacity: 0.22))
                    Capsule()
                        .fill(cor?.grad ?? LinearGradient(colors: [.white], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(g.pct) / 100)
                }
            }
            .frame(height: 10)

            if !g.recorrentes.isEmpty {
                FlowLayout(spacing: 6) {
                    Text("se repete:").font(.system(size: 11)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
                    ForEach(g.recorrentes) { r in
                        HStack(spacing: 3) {
                            Text(r.item).font(.system(size: 12, weight: .semibold))
                            Text("\(r.n) de \(r.de)").font(.system(size: 12)).opacity(0.7)
                        }
                        .foregroundStyle(Color(hex: 0xc9c2fd))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Color(hex: 0x7c6cf6, opacity: 0.18), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color(hex: 0x7c6cf6, opacity: 0.35)))
                    }
                }
            }
        }
    }
}

struct EstatisticasView: View {
    let frequencia: Int
    let duracaoMedia: Int?

    var body: some View {
        HStack(spacing: 12) {
            Stat(rotulo: "Frequência", valor: "\(frequencia)", sufixo: "/mês", sub: "média do período")
            Stat(rotulo: "Duração média", valor: duracaoMedia.map(fmtDuracao) ?? "—", sufixo: nil, sub: "por crise")
        }
    }
}

struct CrisesPorDiaView: View {
    // Calculado uma vez pelo chamador — antes era recalculado a cada frame de
    // arraste no gráfico, porque `porDia` rodava dentro deste `body`.
    let dias: [DiaInfo]
    @State private var selecionado: Date?

    var body: some View {
        if !dias.isEmpty {
            let maxN = max(1, dias.map(\.n).max() ?? 1)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crises por dia").font(.system(size: 16, weight: .bold))
                    Text(legenda(dias))
                        .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.5))
                }
                Chart(dias) { d in
                    LineMark(
                        x: .value("Dia", d.dia, unit: .day),
                        y: .value("Crises", d.n)
                    )
                    .foregroundStyle(Color(hex: 0xff6961))
                    .interpolationMethod(.linear)
                    if d.n > 0 {
                        PointMark(
                            x: .value("Dia", d.dia, unit: .day),
                            y: .value("Crises", d.n)
                        )
                        .foregroundStyle(Color(hex: 0xff453a))
                    }
                }
                .chartYScale(domain: 0...maxN)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3))
                }
                .chartXSelection(value: $selecionado)
                .chartScrollableAxes(dias.count > 45 ? .horizontal : [])
                .chartXVisibleDomain(length: dias.count > 45 ? 45 * 24 * 3600 : TimeInterval(dias.count) * 24 * 3600)
                .frame(height: 160)
            }
            .cartao()
        }
    }

    private func legenda(_ dias: [DiaInfo]) -> String {
        guard let sel = selecionado else { return "Toque num ponto para ver o dia" }
        let n = dias.first { calendarioBR.isDate($0.dia, inSameDayAs: sel) }?.n ?? 0
        return "\(fmtDataHist(sel)) · \(n) \(n == 1 ? "crise" : "crises")"
    }
}

/// Botão + aviso: o estado do compartilhamento pertence ao botão, não à tela.
/// `ShareLink` troca `navigator.share` + fallback de clipboard + tratamento de erro.
struct CompartilharView: View {
    let encerradas: [Crise]
    let paciente: Paciente?

    var body: some View {
        ShareLink(item: textoRelatorio(encerradas, paciente: paciente)) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Compartilhar com o médico")
            }
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

struct CabecalhoRelatorioView: View {
    let n: Int
    let carregando: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SubEyebrow(texto: carregando ? "carregando…" : "\(n) \(n == 1 ? "crise" : "crises") no período")
            Titulo(texto: "Relatório")
        }
    }
}

struct SemDadosView: View {
    var body: some View {
        CardVazio(
            titulo: "Dados insuficientes",
            sub: "Registre ao menos \(MIN_CRISES_RELATORIO) crises para ver correlações.")
    }
}

struct RelatorioView: View {
    let diario: Diario
    let paciente: Paciente

    var body: some View {
        // `diario.encerradas` refiltra `crises` a cada leitura — uma ligação local
        // evita repetir isso quatro vezes neste body.
        let encerradas = diario.encerradas

        VStack(alignment: .leading, spacing: 14) {
            CabecalhoRelatorioView(n: encerradas.count, carregando: diario.carregandoCrises)

            if !diario.carregandoCrises && encerradas.count < MIN_CRISES_RELATORIO {
                SemDadosView()
            }

            if encerradas.count >= MIN_CRISES_RELATORIO {
                let a = analisar(encerradas)
                InsightView(insight: a.insight)
                GatilhosView(gatilhos: a.gatilhos)
                CrisesPorDiaView(dias: porDia(encerradas))
                EstatisticasView(frequencia: a.frequencia, duracaoMedia: a.duracaoMedia)
                CompartilharView(encerradas: encerradas, paciente: paciente)
            }

            Button("Sair da conta") { Task { try? await supabase.auth.signOut() } }
                .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
                .padding(.top, 8)
        }
    }
}
