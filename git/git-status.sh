#!/bin/bash

# Opções para robustez
# set -e # Descomente para sair imediatamente em caso de erro (pode precisar de ajustes no tratamento de erro)
set -o pipefail # Falha o pipeline se algum comando intermediário falhar

# Cores para output (se o terminal suportar)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arrays globais para armazenar informações coletadas
declare -A repo_has_uncommitted_changes # Associa caminho do repo com true/false
declare -A repo_original_branch       # Associa caminho do repo com o branch original
pull_candidates=()                    # Lista de strings: "repo_path:local_branch:upstream_branch:original_branch_in_repo"
push_candidates=()                    # Lista de strings: "repo_path:local_branch:upstream_branch:ahead_count"
diverged_branches=()                  # Lista de strings: "repo_path:local_branch:upstream_branch:ahead_count:behind_count"
local_only_branches=()                # Lista de strings: "repo_path:local_branch"

# --- FUNÇÕES AUXILIARES ---

# Função para obter a raiz de um repositório Git a partir de um diretório dentro dele
get_repo_root() {
    local dir="$1"
    # Verifica se o diretório fornecido já é a raiz ou contém um arquivo .git (para submódulos)
    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
        # Se .git é um diretório, é a raiz de um repo normal.
        # Se .git é um arquivo, pode ser a raiz de um worktree ou submódulo.
        # Para simplificar, vamos usar git rev-parse para encontrar a raiz de forma consistente.
        : # No-op, a lógica abaixo cuidará disso.
    fi

    local root_dir
    # Tenta obter o diretório de nível superior do Git a partir do diretório fornecido
    root_dir=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
    if [[ $? -eq 0 && -n "$root_dir" ]]; then
        echo "$root_dir"
    else
        # Se falhar, talvez o diretório não seja parte de um repo Git
        return 1
    fi
}


# --- FUNÇÃO PRINCIPAL DE VERIFICAÇÃO POR REPOSITÓRIO ---
check_repo() {
    local repo_dir="$1"
    echo -e "\n🔍 ${BLUE}Verificando repositório:${NC} $repo_dir"

    # Salva o diretório atual para poder retornar depois
    local original_pwd
    original_pwd=$(pwd)

    if ! cd "$repo_dir"; then
        echo -e "  ${RED}Erro: Não foi possível acessar o diretório $repo_dir.${NC}"
        return
    fi

    # 1. Salvar branch original do repositório
    repo_original_branch["$repo_dir"]=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -z "${repo_original_branch["$repo_dir"]}" ]]; then
        # Pode ser um repositório vazio ou em detached HEAD
        echo -e "  ${YELLOW}Aviso: Nenhum branch ativo em $repo_dir ou repositório não inicializado/vazio.${NC}"
    fi

    # 2. Git Fetch para atualizar informações remotas
    echo -e "  🔄 ${BLUE}Buscando atualizações remotas (git fetch --all --prune)...${NC}"
    # O --quiet suprime a saída normal do fetch. Erros ainda podem ir para stderr.
    if ! git fetch --all --prune --quiet; then
        echo -e "  ${YELLOW}Aviso: 'git fetch' pode ter tido problemas em $repo_dir. As informações podem estar desatualizadas.${NC}"
        # Considerar se deve retornar aqui ou continuar com dados possivelmente desatualizados. Por ora, continua.
    fi

    # 3. Verificar alterações locais não commitadas
    if [[ -n "$(git status --porcelain)" ]]; then
        echo -e "  ${YELLOW}⚠️  Possui alterações locais não commitadas.${NC}"
        repo_has_uncommitted_changes["$repo_dir"]="true"
    else
        repo_has_uncommitted_changes["$repo_dir"]="false"
    fi

    # 4. Iterar sobre todos os branches locais
    local branches
    branches=$(git for-each-ref --format='%(refname:short)' refs/heads/)
    if [[ -z "$branches" ]]; then
        echo -e "  ${YELLOW}Nenhum branch local encontrado (repositório pode ser novo/vazio).${NC}"
        cd "$original_pwd" > /dev/null # Voltar ao diretório original do script
        return
    fi

    for local_branch in $branches; do
        local upstream_branch
        # Tenta obter o nome do branch remoto que o branch local está rastreando
        upstream_branch=$(git rev-parse --abbrev-ref "$local_branch@{u}" 2>/dev/null)

        if [[ -z "$upstream_branch" ]]; then
            # Se não há upstream, é um branch apenas local
            # echo -e "    ${BLUE}Branch local '$local_branch':${NC} Sem rastreamento remoto (apenas local)."
            local_only_branches+=("$repo_dir:$local_branch")
            continue
        fi

        # Comparar o branch local com seu upstream
        local counts ahead behind
        # shellcheck disable=SC2086 # A expansão de $local_branch...$upstream_branch é intencional aqui
        counts=$(git rev-list --left-right --count "$local_branch...$upstream_branch" 2>/dev/null)
        
        if [[ $? -ne 0 ]]; then
             # Isso pode acontecer se o branch remoto foi deletado após o fetch, ou nome inválido
             echo -e "    ${YELLOW}Branch local '$local_branch':${NC} Não foi possível comparar com ${BLUE}'$upstream_branch'${NC}. Pode ter sido deletado remotamente ou nome inválido."
             continue
        fi

        ahead=$(echo "$counts" | cut -f1)
        behind=$(echo "$counts" | cut -f2)

        # Classificar e registrar o estado do branch
        if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
            echo -e "    ${GREEN}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): Sincronizado ✅"
        elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
            echo -e "    ${YELLOW}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): Desatualizado 🔽 (precisa de pull - $behind commits)"
            pull_candidates+=("$repo_dir:$local_branch:$upstream_branch:${repo_original_branch["$repo_dir"]}")
        elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
            echo -e "    ${BLUE}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): À frente 🔼 (precisa de push - $ahead commits)"
            push_candidates+=("$repo_dir:$local_branch:$upstream_branch:$ahead")
        else # ahead > 0 && behind > 0
            echo -e "    ${RED}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): Divergente ❗ (ahead $ahead, behind $behind)"
            diverged_branches+=("$repo_dir:$local_branch:$upstream_branch:$ahead:$behind")
        fi
    done

    cd "$original_pwd" > /dev/null # Voltar ao diretório original do script
}

