# DECISÕES ARQUITETURAIS REGISTRADAS (ADR)
> *Agente: `@backend-specialist` — Atualizado pós-homologação (2026-05-10)*

---

## ADR-001: Registro do Windows como Zero-Config Source of Truth

- **Contexto:** Manter 5.000 clientes com `.json` geraria dessincronização com o sistema legado.
- **Decisão:** `HKEY_CURRENT_USER\DIGIFARMA\Database` como fonte única de verdade.
- **Aprendizado em Homologação:** Windows Service roda como `SYSTEM` — `HKCU` fica vazio. Implementado fallback com scanner de `HKEY_USERS\{SID}\DIGIFARMA`.
- **Consequência:** Deploy Zero-Config funcional mesmo sob `SYSTEM`.

---

## ADR-002: Bypass de ContentStream no Horse para Downloads Massivos

- **Contexto:** Abstrações do Horse quebravam downloads acima de 5GB com chunking invisível.
- **Decisão:** `Res.RawWebResponse.ContentStream := FS` com `Content-Length` injetado diretamente.
- **Consequência:** Performance máxima, byte-match garantido pelo S.O.

---

## ADR-003: Set Vazio `[]` no FireDAC para Opções de GC

- **Contexto:** Nomenclatura de opções (`poIgnoreLimbo`, `boIgnoreLimbo`) varia entre sub-versões do IDE.
- **Decisão:** `FBackupService.Options := []` — delega comportamento padrão ao Firebird nativo.
- **Consequência:** Compilação cross-version 100% resiliente.

---

## ADR-004: Eliminação do `OnProgress` no TFDIBBackup em Windows Services

- **Contexto:** `OnProgress` tenta `TThread.Synchronize` com a thread de interface. Windows Services não têm message pump — deadlock permanente.
- **Decisão:** `OnProgress` removido. `TFDGUIxWaitCursor` com `Provider := 'Console'` registrado explicitamente.
- **Consequência:** Deadlock eliminado. Barra de progresso pula de ~20% para 100% (aceitável para o contexto).

---

## ADR-005: TFDGUIxWaitCursor como Blindagem de Fábrica do FireDAC

- **Contexto:** FireDAC lança `Object factory for class {3E9B315B...} is missing` em ambiente headless quando o linker descarta `FireDAC.ConsoleUI.Wait`.
- **Decisão:** Instanciar `TFDGUIxWaitCursor` com `Provider := 'Console'` no construtor de `TFB5BackupProvider`.
- **Consequência:** Componente forçado no binário. Handler silencioso registrado. Sem tela ou cursor.

---

## ADR-006: Comunicação HTML ↔ Delphi via `document.title`

- **Contexto:** `TEdgeBrowser` em versões antigas do Delphi não expõe `ExecuteScriptWithResult` síncrono. `WebMessageReceived` tem incompatibilidades cross-version.
- **Decisão:** `document.title` como canal de mensagens (JS → Delphi), capturado por `TTimer` a cada 300ms.

| Mensagem | Ação Delphi |
|----------|-------------|
| `START_BACKUP` | Dispara `btnStartClick` |
| `CLOSE_HTML` | Destrói `TEdgeBrowser`, exibe VCL |
| `CLOSE_APP` | `Application.Terminate` |

- **Consequência:** Universal, cross-version, sem dependências adicionais.

---

## ADR-007: HTML Sempre Reescrito na Abertura

- **Contexto:** Trava `if not FileExists` impedia atualizações de UI chegarem aos clientes após deploy.
- **Decisão:** `ExtractUIDependencies` sobrescreve `index.html` incondicionalmente.
- **Consequência:** UI sempre na versão mais recente do binário.

---

## ADR-008: Windows Service com Dual-Mode

- **Contexto:** Service puro dificulta debug. Console facilita ciclo de desenvolvimento.
- **Decisão:** `BackupAgentS` como `TService` com suporte a `/install`, `/uninstall`, `/console`.
- **Consequência:** Produção silenciosa; desenvolvimento interativo sem reinstalação.

