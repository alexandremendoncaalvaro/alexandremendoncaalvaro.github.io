#!/bin/bash

repos_to_pull=()

find . -type d -name ".git" | while read repo; do
  project_dir=$(dirname "$repo")
  echo "🔍 Verificando repositório: $project_dir"

  (cd "$project_dir" && git fetch --all --quiet 2>/dev/null)

  current_branch=$(cd "$project_dir" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -z "$current_branch" ]; then
    echo "⚠️  Nenhum branch ativo em: $project_dir"
    continue
  fi

  local_status=$(cd "$project_dir" && git rev-list --left-right --count "$current_branch...origin/$current_branch" 2>/dev/null || echo "0	0")
  ahead=$(echo "$local_status" | cut -f1 -d$'\t')
  behind=$(echo "$local_status" | cut -f2 -d$'\t')

  git_status=$(cd "$project_dir" && git status --porcelain 2>/dev/null)

  all_synced=true
  if [ "${ahead:-0}" -gt 0 ]; then
    echo "⚠️  Commits pendentes de push na branch $current_branch em: $project_dir"
    all_synced=false
  elif [ "${behind:-0}" -gt 0 ]; then
    echo "⚠️  Branch $current_branch desatualizada, precisa de pull em: $project_dir"
    all_synced=false
    repos_to_pull+=("$project_dir")
  fi

  if [ -n "$git_status" ]; then
    echo "⚠️  Alterações locais não commitadas em: $project_dir"
    all_synced=false
  fi

  if $all_synced; then
    echo "✅ Tudo sincronizado em: $project_dir"
  fi

  echo
done

if [ ${#repos_to_pull[@]} -eq 0 ]; then
  echo "✨ Nenhum repositório precisa de pull."
  exit 0
fi

echo "🔧 Deseja fazer git pull nos repositórios desatualizados?"
select opt in "Sim (todos)" "Sim (individualmente)" "Não"; do
  case $opt in
    "Sim (todos)")
      for repo in "${repos_to_pull[@]}"; do
        echo "➡️  Dando git pull em: $repo"
        (cd "$repo" && git pull)
      done
      break
      ;;
    "Sim (individualmente)")
      for repo in "${repos_to_pull[@]}"; do
        read -p "🔁 Fazer pull em $repo? (s/N): " resp
        if [[ "$resp" == "s" || "$resp" == "S" ]]; then
          echo "➡️  Dando git pull em: $repo"
          (cd "$repo" && git pull)
        else
          echo "⏭️  Pulado: $repo"
        fi
      done
      break
      ;;
    "Não")
      echo "❌ Nenhuma ação realizada."
      break
      ;;
    *) echo "Opção inválida."; ;;
  esac
done
