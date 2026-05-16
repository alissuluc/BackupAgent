# STATUS DA IMPLEMENTAÇÃO
> *Agente: `@project-planner` — Atualizado pós-homologação FB2.5 + UX Round 2 (2026-05-10)*

---

## ✅ Concluído — MVP Fase 1 (Homologação Validada)

### Backend (BackupAgentS)
- [x] **Windows Service** — `TService` Dual-Mode (Service + Console). `/install`, `/uninstall`.
- [x] **Zero-Config Registry** — `HKCU\DIGIFARMA\Database` como fonte primária.
- [x] **HKEY_USERS Fallback** — Scanner de SIDs para usuário `SYSTEM` do Windows Service.
- [x] **Factory Dinâmica de Provedores** — Detecta Firebird via `rdb$get_context('SYSTEM', 'ENGINE_VERSION')`.
- [x] **Adaptador Firebird 5** — `TFDIBBackup` via Services API TCP. Anti-deadlock: sem `OnProgress`, `TFDGUIxWaitCursor` Console.
- [x] **Adaptador Firebird 2.5** — Services API via `TFDIBBackup` com `VendorLib` explícito (detecta arquitetura do processo em runtime: x86→`Wow6432Node`, x64→chaves nativas). Fallback automático para `gbak.exe`. **Ambos os caminhos validados em homologação.**
- [x] **Proteção de Disco** — `EnsureSufficientDiskSpace` bloqueia sem espaço.
- [x] **Retenção Automática** — `ApplyRetentionPolicy` remove ZIPs com mais de 7 dias.
- [x] **Compactação ZIP** — `.fbk` → `.zip` com senha CNPJ.
- [x] **Assinatura SHA-256** — Header `X-SHA256` em todas as respostas de download.
- [x] **API REST via Horse** — `POST /start`, `GET /status`, `GET /download`.
- [x] **`HEAD /download`** — Endpoint dedicado que retorna `Content-Length` e `Content-Type` sem transferir o arquivo. Permite pré-consulta de tamanho.
- [x] **UTF-8 nos Headers** — `Content-Type: application/json; charset=utf-8`.
- [x] **Bypass WebBroker** — `ContentStream` + `Content-Length` injetados no `RawWebResponse`.
- [x] **Logs de diagnóstico de pipeline** — `server_pipeline.log` e `trace_fb5.log` (homologação).

### Terminal (BackupAgentT)
- [x] **Interface WebView2 (TEdgeBrowser)** — HTML/CSS/JS design Digifarma.
- [x] **WebView2Loader.dll auto-extract** — DLL embutida em `RCDATA`.
- [x] **HTML sempre atualizado** — `index.html` sobrescrito a cada abertura.
- [x] **Comunicação JS ↔ Delphi** — Bridge via `document.title` + `TTimer` (300ms).
- [x] **VCL Fallback** — Link "Voltar para Modo Clássico" → `CLOSE_HTML` → destrói TEdgeBrowser.
- [x] **Botão Fechar** — `btn-close` estilo secundário. Envia `CLOSE_APP` → `Application.Terminate`. **Desabilitado durante backup ativo** via `setInProgress(true/false)`.
- [x] **Exibição de Tamanho Pré-Download** — `HEAD /download` antes de iniciar o stream → `showFileSize(bytes)` → badge verde com tamanho em MB/GB.
- [x] **Download não-bloqueante** — `THTTPClient` em `TTask` ancorando em `TFileStream`.
- [x] **Validação Criptográfica** — SHA-256 local vs `X-SHA256` do servidor.
- [x] **Polling assíncrono** — `TTimer` + `TTask.Run` + `TThread.Queue`.
- [x] **Encoding UTF-8** — `TEncoding.UTF8` na leitura do JSON.

---

## ⏳ Pendente — Antes do Go-Live

- [ ] **Remoção/condicionalização dos logs de diagnóstico** — `TracePipeline`, `Trace()` (FB5, FB25) devem usar `{$IFDEF DEBUG}` nas builds de Release.
- [ ] **Nome do arquivo ZIP no Terminal** — Atualmente `Terminal_Down_Temp.zip`. Considerar usar mesmo nome do servidor.

---

## 📐 Planejado — Settings Screen (Fase 1.5, aguardando sinal verde)

> *Decisões arquiteturais definidas via brainstorm. Implementação NÃO iniciada.*

| Feature | Decisão Arquitetural |
|---------|---------------------|
| **Autenticação** | Novo endpoint `POST /api/v1/auth/validate` no Servidor. Valida `VENDEDORES` WHERE `ACESSO_ADM = 'S'` e `SENHA = MD5(input)` |
| **Persistência** | Arquivo `BackupAgentT.settings.json` local ao lado do `.exe` |
| **Toggle de Download** | `allow_download: bool` no JSON. Persiste entre sessões. |
| **Proteção de troca de papel** | Campo `role` no JSON + detecção automática via Registro na abertura |
| **Bancos adicionais** | Farmachat, Classif_Fiscal, DFE, Farmaceutico — detectados dinamicamente na mesma pasta do Digifarma6.fdb |
| **Backup multi-banco** | ZIP separado por banco. Execução sequencial. |

---

## 🗺️ Roadmap — Fase 2 (Pós Go-Live)

- [ ] **Log Rotativo Diário** — `server-YYYY-MM-DD.log` estruturado.
- [ ] **Retry com Range HTTP 206** — Retomada de download após queda de Wi-Fi.
- [ ] **Token de Sessão** — Evoluir `POST /auth/validate` para retornar JWT de 8h (usuário não digita senha repetidamente).
- [ ] **Dashboard Administrativo** — Painel HTML com métricas de HD, data do último backup, histórico.
- [ ] **Upload para Nuvem** — S3/Azure após validação SHA-256 local.

---

## 📊 Cobertura Atual

| Componente | Unidades | Compilação | Testado FB5 | Testado FB2.5 |
|------------|----------|------------|-------------|---------------|
| Core | 5 unidades | ✅ | ✅ | ✅ |
| Infra | 3 unidades | ✅ | ✅ | ✅ |
| Server | 3 unidades | ✅ | ✅ | ✅ |
| Terminal | 3 unidades | ✅ | ✅ | ✅ |
| **Total** | **14 unidades** | **✅ 100%** | **✅ 100%** | **✅ 100%** |
