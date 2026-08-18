//
//  UI.swift
//  Diario da Cefaleia
//
//  Componentes e estilos compartilhados. Espelha src/ui.jsx, trocando os cartões
//  rgba+blur manuais por Liquid Glass nativo — mesma leitura visual, bem menos código.
//

import SwiftUI

let textoFraco = Color(hex: 0xebebf5, opacity: 0.55)
let textoFraco2 = Color(hex: 0xebebf5, opacity: 0.45)

// MARK: - Layout de quebra de linha (chips de Sintomas, chips do Histórico)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    // Sem cache, sizeThatFits e placeSubviews mediam cada subview duas vezes por
    // passada de layout. SwiftUI reusa esta cache entre as duas chamadas e só
    // recalcula quando o conjunto de subviews muda.
    func makeCache(subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        let largura = proposal.width ?? 0
        // Sem largura finita não dá pra quebrar — mede uma linha só (tamanho intrínseco).
        // Devolver `.infinity` fazia o pai nunca apertar o layout e os chips vazarem.
        guard largura.isFinite, largura > 0 else {
            var w: CGFloat = 0, h: CGFloat = 0
            for (i, tam) in cache.enumerated() {
                w += tam.width + (i > 0 ? spacing : 0)
                h = max(h, tam.height)
            }
            return CGSize(width: w, height: h)
        }
        var x: CGFloat = 0, altura: CGFloat = 0, alturaLinha: CGFloat = 0
        for tam in cache {
            let w = min(tam.width, largura)
            if x + w > largura, x > 0 {
                altura += alturaLinha + spacing
                x = 0
                alturaLinha = 0
            }
            x += w + spacing
            alturaLinha = max(alturaLinha, tam.height)
        }
        altura += alturaLinha
        return CGSize(width: largura, height: altura)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        var x = bounds.minX, y = bounds.minY, alturaLinha: CGFloat = 0
        for (i, view) in subviews.enumerated() {
            let tam = cache[i]
            let w = min(tam.width, bounds.width)
            if x + w > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += alturaLinha + spacing
                alturaLinha = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: w, height: tam.height))
            x += w + spacing
            alturaLinha = max(alturaLinha, tam.height)
        }
    }
}

// MARK: - Toggle de seleção (chips de Sintomas, gatilhos)

extension Array where Element: Equatable {
    mutating func alternar(_ e: Element) {
        if let i = firstIndex(of: e) { remove(at: i) } else { append(e) }
    }
}

// MARK: - Cartão (glass)

extension View {
    /// Substitui o `card` de ui.jsx (rgba + .5px border + backdrop blur + 2 sombras)
    /// pelo material real do sistema.
    func cartao(cornerRadius: CGFloat = 26, padding edgePadding: CGFloat = 16) -> some View {
        self.padding(edgePadding)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }

    /// Estilo dos `<input>` de texto/data — usado com TextField, SecureField, DatePicker.
    func campo() -> some View {
        modifier(CampoStyle())
    }
}

private struct CampoStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 44)
            .tint(.white)
            .glassEffect(in: .rect(cornerRadius: 14))
    }
}

// MARK: - Tipografia

struct Titulo: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 30, weight: .bold)).tracking(0.2)
    }
}

struct SubEyebrow: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 13, weight: .medium)).foregroundStyle(textoFraco)
    }
}

struct Legenda: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 12)).foregroundStyle(textoFraco2)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}

struct SectionLabel: View {
    let texto: String
    var body: some View {
        Text(texto.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(textoFraco)
    }
}

// MARK: - Segmented

/// Cápsula segmentada. `cores` opcional tinge o botão selecionado (intensidade, alívio)
/// via `.buttonStyle(.glass(...))` nativo — sem paleta, cai no azul neutro (Localização, Caráter).
private let corNeutra = Color(hex: 0x38bdf8)

struct Segmented: View {
    let opcoes: [String]
    let valor: String?
    var cores: [String: Color]? = nil
    var fontSize: CGFloat = 15
    var verticalPadding: CGFloat = 9
    var spacing: CGFloat = 5
    let onChange: (String) -> Void

    var body: some View {
        // Como na BarraPacienteView: o container faz os vidros vizinhos amostrarem o
        // fundo juntos e se fundirem, em vez de cada cápsula desfocar por conta própria.
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                ForEach(opcoes, id: \.self) { o in
                    let sel = o == valor
                    Button {
                        onChange(o)
                    } label: {
                        Text(o)
                            .font(.system(size: fontSize, weight: sel ? .bold : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, verticalPadding)
                    }
                    .foregroundStyle(sel ? .black : .white)
                    .buttonStyle(.glass(sel ? .regular.tint(cores?[o] ?? corNeutra) : .regular))
                    .animation(.snappy, value: valor)
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Chip

struct Chip: View {
    let label: String
    let selecionado: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
        }
        .foregroundStyle(selecionado ? .white : Color(hex: 0xebebf5, opacity: 0.6))
        .buttonStyle(.glass(selecionado ? .regular.tint(Color(hex: 0x6c5ce7, opacity: 0.9)) : .regular))
        .animation(.snappy, value: selecionado)
    }
}

// MARK: - Botão primário

struct BotaoPrimario: View {
    let titulo: String
    var verde = false
    var desabilitado = false
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Text(titulo)
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .foregroundStyle(verde ? Color(hex: 0x04250f) : .white)
        .background(
            LinearGradient(
                colors: verde
                    ? [Color(hex: 0x5ee6a8), Color(hex: 0x30d158)]
                    : [Color(hex: 0x8b7cfc), Color(hex: 0x6c5ce7)],
                startPoint: .top, endPoint: .bottom),
            in: Capsule()
        )
        .opacity(desabilitado ? 0.5 : 1)
        .disabled(desabilitado)
    }
}

// MARK: - Banner de erro e card vazio

/// Um só para os dois layouts. Diz "dispensar" e não "toque para dispensar": o texto
/// é o mesmo da web, só o gesto muda de clique pra toque.
struct BannerErro: View {
    let erro: String?
    let dispensar: () -> Void

    var body: some View {
        if let erro {
            Text("\(erro) — dispensar")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: 0xffb5b0))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .glassEffect(.regular.tint(Color(hex: 0xff453a)), in: .rect(cornerRadius: 16))
                .onTapGesture(perform: dispensar)
        }
    }
}

struct CardVazio: View {
    let titulo: String
    let sub: String

    var body: some View {
        VStack(spacing: 4) {
            Text(titulo).font(.system(size: 16, weight: .bold))
            Text(sub).font(.system(size: 13)).foregroundStyle(textoFraco2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 20)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}
