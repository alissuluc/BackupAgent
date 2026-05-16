# MAPA DE RISCOS, PERFORMANCE E DÍVIDA TÉCNICA
> *Agente: `@backend-specialist` — Atualizado pós-homologação (2026-05-10)*

---

## Análise de Performance por Operação

| Operação | Impacto | Gargalo | Risco | Mitigação |
|----------|---------|---------|-------|-----------|
| HEAD /download (tamanho) | Baixo | Rede local | Nenhum | Timeout 10s dedicado |
| Detecção de Engine (Factory) | Baixo | TCP local | Baixo | Timeout implícito FireDAC |
| Services API Backup (FB5) | Alto | I/O Disco + Rede | Médio | `Verbose := True` + sem `OnProgress` |
| FindGbakPath (FB2.5) | Baixo | Registro + FileExists | Nenhum | 3 camadas de fallback |
| gbak.exe Legado (FB2.5) | Alto | CPU + I/O | Baixo | Processo isolado |
| Compactação ZIP | **Crítico** | CPU Single-Thread | Moderado | `TTask` (não bloqueia API) |
| Transfer TCP Stream | Alto | Rede (Banda) | Baixo | `TFileStream` direto, sem RAM |
| SHA-256 do ZIP | Moderado | Disco + CPU | Baixo | < 3s para 1GB |

---

## Riscos Operacionais e Mitigações

### 🔴 Risco 1: Deadlock do TFDIBBackup em Windows Service
**Status:** ✅ **Resolvido**
`OnProgress` removido. `TFDGUIxWaitCursor.Provider := 'Console'` registrado explicitamente no construtor.

### 🟢 Risco 2: Incompatibilidade de DLL fbclient no Firebird 2.5
**Histórico:** Fase 1 usava `gbak.exe` (processo externo) para evitar conflito de DLL. Após validação do gbak, evoluímos para Services API com `VendorLib` explícito.
**Solução final:** `FindFbClientPath` detecta arquitetura do processo em runtime (`SizeOf(Pointer)`), busca a DLL correta no Registro (`Wow6432Node` para x86, chave nativa para x64) e define `TFDPhysFBDriverLink.VendorLib` explicitamente. Fallback automático para `gbak.exe`.
**Status:** ✅ **Resolvido** — Services API validada + gbak fallback validado em homologação.

### 🟡 Risco 3: Corte de Conexão na Transferência TCP
**Mitigação:** `Content-Length` injetado via `RawWebResponse`. SHA-256 detecta e bloqueia arquivos corrompidos.
**Residual:** Sem suporte a `Range HTTP 206`. Download recomeça do zero após queda.

### 🟡 Risco 4: HKEY_USERS Scanner em Máquinas Multi-Usuário
**Mitigação:** Break após primeiro SID com chave `DIGIFARMA`. Risco baixo (farmácia = um banco por máquina).

### 🟡 Risco 5: Concorrência de Jobs
**Mitigação:** `GlobalJob` único + HTTP 409 para segundo Terminal.
**Residual:** Sem fila ou notificação ao segundo Terminal.

### 🟢 Risco 6: Estouro de RAM no Download
**Status:** ✅ **Mitigado** — `THTTPClient` ancorado em `TFileStream`. Buffer ~10MB independente do tamanho do arquivo.

### 🟢 Risco 7: Fechamento Acidental Durante Download
**Status:** ✅ **Mitigado** — `btn-close` desabilitado via `setInProgress(true)` durante toda a operação de backup+download. Reabilitado apenas após conclusão ou falha.

---

## Dívida Técnica Registrada

| ID | Item | Prioridade | Impacto |
|----|------|------------|---------|
| DT-001 | Logs de diagnóstico em produção (`server_pipeline.log`, `trace_fb5.log`) | **Alta** | Exposição de dados internos em disco de cliente |
| DT-002 | Download salvo como `Terminal_Down_Temp.zip` (nome fixo) | Média | Sobrescreve download anterior sem aviso |
| DT-003 | Sem autenticação por token na API principal | Média | Qualquer máquina na LAN pode acionar backup |
| DT-004 | `GlobalJob` sem liberação automática após timeout | Baixa | Job em `bsError` persiste em memória |
| DT-005 | Sem retry automático no Terminal após falha de rede | Baixa | Usuário reanaliza manualmente |
| DT-006 | Settings Screen não implementada | **Média** | Sem controle de permissão de download por terminal |

---

## Recomendações Antes do Go-Live

1. **DT-001 URGENTE:** Encapsular blocos de log em `{$IFDEF DEBUG}` nas builds de Release.
2. **DT-002:** Usar mesmo nome do servidor para o arquivo local de download.
3. **DT-006:** Implementar Settings Screen (ADR-012) para controle de download por terminal antes de distribuição ampla.
