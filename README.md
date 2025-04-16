# MPAS-JEDI SLURM Automation Scripts

Este repositório contém uma estrutura padronizada para automatizar a **compilação** e **teste** do MPAS-JEDI no cluster **Egeon** utilizando SLURM.

---

## 🚀 Como usar

Execute **somente** o script principal:

```bash
./build_and_test.sh
```

Esse script:

1. Clona o repositório `mpas-bundle` (se necessário)
2. Inicializa o ambiente Spack configurado no Egeon
3. Executa o `cmake` para baixar os pacotes
4. Submete os jobs de compilação e teste via SLURM automaticamente

---

## 📁 Estrutura

```bash
.
├── build_and_test.sh          # Script principal (ponto de entrada)
├── jobs/
│   ├── build_job.slurm        # Script SLURM para compilação
│   └── ctest_job.slurm        # Script SLURM para testes com CTest
├── lib/
│   ├── submit_jobs.sh         # Script auxiliar interno (não executar diretamente)
│   ├── monitor_slurm_job.sh   # Monitoramento de jobs em tempo real (opcional)
│   └── generate_html_index.sh # Geração de índice HTML com logs por data
```

---

## 🧪 Logs e Relatórios

- Os logs de build e teste são salvos em:
  ```
  $BUILD_DIR/logs/YYYY-MM-DD/
  ```
- Eles também são copiados automaticamente para:
  ```
  /mnt/beegfs/$USER/relatorios/mpas-jedi/{build,ctest}/YYYY-MM-DD/
  ```

---

## 💬 Dúvidas?

Fale com o responsável pelo ambiente ou envie um issue neste repositório.
