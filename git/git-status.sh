#!/bin/bash

# Opções para robustez
# set -e # Descomente para sair imediatamente em caso de erro (pode precisar de ajustes no tratamento de erro)
set -o pipefail # Falha o pipeline se algum comando intermediário falhar

# --- DETECTAR SHELL E VERIFICAR ALIAS ---
detect_shell_and_alias() {
    local current_shell
    local shell_config_file
    local alias_exists=false
    
    # Detectar o shell do usuário (não o shell do script)
    # Primeiro, tentar detectar pela variável de ambiente SHELL
    local user_shell
    user_shell=$(basename "${SHELL:-}")
    
    # Verificar também pelo processo pai se SHELL não estiver disponível
    if [[ -z "$user_shell" ]]; then
        user_shell=$(ps -p $PPID -o comm= 2>/dev/null | sed 's/^-//')
    fi
    
    # Detectar baseado no shell do usuário
    case "$user_shell" in
        *zsh*)
            current_shell="zsh"
            shell_config_file="$HOME/.zshrc"
            ;;
        *bash*)
            current_shell="bash"
            # Verificar arquivos de configuração do bash em ordem de preferência
            if [[ -f "$HOME/.bashrc" ]]; then
                shell_config_file="$HOME/.bashrc"
            elif [[ -f "$HOME/.bash_profile" ]]; then
                shell_config_file="$HOME/.bash_profile"
            elif [[ -f "$HOME/.profile" ]]; then
                shell_config_file="$HOME/.profile"
            else
                shell_config_file="$HOME/.bashrc"  # padrão
            fi
            ;;
        *fish*)
            current_shell="fish"
            shell_config_file="$HOME/.config/fish/config.fish"
            ;;
        *)
            # Fallback: tentar detectar pelas variáveis de ambiente do shell em execução
            if [[ -n "$ZSH_VERSION" ]]; then
                current_shell="zsh"
                shell_config_file="$HOME/.zshrc"
            elif [[ -n "$BASH_VERSION" ]]; then
                current_shell="bash"
                shell_config_file="$HOME/.bashrc"
            else
                current_shell="unknown ($user_shell)"
                shell_config_file="$HOME/.profile"
            fi
            ;;
    esac
    
    echo -e "${BLUE}🔍 Shell detectado: ${YELLOW}$current_shell${NC}"
    echo -e "${BLUE}📁 Arquivo de configuração: ${YELLOW}$shell_config_file${NC}"
    
    # Verificar se o alias 'repos' existe
    if command -v repos >/dev/null 2>&1 || alias repos >/dev/null 2>&1; then
        alias_exists=true
        echo -e "${GREEN}✅ Alias 'repos' já está configurado e ativo.${NC}"
    else
        echo -e "${YELLOW}⚠️  Alias 'repos' não encontrado.${NC}"
        
        # Verificar se existe no arquivo de configuração mas não está carregado
        if [[ -f "$shell_config_file" ]] && grep -q "alias repos=" "$shell_config_file"; then
            echo -e "${YELLOW}📝 Alias 'repos' encontrado em $shell_config_file, mas não está ativo na sessão atual.${NC}"
            echo -e "${BLUE}💡 Execute: ${YELLOW}source $shell_config_file${NC} ${BLUE}ou abra um novo terminal.${NC}"
        else
            suggest_alias_implementation "$current_shell" "$shell_config_file"
        fi
    fi
    
    return 0
}

