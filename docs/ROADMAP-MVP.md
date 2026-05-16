# ROADMAP — FASE DE EXPANSÃO
> *Agente: `@project-planner` — Atualizado pós-homologação (2026-05-10)*

---

## Status Atual
✅ **MVP Fase 1 — Homologação Concluída com Sucesso em Ambos os Motores**
- Firebird 5: Services API via `TFDIBBackup` — validado
- Firebird 2.5: `gbak.exe` via `FindGbakPath` — validado

---

## Step 0: Estabilização Pré-Go-Live (Imediato)

- [ ] **DT-001 — Logs de diagnóstico condicionais** — `{$IFDEF DEBUG}` em `TracePipeline` e `Trace()`.
- [ ] **DT-002 — Nome do arquivo de download** — Usar mesmo nome do servidor em vez de `Terminal_Down_Temp.zip`.
- [ ] **Teste em cliente real** — Validar `FindGbakPath` em farmácias com Firebird 2.5 em produção.
- [ ] **Script de Firewall** — `netsh` no `install.bat` para abrir TCP:8095 automaticamente.

---

## Step 1: Settings Screen com Auth Digifarma (Fase 1.5)

> *Decisões arquiteturais definidas (ADR-012). Aguardando sinal verde.*

### Backend (BackupAgentS)
- [ ] `POST /api/v1/auth/validate` — Valida `VENDEDORES.ACESSO_ADM = 'S'` + `SENHA = MD5(input)`.
- [ ] Detecção dinâmica de bancos na pasta do Digifarma6 (Farmachat, Classif_Fiscal, DFE, Farmaceutico).
- [ ] Pipeline multi-banco: ZIP separado por banco, execução sequencial.
- [ ] Endpoint de status multi-banco com estado por banco.

### Terminal (BackupAgentT)
- [ ] Modal de login (Login + Senha) → `POST /auth/validate`.
- [ ] Settings Screen HTML: toggle `allow_download`, checkboxes de bancos.
- [ ] Persistência em `BackupAgentT.settings.json`.
- [ ] Leitura do `settings.json` na abertura — respeitar `allow_download` e `role`.
- [ ] Proteção de troca de papel: detectar se máquina mudou de Terminal para Servidor via Registro.

---

## Step 2: Resiliência Operacional (Q3 2026)

- [ ] **Retry com Range HTTP 206** — Retomada de downloads parciais após queda de Wi-Fi.
- [ ] **Health-check de latência** — Na abertura do Terminal, medir latência do servidor e alertar se > 1,5s (redes VPN lentas).
- [ ] **Token de Sessão para Auth** — Após login bem-sucedido, salvar token com TTL de 8h localmente. Usuário não redigita senha repetidamente.
- [ ] **Log Rotativo Diário** — `server-YYYY-MM-DD.log` estruturado em `C:\Install\arquivos\BackupAgent\logs\`.
- [ ] **Notificação para Segundo Terminal** — Em vez de HTTP 409 silencioso, retornar progresso atual.

---

## Step 3: Dashboard Administrativo (Q4 2026)

- [ ] **Painel Web embutido no Servidor** — Endpoint HTML com:
  - Data/hora do último backup bem-sucedido
  - Tamanho do arquivo gerado
  - Espaço livre em disco atual
  - Histórico dos últimos 7 backups por banco
- [ ] **Autenticação por Token JWT** — Header `Authorization: Bearer {token}` para todos os endpoints.

---

## Step 4: Expansão Cloud (Ano Base 2)

- [ ] **Upload automático S3/Azure** — Após SHA-256 local validado, enviar ZIP para storage Digifarma.
- [ ] **Backup Diferencial** — Pages API do Firebird para detectar só páginas alteradas (redução ~80% no tamanho).
- [ ] **Agendamento Embutido** — Cronjob interno no Service (sem Task Scheduler do Windows).
- [ ] **Painel Central Digifarma** — Web dashboard multi-cliente (React/Next.js) consumindo API dos BackupAgents remotamente.
