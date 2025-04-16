#!/bin/bash
#SBATCH --job-name=build_mpas_jedi
#SBATCH --output=logs/build_mpas_%j.out
#SBATCH --error=logs/build_mpas_%j.err
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=32
#SBATCH --partition=PESQ1
#SBATCH --account=users

# =============================================================================
# SLURM job para compilar o MPAS-JEDI no cluster Egeon
# Gera logs cmake/make por data e envia para diretório de relatórios
# =============================================================================

set -euo pipefail
SECONDS=0

# -------------------------------
# Argumentos recebidos via sbatch
# -------------------------------
BUILD_DIR=$1
SPACK_DIR=$2
COMPILER=${3:-gnu}
PRECISION=${4:-ON}

echo "[INFO] Início do job de build: $(date)"
echo "[INFO] Diretório de build: $BUILD_DIR"
echo "[INFO] Ambiente Spack: $SPACK_DIR"
echo "[INFO] Compilador: $COMPILER"
echo "[INFO] Precisão: $PRECISION"

# -------------------------------
# Desativa busca por git no CMake
# -------------------------------
export CMAKE_DISABLE_FIND_PACKAGE_git=ON

# -------------------------------
# Ativação do Spack
# -------------------------------
echo "[INFO] Ativando ambiente Spack..."
source "$SPACK_DIR/start_spack_bundle.sh"

# -------------------------------
# Preparação de diretórios e logs
# -------------------------------
JOBID=${SLURM_JOB_ID:-manual}
TODAY=$(date +%Y-%m-%d)
LOG_DIR="${BUILD_DIR}/logs/${TODAY}"
PUBLISH_DIR="/mnt/beegfs/$USER/relatorios/mpas-jedi/build/${TODAY}"
mkdir -p "$LOG_DIR"
mkdir -p "$PUBLISH_DIR"

# -------------------------------
# Diagnóstico do compilador
# -------------------------------
echo "[INFO] Build iniciado em $(hostname) - $(date)"
echo "[INFO] Compilador C: $(which gcc)"
gcc --version

# -------------------------------
# Executa o CMake
# -------------------------------
cd "$BUILD_DIR"
echo "[INFO] Executando CMake..."
cmake .. \
  -DMPAS_DOUBLE_PRECISION=${PRECISION} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  | tee "$LOG_DIR/cmake_${JOBID}.log"

# -------------------------------
# Compilação com Make
# -------------------------------
echo "[INFO] Compilando com make -j32..."
make -j32 | tee "$LOG_DIR/make_${JOBID}.log"

# -------------------------------
# Tempo total
# -------------------------------
DURATION=$SECONDS
echo "[INFO] Build finalizado em $(date)"
echo "[INFO] Tempo total: $((DURATION / 60)) min $((DURATION % 60)) s"

# -------------------------------
# Cópia dos logs para diretório central
# -------------------------------
cp "$LOG_DIR/cmake_${JOBID}.log" "$PUBLISH_DIR/"
cp "$LOG_DIR/make_${JOBID}.log" "$PUBLISH_DIR/"
echo "[INFO] Logs publicados em: $PUBLISH_DIR"