suggest_alias_implementation() {
    local shell_type="$1"
    local config_file="$2"
    local script_url="https://alexandrealvaro.com.br/git/git-status.sh"
    
    echo -e "\n${BLUE}🛠️  SUGESTÃO DE IMPLEMENTAÇÃO DO ALIAS 'repos':${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
    
    case "$shell_type" in
        "zsh")
            echo -e "${YELLOW}Para ZSH, adicione a seguinte linha ao seu $config_file:${NC}"
            echo -e "${GREEN}alias repos='/bin/bash -c \"\$(curl -fsSL $script_url)\"'${NC}"
            ;;
        "bash")
            echo -e "${YELLOW}Para Bash, adicione a seguinte linha ao seu $config_file:${NC}"
            echo -e "${GREEN}alias repos='/bin/bash -c \"\$(curl -fsSL $script_url)\"'${NC}"
            ;;
        *)
            echo -e "${YELLOW}Para seu shell, adicione a seguinte linha ao arquivo $config_file:${NC}"
            echo -e "${GREEN}alias repos='/bin/bash -c \"\$(curl -fsSL $script_url)\"'${NC}"
            ;;
    esac
    
    echo -e "\n${BLUE}📋 PASSOS PARA IMPLEMENTAR:${NC}"
    echo -e "1. ${YELLOW}Abra o arquivo de configuração:${NC}"
    echo -e "   ${BLUE}nano $config_file${NC} ${YELLOW}ou${NC} ${BLUE}vim $config_file${NC}"
    echo -e "\n2. ${YELLOW}Adicione a linha do alias no final do arquivo${NC}"
    echo -e "\n3. ${YELLOW}Recarregue a configuração:${NC}"
    echo -e "   ${BLUE}source $config_file${NC}"
    echo -e "\n4. ${YELLOW}Ou simplesmente abra um novo terminal${NC}"
    
    echo -e "\n${BLUE}🎯 COMANDO RÁPIDO PARA ADICIONAR:${NC}"
    if [[ -w "$config_file" ]] || [[ ! -f "$config_file" ]]; then
        echo -e "${GREEN}echo \"alias repos='/bin/bash -c \\\"\\\$(curl -fsSL $script_url)\\\"'\" >> $config_file${NC}"
        echo -e "\n${YELLOW}Deseja que eu adicione automaticamente? (s/N):${NC} "
        read -r auto_add_choice
        if [[ "$auto_add_choice" =~ ^[Ss]$ ]]; then
            if echo "alias repos='/bin/bash -c \"\$(curl -fsSL $script_url)\"'" >> "$config_file"; then
                echo -e "${GREEN}✅ Alias adicionado com sucesso a $config_file!${NC}"
                echo -e "${BLUE}Execute: ${YELLOW}source $config_file${NC} ${BLUE}para ativar imediatamente.${NC}"
            else
                echo -e "${RED}❌ Erro ao adicionar alias. Verifique as permissões de $config_file${NC}"
            fi
        else
            echo -e "${BLUE}Você pode copiar e colar o comando acima para adicionar manualmente.${NC}"
        fi
    else
        echo -e "${RED}⚠️  Não é possível escrever em $config_file. Use sudo ou adicione manualmente:${NC}"
        echo -e "${YELLOW}sudo echo \"alias repos='/bin/bash -c \\\"\\\$(curl -fsSL $script_url)\\\"'\" >> $config_file${NC}"
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
}

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
gone_upstream_candidates=()           # Lista de strings: "repo_path:local_branch_to_prune:original_branch_in_repo"


# --- FUNÇÕES AUXILIARES ---

# Função para obter a raiz de um repositório Git a partir de um diretório dentro dele
get_repo_root() {
    local dir="$1"
    local root_dir
    root_dir=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
    if [[ $? -eq 0 && -n "$root_dir" ]]; then
        echo "$root_dir"
    else
        return 1
    fi
}


