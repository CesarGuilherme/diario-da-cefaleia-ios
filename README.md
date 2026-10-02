# Diário da Cefaléia — iOS e macOS

App nativo (SwiftUI) para registrar crises de dor de cabeça por paciente e gerar um
relatório para o médico. Usa o **mesmo Supabase** do app web
([`CesarGuilherme/diario-da-cefaleia`](https://github.com/CesarGuilherme/diario-da-cefaleia)).
Não há backend próprio: o app fala direto com o Supabase e a **RLS** é a fronteira de confiança.

## Specs

| | |
|---|---|
| Plataformas | iOS 27+ · macOS 27+ |
| Linguagem / UI | Swift 5 · SwiftUI (TabView com Liquid Glass, Swift Charts) |
| Dependência | [`supabase-swift`](https://github.com/supabase/supabase-swift) ≥ 2.5.1 (SPM) |
| Backend | Supabase: Postgres + RLS, Auth, Realtime, Edge Functions |
| Testes | Swift Testing (`@Suite` / `@Test`) |
| Bundle IDs | `com.digitalbsb.Diario-da-Cefaleia` (iOS) · `com.digitalbsb.Diario-da-Cefaleia-Mac` (macOS) |
| Idioma | pt-BR (formatação fixa, igual à web) |

## Funcionalidades

- **Pacientes**: uma conta tem N pacientes. Um deles pode ser marcado como "sou eu" (só pela RPC `definir_sou_eu`).
- **Nova crise / Em curso**: início, intensidade, localização, caráter, sintomas, horas de sono, gatilhos,
  medicação e alívio. Intensidade e sintomas são salvos no banco assim que mudam. O alívio só é salvo ao encerrar a crise.
- **Histórico**: editar crises encerradas e apagar com swipe + confirmação.
- **Relatório**: estatísticas e gráfico (Swift Charts). O link para o médico é um snapshot congelado em
  `relatorios`, com token uuid e validade de 7 dias, compartilhado pelo share sheet.
- **Sync em tempo real** entre aparelhos e com a web (Supabase Realtime, sem update otimista).
- **Login**: e-mail/senha, Google (OAuth) e **Sign in with Apple nativo** (nonce SHA-256 e checagem de revogação).
  Inclui redefinição de senha pelo link do e-mail.
- **Ajustes**: nome, quem é você, troca de senha, sair e **excluir conta** (Edge Function `excluir-conta`,
  exigida pela App Review 5.1.1(v)).
- **macOS**: painel fixo de 3 colunas (`PainelView`), que reusa as telas do iOS. Ajustes ficam numa janela própria (⌘,).

Fora de escopo, por decisão: export PDF, notificações, filtro de período/calendário, gráfico sono × crises e troca de e-mail.

## Estrutura

```
Diario da Cefaleia/            target iOS (e código compartilhado com o Mac)
  App/                         entrada, casca (aurora, gate de sessão, abas)
  Comum/                       Supa (cliente + modelos), Diario (store), Sync, Erro,
                               Format, Tokens, UI, CamposCriseView
  Login/                       Login, AppleID, Senha, Conta, RedefinirSenha, Ajustes
  Nova/                        NovaCrise, CriseAndamento
  Historico/  Pacientes/  Relatorio/ (Report.swift = lógica pura do relatório)
Diario da Cefaleia Mac/        PainelView + entitlements (sandbox)
Diario da Cefaleia Tests/      Report, Sync, Senha, Conta, Erro
```

A lógica pura (`Report`, `Sync`, `Senha`, `Conta`, `Format`) espelha os módulos equivalentes da web
(`src/report.js`, `sync.ts`, `senha.ts`, `conta.ts`, `format.js`) número a número. A UI é nativa, não cópia do JSX.

## Modelo de dados

- `pacientes`: `id`, `nome`, `data_nascimento?`, `sou_eu`, `criado_em`
- `crises`: `id`, `paciente_id`, `inicio`, `fim?` (`nil` = em andamento), `intensidade`, `localizacao`,
  `carater`, `sintomas[]`, `sono_horas`, `gatilhos[]`, `detalhes{}`, `medicacao`, `alivio?`
- `relatorios`: `id` (token), `paciente_id`, `dados` (snapshot), `criado_em`, `expira_em`

O schema, as policies de RLS e as migrações estão no repo web (`supabase/`). Já estão aplicados no projeto
de produção e não devem ser reaplicados.

## Configuração

As chaves vêm do `Info.plist` de cada target (`Diario-da-Cefaleia-Info.plist` e `Diario-da-Cefaleia-Mac-Info.plist`):

| Chave | Uso |
|---|---|
| `SUPABASE_URL` | URL do projeto Supabase |
| `SUPABASE_ANON_KEY` | chave publishable (pública por design; quem protege os dados é a RLS) |
| `PUBLIC_REPORT_BASE_URL` | base do link do relatório (app web na Vercel) |

Se faltar alguma chave, o app abre e mostra o que está faltando, em vez de travar.
O URL scheme (`CFBundleURLTypes`) igual ao bundle ID precisa estar nas **Redirect URLs** do Supabase Auth
para OAuth, confirmação de e-mail e redefinição de senha.

## Rodar e testar

Abra `Diario da Cefaleia.xcodeproj` no Xcode e escolha o scheme **Diario da Cefaleia** (iOS) ou
**Diario da Cefaleia Mac**. Pela linha de comando:

```sh
xcodebuild test -project "Diario da Cefaleia.xcodeproj" -scheme "Diario da Cefaleia" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Sign in with Apple exige a capability `com.apple.developer.applesignin` e um time de desenvolvedor pago.
