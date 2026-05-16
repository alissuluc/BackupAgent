import os
import sys

def lint_delphi_files(root_dir):
    errors = 0
    warnings = 0
    print(f"[INFO] Iniciando Linting do Projeto Delphi em: {root_dir}\n")
    
    if not os.path.exists(root_dir):
        print(f"[ERRO CRITICO] Diretorio {root_dir} nao encontrado.")
        sys.exit(1)

    for dirpath, _, filenames in os.walk(root_dir):
        for file in filenames:
            if file.endswith('.pas') or file.endswith('.dpr'):
                filepath = os.path.join(dirpath, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        lines = f.readlines()
                except Exception as e:
                    print(f"[ERRO] Nao foi possivel ler {file}: {str(e)}")
                    continue
                    
                for i, line in enumerate(lines):
                    # Padrões Anti-Pattern Delphi
                    if 'Application.ProcessMessages' in line:
                        print(f"[ERRO] {file}:{i+1} Uso de Application.ProcessMessages bloqueia o event loop de forma imprevisível. Use TTask ou TThread.")
                        errors += 1
                    if 'Sleep(' in line and 'TODO' not in line and 'MOCK' not in line:
                        print(f"[AVISO] {file}:{i+1} Funcao Sleep() bloqueante detectada em producao. Certifique-se de que está dentro de uma TTask.")
                        warnings += 1
                    # Validação de Arquitetura Limpa e Caminhos
                    if 'C:\\' in line.upper() and 'C:\\BACKUP' not in line.upper() and 'C:\\INSTALL' not in line.upper():
                        print(f"[AVISO] {file}:{i+1} Caminho hardcoded fora dos padroes de instalacao detectado: {line.strip()}")
                        warnings += 1
                    # Vazamento de memória
                    if '.Create(' in line and 'try' not in lines[i+1] and 'try' not in "".join(lines[max(0, i-2):i+3]):
                        # Heurística simples de vazamento de memória para alertar desenvolvedor
                        print(f"[AVISO] {file}:{i+1} Criacao de objeto sem try/finally visivel na proximidade. Checar Memory Leak: {line.strip()}")
                        warnings += 1
                        
    print("\n" + "="*50)
    print(f"Resultado Final do Linter: {errors} Erros Criticos | {warnings} Avisos")
    if errors > 0:
        print("[FALHA] LINT FALHOU. Codigo nao esta adequado para commit/deploy na Fase 1.")
        sys.exit(1)
    else:
        print("[SUCESSO] LINT PASSOU. Codigo obedece as regras arquiteturais definidas.")
        sys.exit(0)

if __name__ == '__main__':
    # Assume que o script é chamado da raiz do repositório BackupAgent
    target_dir = os.path.join(os.getcwd(), 'src')
    lint_delphi_files(target_dir)
