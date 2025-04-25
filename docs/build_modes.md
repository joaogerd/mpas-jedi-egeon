# 🛠️ Compilação do MPAS-JEDI: Modos disponíveis

## Modos de compilação

Este sistema oferece dois modos de compilação:

- `slurm`: Utiliza SLURM para compilar em um nó de computação.
- `local`: Compila diretamente no nó de login com uso reduzido de recursos.

## Arquivos relacionados

| Arquivo                 | Função                                          |
|-------------------------|--------------------------------------------------|
| submit_jobs.sh          | Seleciona o modo e coordena a submissão         |
| lib/build_local.sh      | Executa o build no nó de login de forma leve    |
| jobs/build_job.slurm    | Executa o build em um nó computacional via SLURM|
| jobs/ctest_job.slurm    | Executa os testes após o build                  |

## Como usar

### Modo SLURM (padrão)
```bash
./submit_jobs.sh . build-3.0.0 /mnt/beegfs/das.group/spack-envs/mpas-bundle gnu ON slurm
```

### Modo local (nó de login, leve)
```bash
./submit_jobs.sh . build-3.0.0 /mnt/beegfs/das.group/spack-envs/mpas-bundle gnu ON local
```

## Sobre o `lib/build_local.sh`

Este script:
- Usa no máximo 10% dos núcleos disponíveis
- Define prioridade mínima com `nice` e `ionice`
- É útil para compilações rápidas ou emergenciais
- **Não recomendado para builds pesados ou frequentes**

## Requisitos

- Ambiente Spack ativável com `start_spack_bundle.sh`
- Diretório `build-*/` já configurado com `cmake`

## Observações

- Ideal para uso emergencial
- Recomenda-se a instalação de `glibc-devel` nos nós de computação para compilar via SLURM de forma padronizada.
