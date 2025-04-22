#!/bin/bash
# ==============================================================================
# Script: build_and_test.sh
#
# Descrição:
#   Script principal para compilar e testar o MPAS-JEDI no cluster Egeon.
#   Utiliza arquivos CMakeLists.txt modificados e sincronizados previamente
#   via `sync_cmakelists.sh`.
#
# Uso:
#   ./build_and_test.sh [VERSAO]
#     - VERSAO: (opcional) versão do mpas-bundle a ser utilizada.
#       Exemplo: ./build_and_test.sh 3.0.1
#       Se não especificada, usa a versão padrão 3.0.0
#
# Etapas realizadas:
#   1. Define variáveis de ambiente e diretórios
#   2. Copia o CMakeLists_<versao>.txt para o diretório de build
#   3. Ativa o ambiente Spack-Stack
#   4. Executa o CMake
#   5. Submete os jobs SLURM de compilação e teste
#
# Autor:
#   João Gerd Zell de Mattos - 2025
# ==============================================================================

set -euo pipefail

echo "[INFO] Preparando ambiente MPAS-JEDI no Egeon"

# ------------------------------------------------------------------------------
# 1. Configuração inicial
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPACK_DIR="/mnt/beegfs/das.group/spack-envs/mpas-bundle"
ENV_NAME="mpas-bundle"
SNAPSHOT_DATE=$(date +%Y-%m-%d)
DEFAULT_VERSION="3.0.0"

# Versão a ser utilizada (passada por argumento ou default)
VERSION="${1:-$DEFAULT_VERSION}"
CMAKE_FILE="$SCRIPT_DIR/cmake_versions/CMakeLists_${VERSION}.txt"

if [[ ! -f "$CMAKE_FILE" ]]; then
  echo "[ERRO] Arquivo não encontrado: $CMAKE_FILE"
  echo "[DICA] Execute ./sync_cmakelists.sh antes ou verifique a versão desejada."
  exit 1
fi

# ------------------------------------------------------------------------------
# 2. Criação do diretório de build baseado na versão e na data
# ------------------------------------------------------------------------------
BASE_DIR="$HOME/$ENV_NAME"
BUILD_DIR="$BASE_DIR/build-${VERSION}-${SNAPSHOT_DATE}"
TODAY=$(date +%Y-%m-%d)
LOG_DIR="${BUILD_DIR}/logs/${TODAY}"

mkdir -p "$BUILD_DIR"
cp "$CMAKE_FILE" "$BUILD_DIR/CMakeLists.txt"

echo "[INFO] Diretório de build criado: $BUILD_DIR"
cd "$BUILD_DIR"

# ------------------------------------------------------------------------------
# 3. Ativação do ambiente Spack configurado para o Egeon
# ------------------------------------------------------------------------------
echo "[INFO] Ativando ambiente Spack..."
source "$SPACK_DIR/start_spack_bundle.sh"

# ------------------------------------------------------------------------------
# 4. Executa o CMake para configurar os pacotes
# ------------------------------------------------------------------------------
echo "[INFO] Executando CMake com versão ${VERSION} e SNAPSHOT_DATE=${SNAPSHOT_DATE}"
cmake . -DCMAKE_BUILD_TYPE=Release -DSNAPSHOT_DATE=${SNAPSHOT_DATE}
cmake .. \
  -DMPAS_DOUBLE_PRECISION=${PRECISION} \
  -DMPAS_BUNDLE_NOREMOTE=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  | tee "$LOG_DIR/cmake_${JOBID}.log"
# ------------------------------------------------------------------------------
# 5. Submissão dos jobs SLURM com dependência entre build e test
# ------------------------------------------------------------------------------
bash "$SCRIPT_DIR/lib/submit_jobs.sh" "$SCRIPT_DIR" "$BUILD_DIR" "$SPACK_DIR" "gnu" "ON"

