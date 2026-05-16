# 📋 Plano de Execução: BackupAgent (MVP - Fase 1)

## 1. Diretrizes e Restrições
- **Projetos:** `BackupAgentS` (Agente Servidor) e `BackupAgentT` (Agente Terminal).
- **Ambiente:** Dinâmico via Registro do Windows (`HKCU\DIGIFARMA\Database`), abolindo o config.json.
- **Arquivos Locais:** Backups salvos obrigatoriamente em `C:\backup`.
- **Logs e Estado:** Salvos na pasta de instalação `C:\Install\arquivos\BackupAgent`.
- **Compatibilidade:** Foco principal em Firebird 5, com fallback limpo via Interface para Firebird 2.5.
- **MVP Fase 1:** Foco operacional local e rede interna (sem nuvem e sem Web UI). Interface VCL nativa simples focada em feedback e usabilidade de suporte.

## 2. Estrutura Física Windows (No Cliente)
```text
C:\
├── backup\                           # Destino final dos arquivos de backup (.zip)
└── Install\
    └── arquivos\
        └── BackupAgent\
            ├── state.json            # Estado persistido do backup (se necessário, o estado atual fica em memória)
            └── logs\                 # Logs rotativos de auditoria e erros (.txt)
```

## 3. Estrutura de Projetos e Units (Delphi)
A organização adotará divisão física e lógica para garantir o desacoplamento.
O projeto deve nascer em `C:\ProjetosIA\BackupAgent\src\`:

### 3.1. Camada Core (Regras e Contratos puros, sem acoplamento externo)
- `BackupAgent.Core.Interfaces.pas`
  - `IBackupProvider`: Contrato base (`Execute`, `GetProgress`).
  - `ILogger`: Contrato para gravação de logs.
- `BackupAgent.Core.Config.pas`
  - Classe `TConfigManager` para leitura do Registro do Windows e definição automática de AppMode.
- `BackupAgent.Core.Setup.pas`
  - Classe `TSetupManager` para auto-criação das pastas `C:\backup` e `C:\Install\...` em tempo de execução.
- `BackupAgent.Core.Crypto.pas`
  - Classe responsável pelo hashing SHA-256 e proteção do ZIP.
- `BackupAgent.Core.State.pas`
  - Classe `TStateManager` para gerenciar a máquina de estados (Aguardando, Snapshot, Compactando, Pronto, Erro) e refletir no `state.json`.

### 3.2. Camada de Infraestrutura (As implementações concretas)
- `BackupAgent.Infra.Firebird5.pas`
  - Implementa `IBackupProvider` usando `TFDConnection` e a Services API nativa para paralelismo.
- `BackupAgent.Infra.Firebird25.pas`
  - Implementa `IBackupProvider` para o parque legado (pode iniciar usando command-line do `gbak` encapsulado ou adapter de API antiga).
- `BackupAgent.Infra.ProviderFactory.pas`
  - Classe de injeção e fábrica. Baseado na detecção inicial, devolve a instância correta do provedor.
- **Log Centralizado (LoggerPro)**
  - O sistema global de logs é ancorado em `BackupAgent.Core.Setup.pas` e os arquivos são rotacionados utilizando o padrão robusto do `LoggerPro`.

### 3.3. Agente Servidor (`BackupAgentS.dpr` / `BackupAgent.Server.Service.pas`)
- Responsável por rodar o motor. Suporta execução dupla: **Console Application** e **Windows Service**.
- `BackupAgent.Server.API.pas`: Mapeamento de rotas HTTP com o micro-framework *Horse*.
- `BackupAgent.Server.Controller.pas`:
  - `POST /api/v1/backup/start`: Recebe gatilho, inicia processamento `Fire-and-forget` via **OmniThreadLibrary (`Parallel.Async`)** e devolve *HTTP 202*.
  - `GET /api/v1/backup/status`: Devolve o status/progresso em JSON.
  - `GET /api/v1/backup/download`: Rota de streaming do ZIP (retorna o header `X-SHA256`).

### 3.4. Agente Terminal (`BackupAgentT.dpr`)
- Projeto VCL tradicional (Form). Focado apenas na parte visual.
- `BackupAgent.Terminal.Main.pas`: Tela limpa com "Progresso", "Status Atual" e botões diretos.
- `BackupAgent.Terminal.Client.pas`: Usa o componente nativo `TNetHTTPClient` do Delphi para chamar a API REST do `BackupAgentS` (polling a cada ~2s).

## 4. Fluxo de Execução do MVP (O Caminho Feliz)
1. **Trigger (AT -> AS):** O usuário clica em "Iniciar Backup" no `BackupAgentT`. A VCL faz o `POST /start` pro Servidor.
2. **Inicialização Assíncrona:** O `BackupAgentS` lê o CNPJ, valida a versão do banco via Factory e cria a rotina em uma Thread paralela (`TTask`). Retorna o controle pra UI imediatamente.
3. **Geração (Local no Servidor):** O Servidor roda o dump (`.fbk`), compacta para `.zip` protegido com senha e armazena em `C:\backup` do Servidor. Atualiza o `state.json` constantemente.
4. **Monitoramento (Polling):** O `BackupAgentT` (na rede) bate no `/status` de forma silenciosa e atualiza a VCL.
5. **Distribuição:** Quando status é "Pronto", o `BackupAgentT` executa `GET /download` e salva o espelho no `C:\backup` da própria máquina local.
6. **Encerramento:** Ambos (Servidor e Terminal) registram a conclusão nos arquivos de log.

## 5. Checklist de Implementação Inicial (Próximos Passos)
- [ ] 1. Inicializar pastas base do projeto em `C:\ProjetosIA\BackupAgent`.
- [ ] 2. Implementar contratos em `BackupAgent.Core.Interfaces`.
- [ ] 3. Criar a estrutura do `config.json` e a classe `BackupAgent.Core.Config`.
- [ ] 4. Implementar sistema base de logs locais e state (`BackupAgent.Core.State` e Logger).
- [ ] 5. Estruturar o `BackupAgentS` com framework Horse (porta, rota de teste).
- [ ] 6. Criar Factory e casca do `BackupAgent.Infra.Firebird5` (para mock e validação inicial de fluxo).

## Fases de Implementação

- [x] **Fase 1: Infraestrutura Core** (Setup, Config, Interfaces e Provider Factory)
- [x] **Fase 2: Motor de Backup (Server)** (Controllers, ZIP, Crypto e Integração FireDAC nativa)
- [x] **Fase 3: Rede e Terminal (Client)** (VCL, THTTPClient, validação SHA-256 e Streaming HTTP)
- [x] **Fase 4: Implantação e Windows Service** (TService, OmniThreadLibrary, LoggerPro)
