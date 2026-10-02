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
                #if os(macOS)
                // As 3 colunas do PainelView (240 + flexível + 420, mais respiro) não cabem
                // abaixo disto — espelha o mínimo que o dashboard web assume em Painel.tsx.
                .frame(minWidth: 1100, minHeight: 700)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        // Ajustes… no menu do app / ⌘, — abas Perfil e Senha, separadas da janela principal.
        Settings {
            AjustesMacView()
        }
        #endif
    }
}
