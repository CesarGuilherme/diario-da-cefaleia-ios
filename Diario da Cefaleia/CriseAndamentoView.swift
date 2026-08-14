//
//  CriseAndamentoView.swift
//  Diario da Cefaleia
//
//  Espelha screens/CriseAndamento.jsx. Intensidade e sintomas vão direto ao banco ao
//  mudar — não há rascunho a perder; o alívio só vai ao encerrar, igual à web.
//

import SwiftUI

struct CriseAndamentoView: View {
    let diario: Diario
    let ativa: Crise
    let irParaHistorico: () -> Void

    @State private var alivio: String?  // só vai pro banco ao encerrar
    @State private var medicacao: String
    @State private var ocupado = false
    @FocusState private var medicacaoFocada: Bool

    private let duracaoVolta: TimeInterval = 180 * 60  // o anel completa uma volta em 3h

    init(diario: Diario, ativa: Crise, irParaHistorico: @escaping () -> Void) {
        self.diario = diario
        self.ativa = ativa
        self.irParaHistorico = irParaHistorico
        _alivio = State(initialValue: nil)
        _medicacao = State(initialValue: ativa.medicacao)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { contexto in
            let decorrido = max(0, contexto.date.timeIntervalSince(ativa.inicio))
            let progresso = min(decorrido / duracaoVolta, 1)

            VStack(spacing: 16) {
                Text("CRISE EM ANDAMENTO")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))

                anel(progresso: progresso, decorrido: decorrido)
                intensidadeSecao
                sintomasSecao
                medicacaoSecao

                BotaoPrimario(titulo: "Encerrar crise", verde: true, desabilitado: ocupado, acao: fechar)
                Legenda(texto: "A duração total é calculada automaticamente")
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
        }
    }

    private func anel(progresso: Double, decorrido: TimeInterval) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progresso)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: 0xff9f0a), Color(hex: 0xff453a)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(fmtDecorrido(decorrido * 1000))
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                Text("início às \(fmtHora(ativa.inicio))")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 220, height: 220)
    }

    private var intensidadeSecao: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Intensidade agora").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("atualize se mudar").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
            }
            Segmented(opcoes: INTENSIDADES, valor: ativa.intensidade, cores: INT.mapValues(\.dot)) { v in
                Task { await diario.atualizar(ativa.id, CrisePatch(intensidade: v)) }
            }
        }
        .cartao()
    }

    private var sintomasSecao: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sintomas").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("marque se surgir agora").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
            }
            FlowLayout(spacing: 8) {
                ForEach(SINTOMAS, id: \.self) { s in
                    Chip(label: s, selecionado: ativa.sintomas.contains(s)) { alternarSintoma(s) }
                }
            }
        }
        .cartao()
    }

    private var medicacaoSecao: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(texto: "Medicação")
            TextField("Ex.: Ibuprofeno 400 mg", text: $medicacao)
                .campo()
                .focused($medicacaoFocada)
                .onChange(of: medicacaoFocada) { _, focada in
                    if !focada { salvarMedicacaoSeMudou() }
                }
            Text("Tomou algo durante a crise? Anote aqui — salva ao sair do campo.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))

            SectionLabel(texto: "Aliviou?").padding(.top, 6)
            Segmented(opcoes: ALIVIOS, valor: alivio, cores: ALIVIO_PAL, fontSize: 14, verticalPadding: 8) {
                alivio = $0
            }
        }
        .cartao()
    }

    private func alternarSintoma(_ s: String) {
        var sintomas = ativa.sintomas
        if let idx = sintomas.firstIndex(of: s) { sintomas.remove(at: idx) } else { sintomas.append(s) }
        Task { await diario.atualizar(ativa.id, CrisePatch(sintomas: sintomas)) }
    }

    private func salvarMedicacaoSeMudou() {
        guard medicacao != ativa.medicacao else { return }
        Task { await diario.atualizar(ativa.id, CrisePatch(medicacao: medicacao)) }
    }

    private func fechar() {
        ocupado = true
        Task {
            if await diario.encerrar(ativa.id, alivio: alivio) {
                irParaHistorico()
            } else {
                ocupado = false
            }
        }
    }
}
