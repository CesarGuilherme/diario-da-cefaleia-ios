//
//  CamposCriseView.swift
//  Diario da Cefaleia
//
//  Os campos de uma crise, extraídos pra serem os mesmos no registro e na edição
//  posterior — um formulário só, nada de dois que divergem. Espelha CamposCrise.jsx.
//

import SwiftUI

struct CamposCriseView: View {
    @Binding var form: CriseForm

    var body: some View {
        Group {
            intensidadeSecao
            sintomasSecao
            gatilhosSecao
            medicacaoSecao
        }
    }

    private var intensidadeSecao: some View {
        VStack(spacing: 14) {
            SectionLabel(texto: "Intensidade")
            Segmented(opcoes: INTENSIDADES, valor: form.intensidade, cores: INT_DOTS) {
                form.intensidade = $0
            }

            SectionLabel(texto: "Localização")
            Segmented(opcoes: LOCALIZACOES, valor: form.localizacao) { form.localizacao = $0 }

            SectionLabel(texto: "Caráter")
            Segmented(opcoes: CARATERES, valor: form.carater) { form.carater = $0 }
        }
        .cartao()
    }

    private var sintomasSecao: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(texto: "Sintomas")
            FlowLayout(spacing: 8) {
                ForEach(SINTOMAS, id: \.self) { s in
                    Chip(label: s, selecionado: form.sintomas.contains(s)) { alternarSintoma(s) }
                }
            }
        }
        .cartao()
    }

    private var gatilhosSecao: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(texto: "Gatilhos")

            HStack {
                Text("Sono (noite anterior)").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(fmtSono(form.sonoHoras))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8b7cfc))
            }
            .padding(.bottom, 2)

            Slider(value: $form.sonoHoras, in: 3...12, step: 0.5)
                .tint(Color(hex: 0x8b7cfc))
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                ForEach(GATILHOS, id: \.valor) { g in
                    gatilhoLinha(g)
                }
            }
        }
        .cartao()
    }

    private func gatilhoLinha(_ g: (label: String, valor: String, dica: String)) -> some View {
        let ligado = form.gatilhos.contains(g.valor)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                alternarGatilho(g.valor)
            } label: {
                HStack {
                    Text(g.label).font(.system(size: 15)).foregroundStyle(.white)
                    Spacer()
                    Capsule()
                        .fill(ligado ? Color(hex: 0x30d158) : Color.white.opacity(0.32))
                        .frame(width: 48, height: 29)
                        .overlay(alignment: ligado ? .trailing : .leading) {
                            Circle().fill(.white).frame(width: 25, height: 25).padding(2)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                        }
                }
                .padding(.vertical, 8)
            }

            // O detalhe só existe se o gatilho está ligado — nada de campo órfão.
            if ligado {
                VStack(alignment: .leading, spacing: 5) {
                    TextField(
                        "Detalhe de \(g.valor)", text: Binding(
                            get: { form.detalhes[g.valor] ?? "" },
                            set: { form.detalhes[g.valor] = $0 }),
                        prompt: Text(g.dica).foregroundStyle(textoFraco)
                    )
                    .campo()
                    Text("Separe por vírgula — é o que permite achar o item que se repete")
                        .font(.system(size: 11)).foregroundStyle(textoFraco2)
                }
                .padding(.leading, 12)
                .padding(.bottom, 10)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(hex: 0x30d158, opacity: 0.35)).frame(width: 2)
                }
            }
        }
    }

    private var medicacaoSecao: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(texto: "Medicação")
            TextField("Ex.: Ibuprofeno 400 mg", text: $form.medicacao)
                .campo()
        }
        .cartao()
    }

    private func alternarSintoma(_ s: String) {
        form.sintomas.alternar(s)
    }

    private func alternarGatilho(_ g: String) {
        form.gatilhos.alternar(g)
    }
}
