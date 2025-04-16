#!/bin/bash
# ============================================
# Script principal para preparação do ambiente
# e submissão de jobs SLURM no cluster Egeon
# para o projeto MPAS-JEDI (versão 3.0.0)
# ============================================

set -euo pipefail

echo "[INFO] Preparando ambiente MPAS-JEDI no Egeon"

# Variáveis iniciais
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/JCSDA/mpas-bundle.git"
ENV_NAME="mpas-bundle"
SPACK_DIR="/mnt/beegfs/das.group/spack-envs/$ENV_NAME"
SNAPSHOT_DATE=$(date +%Y-%m-%d)

# Diretórios
BASE_DIR="$HOME/$ENV_NAME"
BUILD_DIR="$BASE_DIR/build-${SNAPSHOT_DATE}"

# Clonagem do repositório
if [ ! -d "$BASE_DIR" ]; then
  echo "[INFO] Clonando repositório MPAS-BUNDLE..."
  git clone "$REPO_URL" "$BASE_DIR"
  cd "$BASE_DIR"
  git checkout 3.0.0
  git submodule update --init --recursive
else
  echo "[INFO] Repositório já existente: $BASE_DIR"
fi

# Criação do diretório de build com data
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Ativação do ambiente Spack
echo "[INFO] Ativando ambiente Spack..."
source "$SPACK_DIR/start_spack_bundle.sh"

# Executa o CMake para baixar os pacotes (sem compilar)
echo "[INFO] Rodando CMake com SNAPSHOT_DATE=$SNAPSHOT_DATE"
cmake .. -DCMAKE_BUILD_TYPE=Release -DSNAPSHOT_DATE=${SNAPSHOT_DATE}

# Submissão dos jobs com dependência
bash "$SCRIPT_DIR/run_all.sh" "$BUILD_DIR" "$SPACK_DIR" "gnu" "ON"

