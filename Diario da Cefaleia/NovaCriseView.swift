//
//  NovaCriseView.swift
//  Diario da Cefaleia
//
//  Espelha screens/NovaCrise.jsx.
//

import SwiftUI

struct NovaCriseView: View {
    let diario: Diario
    @State private var form = FORM_PADRAO
    @State private var ocupado = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { contexto in
            VStack(alignment: .leading, spacing: 14) {
                cabecalho(contexto.date)
                CamposCriseView(form: $form)
                BotaoPrimario(titulo: "Iniciar registro da crise", desabilitado: ocupado, acao: enviar)
                Legenda(texto: "A duração e o alívio são registrados ao encerrar a crise")
            }
        }
    }

    private func cabecalho(_ agora: Date) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                SubEyebrow(texto: fmtEyebrow(agora))
                Titulo(texto: "Nova Crise")
            }
            Spacer()
            Text("\(fmtHora(agora)) · Agora")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .frame(height: 38)
                .glassEffect(in: Capsule())
        }
    }

    private func enviar() {
        guard let pacienteId = diario.paciente?.id else { return }
        ocupado = true
        Task {
            // O rascunho só é descartado se o servidor confirmou — falhou, o usuário não redigita.
            if await diario.iniciar(paraNovaCriseInput(form, pacienteId: pacienteId)) {
                form = FORM_PADRAO
            }
            ocupado = false
        }
    }
}
