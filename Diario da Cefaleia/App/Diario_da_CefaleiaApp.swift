//
//  Diario_da_CefaleiaApp.swift
//  Diario da Cefaleia
//

import Supabase
import SwiftUI

@main
struct Diario_da_CefaleiaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Link do e-mail (confirmação de cadastro, recuperação de senha): o GoTrue
                // manda o código nesta URL, handle(_:) troca por sessão e authStateChanges
                // notifica o ContentView. OAuth não passa por aqui — a ASWebAuthenticationSession
                // fecha o próprio callback antes de devolver o controle ao app.
                .onOpenURL { supabase.auth.handle($0) }
        }
    }
}