---

## ADR-009: FindGbakPath — Lookup em Registro antes de PATH do Sistema *(Evoluído para ADR-013)*

- **Contexto original:** Windows Service tem PATH truncado — `gbak.exe` no PATH do usuário não era encontrado, gerando `Win32 Error 2`.
- **Decisão original:** `FindGbakPath` com 3 camadas (Registro `HKLM`, `Wow6432Node`, paths físicos). Funções internas `TryReadRegValue` isolam cada tentativa em instância própria de `TRegistry`.
- **Evolução:** Após validação, abordagem elevada para Services API nativa (ADR-013). `FindGbakPath` permanece como fallback de emergência.

---

## ADR-010: HEAD /download para Pré-Consulta de Tamanho

- **Contexto:** Em redes VPN lentas, o usuário iniciava um download de vários GB sem saber o tamanho, gerando frustração e desconfiança no processo.
- **Decisão:** Endpoint dedicado `HEAD /api/v1/backup/download` retorna apenas `Content-Length` e `Content-Type` sem transferir dados. O Terminal faz essa consulta antes de iniciar o stream e exibe o tamanho em um badge verde (`showFileSize`).
- **Consequência:** Usuário informado do tamanho exato antes de comprometer a rede. Custo: uma request adicional de ~50ms.

---

## ADR-011: Botão Fechar Bloqueado Durante Backup Ativo

- **Contexto:** Fechar o Terminal durante um download ativo encerra o socket TCP, corrompendo o arquivo parcialmente baixado.
- **Decisão:** `btn-close` desabilitado via `setInProgress(true)` no início do backup e reabilitado via `setInProgress(false)` ao fim (sucesso ou falha). Mesmo comportamento no modo VCL (`btnStart.Enabled`).
- **Consequência:** Impossível fechar acidentalmente durante operações críticas.

---

## ADR-012 (Planejado): Settings Screen com Auth via VENDEDORES do Digifarma

- **Contexto:** Necessidade de controle granular por terminal — toggle de download, seleção de bancos para backup.
- **Decisão (aguardando implementação):**
  - Auth via `POST /api/v1/auth/validate` — valida `VENDEDORES.ACESSO_ADM = 'S'` e `SENHA = MD5(input)`
  - Persistência em `BackupAgentT.settings.json` (local ao `.exe`)
  - Proteção de troca de papel via campo `role` + detecção automática via Registro na abertura
  - Bancos adicionais detectados dinamicamente na mesma pasta do Digifarma6.fdb
  - Backup multi-banco: ZIP separado por banco, execução sequencial

---

## ADR-013: Services API com VendorLib Arch-Aware para Firebird 2.5

- **Contexto:** Após `FindGbakPath` resolver o problema de PATH, identificou-se que a Services API é preferível ao gbak (sem processo externo, mesmo padrão que FB5). O desafio: a `fbclient.dll` deve ter a mesma arquitetura do processo que a carrega.
- **Decisão:** `FindFbClientPath` detecta bitness do processo via `SizeOf(Pointer)` e busca a DLL compativel:
  - **Processo 64-bit:** chaves nativas `SOFTWARE\Firebird Project\...` → `Program Files\Firebird\`
  - **Processo 32-bit:** chaves `Wow6432Node\...` → `Program Files (x86)\Firebird\`
  - `TFDPhysFBDriverLink.VendorLib` definido explicitamente antes do `Backup`
- **Fallback:** `ExecuteViaGbak` ativado automaticamente se Services API falhar (ex: DLL ausente ou incompatível em hardware atípico)
- **Rastreio:** `trace_fb25.log` registra processo, DLL encontrada e qual caminho foi executado
- **Validado:** ✅ Services API (caminho principal) + ✅ gbak fallback — ambos em homologação (2026-05-10)
