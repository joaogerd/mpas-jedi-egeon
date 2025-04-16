#!/bin/bash

BUILD_DIR=$1
SPACK_DIR=$2
COMPILER=${3:-gnu}
PRECISION=${4:-ON}

mkdir -p logs

echo "[INFO] Submetendo build_job.slurm..."
BUILD_JOB_ID=$(sbatch --parsable build_job.slurm "$BUILD_DIR" "$SPACK_DIR" "$COMPILER" "$PRECISION")

if [ -z "$BUILD_JOB_ID" ]; then
  echo "[ERRO] Falha ao submeter o build_job.slurm"
  exit 1
fi

echo "[INFO] BUILD job submetido com ID: $BUILD_JOB_ID"
sleep 10

# Verifica se o job realmente entrou na fila
JOB_STATE=$(sacct -j "$BUILD_JOB_ID" --format=JobID,State --noheader | grep "$BUILD_JOB_ID" | awk '{print $2}')

if [[ "$JOB_STATE" == "" ]]; then
  echo "[ERRO] Job $BUILD_JOB_ID não encontrado no sistema SLURM."
  exit 1
elif [[ "$JOB_STATE" == "FAILED" || "$JOB_STATE" == "CANCELLED" ]]; then
  echo "[ERRO] Job de build falhou ou foi cancelado. Abortando submissão do ctest."
  exit 1
fi

echo "[INFO] Submetendo ctest_job.slurm com dependência de sucesso no build..."
sbatch --dependency=afterok:$BUILD_JOB_ID ctest_job.slurm "$BUILD_DIR" "$SPACK_DIR"
