# OPERABILIDADE E SUSTENTAÇÃO
> *Agente: `@documentation-writer` — Atualizado em Homologação (2026-05-09)*

---

## Estrutura de Diretórios do Sistema

| Caminho | Criação | Função |
|---------|---------|--------|
| `C:\backup\BackupAgent\` | Automática (Server startup) | Arquivos de backup `.zip` e logs de diagnóstico |
| `C:\Install\arquivos\BackupAgent\logs\` | Manual (primeiro deploy) | Logs de auditoria estruturados (Roadmap) |
| `{pasta do exe}\ui\` | Automática (Terminal startup) | HTML/CSS/JS da interface WebView2 |
| `{pasta do exe}\WebView2Loader.dll` | Automática (Terminal startup) | DLL WebView2 extraída do recurso RCDATA |

---

## Configuração via Registro do Windows

### Chave Principal
```
HKEY_CURRENT_USER\DIGIFARMA\Database
```

**Formatos aceitos:**

| Valor | Comportamento |
|-------|--------------|
| `C:\Digifarma\Dados\Digifarma6.fdb` | → Modo Servidor ✅ |
| `192.168.0.2:C:\Digifarma\Dados\Digifarma6.fdb` | → Modo Terminal (Servidor rejeitará inicialização) ❌ |

### Fallback para Windows Service (Usuário SYSTEM)
Quando o serviço roda sob `SYSTEM` (sem `HKCU` configurado), o sistema **automaticamente** varre:
```
HKEY_USERS\{SID-do-usuário-administrador}\DIGIFARMA\Database
```

---

## Procedimentos Operacionais

### Deploy Inicial — Servidor

```bat
:: 1. Copiar BackupAgentS.exe para a pasta de instalação
:: 2. Instalar e iniciar o serviço
BackupAgentS.exe /install
net start BackupAgentSvc

:: 3. Verificar no Event Viewer do Windows ou via:
sc query BackupAgentSvc
```

### Atualização do Servidor

```bat
:: OBRIGATÓRIO: parar o serviço antes de substituir o exe
net stop BackupAgentSvc

:: Substituir BackupAgentS.exe pelo novo binário

:: Reiniciar
net start BackupAgentSvc
```

> ⚠️ **Não pule o `net stop`!** O compilador do Delphi reportará `F2039 Could not create output file` se o `.exe` estiver bloqueado pelo Service Manager.

### Deploy Inicial — Terminal

```bat
:: Apenas copiar os arquivos para a pasta destino
:: WebView2Loader.dll e ui/index.html são extraídos automaticamente na primeira abertura
xcopy BackupAgentT.exe C:\Digifarma\BackupAgent\ /Y
```

### Desinstalação do Servidor

```bat
net stop BackupAgentSvc
BackupAgentS.exe /uninstall
```

---

## Política de Retenção Automática

O servidor aplica automaticamente uma política de retenção de **7 dias** após cada backup bem-sucedido.

Arquivos `.zip` mais antigos que 7 dias em `C:\backup\BackupAgent\` são **excluídos automaticamente**.

> 💡 Para ajustar o período, edite a constante em `TSetupManager.ApplyRetentionPolicy`.

---

## Diagnóstico e Suporte

### Logs de Diagnóstico (Homologação)

| Arquivo | Conteúdo | Quando Usar |
|---------|----------|-------------|
| `C:\backup\BackupAgent\server_pipeline.log` | Rastreio passo a passo da pipeline de backup no Controller | Backup trava antes de atingir o motor FB |
| `C:\backup\BackupAgent\trace_fb5.log` | Rastreio interno do `TFB5BackupProvider` (FireDAC) | Backup trava dentro do motor FB5 |

> ⚠️ Esses arquivos são gerados apenas na versão de homologação. Devem ser removidos ou tornados condicionais antes do release de produção.

### Checklist de Suporte N1

Se o Terminal reportar erro após "Sinal Aceito (HTTP 202)":

1. **Verificar se o serviço está rodando:** `sc query BackupAgentSvc`
2. **Verificar Registro:** `HKCU\DIGIFARMA\Database` contém o caminho do banco?
3. **Verificar espaço em disco:** `C:\backup\` tem espaço ≥ 120% do tamanho do banco?
4. **Verificar Firebird:** O serviço `FirebirdServerDefaultInstance` está ativo?
5. **Exportar logs:** Coletar `server_pipeline.log` e `trace_fb5.log` para suporte N2.

### Checklist de Suporte N1 — Terminal não abre HTML

1. **Verificar WebView2:** Abrir Edge no computador. Se Edge abrir, WebView2 está instalado.
2. **Verificar arquivo:** `WebView2Loader.dll` existe na pasta do `BackupAgentT.exe`?
3. **VCL Fallback:** A interface VCL nativa funciona normalmente mesmo sem WebView2.

---

## Segurança de Rede

- Porta `8095` deve ser liberada no Firewall do Windows da máquina Servidor.
- Comunicação ocorre exclusivamente na LAN local da farmácia.
- Não há autenticação por token no MVP. O isolamento de rede é a camada de proteção primária.

```powershell
# Abrir porta 8095 no Firewall (executar como Administrador no Servidor)
netsh advfirewall firewall add rule name="BackupAgent API" dir=in action=allow protocol=TCP localport=8095
```
