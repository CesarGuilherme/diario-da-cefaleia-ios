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
        VStack(alignment: .leading, spacing: 14) {
            cabecalho
            CamposCriseView(form: $form)
            BotaoPrimario(titulo: "Iniciar registro da crise", desabilitado: ocupado, acao: enviar)
            Legenda(texto: "A duração e o alívio são registrados ao encerrar a crise")
        }
    }

    // Só o relógio precisa do tick — reconstruir o formulário inteiro a cada
    // minuto seria desperdício (e interromperia o foco de um campo de texto).
    private var cabecalho: some View {
        TimelineView(.everyMinute) { contexto in
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    SubEyebrow(texto: fmtEyebrow(contexto.date))
                    Titulo(texto: "Nova Crise")
                }
                Spacer()
                Text("\(fmtHora(contexto.date)) · Agora")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .glassEffect(in: Capsule())
            }
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
