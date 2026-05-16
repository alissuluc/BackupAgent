# ESTRUTURA TÉCNICA E ARQUITETURA
> *Agente: `@backend-specialist` — Atualizado em Homologação (2026-05-09)*

## Visão Geral

O **BackupAgent** é um sistema distribuído composto por dois executáveis independentes que se comunicam exclusivamente via protocolo HTTP/REST local.

```
┌─────────────────────────────────────────────────────────────┐
│  BackupAgentT.exe  (Terminal - Interface)                    │
│  ┌─────────────────┐   ┌──────────────┐  ┌───────────────┐ │
│  │  TEdgeBrowser   │   │  VCL Fallback│  │ TBackupClient │ │
│  │  (WebView2/HTML)│◄──│  (TMemo/VCL) │  │ (THTTPClient) │ │
│  └─────────────────┘   └──────────────┘  └──────┬────────┘ │
└──────────────────────────────────────────────────┼──────────┘
                                          HTTP :8095│
┌──────────────────────────────────────────────────┼──────────┐
│  BackupAgentS.exe  (Servidor - Windows Service)  │          │
│  ┌──────────────────────────────────────────┐    │          │
│  │  Horse Framework (REST API)              │◄───┘          │
│  │  POST /start  GET /status  GET /download │               │
│  └───────────────────┬──────────────────────┘               │
│                      │ TTask (Background Thread)            │
│  ┌───────────────────▼──────────────────────┐               │
│  │  TProviderFactory (Detecção Automática)   │               │
│  │  ┌─────────────────┐ ┌────────────────┐  │               │
│  │  │ TFB5BackupProv. │ │ TFB25BackupPrv.│  │               │
│  │  │ (FireDAC API)   │ │ (gbak.exe CLI) │  │               │
│  │  └─────────────────┘ └────────────────┘  │               │
│  └──────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

## Princípio Arquitetural: Clean Architecture em Delphi

A codebase está organizada em 4 camadas com separação rígida de responsabilidades:

| Camada | Namespace | Responsabilidade |
|--------|-----------|-----------------|
| **Core** | `BackupAgent.Core.*` | Interfaces puras, Estado de máquina, Crypto, Config, Setup |
| **Infra** | `BackupAgent.Infra.*` | Adapters do Firebird (FB5 e FB2.5) e Factory de Provedores |
| **Server** | `BackupAgent.Server.*` | API REST (Horse), Controller, Windows Service bootstrap |
| **Terminal** | `BackupAgent.Terminal.*` | UI híbrida (WebView2 + VCL), Client HTTP, Assets HTML/CSS |

---

## Camada Core — Interfaces e Contratos

### `BackupAgent.Core.Interfaces`
Define o contrato `IBackupProvider` que qualquer adaptador de banco deve implementar:
```pascal
IBackupProvider = interface
  procedure ExecuteBackup(const ADatabasePath, ADestinationPath, ACnpjPwd: string);
  function GetProgress: Integer;
  function GetCurrentState: TBackupState;