# --- FUNÇÃO PARA LIDAR COM PULLS ---
handle_pulls() {
    if [ ${#pull_candidates[@]} -eq 0 ]; then
        echo -e "\n${GREEN}✨ Nenhum branch precisa de pull.${NC}"
        return
    fi

    echo -e "\n🔧 ${YELLOW}Os seguintes branches estão desatualizados e podem ser atualizados (pull):${NC}"
    for i in "${!pull_candidates[@]}"; do
        # Desmembra a string de informação do candidato a pull
        IFS=':' read -r repo_path local_b upstream_b _ <<< "${pull_candidates[$i]}"
        echo -e "  $(($i+1))) Repositório: ${BLUE}$repo_path${NC} | Branch: ${YELLOW}$local_b${NC} (desatualizado de ${BLUE}$upstream_b${NC})"
    done

    echo # Linha em branco para formatação
    PS3=$'\nEscolha uma opção para pull (ou digite o número): '
    options=("Sim, atualizar todos os branches listados" "Sim, escolher individualmente quais atualizar" "Não, não fazer pull agora")
    
    # Loop para garantir que uma opção válida seja escolhida
    while true; do
        select opt in "${options[@]}"; do
            case $opt in
                "Sim, atualizar todos os branches listados")
                    for item in "${pull_candidates[@]}"; do
                        process_pull_item "$item" "all"
                    done
                    return # Sai da função handle_pulls
                    ;;
                "Sim, escolher individualmente quais atualizar")
                    for item in "${pull_candidates[@]}"; do
                        process_pull_item "$item" "individual"
                    done
                    return # Sai da função handle_pulls
                    ;;
                "Não, não fazer pull agora")
                    echo -e "${BLUE}❌ Nenhuma ação de pull realizada.${NC}"
                    return # Sai da função handle_pulls
                    ;;
                *) 
                    echo -e "${RED}Opção inválida $REPLY. Por favor, tente novamente.${NC}"
                    break # Sai do select interno para repetir o prompt
                    ;;
            esac
        done
    done
}

