# CONTRATOS DA API REST — BackupAgentS
> *Agente: `@backend-specialist` — Atualizado pós-homologação (2026-05-10)*

**Base URL:** `http://{SERVER_IP}:8095`  
**Encoding:** `application/json; charset=utf-8`  
**Framework:** Horse (Delphi)

---

## 1. Disparar Backup

**`POST /api/v1/backup/start`**

Inicia a pipeline de extração de forma **não-bloqueante**. Retorna imediatamente após enfileirar o job em `TTask`.

| Código | Situação | Body |
|--------|----------|------|
| `202 Accepted` | Job enfileirado | `{"status":"started","job_id":"<UUID>"}` |
| `409 Conflict` | Backup já em andamento | `{"error":"Um backup ja esta em andamento."}` |

---

## 2. Monitorar Progresso

**`GET /api/v1/backup/status`**

Polling a cada 2s pelo Terminal.

### Resposta `200 OK`
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "state_code": 2,
  "progress": 45,
  "message": "Verificando disco livre e iniciando snapshot..."
}
```

### Mapa de `state_code`

| Código | Enum | Significado |
|--------|------|-------------|
| `0` | `bsWaiting` | Aguardando |
| `1` | `bsConnecting` | Detectando banco e motor Firebird |
| `2` | `bsSnapshot` | Extração ativa via Services API / gbak |
| `3` | `bsHashing` | Calculando SHA-256 |
| `4` | `bsZipping` | Compactando .fbk → .zip |
| `5` | `bsReady` | **Pronto para download** |
| `6` | `bsError` | Falha — `message` contém o erro detalhado |

| Código | Situação |
|--------|----------|
| `404 Not Found` | Nenhum job iniciado |

---

## 3. Consultar Tamanho do Arquivo *(novo)*

**`HEAD /api/v1/backup/download`**

Retorna apenas os **headers HTTP** sem transferir o arquivo. Usado pelo Terminal para exibir o tamanho do ZIP antes de iniciar o download.

### Headers de Resposta

| Header | Tipo | Descrição |
|--------|------|-----------|
| `Content-Type` | `application/zip` | Tipo do arquivo |
| `Content-Length` | `integer` | Tamanho exato em bytes do ZIP gerado |

### Códigos

| Código | Situação |
|--------|----------|
| `200 OK` | Arquivo disponível. `Content-Length` retornado. |
| `400 Bad Request` | Backup não finalizado (state_code ≠ 5) |
| `404 Not Found` | Arquivo ZIP não encontrado no disco |

> 💡 **Uso no Terminal:** `FHttp.Head(URL)` → lê `Content-Length` → chama `showFileSize(bytes)` no HTML.

---

## 4. Download do Backup

**`GET /api/v1/backup/download`**

Transfere o arquivo `.zip` como stream binário puro. Timeout mínimo recomendado: **3 horas**.

### Headers de Resposta

| Header | Tipo | Descrição |
|--------|------|-----------|
| `Content-Type` | `application/zip` | Tipo do conteúdo |
| `Content-Length` | `integer` | Tamanho exato em bytes. Injetado via `RawWebResponse` (bypass Horse). |
| `X-SHA256` | `string` | Hash SHA-256 do ZIP. Comparado pelo Terminal após download. |

### Implementação Client-Side

```pascal
// 1. HEAD para obter tamanho antes de baixar
FAgentClient.GetDownloadSize(FileSizeBytes, SizeErr);
// → showFileSize(FileSizeBytes) no HTML

// 2. GET com TFileStream (sem explodir RAM)
FAgentClient.DownloadBackup(LocalPath, ServerHash, ErrMsg);

// 3. Validação criptográfica local
LocalHash := TCryptoUtils.CalculateSHA256(LocalPath);
Assert(SameText(LocalHash, ServerHash), 'INTEGRIDADE COMPROMETIDA!');
```

| Código | Situação |
|--------|----------|
| `200 OK` | Stream iniciado |
| `400 Bad Request` | Backup não finalizado |
| `404 Not Found` | ZIP não encontrado |

---

## 5. Validar Credenciais Admin *(planejado — Fase 1.5)*

**`POST /api/v1/auth/validate`**

> ⚠️ **NÃO IMPLEMENTADO** — Aguardando sinal verde para Settings Screen.

Valida credenciais de administrador contra a tabela `VENDEDORES` do Digifarma6.

### Request Body
```json
{
  "login": "ADMIN",
  "senha_md5": "5f4dcc3b5aa765d61d8327deb882cf99"
}
```

### Lógica de Validação (Servidor)
```sql
SELECT COUNT(*) FROM VENDEDORES
WHERE ACESSO_ADM = 'S'
  AND SENHA = :senha_md5
  AND NOME = :login
```

| Código | Situação |
|--------|----------|
| `200 OK` | `{"authorized": true}` |
| `401 Unauthorized` | Credenciais inválidas ou sem permissão ADM |

---

## 6. Convenções de Nomenclatura de Arquivos

```
Bkp_{CNPJ}_{YYYY-MM-DD}_{HHmm}.zip
Exemplo: Bkp_02695980000110_2026-05-10_0238.zip
```

**Multi-banco (planejado):**
```
Bkp_{CNPJ}_{YYYY-MM-DD}_{HHmm}_Digifarma6.zip
Bkp_{CNPJ}_{YYYY-MM-DD}_{HHmm}_Farmachat.zip
Bkp_{CNPJ}_{YYYY-MM-DD}_{HHmm}_DFE.zip
```

---

## 7. Segurança e Isolamento de Rede

- Porta `8095` deve ser acessível apenas na LAN local.
- Sem autenticação por token no MVP (isolamento por rede física).
- O servidor rejeita inicialização se `DatabasePath` aponta para IP remoto.
