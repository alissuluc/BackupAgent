# FLUXOS DE EXECUÇÃO PONTA A PONTA
> *Agente: `@backend-specialist` + `@frontend-specialist` — Atualizado (2026-05-10)*

---

## Fluxo 1: Abertura do Terminal

```
BackupAgentT.exe inicializa
  │
  ├─ ExtractUIDependencies() → Sobrescreve ui/index.html (sempre)
  ├─ ExtractWebView2Loader() → Extrai WebView2Loader.dll se necessário
  │
  ├─ TEdgeBrowser.Create() ──────────────────────────────────► [SUCESSO]
  │   └─ Navigate('file:///...ui/index.html')                      │
  │                                                          TTimer UIHook (300ms)
  │   [FALHA - WebView2 não instalado]                             │
  └─ FEdgeBrowser := nil                                    Aguarda document.title:
      └─ VCL Fallback (TMemo + TProgressBar)                 'START_BACKUP'
                                                             'CLOSE_HTML'
                                                             'CLOSE_APP'
  TConfigManager.Create()
    └─ LoadFromRegistry()
        ├─ HKCU\DIGIFARMA\Database (modo interativo)
        └─ HKEY_USERS\{SID}\DIGIFARMA (fallback Service SYSTEM)

  FAgentClient.BaseURL = 'http://{ServerIP}:8095'
  Log('Conectado ao Servidor: ...')
```

---

## Fluxo 2: Disparo de Backup

```
[Usuário clica botão no HTML]
  │
  ├─ JavaScript: document.title = 'START_BACKUP'
  ├─ TTimer UIHookTimer detecta → btnStartClick(nil)
  │
  ├─ btnStart.Enabled := False
  ├─ EdgeBrowser.ExecuteScript('setInProgress(true)') ← desabilita btn-close
  │
  └─ TTask.Run → POST /start → HTTP 202 → OnBackupStarted
       └─ tmrPolling.Enabled := True

[Servidor — Background Thread]
  ├─ TConfigManager → DatabasePath (HKCU ou HKEY_USERS scanner)
  ├─ TProviderFactory.CreateBackupProvider(DatabasePath)
  │     ├─ ENGINE_VERSION = 5.x → TFB5BackupProvider
  │     │     └─ TFDIBBackup.Backup (Services API, sem OnProgress)
  │     └─ ENGINE_VERSION = 2.5 → TFB25BackupProvider
  │           └─ FindGbakPath → Registro HKLM → paths físicos → CreateProcess
  ├─ CompressToZip → DeleteFBK → CalculateSHA256
  └─ GlobalJob.State := bsReady
```

---

## Fluxo 3: Polling de Status

```
tmrPolling.OnTimer (2s):
  ├─ TTask.Run → GET /status → JSON {state_code, progress, message}
  └─ TThread.Queue:
        ├─ [Falha de rede] → Log('Reconectando...') → reativa timer
        ├─ [state_code 1-4] → atualiza barra + label → reativa timer
        ├─ [state_code = 5] → OnBackupFinished()
        └─ [state_code = 6] → Log('ABORTADO') → btnStart.Enabled := True
```

---

## Fluxo 4: Pré-Download → Exibição de Tamanho → Download → Validação

```
OnBackupFinished():
  │
  └─ TTask.Run:
        │
        ├─ [NOVO] HEAD /api/v1/backup/download
        │     └─ Lê Content-Length (bytes reais do ZIP)
        │          └─ TThread.Queue → EdgeBrowser.ExecuteScript('showFileSize(N)')
        │               └─ HTML: badge verde "📦 Arquivo pronto: X MB"
        │
        ├─ GET /api/v1/backup/download
        │     ├─ Lê header X-SHA256 (ServerHash)
        │     └─ Stream direto: HTTP → TFileStream → disco local
        │          (Não passa pela RAM — suporta qualquer tamanho)
        │
        └─ TThread.Queue:
              ├─ EdgeBrowser.ExecuteScript('setInProgress(false)') ← reabilita btn-close
              ├─ [Falha] Log('Falha grave de rede: ' + ErrMsg)
              └─ [Sucesso] CalculateSHA256(ZipPath) → LocalHash
                    ├─ [=] ✅ 'SUCESSO! Integridade Validada (SHA-256)'
                    │     └─ updateStatus(5, 100, ...) + resetUI()
                    └─ [≠] ❌ 'ERRO FATAL: Hash divergente!'
                          └─ Logs dos dois hashes para diagnóstico
```

---

## Fluxo 5: Fallback VCL (Botão "Voltar ao Modo Clássico")

```
[Link no rodapé HTML clicado]
  ├─ JavaScript: document.title = 'CLOSE_HTML'
  └─ TTimer detecta → FEdgeBrowser.Free + VCL visível (TMemo, TProgressBar, TLabel)
```

---

## Fluxo 6: Fechar Aplicação

```
[Botão "Fechar" clicado no HTML]
  ├─ [Durante backup] → btn-close desabilitado → clique ignorado
  └─ [Sem backup] → JavaScript: document.title = 'CLOSE_APP'
                        └─ TTimer detecta → Application.Terminate
```

---

## Fluxo 7 (Planejado): Autenticação para Settings Screen

```
[Usuário clica "⚙️ Configurações" no HTML]
  │
  ├─ Modal de login exibido (campos: login, senha)
  │
  └─ [Submit] → POST /api/v1/auth/validate {login, senha_md5: MD5(input)}
        ├─ [401] → "Acesso negado. Verifique credenciais."
        └─ [200] → Settings Screen desbloqueada
              ├─ Toggle: ☑ Realizar download no Terminal
              ├─ Bancos disponíveis (detectados na pasta do Digifarma6):
              │     ☑ Digifarma6  ☐ Farmachat  ☐ DFE ...
              └─ [Salvar] → BackupAgentT.settings.json atualizado
                    └─ role: verificado na abertura (proteção troca servidor/terminal)
```
