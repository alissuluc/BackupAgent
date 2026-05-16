# BackupAgent
> Sistema distribuído para extração, compactação e transferência segura de backups Firebird em ambientes corporativos Windows.

*Versão: Homologação FB5 + FB2.5 Concluída — 2026-05-10*

---

## 🎯 Propósito

Garantir integridade, segurança e auditabilidade na geração de backups para os clientes Digifarma, operando com **compatibilidade total** entre ambientes legados (Firebird 2.5) e modernos (Firebird 5.0), sem nenhuma configuração manual.

---

## 🏗️ Componentes

| Executável | Tipo | Função |
|-----------|------|--------|
| `BackupAgentS.exe` | **Windows Service** | Extrai o banco via Services API ou gbak, compacta e expõe via REST na porta 8095. |
| `BackupAgentT.exe` | **Aplicação Desktop** | Interface WebView2 + VCL fallback. Solicita, monitora, exibe tamanho pré-download e valida o backup. |

---

## 🚀 Quick Start

### Servidor
```bat
BackupAgentS.exe /install
net start BackupAgentSvc

:: Abrir porta no Firewall
netsh advfirewall firewall add rule name="BackupAgent API" dir=in action=allow protocol=TCP localport=8095
```

### Terminal
```bat
:: Apenas executar — sem instalação necessária
BackupAgentT.exe
```

1. Interface web abre automaticamente.
2. Clique **"Disparar Backup Seguro"**.
3. Antes do download, o tamanho exato do arquivo é exibido.
4. Após download, SHA-256 valida a integridade automaticamente.

---

## ✨ Funcionalidades Implementadas

- 🔍 **Zero-Config** — Registro do Windows como fonte de verdade (sem `.json`)
- 🔄 **Dual-Engine** — Firebird 5 (Services API) e Firebird 2.5 (gbak com lookup no Registro)
- 🛡️ **Proteção de Disco** — Bloqueia backup sem espaço suficiente
- 🗑️ **Retenção Automática** — Remove ZIPs com mais de 7 dias
- 🔐 **SHA-256 End-to-End** — Integridade verificada na transferência TCP
- 📦 **Tamanho Pré-Download** — `HEAD /download` mostra o tamanho exato antes de iniciar
- 🌐 **Interface Moderna** — WebView2 com design Digifarma + fallback VCL nativo
- ✖️ **Botão Fechar Seguro** — Desabilitado durante backup ativo, via `setInProgress`
- 🔧 **Modo Console/Service** — Dual-mode para dev e produção
- 📡 **API REST** — 4 endpoints na porta 8095

---

## 📁 Estrutura do Projeto

```
BackupAgent/
├── src/
│   ├── Core/          ← Interfaces, Estado, Crypto, Config, Setup
│   ├── Infra/         ← Adaptadores FB5 e FB2.5 + Factory
│   ├── Server/        ← Windows Service + API REST (Horse)
│   └── Terminal/      ← WebView2 + VCL + Client HTTP
└── docs/
    ├── README.md
    ├── ARCHITECTURE.md
    ├── API-CONTRACTS.md
    ├── DECISIONS.md           ← 12 ADRs documentadas
    ├── RUNTIME-FLOW.md        ← 7 fluxos ponta a ponta
    ├── IMPLEMENTATION-STATUS.md
    ├── OPERATIONS.md
    ├── LOGGING-AUDIT.md
    ├── RISKS-AND-TECH-DEBT.md
    └── ROADMAP-MVP.md
```

---

## 🔗 Documentação Técnica

| Documento | Descrição |
|-----------|-----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Diagrama de componentes e camadas |
| [API-CONTRACTS.md](API-CONTRACTS.md) | 5 endpoints (4 implementados + 1 planejado) |
| [DECISIONS.md](DECISIONS.md) | 12 ADRs com histórico de decisões |
| [RUNTIME-FLOW.md](RUNTIME-FLOW.md) | 7 fluxos ponta a ponta em ASCII |
| [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) | Checklist completo + plano Settings Screen |
| [OPERATIONS.md](OPERATIONS.md) | Deploy, atualização, suporte e diagnóstico |
| [LOGGING-AUDIT.md](LOGGING-AUDIT.md) | Estratégia de auditoria e rastreabilidade |
| [RISKS-AND-TECH-DEBT.md](RISKS-AND-TECH-DEBT.md) | 7 riscos mapeados + 6 itens de dívida |
| [ROADMAP-MVP.md](ROADMAP-MVP.md) | 4 Steps: Pré-Go-Live → Settings → Cloud |

---

## ⚙️ Requisitos de Sistema

| Componente | Servidor | Terminal |
|-----------|---------|---------|
| Windows | 10/11 ou Server 2019+ | 10/11 |
| Firebird | **2.5 ou 5.0** ✅ | Não necessário |
| Firebird 2.5 path | Detectado via Registro + paths físicos | — |
| Microsoft Edge/WebView2 | Não necessário | Recomendado (VCL fallback disponível) |
| RAM | 256MB | 128MB |
| Disco livre | ≥ 120% do tamanho do banco | ≥ tamanho do ZIP |
| Porta TCP | 8095 aberta no Firewall | — |

---

## 🧑‍💼 Desenvolvido por Digifarma
Homologação FB5 + FB2.5 concluída — 2026-05-10