# --- FUNÇÃO PRINCIPAL DE VERIFICAÇÃO POR REPOSITÓRIO ---
check_repo() {
    local repo_dir="$1"
    echo -e "\n🔍 ${BLUE}Verificando repositório:${NC} $repo_dir"

    local original_pwd
    original_pwd=$(pwd)

    if ! cd "$repo_dir"; then
        echo -e "  ${RED}Erro: Não foi possível acessar o diretório $repo_dir.${NC}"
        return
    fi

    repo_original_branch["$repo_dir"]=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -z "${repo_original_branch["$repo_dir"]}" ]]; then
        echo -e "  ${YELLOW}Aviso: Nenhum branch ativo em $repo_dir ou repositório não inicializado/vazio.${NC}"
    fi

    echo -e "  🔄 ${BLUE}Buscando atualizações remotas (git fetch --all --prune)...${NC}"
    if ! git fetch --all --prune --quiet; then
        echo -e "  ${YELLOW}Aviso: 'git fetch' pode ter tido problemas em $repo_dir. As informações podem estar desatualizadas.${NC}"
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        echo -e "  ${YELLOW}⚠️  Possui alterações locais não commitadas.${NC}"
        repo_has_uncommitted_changes["$repo_dir"]="true"
    else
        repo_has_uncommitted_changes["$repo_dir"]="false"
    fi

    local branches
    branches=$(git for-each-ref --format='%(refname:short)' refs/heads/)
    if [[ -z "$branches" ]]; then
        echo -e "  ${YELLOW}Nenhum branch local encontrado (repositório pode ser novo/vazio).${NC}"
        cd "$original_pwd" > /dev/null 
        return
    fi

    # Loop para status de sincronia (pull, push, diverged, synced)
    for local_branch in $branches; do
        local upstream_branch
        upstream_branch=$(git rev-parse --abbrev-ref "$local_branch@{u}" 2>/dev/null)

        if [[ -z "$upstream_branch" ]]; then
            # Se não há upstream, pode ser apenas local ou o upstream foi removido.
            # A verificação de "gone" cuidará do segundo caso.
            # Adiciona a local_only_branches por enquanto, será filtrado depois se for "gone".
            local_only_branches+=("$repo_dir:$local_branch")
            continue # Pula a comparação de ahead/behind se não há upstream direto
        fi

        local counts ahead behind
        # shellcheck disable=SC2086 
        counts=$(git rev-list --left-right --count "$local_branch...$upstream_branch" 2>/dev/null)
        
        if [[ $? -ne 0 ]]; then
             # Esta condição agora é menos provável de ser a primeira a falhar se o upstream sumiu,
             # pois o `git rev-parse ...@{u}` já teria falhado ou retornado vazio.
             # Mas mantemos para robustez.
             echo -e "    ${YELLOW}Branch local '$local_branch':${NC} Não foi possível comparar com o upstream configurado ${BLUE}'$upstream_branch'${NC}. O branch remoto pode ter sido removido ou o nome é inválido."
             continue
        fi

        ahead=$(echo "$counts" | cut -f1)
        behind=$(echo "$counts" | cut -f2)

        if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
            echo -e "    ${GREEN}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): Sincronizado ✅"
        elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
            echo -e "    ${YELLOW}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): Desatualizado 🔽 (precisa de pull - $behind commits)"
            pull_candidates+=("$repo_dir:$local_branch:$upstream_branch:${repo_original_branch["$repo_dir"]}")
        elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
            echo -e "    ${BLUE}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): À frente 🔼 (precisa de push - $ahead commits)"
            push_candidates+=("$repo_dir:$local_branch:$upstream_branch:$ahead")
        else 
            echo -e "    ${RED}Branch local '$local_branch'${NC} (rastreia ${BLUE}'$upstream_branch'${NC}): Divergente ❗ (ahead $ahead, behind $behind)"
            diverged_branches+=("$repo_dir:$local_branch:$upstream_branch:$ahead:$behind")
        fi
    done

    # Loop dedicado para identificar branches com upstreams "gone"
    # Usar --no-color para simplificar o parsing do 'git branch -vv'
    # Usar substituição de processo para evitar problemas de subshell com modificação de array
    while IFS= read -r line; do
        if [[ "$line" == *": gone]"* ]]; then
            local gone_branch_name
            # Extrai o nome do branch. Remove o '*' inicial (se for o branch atual) e tudo após o primeiro espaço.
            gone_branch_name=$(echo "$line" | sed -e 's/^[ *]*//' -e 's/ .*//')
            
            local current_branch_in_repo_for_gone_check
            current_branch_in_repo_for_gone_check=$(git rev-parse --abbrev-ref HEAD)

            if [[ "$gone_branch_name" == "$current_branch_in_repo_for_gone_check" ]]; then
                 echo -e "    ${YELLOW}Branch local ATIVO '$gone_branch_name'${NC}: Upstream remoto removido. Não pode ser podado enquanto ativo."
            else
                 # Evitar duplicatas
                 local already_candidate=false
                 for existing_candidate in "${gone_upstream_candidates[@]}"; do
                     if [[ "$existing_candidate" == "$repo_dir:$gone_branch_name:"* ]]; then
                         already_candidate=true
                         break
                     fi
                 done
                 if ! $already_candidate; then
                    echo -e "    ${YELLOW}Branch local '$gone_branch_name'${NC}: Upstream remoto removido. Candidato para poda."
                    gone_upstream_candidates+=("$repo_dir:$gone_branch_name:${repo_original_branch["$repo_dir"]}")
                    
                    # Remover da lista de "apenas local" se estiver lá, pois agora sabemos que tinha um upstream que sumiu
                    for i in "${!local_only_branches[@]}"; do
                        if [[ "${local_only_branches[$i]}" == "$repo_dir:$gone_branch_name" ]]; then
                            unset 'local_only_branches[i]'
                            break 
                        fi
                    done
                 fi
            fi
        fi
    done < <(git branch -vv --no-color)


    # Reconstruir local_only_branches para remover índices vazios se algo foi removido
    local_only_branches_temp=("${local_only_branches[@]}")
    local_only_branches=()
    for item in "${local_only_branches_temp[@]}"; do
        local_only_branches+=("$item")
    done


    cd "$original_pwd" > /dev/null
}

