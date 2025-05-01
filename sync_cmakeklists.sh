#!/bin/bash
set -euo pipefail

# =============================================================================
# Script: sync_cmakelists.sh
#
# Descrição:
#   Este script sincroniza e prepara arquivos CMakeLists.txt extraídos do
#   repositório oficial `mpas-bundle` (JCSDA). Ele busca automaticamente
#   as versões mais recentes dos branches `release/*` e `develop`, salva
#   o CMakeLists.txt correspondente de cada versão e aplica as seguintes
#   modificações:
#
#   1. Substitui chamadas:
#      ecbuild_bundle(PROJECT ...) → ecbuild_add_bundle_ext(...)
#
#   2. Remove automaticamente os argumentos UPDATE e NOREMOTE
#      de qualquer parte da linha.
#
#   3. Insere uma macro genérica `ecbuild_add_bundle_ext` no topo do arquivo,
#      permitindo a inclusão futura de argumentos como RECURSIVE, MANUAL etc.
#
#   4. Salva cada versão como:
#      cmake_versions/CMakeLists_<versao>.txt
#
# Uso:
#   ./sync_cmakelists.sh
#
# Requisitos:
#   - git
#   - bash >= 4
#   - awk (padrão do sistema)
#
# Estrutura de saída:
#   cmake_versions/
#   ├── CMakeLists_3.0.0.txt
#   ├── CMakeLists_3.0.1.txt
#   ├── CMakeLists_3.0.2.txt
#   └── CMakeLists_develop.txt
#
# Autor:
#   João Gerd Zell de Mattos - 2025
# =============================================================================

# -----------------------------------------------------------------------------
# Variáveis principais
# -----------------------------------------------------------------------------

# Repositório oficial do JCSDA
MPAS_REPO="https://github.com/JCSDA/mpas-bundle.git"

# Diretório base (onde o script está localizado)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Diretório onde os CMakeLists modificados serão salvos
CMAKE_DIR="$BASE_DIR/cmake_versions"
mkdir -p "$CMAKE_DIR"

# Diretórios temporários para clonagem
TMP_DIR=$(mktemp -d)
WORKTREE_DIR=$(mktemp -d)

# -----------------------------------------------------------------------------
# Clonagem do repositório em modo bare (para listar branches remotos)
# -----------------------------------------------------------------------------
echo "[INFO] Clonando repositório temporariamente (modo bare) em $TMP_DIR..."
git clone --quiet --bare "$MPAS_REPO" "$TMP_DIR"

# Filtra os branches relevantes: release/* e develop
mapfile -t REMOTE_BRANCHES < <(git --git-dir="$TMP_DIR" ls-remote --heads \
  | awk '{print $2}' \
  | grep -E 'refs/heads/(release/|develop)' \
  | sed 's|refs/heads/||')

# Clonagem completa para checkout das branches
git clone --quiet "$MPAS_REPO" "$WORKTREE_DIR"
cd "$WORKTREE_DIR"

# -----------------------------------------------------------------------------
# Loop principal: processa cada branch e salva/modifica o CMakeLists.txt
# -----------------------------------------------------------------------------
for VERSION in "${REMOTE_BRANCHES[@]}"; do
  echo "[INFO] Processando versão $VERSION..."
  git fetch origin "$VERSION" --quiet
  git checkout --quiet "$VERSION"

  # Nome de versão limpo (ex: release/3.0.2 → 3.0.2)
  CLEAN_VERSION=$(echo "$VERSION" | sed 's|release/||;s|/|-|g')
  DEST_FILE="$CMAKE_DIR/CMakeLists_${CLEAN_VERSION}.txt"

  if [[ -f "$DEST_FILE" ]]; then
    echo "[INFO] -> CMakeLists_${CLEAN_VERSION}.txt já existe. Pulando..."
    continue
  fi

  echo "[INFO] -> CMakeLists.txt salvo como $DEST_FILE"

  # -----------------------------------------------------------------------------
  # Processamento do arquivo: substituição + macro + documentação
  # -----------------------------------------------------------------------------
  awk '
  BEGIN { inserted = 0 }
  {
    # Substitui ecbuild_bundle(PROJECT ... por ecbuild_add_bundle_ext(
    gsub(/ecbuild_bundle[ \t]*\([ \t]*PROJECT[ \t]+/, "ecbuild_add_bundle_ext(")

    # Remove UPDATE ou NOREMOTE de qualquer lugar da linha
    gsub(/[ \t]+(UPDATE|NOREMOTE)[ \t]*/, " ")

    print $0

    # Após o project(...), insere a macro e a documentação
    if (!inserted && $0 ~ /^project[ \t]*\(/) {
      inserted = 1
      print ""
      print "# =============================================="
      print "# OFFLINE BUILD CONTROL"
      print "#"
      print "# This CMake file uses a macro '\''ecbuild_add_bundle_ext'\''"
      print "# that wraps around ecbuild_bundle() to control whether"
      print "# Git repositories should be updated (via '\''UPDATE'\'') or"
      print "# used without remote fetch (via '\''NOREMOTE'\'')."
      print "#"
      print "# Pass -DMPAS_BUNDLE_NOREMOTE=ON to build in fully"
      print "# offline mode (no git fetch will be attempted)."
      print "#"
      print "# Example usage:"
      print "#   cmake .. -DCMAKE_BUILD_TYPE=Release -DMPAS_BUNDLE_NOREMOTE=ON"
      print "#"
      print "# When OFF (default), ecbuild will use UPDATE to ensure"
      print "# each repo is synchronized with its specified branch or tag."
      print "# =============================================="
      print ""
      print "# ============================"
      print "# Control for git access (EXT version)"
      print "# ============================"
      print "option(MPAS_BUNDLE_NOREMOTE \"Disable git fetch/update during ecbuild_bundle\" OFF)"
      print ""
      print "macro(ecbuild_add_bundle_ext project_name)"
      print "  if(MPAS_BUNDLE_NOREMOTE)"
      print "    ecbuild_bundle(PROJECT ${project_name} ${ARGN} NOREMOTE)"
      print "  else()"
      print "    ecbuild_bundle(PROJECT ${project_name} ${ARGN} UPDATE)"
      print "  endif()"
      print "endmacro()"
      print ""
    }
  }' CMakeLists.txt > "$DEST_FILE"
done

# -----------------------------------------------------------------------------
# Limpeza dos diretórios temporários
# -----------------------------------------------------------------------------
rm -rf "$TMP_DIR" "$WORKTREE_DIR"
echo "[INFO] Sincronização concluída com sucesso!"

