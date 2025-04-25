#!/bin/bash
# ==============================================================================
# Nome: generate_html_index.sh
#
# Descrição:
#   Gera um índice HTML navegável com links para logs de build e ctest
#   armazenados em /mnt/beegfs/$USER/relatorios/mpas-jedi
#
# Uso:
#   ./generate_html_index.sh
#
# Saída:
#   - Cria o arquivo index.html com os logs por data e tipo
#
# Autor:
#   João Gerd Zell de Mattos - 2025
# ==============================================================================

# Diretório base
RELATORIO_DIR="/mnt/beegfs/$USER/relatorios/mpas-jedi"
INDEX_HTML="$RELATORIO_DIR/index.html"

echo "[INFO] Gerando índice HTML em $INDEX_HTML"

{
echo "<!DOCTYPE html>"
echo "<html><head><meta charset='UTF-8'><title>Relatórios MPAS-JEDI</title>"
echo "<style>body { font-family: sans-serif; } h2 { margin-top: 1.5em; } ul { line-height: 1.6; }</style>"
echo "</head><body>"
echo "<h1>📊 Relatórios MPAS-JEDI por Data - Usuário: $USER</h1>"

for TIPO in build ctest; do
  echo "<h2>${TIPO^^}</h2>"
  BASE_DIR="$RELATORIO_DIR/$TIPO"
  
  if [ ! -d "$BASE_DIR" ]; then
    echo "<p><i>Nenhum relatório encontrado para $TIPO</i></p>"
    continue
  fi

  for DIA in $(ls -1 $BASE_DIR | sort -r); do
    echo "<h3>📅 $DIA</h3><ul>"
    for LOG in "$BASE_DIR/$DIA"/*.log; do
      [ -e "$LOG" ] || continue
      FNAME=$(basename "$LOG")
      RELPATH="${TIPO}/${DIA}/${FNAME}"
      echo "<li><a href="${RELPATH}">${FNAME}</a></li>"
    done
    echo "</ul>"
  done
done

echo "</body></html>"
} > "$INDEX_HTML"

echo "[INFO] Índice HTML gerado com sucesso!"