# --- FUNÇÃO PARA LIDAR COM PULLS ---
handle_pulls() {
    if [ ${#pull_candidates[@]} -eq 0 ]; then
        return
    fi

    echo -e "\n🔧 ${YELLOW}Os seguintes branches estão desatualizados e podem ser atualizados (pull):${NC}"
    for i in "${!pull_candidates[@]}"; do
        IFS=':' read -r repo_path local_b upstream_b _ <<< "${pull_candidates[$i]}"
        echo -e "  $(($i+1))) Repositório: ${BLUE}$repo_path${NC} | Branch: ${YELLOW}$local_b${NC} (desatualizado de ${BLUE}$upstream_b${NC})"
    done

    echo 
    PS3=$'\nEscolha uma opção para pull (ou digite o número): '
    options=("Sim, atualizar todos os branches listados" "Sim, escolher individualmente quais atualizar" "Não, não fazer pull agora")
    
    while true; do
        select opt in "${options[@]}"; do
            case $opt in
                "Sim, atualizar todos os branches listados")
                    for item in "${pull_candidates[@]}"; do
                        process_pull_item "$item" "all"
                    done
                    return 
                    ;;
                "Sim, escolher individualmente quais atualizar")
                    for item in "${pull_candidates[@]}"; do
                        process_pull_item "$item" "individual"
                    done
                    return 
                    ;;
                "Não, não fazer pull agora")
                    echo -e "${BLUE}❌ Nenhuma ação de pull realizada.${NC}"
                    return 
                    ;;
                *) 
                    echo -e "${RED}Opção inválida $REPLY. Por favor, tente novamente.${NC}"
                    break 
                    ;;
            esac
        done
    done
}

