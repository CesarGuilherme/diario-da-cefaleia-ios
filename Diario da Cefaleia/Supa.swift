//
//  Supa.swift
//  Diario da Cefaleia
//
//  Cliente Supabase e os modelos de dados. Espelha src/lib/supabase.js e os tipos
//  implícitos em useCrises.js/Pacientes.jsx do app web — mesmo backend, mesmas linhas.
//

import Foundation
import Supabase

// Sem as chaves o app não funciona — mas precisa carregar para conseguir DIZER isso.
// Um `fatalError` aqui derrubaria o processo antes da UI aparecer; quem mostra o erro
// é a `ContentView`. A anon key é pública por design — quem protege os dados é a RLS.
private let infoPlist = Bundle.main.infoDictionary
private let supabaseURLString = infoPlist?["SUPABASE_URL"] as? String
private let supabaseAnonKey = infoPlist?["SUPABASE_ANON_KEY"] as? String

let faltaConfig = supabaseURLString == nil || supabaseAnonKey == nil
    || supabaseURLString?.isEmpty == true || supabaseAnonKey?.isEmpty == true

let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURLString ?? "https://fachada.supabase.co")!,
    supabaseKey: supabaseAnonKey ?? "fachada"
)

// MARK: - Modelos

struct Paciente: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var nome: String
    var dataNascimento: String?  // 'YYYY-MM-DD', opcional — só alimenta a idade no relatório
    var criadoEm: Date

    enum CodingKeys: String, CodingKey {
        case id, nome
        case dataNascimento = "data_nascimento"
        case criadoEm = "criado_em"
    }
}

struct Crise: Codable, Identifiable, Equatable {
    var id: UUID
    var pacienteId: UUID
    var inicio: Date
    var fim: Date?  // nil = crise em andamento
    var intensidade: String
    var localizacao: String
    var carater: String
    var sintomas: [String]
    var sonoHoras: Double
    var gatilhos: [String]
    // gatilho -> itens específicos daquela crise, ex.: {"Alimentação": ["leite","chocolate"]}
    var detalhes: [String: [String]]
    var medicacao: String
    var alivio: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pacienteId = "paciente_id"
        case inicio, fim, intensidade, localizacao, carater, sintomas
        case sonoHoras = "sono_horas"
        case gatilhos, detalhes, medicacao, alivio
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        pacienteId = try c.decode(UUID.self, forKey: .pacienteId)
        inicio = try c.decode(Date.self, forKey: .inicio)
        fim = try c.decodeIfPresent(Date.self, forKey: .fim)
        intensidade = try c.decode(String.self, forKey: .intensidade)
        localizacao = try c.decode(String.self, forKey: .localizacao)
        carater = try c.decode(String.self, forKey: .carater)
        sintomas = try c.decodeIfPresent([String].self, forKey: .sintomas) ?? []
        gatilhos = try c.decodeIfPresent([String].self, forKey: .gatilhos) ?? []
        detalhes = try c.decodeIfPresent([String: [String]].self, forKey: .detalhes) ?? [:]
        medicacao = try c.decodeIfPresent(String.self, forKey: .medicacao) ?? ""
        alivio = try c.decodeIfPresent(String.self, forKey: .alivio)

        // numeric(3,1) do Postgres pode chegar como número ou como string no JSON.
        // Normaliza na entrada, uma vez, em vez de espalhar conversão por todo consumidor.
        if let d = try? c.decode(Double.self, forKey: .sonoHoras) {
            sonoHoras = d
        } else {
            let s = try c.decode(String.self, forKey: .sonoHoras)
            guard let d = Double(s) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sonoHoras, in: c, debugDescription: "sono_horas não é numérico")
            }
            sonoHoras = d
        }
    }
}

// MARK: - Escrita

struct PacienteInput: Encodable {
    var nome: String
    var dataNascimento: String?

    enum CodingKeys: String, CodingKey {
        case nome
        case dataNascimento = "data_nascimento"
    }

    // encode (não encodeIfPresent): nascimento vazio precisa gravar `null` explícito,
    // igual ao `nasc || null` da web — omitir a chave deixaria o valor antigo no banco.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(nome, forKey: .nome)
        try c.encode(dataNascimento, forKey: .dataNascimento)
    }
}

struct NovaCriseInput: Encodable {
    var pacienteId: UUID
    var inicio: Date
    var intensidade: String
    var localizacao: String
    var carater: String
    var sintomas: [String]
    var sonoHoras: Double
    var gatilhos: [String]
    var detalhes: [String: [String]]
    var medicacao: String

    enum CodingKeys: String, CodingKey {
        case pacienteId = "paciente_id"
        case inicio, intensidade, localizacao, carater, sintomas
        case sonoHoras = "sono_horas"
        case gatilhos, detalhes, medicacao
    }
}

/// Update parcial de uma crise. `nil` num campo = não mexer nele — é o que permite
/// `atualizar(id, intensidade: v)` no meio de uma crise sem tocar no resto da linha.
/// ponytail: encodeIfPresent nunca grava NULL; ok porque a UI só deixa `alivio` ir de
/// nil→valor, nunca "desmarcar". Trocar por AnyJSON se surgir uma ação de limpar.
struct CrisePatch: Encodable {
    var intensidade: String? = nil
    var localizacao: String? = nil
    var carater: String? = nil
    var sintomas: [String]? = nil
    var sonoHoras: Double? = nil
    var gatilhos: [String]? = nil
    var detalhes: [String: [String]]? = nil
    var medicacao: String? = nil
    var fim: Date? = nil
    var alivio: String? = nil

    enum CodingKeys: String, CodingKey {
        case intensidade, localizacao, carater, sintomas
        case sonoHoras = "sono_horas"
        case gatilhos, detalhes, medicacao, fim, alivio
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(intensidade, forKey: .intensidade)
        try c.encodeIfPresent(localizacao, forKey: .localizacao)
        try c.encodeIfPresent(carater, forKey: .carater)
        try c.encodeIfPresent(sintomas, forKey: .sintomas)
        try c.encodeIfPresent(sonoHoras, forKey: .sonoHoras)
        try c.encodeIfPresent(gatilhos, forKey: .gatilhos)
        try c.encodeIfPresent(detalhes, forKey: .detalhes)
        try c.encodeIfPresent(medicacao, forKey: .medicacao)
        try c.encodeIfPresent(fim, forKey: .fim)
        try c.encodeIfPresent(alivio, forKey: .alivio)
    }
}
