#!/bin/bash
#SBATCH --job-name=ctest_mpas_jedi             # Nome do job
#SBATCH --output=logs/ctest_mpas_%j.out        # Log padrão
#SBATCH --error=logs/ctest_mpas_%j.err         # Log de erro
#SBATCH --time=01:00:00                        # Tempo máximo
#SBATCH --nodes=1                              # Nós computacionais
#SBATCH --ntasks=16                            # Núcleos de CPU
#SBATCH --partition=PESQ1                      # Partição
#SBATCH --account=users                        # Conta SLURM
#SBATCH --dependency=afterok:<BUILD_JOB_ID>    # Dependência de build

# =============================================================================
# SLURM job script para rodar os testes do MPAS-JEDI usando CTest
# Agrupa logs por data e envia automaticamente para diretório centralizado
# =============================================================================

set -euo pipefail
SECONDS=0

# -------------------------------
# Argumentos recebidos via sbatch
# -------------------------------
BUILD_DIR=$1
SPACK_DIR=$2

echo "[INFO] Iniciando execução de CTest: $(date)"
echo "[INFO] Diretório de build: $BUILD_DIR"
echo "[INFO] Ambiente Spack: $SPACK_DIR"

# Ativação do ambiente Spack
echo "[INFO] Ativando ambiente Spack..."
source "$SPACK_DIR/start_spack_bundle.sh"

# -------------------------------
# Diretórios e variáveis auxiliares
# -------------------------------
JOBID=${SLURM_JOB_ID:-manual}
TODAY=$(date +%Y-%m-%d)
LOG_DIR="${BUILD_DIR}/logs/${TODAY}"
PUBLISH_DIR="/mnt/beegfs/$USER/relatorios/mpas-jedi/ctest/${TODAY}"

mkdir -p "$LOG_DIR"
mkdir -p "$PUBLISH_DIR"

# -------------------------------
# Executa os testes com CTest
# -------------------------------
LOGFILE="ctest_${JOBID}.log"
cd "$BUILD_DIR/mpas-jedi"

echo "[INFO] Executando CTest com saída paralela (16 threads)..."
ctest --output-on-failure -j16 | tee "$LOG_DIR/$LOGFILE"

# -------------------------------
# Tempo total
# -------------------------------
DURATION=$SECONDS
echo "[INFO] CTest finalizado: $(date)"
echo "[INFO] Tempo total de execução: $((DURATION / 60)) min $((DURATION % 60)) s"

# -------------------------------
# Envia log para diretório de relatórios compartilhado
# -------------------------------
cp "$LOG_DIR/$LOGFILE" "$PUBLISH_DIR/"
echo "[INFO] Log publicado em: $PUBLISH_DIR/$LOGFILE"