# Função para processar um item individual da lista de pull
process_pull_item() {
    local item="$1"
    local mode="$2" 
    
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

    local current_branch_in_repo_now 
    current_branch_in_repo_now=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local did_stash_for_this_operation=false
    local stashed_on_branch="$current_branch_in_repo_now" 

    local current_uncommitted_status
    current_uncommitted_status=$(git status --porcelain)

    if [[ -n "$current_uncommitted_status" ]]; then
        read -r -p $"  ⚠️  O repositório '$repo_path' tem alterações locais (atualmente no branch '$current_branch_in_repo_now'). Fazer 'git stash' antes de prosseguir com o pull de '$local_b_to_pull'? (s/N): " stash_choice
        if [[ "$stash_choice" =~ ^[Ss]$ ]]; then
            echo -e "    ${BLUE}Fazendo stash das alterações em '$current_branch_in_repo_now'...${NC}"
            if git stash push -u -m "Autostash by sync_script for pulling $local_b_to_pull"; then
                echo -e "    ${GREEN}Stash criado com sucesso.${NC}"
                did_stash_for_this_operation=true
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

    if [[ "$local_b_to_pull" != "$current_branch_in_repo_now" ]]; then
        echo -e "  ${BLUE}Fazendo checkout do branch '$local_b_to_pull'...${NC}"
        if ! git checkout "$local_b_to_pull"; then
            echo -e "  ${RED}Falha ao fazer checkout do branch '$local_b_to_pull'. Verifique o estado do repositório.${NC}"
            if $did_stash_for_this_operation; then
                 echo -e "  ${YELLOW}Lembre-se que um stash foi feito no branch '$stashed_on_branch'.${NC}"
            fi
            cd "$original_pwd_pull_item" > /dev/null
            return
        fi
        current_branch_in_repo_now="$local_b_to_pull"
    fi

    local remote_name remote_branch_name
    remote_name=$(echo "$upstream_b" | cut -d/ -f1)
    remote_branch_name=$(echo "$upstream_b" | cut -d/ -f2-)

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

    if $did_stash_for_this_operation; then
        if [[ "$current_branch_in_repo_now" != "$stashed_on_branch" ]]; then
            echo -e "  ${BLUE}Voltando para o branch '$stashed_on_branch' para aplicar o stash...${NC}"
            if ! git checkout "$stashed_on_branch"; then
                echo -e "  ${RED}Falha ao voltar para '$stashed_on_branch'. O stash não será aplicado automaticamente.${NC}"
                echo -e "  ${YELLOW}Use 'git stash apply' ou 'git stash pop' manualmente no branch '$stashed_on_branch'.${NC}"
                if [[ "$(git rev-parse --abbrev-ref HEAD)" != "$original_b_repo_when_checked" && -n "$original_b_repo_when_checked" ]]; then
                    git checkout "$original_b_repo_when_checked" > /dev/null 2>&1 || echo -e "  ${YELLOW}Aviso: não foi possível voltar para o branch original do repositório '$original_b_repo_when_checked'.${NC}"
                fi
                cd "$original_pwd_pull_item" > /dev/null
                return
            fi
             current_branch_in_repo_now="$stashed_on_branch"
        fi

        echo -e "  ${BLUE}Restaurando stash...${NC}"
        if git stash pop; then 
            echo -e "  ${GREEN}Stash restaurado com sucesso.${NC}"
            repo_has_uncommitted_changes["$repo_path"]="true" 
        else
            echo -e "  ${RED}Falha ao restaurar o stash (possível conflito). Resolva manualmente em '$repo_path'.${NC}"
            echo -e "  ${YELLOW}O stash ainda pode estar lá. Use 'git stash list' e 'git stash apply <stash_id>'.${NC}"
            repo_has_uncommitted_changes["$repo_path"]="true"
        fi
    fi

    local final_current_branch_in_repo
    final_current_branch_in_repo=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ "$final_current_branch_in_repo" != "$original_b_repo_when_checked" && -n "$original_b_repo_when_checked" ]]; then
        echo -e "  ${BLUE}Voltando para o branch original do repositório ('$original_b_repo_when_checked')...${NC}"
        if ! git checkout "$original_b_repo_when_checked"; then
            echo -e "  ${YELLOW}Aviso: Não foi possível voltar para o branch original do repositório '$original_b_repo_when_checked'. Pode ser necessário fazer checkout manualmente.${NC}"
        fi
    fi

    cd "$original_pwd_pull_item" > /dev/null
}

