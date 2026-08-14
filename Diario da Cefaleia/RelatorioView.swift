//
//  RelatorioView.swift
//  Diario da Cefaleia
//
//  Espelha screens/Relatorio.jsx. Swift Charts troca a barra empilhada em CSS;
//  ShareLink troca navigator.share + fallback de clipboard inteiro.
//

import Charts
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

struct DiasPorMesView: View {
    let crises: [Crise]

    var body: some View {
        let meses = porMes(crises)
        if !meses.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dias por mês").font(.system(size: 16, weight: .bold))
                    HStack(spacing: 4) {
                        Text("■").foregroundStyle(Color(hex: 0xff9f9a))
                        Text("com crise")
                        Text("·")
                        Text("■").foregroundStyle(Color(hex: 0xebebf5, opacity: 0.35))
                        Text("sem crise")
                    }
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.5))
                }
                Chart(meses) { m in
                    BarMark(x: .value("Mês", m.mes), y: .value("Com crise", m.com))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xff6961), Color(hex: 0xff453a)],
                                startPoint: .top, endPoint: .bottom)
                        )
                        .annotation(position: .top) {
                            Text("\(m.com)").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: 0xff9f9a))
                        }
                }
                .chartYScale(domain: 0...(meses.map(\.total).max() ?? 1))
                .chartYAxis(.hidden)
                .frame(height: 140)
            }
            .cartao()
        }
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
        .background(Color.white.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18)))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CabecalhoRelatorioView(n: diario.encerradas.count, carregando: diario.carregandoCrises)

                if !diario.carregandoCrises && diario.encerradas.count < MIN_CRISES_RELATORIO {
                    SemDadosView()
                }

                if diario.encerradas.count >= MIN_CRISES_RELATORIO {
                    let a = analisar(diario.encerradas)
                    InsightView(insight: a.insight)
                    GatilhosView(gatilhos: a.gatilhos)
                    DiasPorMesView(crises: diario.encerradas)
                    EstatisticasView(frequencia: a.frequencia, duracaoMedia: a.duracaoMedia)
                    CompartilharView(encerradas: diario.encerradas, paciente: paciente)
                }

                Button("Sair da conta") { Task { try? await supabase.auth.signOut() } }
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
                    .padding(.top, 8)
            }
            .padding(.bottom, 8)
        }
    }
}
