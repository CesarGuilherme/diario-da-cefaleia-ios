//
//  RelatorioView.swift
//  Diario da Cefaleia
//
//  Espelha screens/Relatorio.jsx. Swift Charts troca a barra empilhada em CSS;
//  o card de compartilhar gera link público em `relatorios` e abre o share sheet.
//

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
    // Pré-filtrado junto com `dias` (fora do body): o `if d.n > 0` por marca é o
    // que impedia o caminho vetorizado do Charts (WWDC24 10155).
    let diasComCrise: [DiaInfo]
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
                Chart {
                    LinePlot(dias, x: .value("Dia", \.dia), y: .value("Crises", \.n))
                        .foregroundStyle(Color(hex: 0xff6961))
                        .interpolationMethod(.linear)
                    PointPlot(diasComCrise, x: .value("Dia", \.dia), y: .value("Crises", \.n))
                        .foregroundStyle(Color(hex: 0xff453a))
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

/// Compartilhar com o médico: card com link público. Espelha `Compartilhar` em
/// Relatorio.jsx — botão grande gera/envia a URL; texto e copiar/revogar são secundários.
struct CompartilharView: View {
    let encerradas: [Crise]
    let paciente: Paciente

    @State private var link: RelatorioPublico?
    @State private var ocupado = true
    @State private var aviso: String?
    @State private var confirmarRevogar = false

    private var url: URL? { link.flatMap { urlRelatorioPublico($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compartilhar com o médico").font(.system(size: 16, weight: .bold))
            Text("Uma página só de leitura com este relatório, que abre sem conta nenhuma. Quem tiver o endereço vê o relatório — ele não é indexado, mas também não pede senha.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.5))
                .padding(.top, 2)
                .padding(.bottom, 14)

            if let url, let link {
                Text(url.absoluteString)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.85))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .glassEffect(in: .rect(cornerRadius: 14))
                Text("Expira em \(fmtDataHist(link.expiraEm)) · congelado como o relatório está hoje")
                    .font(.system(size: 12))
                    .foregroundStyle(textoFraco2)
                    .padding(.top, 8)
            }

            Group {
                if let url {
                    ShareLink(item: url) {
                        botaoEnviarLabel(titulo: "Enviar link ao médico")
                    }
                } else {
                    Button {
                        Task { await gerar() }
                    } label: {
                        botaoEnviarLabel(titulo: "Gerar link e enviar")
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .capsule)
            .disabled(ocupado)
            .opacity(ocupado ? 0.5 : 1)
            .padding(.top, 14)

            FlowLayout(spacing: 4) {
                if url != nil {
                    SecundariaLink("copiar", desabilitado: ocupado) { copiar() }
                    SecundariaLink("gerar novo", desabilitado: ocupado) {
                        Task { await gerar() }
                    }
                    SecundariaLink("revogar", desabilitado: ocupado, perigo: true) {
                        confirmarRevogar = true
                    }
                }
                SecundariaLink("copiar como texto", desabilitado: ocupado) { copiarTexto() }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            if let aviso {
                Text(aviso)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.6))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
        .cartao(padding: 18)
        .task(id: paciente.id) { await carregar() }
        .confirmationDialog(
            "Revogar o link? Quem já recebeu deixa de conseguir abrir.",
            isPresented: $confirmarRevogar, titleVisibility: .visible
        ) {
            Button("Revogar", role: .destructive) { Task { await revogar() } }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func botaoEnviarLabel(titulo: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
            Text(titulo)
        }
        .font(.system(size: 16, weight: .bold))
        .frame(maxWidth: .infinity)
        .frame(height: 54)
    }

    private func carregar() async {
        ocupado = true
        aviso = nil
        do {
            let rows: [RelatorioPublico] = try await supabase.from("relatorios")
                .select("id, paciente_id, criado_em, expira_em")
                .eq("paciente_id", value: paciente.id)
                .order("criado_em", ascending: false)
                .limit(1)
                .execute().value
            link = rows.first.flatMap { $0.expiraEm < Date() ? nil : $0 }
        } catch {
            link = nil
            aviso = mensagemErro(error, senao: "Não foi possível carregar o link. Tente de novo.")
        }
        ocupado = false
    }

    @discardableResult
    private func gerar() async -> URL? {
        guard publicReportBaseURL != nil else {
            aviso = "Falta PUBLIC_REPORT_BASE_URL no Info.plist."
            return nil
        }
        ocupado = true
        aviso = nil
        defer { ocupado = false }
        do {
            let criado: RelatorioPublico = try await supabase.from("relatorios")
                .insert(RelatorioInput(
                    pacienteId: paciente.id,
                    dados: snapshotRelatorio(encerradas, paciente: paciente)))
                .select("id, paciente_id, criado_em, expira_em")
                .single()
                .execute().value
            // Insere antes de apagar: se a limpeza falhar sobra um link a mais, nunca nenhum.
            _ = try? await supabase.from("relatorios")
                .delete()
                .eq("paciente_id", value: paciente.id)
                .neq("id", value: criado.id)
                .execute()
            link = criado
            return urlRelatorioPublico(criado.id)
        } catch {
            aviso = mensagemErro(error, senao: "Não foi possível gerar o link. Tente de novo.")
            return nil
        }
    }

    private func copiar() {
        guard let url else { return }
        copiarParaAreaDeTransferencia(url.absoluteString)
        aviso = "Link copiado."
    }

    private func copiarTexto() {
        copiarParaAreaDeTransferencia(textoRelatorio(encerradas, paciente: paciente))
        aviso = "Relatório copiado como texto."
    }

    private func revogar() async {
        guard let link else { return }
        ocupado = true
        do {
            try await supabase.from("relatorios").delete().eq("id", value: link.id).execute()
            self.link = nil
            aviso = nil
        } catch {
            aviso = mensagemErro(error, senao: "Não foi possível revogar o link. Tente de novo.")
        }
        ocupado = false
    }
}

private struct SecundariaLink: View {
    let titulo: String
    var desabilitado = false
    var perigo = false
    let acao: () -> Void

    init(_ titulo: String, desabilitado: Bool = false, perigo: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.desabilitado = desabilitado
        self.perigo = perigo
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            Text(titulo)
                .font(.system(size: 13))
                .underline(color: perigo ? Color(hex: 0xff9f9a, opacity: 0.85) : textoFraco)
                .foregroundStyle(perigo ? Color(hex: 0xff9f9a, opacity: 0.85) : textoFraco)
        }
        .buttonStyle(.plain)
        .disabled(desabilitado)
        .opacity(desabilitado ? 0.5 : 1)
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
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
    // Painel do Mac (Painel.tsx no web): gatilhos à esquerda, estatísticas empilhadas
    // com o gráfico à direita. No telefone tudo fica numa coluna só, nesta ordem.
    var desktop = false

    // analisar + porDia varrem o histórico inteiro (porDia aloca um DiaInfo por dia
    // desde a primeira crise) — rodavam a cada avaliação deste body, no MainActor.
    // Agora rodam uma vez por mudança de dados, fora da main thread (WWDC26 268).
    @State private var analise: Analise?
    @State private var dias: [DiaInfo] = []
    @State private var diasComCrise: [DiaInfo] = []

    var body: some View {
        // `diario.encerradas` refiltra `crises` a cada leitura — uma ligação local
        // evita repetir isso quatro vezes neste body.
        let encerradas = diario.encerradas

        VStack(alignment: .leading, spacing: 14) {
            CabecalhoRelatorioView(n: encerradas.count, carregando: diario.carregandoCrises)

            if !diario.carregandoCrises && encerradas.count < MIN_CRISES_RELATORIO {
                SemDadosView()
            }

            if encerradas.count >= MIN_CRISES_RELATORIO, let a = analise {
                InsightView(insight: a.insight)
                if desktop {
                    HStack(alignment: .top, spacing: 14) {
                        GatilhosView(gatilhos: a.gatilhos)
                        VStack(spacing: 14) {
                            EstatisticasView(frequencia: a.frequencia, duracaoMedia: a.duracaoMedia)
                            CrisesPorDiaView(dias: dias, diasComCrise: diasComCrise)
                        }
                    }
                } else {
                    GatilhosView(gatilhos: a.gatilhos)
                    CrisesPorDiaView(dias: dias, diasComCrise: diasComCrise)
                    EstatisticasView(frequencia: a.frequencia, duracaoMedia: a.duracaoMedia)
                }
                CompartilharView(encerradas: encerradas, paciente: paciente)
            }
        }
        .task(id: encerradas) {
            guard encerradas.count >= MIN_CRISES_RELATORIO else { return }
            (analise, dias, diasComCrise) = await Task { @concurrent in
                let d = porDia(encerradas)
                return (analisar(encerradas), d, d.filter { $0.n > 0 })
            }.value
        }
    }
}