# --- FUNÇÃO PARA LIDAR COM PODA DE BRANCHES ---
handle_pruning() {
    if [ ${#gone_upstream_candidates[@]} -eq 0 ]; then
        return
    fi

    echo -e "\n🌿 ${YELLOW}Os seguintes branches locais têm upstreams remotos ausentes e podem ser podados:${NC}"
    local display_index=1
    local valid_prune_options_for_select=() 
    local prune_map_for_select=() 

    for i in "${!gone_upstream_candidates[@]}"; do
        IFS=':' read -r repo_path branch_to_prune _ <<< "${gone_upstream_candidates[$i]}"
        echo -e "  $display_index) Repositório: ${BLUE}$repo_path${NC} | Branch: ${YELLOW}$branch_to_prune${NC}"
        valid_prune_options_for_select+=("Repo: $repo_path | Branch: $branch_to_prune")
        prune_map_for_select[$display_index]="${gone_upstream_candidates[$i]}"
        ((display_index++))
    done
    
    if [ ${#valid_prune_options_for_select[@]} -eq 0 ]; then
        echo -e "${GREEN}Nenhum branch elegível para poda interativa (branches ativos com upstreams ausentes foram ignorados para seleção).${NC}"
        return
    fi

    echo 
    PS3=$'\nEscolha uma opção para poda (ou digite o número): '
    options_for_select_menu=("Sim, podar todos os branches listados (exceto ativos)" "Sim, escolher individualmente quais podar" "Não, não podar branches agora")

    while true; do
        select opt_text in "${options_for_select_menu[@]}"; do
            case $opt_text in
                "Sim, podar todos os branches listados (exceto ativos)")
                    for item_to_prune in "${gone_upstream_candidates[@]}"; do 
                        process_prune_item "$item_to_prune" "all"
                    done
                    return 
                    ;;
                "Sim, escolher individualmente quais podar")
                    echo -e "${YELLOW}Escolha os branches para podar individualmente:${NC}"
                    local individual_choices_display=()
                    local individual_choices_map=()
                    local choice_idx=1
                    for item_to_prune_individual in "${gone_upstream_candidates[@]}"; do
                        IFS=':' read -r rp_ind br_ind _ <<< "$item_to_prune_individual"
                        individual_choices_display+=("Repo: $rp_ind | Branch: $br_ind")
                        individual_choices_map[$choice_idx]="$item_to_prune_individual"
                        ((choice_idx++))
                    done
                    individual_choices_display+=("Concluir seleção individual")

                    PS3_INDIVIDUAL="Podar qual branch? (ou 'Concluir'): "
                    select ind_choice_text in "${individual_choices_display[@]}"; do
                        if [[ "$ind_choice_text" == "Concluir seleção individual" ]]; then
                            break 
                        elif [[ -n "$REPLY" && "$REPLY" -le ${#individual_choices_map[@]} ]]; then
                            process_prune_item "${individual_choices_map[$REPLY]}" "individual_selected" 
                        else
                            echo -e "${RED}Opção inválida $REPLY.${NC}"
                        fi
                    done
                    return 
                    ;;
                "Não, não podar branches agora")
                    echo -e "${BLUE}❌ Nenhuma ação de poda realizada.${NC}"
                    return 
                    ;;
                *) 
                    echo -e "${RED}Opção inválida $REPLY. Por favor, tente novamente.${NC}"
                    break 
                    ;;
            esac
        done
    done
}

# Função para processar um item individual da lista de poda
process_prune_item() {
    local item="$1" 
    local mode="$2" 
    
    IFS=':' read -r repo_path branch_to_prune original_b_repo <<< "$item"

    if [[ "$mode" == "individual" ]]; then 
        read -r -p $"  Podar branch local '${YELLOW}$branch_to_prune${NC}' em '${BLUE}$repo_path${NC}' (upstream removido)? (s/N): " choice
        if [[ ! "$choice" =~ ^[Ss]$ ]]; then
            echo -e "  ⏭️  ${BLUE}Poda de '$branch_to_prune' em '$repo_path' pulada.${NC}"
            return
        fi
    fi

    echo -e "\n➡️  ${BLUE}Processando poda para branch '$branch_to_prune' em '$repo_path'...${NC}"
    
    local original_pwd_prune_item
    original_pwd_prune_item=$(pwd)
    if ! cd "$repo_path"; then 
        echo -e "  ${RED}Erro: Não foi possível acessar o diretório $repo_path para poda.${NC}"
        return
    fi

    local current_active_branch
    current_active_branch=$(git rev-parse --abbrev-ref HEAD)

    if [[ "$branch_to_prune" == "$current_active_branch" ]]; then
        echo -e "  ${RED}❌ Impossível podar o branch ATIVO ('$branch_to_prune'). Faça checkout para outro branch primeiro.${NC}"
        cd "$original_pwd_prune_item" > /dev/null
        return
    fi

    echo -e "  ${BLUE}Tentando 'git branch -d $branch_to_prune'...${NC}"
    if git branch -d "$branch_to_prune"; then
        echo -e "  ${GREEN}Branch '$branch_to_prune' podado com sucesso.${NC}"
    else
        echo -e "  ${RED}Falha ao podar branch '$branch_to_prune'.${NC} Pode ter commits não mergeados."
        echo -e "  ${YELLOW}Use 'git branch -D $branch_to_prune' para forçar a deleção (CUIDADO).${NC}"
    fi
    
    cd "$original_pwd_prune_item" > /dev/null
}


# --- SCRIPT PRINCIPAL ---
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}   Verificador de Status de Repositórios Git   ${NC}"
echo -e "${BLUE}===============================================${NC}"

# Detectar shell e verificar alias antes de prosseguir (pode ser desabilitado com --skip-alias-check)
if [[ "$1" != "--skip-alias-check" ]]; then
    detect_shell_and_alias
    echo -e "\n${BLUE}🔍 Iniciando verificação dos repositórios...${NC}"
else
    echo -e "\n${YELLOW}⚠️  Verificação de alias pulada (--skip-alias-check)${NC}"
    echo -e "${BLUE}🔍 Iniciando verificação dos repositórios...${NC}"
fi

declare -A processed_repo_roots

# Usar substituição de processo para o loop while
while IFS= read -r -d $'\0' git_dir_found; do
    repo_root_candidate=$(get_repo_root "$(dirname "$git_dir_found")")
    if [[ -n "$repo_root_candidate" && -z "${processed_repo_roots["$repo_root_candidate"]}" ]]; then
        check_repo "$repo_root_candidate"
        processed_repo_roots["$repo_root_candidate"]=1 
    fi
done < <(find . -type d -name ".git" -print0)


if [[ ${#processed_repo_roots[@]} -eq 0 ]]; then
    current_dir_as_repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$current_dir_as_repo_root" ]]; then 
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
# Corrigido: remover 'local' da declaração de uncommitted_found
uncommitted_found=false # Declarar sem 'local' aqui
if [[ ${#repo_has_uncommitted_changes[@]} -gt 0 ]]; then
    for repo_path_key in "${!repo_has_uncommitted_changes[@]}"; do
        if [[ "${repo_has_uncommitted_changes[$repo_path_key]}" == "true" ]]; then
            if ! $uncommitted_found; then # Usar a variável já declarada
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
    echo -e "\n${GREEN}✅ Nenhum branch precisa de pull (sincronizado ou à frente do remoto).${NC}"
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

# Filtrar a lista de local_only_branches para não incluir os que são 'gone'
declare -a final_local_only_branches=()
for local_item in "${local_only_branches[@]}"; do
    is_gone=false
    IFS=':' read -r lo_repo_path lo_branch_name <<< "$local_item"
    for gone_item in "${gone_upstream_candidates[@]}"; do
        IFS=':' read -r g_repo_path g_branch_name _ <<< "$gone_item"
        if [[ "$lo_repo_path" == "$g_repo_path" && "$lo_branch_name" == "$g_branch_name" ]]; then
            is_gone=true
            break
        fi
    done
    if ! $is_gone; then
        final_local_only_branches+=("$local_item")
    fi
done

if [[ ${#final_local_only_branches[@]} -gt 0 ]]; then
    echo -e "\n${BLUE}Branches APENAS LOCAIS (sem rastreamento remoto configurado ou válido):${NC}"
    for item in "${final_local_only_branches[@]}"; do
        IFS=':' read -r repo_path_item local_b_item <<< "$item"
        echo -e "  - Repo: $repo_path_item | Branch: $local_b_item"
    done
fi


if [[ ${#gone_upstream_candidates[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Branches com UPSTREAMS REMOTOS AUSENTES (candidatos à poda local):${NC}"
    for item in "${gone_upstream_candidates[@]}"; do
        IFS=':' read -r repo_path_item local_b_item _ <<< "$item"
        echo -e "  - Repo: $repo_path_item | Branch: $local_b_item"
    done
else
    echo -e "\n${GREEN}✅ Nenhum branch local com upstream ausente encontrado para poda.${NC}"
fi

echo -e "${BLUE}===============================================${NC}"

if [[ ${#pull_candidates[@]} -gt 0 ]]; then
    handle_pulls
fi

if [[ ${#gone_upstream_candidates[@]} -gt 0 ]]; then
    handle_pruning
fi

echo -e "\n${GREEN}Verificação concluída.${NC}"