end;
```

### `BackupAgent.Core.State` — Máquina de Estado
Gerencia o `TBackupJob` com estado global em memória:

| Estado | Código | Significado |
|--------|--------|-------------|
| `bsWaiting` | 0 | Aguardando solicitação |
| `bsConnecting` | 1 | Lendo Registro + detectando engine |
| `bsSnapshot` | 2 | Extração ativa no Firebird |
| `bsHashing` | 3 | Calculando SHA-256 |
| `bsZipping` | 4 | Compactando .fbk → .zip |
| `bsReady` | 5 | Arquivo disponível para download |
| `bsError` | 6 | Falha — mensagem disponível em `StatusMessage` |

### `BackupAgent.Core.Config` — Leitura Inteligente do Registro
Responsável por descobrir o caminho do banco sem arquivo de configuração externo.

**Estratégia de Leitura (ordem de prioridade):**
1. `HKEY_CURRENT_USER\DIGIFARMA\Database` (modo Console/interativo)
2. **Fallback HKEY_USERS scanner** — Quando rodando como Windows Service (`SYSTEM`), varre todas as chaves de usuário em `HKEY_USERS\{SID}\DIGIFARMA\Database`

**Formato do valor lido:**
- `C:\Digifarma\Dados\Digifarma6.fdb` → Modo Servidor (local)
- `192.168.0.2:C:\Digifarma\Dados\Digifarma6.fdb` → Modo Terminal (rejeita instalação de Servidor)

### `BackupAgent.Core.Setup` — Ambiente e Segurança de Disco
- Garante existência de `C:\backup\BackupAgent\` na inicialização
- `EnsureSufficientDiskSpace` — bloqueia o backup se o disco de destino tiver menos que 120% do tamanho do banco
- `ApplyRetentionPolicy` — limpa automaticamente arquivos com mais de 7 dias

---

## Camada Infra — Adaptadores de Banco

### `BackupAgent.Infra.ProviderFactory`
Factory inteligente que detecta o motor Firebird em runtime executando:
```sql
SELECT rdb$get_context('SYSTEM', 'ENGINE_VERSION') FROM rdb$database;
```
- Retorno `5.x.x` → instancia `TFB5BackupProvider`
- Retorno `2.5.x` ou erro → instancia `TFB25BackupProvider`

### `BackupAgent.Infra.Firebird5` — Services API Nativa
Utiliza `TFDIBBackup` (FireDAC) via Services API TCP:
- Conecta em `127.0.0.1` com protocolo `ipTCPIP`
- `Verbose := True` — mantém o pipe de rede ativo, prevenindo timeout silencioso
- `TFDGUIxWaitCursor` com `Provider := 'Console'` — blindagem contra o erro `Object factory missing` em Windows Services (sessão sem tela)
- **SEM** `OnProgress` — previne Deadlock em Windows Services (sem message pump)

### `BackupAgent.Infra.Firebird25` — Services API com Detecção de Arquitetura
Utiliza `TFDIBBackup` com `VendorLib` explícito — mesma abordagem do FB5, com lógica adicional para garantir compatibilidade de arquitetura da DLL:

**`FindFbClientPath` — Detecção arch-aware:**
- Detecta se o processo é 32-bit ou 64-bit via `SizeOf(Pointer)` em runtime
- **Processo 64-bit:** busca em `SOFTWARE\Firebird Project\...` (chave nativa x64)
- **Processo 32-bit:** busca em `SOFTWARE\Wow6432Node\Firebird Project\...` (chave x86 em sistema 64-bit)
- Fallback para paths físicos (`Program Files\` ou `Program Files (x86)\` conforme arquitetura)

**Cadeia de execução:**
1. `ExecuteViaServicesAPI` — `TFDIBBackup` com `DriverLink.VendorLib := FbClientPath` ← **preferencial**
2. `ExecuteViaGbak` — processo `gbak.exe` isolado ← fallback automático se Services API falhar

**Rastreio:** `trace_fb25.log` registra processo (32/64-bit), DLL encontrada e qual caminho foi executado.

**Validado em homologação:** ✅ Services API com sucesso | ✅ gbak fallback com sucesso

---

## Camada Server — API REST

### `BackupAgent.Server.Service` — Windows Service Bootstrap
Herda de `TService` (VCL Service Application). Gerencia start/stop do servidor Horse e garante que o processo sobe junto com o Sistema Operacional sem tela.

### `BackupAgent.Server.Controller` — Rotas REST
Orquestra a pipeline de backup em `TTask.Run()` (background thread) retornando HTTP 202 imediatamente:

```
Pipeline de Background:
  LoadFromRegistry → CreateBackupProvider → GetDatabaseCNPJ
  → EnsureDiskSpace → ExecuteBackup → CompressToZip
  → DeleteFBK → CalculateSHA256 → ApplyRetention → bsReady
```

---

## Camada Terminal — Interface Híbrida

### Modo WebView2 (Padrão)
- `TEdgeBrowser` carrega `index.html` (embutido no `.exe` via `RCDATA`)
- `WebView2Loader.dll` extraída automaticamente junto ao `.exe` na primeira execução
- Comunicação bidirecional **Delphi ↔ JavaScript** via `document.title` como canal de mensagens:

| Mensagem (document.title) | Origem | Ação Delphi |
|---------------------------|--------|-------------|
| `START_BACKUP` | HTML → Delphi | Dispara `btnStartClick` |
| `CLOSE_HTML` | HTML → Delphi | Destrói `TEdgeBrowser`, exibe VCL |

### Modo VCL Fallback
Ativado quando: WebView2 não está instalado, usuário clica em "Voltar para Modo Clássico" ou WebView2 lança exceção.
- `TMemo` como log visual
- `TProgressBar` para progresso
- `TLabel` para status textual

### Polling de Status
`TTimer` (2s) → `TTask.Run` → `GET /api/v1/backup/status` → `TThread.Queue` (UI Thread)
Garante que a interface nunca trava aguardando resposta de rede.

---

## Estrutura de Diretórios em Runtime

```
C:\backup\BackupAgent\           ← Zona de Volume Crítico
├── Bkp_CNPJ_2026-05-09_1400.zip  ← Backup final encriptado
├── server_pipeline.log            ← Trace de diagnóstico (pipeline)
└── trace_fb5.log                  ← Trace de diagnóstico (motor FB5)

C:\Install\arquivos\BackupAgent\ ← Zona de Auditoria
└── logs\                          ← (Roadmap: logs rotativos diários)

[pasta do BackupAgentT.exe]\
├── BackupAgentT.exe
├── WebView2Loader.dll             ← Extraída automaticamente do RCDATA
└── ui\
    └── index.html                 ← HTML/CSS/JS sempre reescrito na abertura
```
