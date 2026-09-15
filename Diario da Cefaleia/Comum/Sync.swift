//
//  Sync.swift
//  Diario da Cefaleia
//
//  Espelha src/sync.ts: o que fazer com um evento do Realtime na lista em memória.
//  Fora do Diario de propósito — puro e testável sem o cliente do Supabase.
//  sono_horas como string já é normalizado no decoder de Crise.
//

import Foundation

nonisolated enum EventoCrise {
    case inserir(Crise)
    case atualizar(Crise)
    case apagar(UUID?)
}

/// Aplica na lista a mudança que veio de outro aparelho (ou o eco da nossa).
/// Idempotente: o mesmo evento duas vezes dá o mesmo resultado.
nonisolated func aplicar(_ crises: [Crise], _ evento: EventoCrise) -> [Crise] {
    switch evento {
    case .apagar(let id):
        guard let id else { return crises }
        return crises.filter { $0.id != id }

    case .inserir(let linha), .atualizar(let linha):
        let conhecida = crises.contains { $0.id == linha.id }
        if case .inserir = evento, conhecida { return crises }
        let lista = conhecida
            ? crises.map { $0.id == linha.id ? linha : $0 }
            : [linha] + crises
        return lista.sorted { $0.inicio > $1.inicio }
    }
}
