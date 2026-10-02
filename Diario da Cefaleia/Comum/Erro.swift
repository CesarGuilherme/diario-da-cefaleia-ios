//
//  Erro.swift
//  Diario da Cefaleia
//
//  Frase para a pessoa, no lugar de `localizedDescription`. URLError do sistema até
//  vem em português; PostgREST e GoTrue devolvem inglês cru ("JWT expired",
//  "permission denied"). A frase genérica muda com a ação; rede e sessão não.
//

import Auth
import Foundation
import Functions
import Helpers
import PostgREST

nonisolated private let codigosSemRede: Set<URLError.Code> = [
    .notConnectedToInternet, .networkConnectionLost, .timedOut,
    .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
    .dataNotAllowed, .internationalRoamingOff, .callIsActive,
]

nonisolated private let codigosSessaoAuth: Set<ErrorCode> = [
    .sessionNotFound, .sessionExpired, .refreshTokenNotFound,
    .refreshTokenAlreadyUsed, .badJWT, .invalidJWT, .noAuthorization,
]

nonisolated private let codigosSessaoPostgrest: Set<String> = ["PGRST301", "PGRST302", "PGRST303"]

nonisolated func mensagemErro(
    _ error: Error,
    senao: String = "Não foi possível salvar. Tente de novo."
) -> String {
    if semRede(error) { return "Sem conexão. Nada foi salvo." }
    if sessaoCaiu(error) { return "Sua sessão expirou. Entre de novo." }
    return senao
}

nonisolated private func semRede(_ error: Error) -> Bool {
    if let url = error as? URLError { return codigosSemRede.contains(url.code) }
    let ns = error as NSError
    if ns.domain == NSURLErrorDomain {
        return codigosSemRede.contains(URLError.Code(rawValue: ns.code))
    }
    // Um nível só: o cliente às vezes embrulha o URLError, e recursão aqui não acrescenta.
    if let causa = ns.userInfo[NSUnderlyingErrorKey] as? URLError {
        return codigosSemRede.contains(causa.code)
    }
    return false
}

nonisolated private func sessaoCaiu(_ error: Error) -> Bool {
    if let auth = error as? AuthError {
        switch auth {
        case .sessionMissing, .jwtVerificationFailed:
            return true
        case .api(_, let code, _, let response):
            return response.statusCode == 401 || codigosSessaoAuth.contains(code)
        default:
            return false
        }
    }
    if let postgrest = error as? PostgrestError, let code = postgrest.code {
        return codigosSessaoPostgrest.contains(code)
    }
    if let http = error as? HTTPError, http.response.statusCode == 401 { return true }
    if let functions = error as? FunctionsError, case .httpError(let code, _) = functions, code == 401 {
        return true
    }
    return false
}