# Função para processar um item individual da lista de pull
process_pull_item() {
    local item="$1"
    local mode="$2" # "all" ou "individual"
    
    # Desmembra a string de informação do item
    IFS=':' read -r repo_path local_b_to_pull upstream_b original_b_repo_when_checked <<< "$item"

    if [[ "$mode" == "individual" ]]; then
        read -r -p $"  Pull branch '${YELLOW}$local_b_to_pull${NC}' em '${BLUE}$repo_path${NC}'? (s/N): " choice
        if [[ ! "$choice" =~ ^[Ss]$ ]]; then
            echo -e "  ⏭️  ${BLUE}Pull de '$local_b_to_pull' em '$repo_path' pulado.${NC}"
            return
        fi
    fi

    echo -e "\n➡️  ${BLUE}Processando pull para branch '$local_b_to_pull' em '$repo_path'...${NC}"
    
    local original_pwd_pull_item
    original_pwd_pull_item=$(pwd)

    if ! cd "$repo_path"; then
        echo -e "  ${RED}Erro: Não foi possível acessar o diretório $repo_path para pull.${NC}"
        return
    fi

    local current_branch_in_repo_now # Branch ativo no momento da operação de pull
    current_branch_in_repo_now=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local did_stash_for_this_operation=false
    local stashed_on_branch="$current_branch_in_repo_now" # Branch onde o stash foi efetivamente feito

    # Re-verificar alterações não commitadas no REPOSITÓRIO no momento da ação
    # A informação de repo_has_uncommitted_changes pode estar desatualizada se o usuário mexeu nos arquivos
    local current_uncommitted_status
    current_uncommitted_status=$(git status --porcelain)

    if [[ -n "$current_uncommitted_status" ]]; then
        read -r -p $"  ⚠️  O repositório '$repo_path' tem alterações locais (atualmente no branch '$current_branch_in_repo_now'). Fazer 'git stash' antes de prosseguir com o pull de '$local_b_to_pull'? (s/N): " stash_choice
        if [[ "$stash_choice" =~ ^[Ss]$ ]]; then
            echo -e "    ${BLUE}Fazendo stash das alterações em '$current_branch_in_repo_now'...${NC}"
            # Usar -u para incluir arquivos não rastreados no stash
            if git stash push -u -m "Autostash by sync_script for pulling $local_b_to_pull"; then
                echo -e "    ${GREEN}Stash criado com sucesso.${NC}"
                did_stash_for_this_operation=true
                # Atualiza o estado global, embora seja melhor confiar na verificação local para a próxima vez
                repo_has_uncommitted_changes["$repo_path"]="false" 
            else
                echo -e "    ${RED}Falha ao criar stash. Pull de '$local_b_to_pull' abortado para este repositório.${NC}"
                cd "$original_pwd_pull_item" > /dev/null
                return
            fi
        else
            echo -e "  ${YELLOW}Pull de '$local_b_to_pull' em '$repo_path' abortado devido a alterações locais não stasheadas.${NC}"
            cd "$original_pwd_pull_item" > /dev/null
            return
        fi
    fi

    # Checkout para o branch a ser atualizado, se não for o atual
    if [[ "$local_b_to_pull" != "$current_branch_in_repo_now" ]]; then
        echo -e "  ${BLUE}Fazendo checkout do branch '$local_b_to_pull'...${NC}"
        if ! git checkout "$local_b_to_pull"; then
            echo -e "  ${RED}Falha ao fazer checkout do branch '$local_b_to_pull'. Verifique o estado do repositório.${NC}"
            # Se um stash foi feito AGORA para o branch original, ele permanece.
            if $did_stash_for_this_operation; then
                 echo -e "  ${YELLOW}Lembre-se que um stash foi feito no branch '$stashed_on_branch'.${NC}"
            fi
            cd "$original_pwd_pull_item" > /dev/null
            return
        fi
        # Atualiza o branch ativo após o checkout bem-sucedido
        current_branch_in_repo_now="$local_b_to_pull"
    fi

    # Realizar o Pull
    # Extrair nome do remoto e nome do branch remoto do upstream_b (ex: origin/main -> origin main)
    local remote_name remote_branch_name
    remote_name=$(echo "$upstream_b" | cut -d/ -f1)
    remote_branch_name=$(echo "$upstream_b" | cut -d/ -f2-) # Pega tudo após a primeira barra

    echo -e "  ${BLUE}Tentando 'git pull --ff-only $remote_name $remote_branch_name'...${NC}"
    if git pull --ff-only "$remote_name" "$remote_branch_name"; then
        echo -e "  ${GREEN}Pull (fast-forward) bem-sucedido para '$local_b_to_pull'.${NC}"
    else
        echo -e "  ${YELLOW}Pull (fast-forward) falhou. Isso pode significar que o branch local divergiu ou precisa de um merge.${NC}"
        read -r -p $"    Tentar 'git pull $remote_name $remote_branch_name' (pode criar um merge commit ou rebase, dependendo da config)? (s/N): " regular_pull_choice
        if [[ "$regular_pull_choice" =~ ^[Ss]$ ]]; then
            if git pull "$remote_name" "$remote_branch_name"; then
                 echo -e "  ${GREEN}Pull (com merge/rebase) bem-sucedido para '$local_b_to_pull'.${NC}"
            else
                 echo -e "  ${RED}Pull normal também falhou para '$local_b_to_pull'. Requer intervenção manual.${NC}"
            fi
        else
            echo -e "  ${YELLOW}Pull para '$local_b_to_pull' não completado.${NC}"
        fi
    fi

    # Restaurar Stash, se foi feito
    if $did_stash_for_this_operation; then
        # Voltar para o branch onde o stash foi feito, se diferente do branch atual (local_b_to_pull)
        # Isso é importante se o stash foi feito em um branch X, e o pull foi feito em Y
        if [[ "$current_branch_in_repo_now" != "$stashed_on_branch" ]]; then
            echo -e "  ${BLUE}Voltando para o branch '$stashed_on_branch' para aplicar o stash...${NC}"
            if ! git checkout "$stashed_on_branch"; then
                echo -e "  ${RED}Falha ao voltar para '$stashed_on_branch'. O stash não será aplicado automaticamente.${NC}"
                echo -e "  ${YELLOW}Use 'git stash apply' ou 'git stash pop' manualmente no branch '$stashed_on_branch'.${NC}"
                # Mesmo com essa falha, tentamos voltar ao branch original do repositório
                if [[ "$(git rev-parse --abbrev-ref HEAD)" != "$original_b_repo_when_checked" && -n "$original_b_repo_when_checked" ]]; then
                    git checkout "$original_b_repo_when_checked" > /dev/null 2>&1 || echo -e "  ${YELLOW}Aviso: não foi possível voltar para o branch original do repositório '$original_b_repo_when_checked'.${NC}"
                fi
                cd "$original_pwd_pull_item" > /dev/null
                return
            fi
            # Atualiza o branch ativo após o checkout para o stash
             current_branch_in_repo_now="$stashed_on_branch"
        fi

        echo -e "  ${BLUE}Restaurando stash...${NC}"
        if git stash pop; then # Tenta aplicar e remover o último stash
            echo -e "  ${GREEN}Stash restaurado com sucesso.${NC}"
            repo_has_uncommitted_changes["$repo_path"]="true" # Marcar que as alterações voltaram
        else
            echo -e "  ${RED}Falha ao restaurar o stash (possível conflito). Resolva manualmente em '$repo_path'.${NC}"
            echo -e "  ${YELLOW}O stash ainda pode estar lá. Use 'git stash list' e 'git stash apply <stash_id>'.${NC}"
            # Mesmo com falha no pop, as alterações podem ter sido parcialmente aplicadas.
            repo_has_uncommitted_changes["$repo_path"]="true"
        fi
    fi

    # Voltar ao branch original do REPOSITÓRIO (o que estava ativo quando check_repo começou para este repo)
    # apenas se o branch atual não for ele e se ele existir.
    local final_current_branch_in_repo
    final_current_branch_in_repo=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ "$final_current_branch_in_repo" != "$original_b_repo_when_checked" && -n "$original_b_repo_when_checked" ]]; then
        echo -e "  ${BLUE}Voltando para o branch original do repositório ('$original_b_repo_when_checked')...${NC}"
        if ! git checkout "$original_b_repo_when_checked"; then
            echo -e "  ${YELLOW}Aviso: Não foi possível voltar para o branch original do repositório '$original_b_repo_when_checked'. Pode ser necessário fazer checkout manualmente.${NC}"
        fi
    fi

    cd "$original_pwd_pull_item" > /dev/null # Voltar ao diretório de onde o script foi chamado
}


