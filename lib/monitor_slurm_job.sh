#!/bin/bash

# Verifica se o job ID foi passado
if [ $# -ne 1 ]; then
  echo "Uso: $0 <JOBID>"
  exit 1
fi

JOBID=$1

echo "[INFO] Monitorando SLURM Job $JOBID... (Ctrl+C para sair)"
echo "[INFO] Aguardando job sair de estado PENDING..."

# Loop até o job sair do estado PD (Pending)
while true; do
  STATE=$(squeue -j $JOBID -h -o %T)
  
  if [[ "$STATE" != "PENDING" ]]; then
    echo "[INFO] Job $JOBID saiu do estado PENDING. Novo estado: $STATE"
    
    if [[ "$STATE" == "RUNNING" ]]; then
      notify-send "SLURM Job $JOBID está RODANDO"
    elif [[ "$STATE" == "COMPLETED" ]]; then
      notify-send "SLURM Job $JOBID FINALIZADO com sucesso"
    else
      notify-send "SLURM Job $JOBID saiu do estado PENDING: $STATE"
    fi
    
    break
  fi

  sleep 30  # espera 30 segundos antes de verificar novamente
done
