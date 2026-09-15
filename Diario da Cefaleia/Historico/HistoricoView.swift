//
//  HistoricoView.swift
//  Diario da Cefaleia
//
//  Espelha screens/Historico.jsx. Diverge da web de propósito: apagar é swipe +
//  confirmationDialog (na web é botão ✕ + confirm(), porque browser não tem swipe).
//

import SwiftUI

private struct ChipInfo {
    let label: String
    let fg: Color
    let bg: Color
}

private let neutroChipFg = Color(hex: 0xebebf5, opacity: 0.75)
private let neutroChipBg = Color(hex: 0x787880, opacity: 0.2)

/// Ordem dos chips copiada do protótipo — é o que dá a leitura rápida do card.
/// Cada gatilho vem seguido do seu detalhe: "Alimentação → leite · pão".
private func chipsDe(_ c: Crise) -> [ChipInfo] {
    let m = INT[c.intensidade] ?? INT_PADRAO
    var chips = [
        ChipInfo(label: c.intensidade, fg: m.chipFg, bg: m.chipBg),
        ChipInfo(label: "\(c.localizacao) · \(c.carater)", fg: neutroChipFg, bg: neutroChipBg),
    ]
    chips += c.sintomas.map { ChipInfo(label: $0, fg: neutroChipFg, bg: neutroChipBg) }

    if c.sonoHoras < 7 {
        chips.append(
            ChipInfo(
                label: "Sono \(fmtSono(c.sonoHoras))",
                fg: Color(hex: 0xc9c2fd), bg: Color(hex: 0x7c6cf6, opacity: 0.18)))
    }

    for g in c.gatilhos {
        let p = GATCHIP[g] ?? GATCHIP_PADRAO
        chips.append(ChipInfo(label: g, fg: p.fg, bg: p.bg))
        if let itens = c.detalhes[g], !itens.isEmpty {
            chips.append(
                ChipInfo(
                    label: "“\(itens.joined(separator: " · "))”",
                    fg: Color(hex: 0xebebf5, opacity: 0.6), bg: Color(hex: 0x787880, opacity: 0.14)))
        }
    }
    return chips
}

private struct CriseCard: View, Equatable {
    let c: Crise
    let apagar: () -> Void
    let editar: () -> Void

    // As closures impedem a síntese do ==; só a crise decide se o card mudou —
    // editar/apagar uma crise deixa de reavaliar o body das outras N-1.
    static func == (l: Self, r: Self) -> Bool { l.c == r.c }

    var body: some View {
        // Uma passada só por avaliação do body; `indices` como id evita o Array +
        // enumerated por render (chips são estáveis enquanto a crise não muda).
        let chips = chipsDe(c)
        VStack(alignment: .leading, spacing: 9) {
            cabecalho
            FlowLayout(spacing: 6) {
                ForEach(chips.indices, id: \.self) { i in
                    let ch = chips[i]
                    Text(ch.label)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .foregroundStyle(ch.fg)
                        .background(ch.bg, in: Capsule())
                }
            }
            Text(
                c.medicacao.isEmpty
                    ? "Sem medicação"
                    : "℞ \(c.medicacao)\(c.alivio.map { " · alívio \($0.lowercased())" } ?? "")"
            )
            .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.5))
        }
        .cartao(cornerRadius: 24, padding: 16)
        .swipeActions(edge: .trailing) {
            Button(action: editar) { Label("Editar", systemImage: "pencil") }.tint(.blue)
            Button(role: .destructive, action: apagar) {
                Label("Apagar", systemImage: "trash")
            }
        }
    }

    private var cabecalho: some View {
        let m = INT[c.intensidade] ?? INT_PADRAO
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) {
                Circle().fill(m.dot).frame(width: 11, height: 11).shadow(color: m.glow, radius: 5)
                Text(fmtDataHist(c.inicio)).font(.system(size: 16, weight: .bold)).lineLimit(1)
                Spacer(minLength: 8)
                horario
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 9) {
                    Circle().fill(m.dot).frame(width: 11, height: 11).shadow(color: m.glow, radius: 5)
                    Text(fmtDataHist(c.inicio)).font(.system(size: 16, weight: .bold)).lineLimit(1)
                }
                horario
            }
        }
    }

    @ViewBuilder
    private var horario: some View {
        if let fim = c.fim, let dur = duracaoMin(c) {
            Text("\(fmtHora(c.inicio)) – \(fmtHora(fim)) · \(fmtDuracao(dur))")
                .font(.system(size: 13.5))
                .foregroundStyle(Color(hex: 0xebebf5, opacity: 0.55))
                .lineLimit(1)
        } else {
            Text("Em andamento")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0xff6961))
                .lineLimit(1)
        }
    }
}

