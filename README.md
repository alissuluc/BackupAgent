# BackupAgent

Sistema gerenciador de backups automatizados, desenvolvido em Delphi. O **BackupAgent** é responsável por garantir a integridade, compactação e segurança dos dados através de rotinas programadas e logs detalhados de operação.

## 🚀 Visão Geral

O projeto visa fornecer uma solução de backup confiável, rodando muitas vezes como serviço (ou rotina em background), garantindo que as informações críticas estejam sempre salvas e prontas para restauração.

## ✨ Funcionalidades

- **Backups Automatizados:** Execução de cópias de segurança em segundo plano.
- **Compactação e Criptografia:** Proteção de dados durante o armazenamento.
- **Relatórios e Logs:** Registro detalhado de cada operação de backup para fácil auditoria.
- **Alertas Proativos:** Notificações em caso de falha nas rotinas de cópia.

## 🛠 Tecnologias

- **Linguagem:** Delphi / Object Pascal
- **Arquitetura:** Agente / Background Service API (Horse)
- **Concorrência e Multithreading:** OmniThreadLibrary (OTL)
- **Log e Auditoria:** LoggerPro (Console & File Appenders)
- **Controle de Versão:** Git / GitHub

## 📂 Versionamento

Para contribuir com o projeto:
1. Crie uma branch a partir da `main` (`feature/novo-recurso`).
2. Faça os commits seguindo o padrão (`feat: adiciona rotina de FTP`).
3. Envie para o GitHub e abra um Pull Request.
