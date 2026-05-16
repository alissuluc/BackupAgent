# LOGS, AUDITORIA E RASTREABILIDADE
> *Agente: `@documentation-writer` — Atualizado em Homologação (2026-05-09)*

---

## Arquitetura de Rastreabilidade (Versão Atual)

O BackupAgent usa um modelo leve de auditoria sem dependência de banco de dados SQL.

### 1. Hash de Transferência (X-SHA256)
O header HTTP `X-SHA256` é o contrato de integridade primário do sistema. Gerado no Servidor com `CalculateSHA256(ZipFile)` imediatamente antes do envio e comparado byte a byte pelo Terminal após o download.

- **Positivo:** `SUCESSO! Integridade Hash Validada (SHA-256). Cópias são idênticas.`
- **Negativo:** `ERRO FATAL: O pacote ZIP baixado divergente! (Hash Incorreto)` + logs dos dois hashes para comparação.

### 2. Nomenclatura Semântica de Arquivos
Os backups são nomeados com CNPJ + timestamp, tornando-os auditáveis em storages de massa:
```
Bkp_{CNPJ}_{YYYY-MM-DD}_{HHmm}.zip
Exemplo: Bkp_02695980000110_2026-05-09_2145.zip
```
O CNPJ é extraído da tabela `CONFIG` do banco Firebird a cada execução.

### 3. Log Visual do Terminal
O componente `TMemo` da interface VCL (e o equivalente no HTML via `log-box`) registra em tempo real cada etapa da operação com timestamps `hh:nn:ss`.

---

## Logs de Diagnóstico (Ambiente de Homologação)

> ⚠️ **Estes logs existem apenas na build de homologação. Devem ser removidos antes do release de produção.**

| Arquivo | Caminho | Gerado por | Conteúdo |
|---------|---------|-----------|---------|
| `server_pipeline.log` | `C:\backup\BackupAgent\` | `BackupAgent.Server.Controller` | Rastreio da pipeline completa de backup step-a-step |
| `trace_fb5.log` | `C:\backup\BackupAgent\` | `BackupAgent.Infra.Firebird5` | Rastreio interno do motor TFDIBBackup |

**Exemplo de `server_pipeline.log`:**
```
21:45:06.134 - === INICIO DA PIPELINE EM BACKGROUND ===
21:45:06.135 - 1. UpdateStatus OK. Chamando CreateBackupProvider para: C:\Digifarma\Dados\Digifarma6.fdb
21:45:06.266 - 2. CreateBackupProvider OK. Chamando GetDatabaseCNPJ...
21:45:06.333 - 3. GetDatabaseCNPJ OK. Retornou: 02695980000110
21:45:06.333 - 4. Path definido. Chamando EnsureSufficientDiskSpace...
21:45:06.333 - 5. Espaço OK. Disparando Provider.ExecuteBackup...
21:45:xx.xxx - 6. ExecuteBackup RETORNOU COM SUCESSO.
```

---

## Log Técnico Estruturado (Roadmap — Fase 2)

Um arquivo de log rotativo diário será implementado em `C:\Install\arquivos\BackupAgent\logs\server-YYYY-MM-DD.log`.

### Formato Planejado (Estruturado)

```
[2026-05-09 21:45:06] [INFO] [SNAPSHOT] Iniciando extração. DB=C:\Digifarma\Dados\Digifarma6.fdb
[2026-05-09 21:45:07] [INFO] [SNAPSHOT] Engine detectada: Firebird 5.0.3
[2026-05-09 21:45:09] [INFO] [ZIP]      Compactação concluída. Tamanho: 234MB
[2026-05-09 21:45:10] [INFO] [HASH]     SHA-256: a3f1b2c4...
[2026-05-09 21:45:10] [INFO] [READY]    Job concluído em 4.2s
[2026-05-09 21:45:11] [INFO] [TRANSFER] Download iniciado pelo Terminal 192.168.0.15
[2026-05-09 21:45:45] [INFO] [TRANSFER] Validação SHA-256 OK. Download íntegro.
```

### Métricas de Performance para Diagnóstico Preditivo
O log de duração de backup é especialmente valioso para detectar degradação de hardware:
- Backup hoje: `4.2s` 
- Backup em 30 dias: `47s` → **Sinal de HD com setores ruins ou fragmentação crítica**

Esta correlação temporal permitirá ao suporte Digifarma antecipar falhas físicas de hardware antes que o cliente perca dados.