/// Editar depois do fato: o sintoma que só foi notado no dia seguinte, o alívio que
/// veio horas depois. Mesmo formulário do registro — `inicio`/`fim` não são editáveis.
private struct EditarCriseView: View {
    let diario: Diario
    let crise: Crise
    let fechar: () -> Void

    @State private var form: CriseForm
    @State private var alivio: String?
    @State private var ocupado = false

    init(diario: Diario, crise: Crise, fechar: @escaping () -> Void) {
        self.diario = diario
        self.crise = crise
        self.fechar = fechar
        _form = State(initialValue: paraForm(crise))
        _alivio = State(initialValue: crise.alivio)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SubEyebrow(texto: "editando a crise de \(fmtDataHist(crise.inicio))")
                CamposCriseView(form: $form)

                if crise.fim != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(texto: "Aliviou?")
                        Segmented(
                            opcoes: ALIVIOS, valor: alivio, cores: ALIVIO_PAL,
                            fontSize: 14, verticalPadding: 8
                        ) { alivio = $0 }
                    }
                    .cartao()
                }

                BotaoPrimario(titulo: "Salvar alterações", desabilitado: ocupado, acao: salvar)
                Button("Cancelar", action: fechar)
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0xebebf5, opacity: 0.45))
            }
            .padding()
        }
    }

    private func salvar() {
        ocupado = true
        var patch = paraCrisePatch(form)
        if crise.fim != nil { patch.alivio = alivio }
        Task {
            if await diario.atualizar(crise.id, patch) { fechar() } else { ocupado = false }
        }
    }
}

struct HistoricoView<Barra: View>: View {
    let diario: Diario
    // A barra de paciente vem do chamador: como esta aba é um List (e não passa
    // pelo AbaScroll), a composição da barra fica onde estão os handlers dela.
    @ViewBuilder let barra: () -> Barra
    @State private var editando: Crise?
    @State private var apagando: Crise?

    var body: some View {
        // List, não LazyVStack num ScrollView: reciclagem real de células e
        // swipeActions nativas, sem precisar do `.swipeActionsContainer()`.
        List {
            Group {
                barra()
                    .padding(.top, 12)
                cabecalho
                if !diario.carregandoCrises && diario.crises.isEmpty {
                    CardVazio(titulo: "Nenhuma crise registrada", sub: "Registre a primeira crise para começar.")
                }
                ForEach(diario.crises) { c in
                    CriseCard(
                        c: c, apagar: { apagando = c },
                        editar: { editando = c })
                    .equatable()
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.snappy, value: diario.crises)
        .sheet(item: $editando) { c in
            EditarCriseView(diario: diario, crise: c) { editando = nil }
        }
        // Um diálogo só para a lista inteira (antes era um por card, e o @State do
        // card invalidava o body dele a cada toque).
        .confirmationDialog(
            "Apagar a crise de \(apagando.map { fmtDataHist($0.inicio) } ?? "")?",
            isPresented: Binding(get: { apagando != nil }, set: { if !$0 { apagando = nil } }),
            titleVisibility: .visible, presenting: apagando
        ) { c in
            Button("Apagar", role: .destructive) { Task { await diario.apagar(c.id) } }
        } message: { _ in
            Text("Isso não pode ser desfeito.")
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 0) {
            SubEyebrow(
                texto: diario.carregandoCrises
                    ? "carregando…"
                    : "\(diario.crises.count) \(diario.crises.count == 1 ? "crise registrada" : "crises registradas")"
            )
            Titulo(texto: "Histórico")
        }
    }
}
