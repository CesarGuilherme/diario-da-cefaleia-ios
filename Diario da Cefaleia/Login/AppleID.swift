//
//  AppleID.swift
//  Diario da Cefaleia
//
//  Nonce anti-replay e monitoramento de revogação para o Sign in with Apple nativo.
//  Espelha o que a WWDC22 "Enhance your Sign in with Apple experience" recomenda —
//  não tem equivalente no Login.jsx porque o botão da Apple saiu do webapp por falta
//  de Services ID (só o fluxo web precisa disso; o nativo não).
//

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

nonisolated private let chaveAppleUserID = "appleUserID"

/// O bruto vai para `signInWithIdToken`; o hash vai para `ASAuthorizationAppleIDRequest.nonce`.
/// O Supabase compara o hash do bruto com a claim `nonce` do JWT da Apple — é a defesa
/// contra replay que a WWDC22 pede.
nonisolated func gerarNonce(tamanho: Int = 32) -> String {
    var bytes = [UInt8](repeating: 0, count: tamanho)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    precondition(status == errSecSuccess, "SecRandomCopyBytes falhou: \(status)")
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(bytes.map { charset[Int($0) % charset.count] })
}

nonisolated func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
}

/// Guarda o identificador opaco da Apple (não é segredo, só o que `getCredentialState`
/// pede) para poder checar a revogação no próximo launch.
nonisolated func salvarAppleUserID(_ id: String) {
    UserDefaults.standard.set(id, forKey: chaveAppleUserID)
}

nonisolated private func estadoCredencialApple(userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
    await withCheckedContinuation { cont in
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { estado, _ in
            cont.resume(returning: estado)
        }
    }
}

/// Sem isto, revogar em Ajustes → Apple Account → Sign in with Apple (ou trocar de conta)
/// deixaria uma sessão Supabase válida rodando com uma credencial morta. Roda a cada
/// abertura do app — a notificação abaixo só cobre o app já em primeiro plano.
nonisolated func checarRevogacaoAppleID() async {
    guard let id = UserDefaults.standard.string(forKey: chaveAppleUserID) else { return }
    if await estadoCredencialApple(userID: id) == .revoked {
        UserDefaults.standard.removeObject(forKey: chaveAppleUserID)
        try? await supabase.auth.signOut(scope: .local)
    }
}

/// Com o app aberto, a Apple avisa por notificação em vez de esperar o próximo launch.
/// Quem chama é o `.task` da casca: `addObserver(forName:using:)` devolve um token que
/// precisa ficar retido, e descartá-lo desliga a escuta na hora. O async sequence vive
/// enquanto o task viver e morre com ele.
func escutarRevogacaoAppleID() async {
    let notas = NotificationCenter.default.notifications(
        named: ASAuthorizationAppleIDProvider.credentialRevokedNotification)
    for await _ in notas {
        UserDefaults.standard.removeObject(forKey: chaveAppleUserID)
        try? await supabase.auth.signOut(scope: .local)
    }
}