# --- SCRIPT PRINCIPAL ---
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}   Verificador de Status de Repositórios Git   ${NC}"
echo -e "${BLUE}===============================================${NC}"

# Array para rastrear raízes de repositório já processadas
declare -A processed_repo_roots

# Encontrar todos os diretórios .git e obter a raiz do repositório para cada um
# Usar -print0 e read -d '' para lidar com nomes de arquivo/diretório com espaços ou caracteres especiais
find . -type d -name ".git" -print0 | while IFS= read -r -d $'\0' git_dir_found; do
    # dirname "$git_dir_found" nos dá o diretório que contém .git, que é a raiz do repo
    repo_root_candidate=$(get_repo_root "$(dirname "$git_dir_found")")
    if [[ -n "$repo_root_candidate" && -z "${processed_repo_roots["$repo_root_candidate"]}" ]]; then
        check_repo "$repo_root_candidate"
        processed_repo_roots["$repo_root_candidate"]=1
    fi
done

# Caso o script seja executado de dentro de um repositório Git que não tenha sub-repositórios .git
if [[ ${#processed_repo_roots[@]} -eq 0 ]]; then
    current_dir_as_repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$current_dir_as_repo_root" && -z "${processed_repo_roots["$current_dir_as_repo_root"]}" ]]; then
        echo "Nenhum sub-repositório .git encontrado, verificando o diretório atual como um repositório Git..."
        check_repo "$current_dir_as_repo_root"
        processed_repo_roots["$current_dir_as_repo_root"]=1
    fi
fi


if [[ ${#processed_repo_roots[@]} -eq 0 ]]; then
    echo -e "\n${RED}Nenhum repositório Git encontrado para verificar.${NC}"
    exit 0
fi

# Relatório Final (Resumido)
echo -e "\n${BLUE}================= RESUMO ====================${NC}"
# Verifica se o array associativo tem chaves antes de iterar
# shellcheck disable=SC2145 # Comportamento de arrays associativos em bash
if [[ ${#repo_has_uncommitted_changes[@]} -gt 0 ]]; then
    local uncommitted_found=false
    for repo_path_key in "${!repo_has_uncommitted_changes[@]}"; do
        if [[ "${repo_has_uncommitted_changes[$repo_path_key]}" == "true" ]]; then
            if ! $uncommitted_found; then
                 echo -e "\n${YELLOW}Repositórios com alterações locais não commitadas:${NC}"
                 uncommitted_found=true
            fi
            echo -e "  - $repo_path_key"
        fi
    done
fi

if [[ ${#pull_candidates[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Branches que precisam de PULL:${NC}"
    for item in "${pull_candidates[@]}"; do
        IFS=':' read -r repo_path_item local_b_item upstream_b_item _ <<< "$item"
        echo -e "  - Repo: $repo_path_item | Branch: $local_b_item (de $upstream_b_item)"
    done
else
    echo -e "\n${GREEN}✅ Todos os branches rastreados estão sincronizados ou à frente do remoto (nenhum pull necessário).${NC}"
fi

if [[ ${#push_candidates[@]} -gt 0 ]]; then
    echo -e "\n${BLUE}Branches com commits locais para PUSH:${NC}"
    for item in "${push_candidates[@]}"; do
        IFS=':' read -r repo_path_item local_b_item upstream_b_item ahead_c_item <<< "$item"
        echo -e "  - Repo: $repo_path_item | Branch: $local_b_item (para $upstream_b_item, $ahead_c_item commits à frente)"
    done
fi

if [[ ${#diverged_branches[@]} -gt 0 ]]; then
    echo -e "\n${RED}Branches DIVERGENTES (requerem atenção manual):${NC}"
    for item in "${diverged_branches[@]}"; do
        IFS=':' read -r repo_path_item local_b_item upstream_b_item ahead_c_item behind_c_item <<< "$item"
        echo -e "  - Repo: $repo_path_item | Branch: $local_b_item (de $upstream_b_item, $ahead_c_item à frente, $behind_c_item atrás)"
    done
fi

if [[ ${#local_only_branches[@]} -gt 0 ]]; then
    echo -e "\n${BLUE}Branches APENAS LOCAIS (sem rastreamento remoto):${NC}"
    for item in "${local_only_branches[@]}"; do
        IFS=':' read -r repo_path_item local_b_item <<< "$item"
        echo -e "  - Repo: $repo_path_item | Branch: $local_b_item"
    done
fi
echo -e "${BLUE}===============================================${NC}"

# Lidar com pulls, se houver candidatos
if [[ ${#pull_candidates[@]} -gt 0 ]]; then
    handle_pulls
fi

echo -e "\n${GREEN}Verificação concluída.${NC}"
