# 🛍️ Sistema Automatizado de Compilacao e Testes do MPAS-JEDI no Cluster Egeon

Este repositório contém uma estrutura padronizada e automatizada para compilar e testar o sistema **MPAS-JEDI** no cluster **Egeon**, utilizando o Spack-Stack 1.7.0 e o SLURM como sistema de filas.

---

## 📂 Estrutura do Repositório

```bash
.
├── build_and_test.sh           # ✅ Script principal (ponto de entrada)
├── README.md                   # 📄 Este documento
├── jobs/                       # 🗒 Scripts SLURM para submissão de jobs
│   ├── build_job.slurm         # Compilação do MPAS-JEDI
│   └── ctest_job.slurm         # Execução dos testes CTest
├── lib/                        # ⚙️ Scripts auxiliares
│   ├── submit_jobs.sh          # Submissão dos jobs SLURM (invocado pelo script principal)
│   ├── monitor_slurm_job.sh    # Monitoramento de jobs em tempo real (opcional)
│   └── generate_html_index.sh  # Geração de índice HTML com logs por data
├── sync_cmakelists.sh          # ✨ Sincroniza e adapta os CMakeLists.txt do mpas-bundle
└── cmake_versions/             # 📂 Armazena os CMakeLists.txt modificados por versão
                                #     Ex: CMakeLists_3.0.0.txt, CMakeLists_3.0.1.txt
```

---

## 🚀 Como Usar

Execute **somente** o script principal:

```bash
./build_and_test.sh [VERSAO]
```

**Argumentos:**
- `VERSAO` (opcional): versão do `mpas-bundle` a ser utilizada.
  - Exemplo: `./build_and_test.sh 3.0.2`
  - Se omitido, será usada a versão padrão `3.0.0`.

Este script irá:

1. Verificar se o arquivo `CMakeLists_<versao>.txt` está disponível na pasta `cmake_versions`
2. Criar um diretório de build com base na versão e data atual
3. Copiar o `CMakeLists_<versao>.txt` correspondente para o diretório de build
4. Ativar o ambiente Spack configurado no Egeon
5. Executar o `cmake` para configurar os pacotes
6. Submeter automaticamente os jobs de compilação e testes via SLURM

---

## 📦 Pré-Requisitos

- Ter o ambiente Spack-Stack 1.7.0 configurado em:
  ```
  /mnt/beegfs/das.group/spack-envs/mpas-bundle/start_spack_bundle.sh
  ```

- Módulos recomendados para carregar antes de iniciar:
  ```bash
  module load gnu9
  ```

---

## 📁 Organização dos Logs

Os logs são organizados automaticamente por **data** e **tipo**, e armazenados em:

```bash
$BUILD_DIR/logs/YYYY-MM-DD/
```

Também são copiados para um diretório compartilhado:

```bash
/mnt/beegfs/$USER/relatorios/mpas-jedi/{build,ctest}/YYYY-MM-DD/
```

---

## 🧪 Monitoramento e Relatórios

- Use `monitor_slurm_job.sh` para acompanhar jobs em tempo real:

  ```bash
  ./lib/monitor_slurm_job.sh <JOBID>
  ```

- Gere um índice HTML com os logs por data:

  ```bash
  ./lib/generate_html_index.sh
  ```

  O índice será salvo em:

  ```
  /mnt/beegfs/$USER/relatorios/mpas-jedi/index.html
  ```

---

## 📜 Sobre o sync_cmakelists.sh

O script `sync_cmakelists.sh` automatiza a coleta dos arquivos `CMakeLists.txt` das releases do repositório `mpas-bundle`, aplicando:

- Substituição de `ecbuild_bundle(PROJECT ...)` por `ecbuild_add_bundle_ext(...)`
- Remoção dos argumentos `UPDATE` e `NOREMOTE`
- Inserção da macro `ecbuild_add_bundle_ext` com suporte a `MPAS_BUNDLE_NOREMOTE`

Arquivos modificados ficam salvos em:
```bash
cmake_versions/CMakeLists_<versao>.txt
```

---

## 📓 Licença

Este projeto é licenciado sob os termos da **LGPL v3.0**.  
Consulte o arquivo [LICENSE](./LICENSE) para mais detalhes.

---

## 👥 Ambiente Compartilhado

Para evitar instalações duplicadas entre usuários do grupo, utilize o ambiente compartilhado:

```bash
source /mnt/beegfs/das.group/spack-envs/mpas-bundle/start_spack_bundle.sh
```

Esse script garante a ativação completa do ambiente com módulos e variáveis necessárias para compilar e rodar o MPAS-JEDI.

---

## 📧 Contato

Para dúvidas ou contribuições, entre em contato com **João Gerd**  
Instituto Nacional de Pesquisas Espaciais (INPE)  
📧 joao.gerd [at] inpe.br  
➡️ ou abra uma [issue](https://github.com/joaogerd/mpas-jedi-egeon/issues) neste repositório.


