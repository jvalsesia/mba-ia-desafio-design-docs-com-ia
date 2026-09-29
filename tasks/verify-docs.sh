#!/usr/bin/env bash
# Verificações automáticas do pacote de design docs (SPEC.md §3).
# Uso: bash tasks/verify-docs.sh [--root DIR]
# Sai com código != 0 se alguma verificação falhar. Documento ainda inexistente gera aviso, não falha.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--root" ] && [ -n "${2:-}" ]; then ROOT="$(cd "$2" && pwd)"; fi
cd "$ROOT" || exit 2

FAILS=0
WARNS=0
fail() { echo "  FALHA: $*"; FAILS=$((FAILS + 1)); }
warn() { echo "  aviso: $*"; WARNS=$((WARNS + 1)); }
ok()   { echo "  ok: $*"; }
section() { echo; echo "== $*"; }

# Remove o cabeçalho "| ID |" e a linha separadora; imprime só as linhas de dados da tabela.
tracker_rows() { awk -F'|' '/^\| *[A-Z]+-[A-Z0-9]/' docs/TRACKER.md; }

DOCS=()
for f in docs/PRD.md docs/RFC.md docs/FDD.md; do [ -f "$f" ] && DOCS+=("$f"); done
ADRS=()
for f in docs/adrs/ADR-*.md; do [ -f "$f" ] && ADRS+=("$f"); done

# ---------------------------------------------------------------------------
section "1. Código da aplicação e transcrição intocados"
BASE_REF="main"
git rev-parse --verify -q "$BASE_REF" >/dev/null || BASE_REF="$(git rev-list --max-parents=0 HEAD | tail -1)"
PROTECTED=(src prisma tests package.json package-lock.json tsconfig.json tsconfig.build.json vitest.config.ts .eslintrc.json .prettierrc .prettierignore docker-compose.yml .env.example TRANSCRICAO.md)
changed="$(git diff --name-only "$BASE_REF" -- "${PROTECTED[@]}"; git ls-files --others --exclude-standard -- src prisma tests)"
if [ -n "$changed" ]; then
  while read -r p; do fail "arquivo protegido alterado: $p"; done <<< "$changed"
else
  ok "nenhum arquivo protegido alterado (base: $BASE_REF)"
fi

# ---------------------------------------------------------------------------
section "2. ADRs: quantidade e nomenclatura"
n_adr=${#ADRS[@]}
if [ "$n_adr" -eq 0 ]; then
  warn "nenhum ADR ainda"
elif [ "$n_adr" -lt 5 ] || [ "$n_adr" -gt 8 ]; then
  warn "$n_adr ADRs (a entrega final exige entre 5 e 8)"
else
  ok "$n_adr ADRs"
fi
bad_names="$(ls docs/adrs | grep -vE '^(README\.md|ADR-[0-9]{3}-[a-z0-9]+(-[a-z0-9]+)*\.md)$' || true)"
if [ -n "$bad_names" ]; then
  while read -r p; do fail "nome fora do padrão em docs/adrs/: $p"; done <<< "$bad_names"
else
  ok "nomes no padrão ADR-NNN-titulo-em-kebab-case.md"
fi

# ---------------------------------------------------------------------------
section "3. ADRs: seções obrigatórias"
for f in "${ADRS[@]}"; do
  for s in "Status" "Contexto" "Decisão" "Alternativas Consideradas" "Consequências"; do
    grep -q "^## $s" "$f" || fail "$f: falta '## $s'"
  done
done
[ "$n_adr" -gt 0 ] && ok "seções conferidas em $n_adr ADR(s)"

# ---------------------------------------------------------------------------
section "4. Caminhos de código citados existem (allowlist de arquivos novos propostos)"
SCAN=("${DOCS[@]}" "${ADRS[@]}")
[ -f docs/TRACKER.md ] && SCAN+=(docs/TRACKER.md)
[ -f README.md ] && SCAN+=(README.md)
missing=0
while read -r p; do
  [ -z "$p" ] && continue
  if [ ! -e "$p" ]; then fail "caminho citado não existe: $p"; missing=1; fi
done < <(grep -ohE '\b(src|prisma|tests)/[A-Za-z0-9_./-]+\.(ts|prisma|sql|json)\b' "${SCAN[@]}" 2>/dev/null \
          | sort -u | grep -vE '^(src/worker\.ts|src/modules/webhooks/)' || true)
[ "$missing" -eq 0 ] && ok "todos os caminhos existentes citados resolvem"

# ---------------------------------------------------------------------------
if [ ! -f docs/TRACKER.md ] || [ -z "$(tracker_rows)" ]; then
  section "5-9. Tracker"
  warn "docs/TRACKER.md sem linhas de dados ainda"
else
  section "5. Timestamps do Tracker existem na transcrição com o falante correto"
  invalid=0
  while read -r t; do
    [ -z "$t" ] && continue
    grep -qF "$t:" TRANSCRICAO.md || { fail "timestamp/falante inexistente: $t"; invalid=1; }
  done < <(grep -oE '\[[0-9]{2}:[0-9]{2}\] [A-Z][a-z]+' docs/TRACKER.md | sort -u)
  [ "$invalid" -eq 0 ] && ok "todos os timestamps conferem"

  # Linhas TRANSCRICAO sem timestamp válido na coluna Localização
  bad_loc="$(tracker_rows | awk -F'|' '$6 ~ /TRANSCRICAO/ && $7 !~ /\[[0-9][0-9]:[0-9][0-9]\] [A-Z][a-z]+/ {gsub(/ /,"",$2); print $2}')"
  [ -n "$bad_loc" ] && while read -r id; do fail "linha TRANSCRICAO sem [hh:mm] Nome: $id"; done <<< "$bad_loc"

  section "6. Proporção de fontes (TRANSCRICAO >= 70%, CODIGO >= 5)"
  read -r n t c < <(tracker_rows | awk -F'|' '{n++; if ($6 ~ /TRANSCRICAO/) t++; if ($6 ~ /CODIGO/) c++} END {print n+0, t+0, c+0}')
  pct=$(( n > 0 ? 100 * t / n : 0 ))
  echo "  linhas=$n transcricao=$t ($pct%) codigo=$c"
  [ "$pct" -ge 70 ] || fail "TRANSCRICAO abaixo de 70% ($pct%)"
  if [ "$c" -lt 5 ]; then warn "apenas $c linhas CODIGO (a entrega final exige >= 5)"; fi
  other="$(tracker_rows | awk -F'|' '$6 !~ /TRANSCRICAO|CODIGO/ {gsub(/ /,"",$2); print $2}')"
  [ -n "$other" ] && while read -r id; do fail "Fonte deve ser TRANSCRICAO ou CODIGO: $id"; done <<< "$other"

  section "7. Caminhos com Fonte=CODIGO existem"
  invalid=0
  while read -r p; do
    [ -z "$p" ] && continue
    [ -e "$p" ] || { fail "CODIGO aponta para caminho inexistente: $p"; invalid=1; }
  done < <(tracker_rows | awk -F'|' '$6 ~ /CODIGO/ {gsub(/[ `]/, "", $7); print $7}' | sort -u)
  [ "$invalid" -eq 0 ] && ok "caminhos CODIGO resolvem"

  section "8. Cobertura: IDs dos documentos presentes no Tracker"
  if [ ${#DOCS[@]} -eq 0 ] && [ "$n_adr" -eq 0 ]; then
    warn "nenhum documento para cobrir ainda"
  else
    doc_ids="$(grep -ohE '\b((PRD|RFC|FDD)-[A-Z]+-[0-9]{2}|ADR-[0-9]{3}(-[A-Z]+-[0-9]{2})?)\b' "${DOCS[@]}" "${ADRS[@]}" | sort -u)"
    trk_ids="$(tracker_rows | awk -F'|' '{gsub(/ /, "", $2); print $2}' | sort -u)"
    total=$(printf '%s\n' "$doc_ids" | grep -c . || true)
    miss="$(comm -23 <(printf '%s\n' "$doc_ids") <(printf '%s\n' "$trk_ids"))"
    n_miss=$(printf '%s\n' "$miss" | grep -c . || true)
    cov=$(( total > 0 ? 100 * (total - n_miss) / total : 100 ))
    echo "  ids_nos_documentos=$total faltando_no_tracker=$n_miss cobertura=$cov%"
    [ -n "$miss" ] && while read -r id; do warn "ID sem linha no Tracker: $id"; done <<< "$miss"
    [ "$cov" -ge 80 ] || fail "cobertura abaixo de 80% ($cov%)"
    orphan="$(comm -13 <(printf '%s\n' "$doc_ids") <(printf '%s\n' "$trk_ids"))"
    [ -n "$orphan" ] && while read -r id; do warn "ID no Tracker que não aparece nos documentos: $id"; done <<< "$orphan"
  fi

  section "9. IDs duplicados no Tracker"
  dups="$(tracker_rows | awk -F'|' '{gsub(/ /, "", $2); print $2}' | sort | uniq -d)"
  if [ -n "$dups" ]; then while read -r id; do fail "ID duplicado: $id"; done <<< "$dups"; else ok "sem duplicatas"; fi
fi

# ---------------------------------------------------------------------------
section "10. RFC: links para ADRs e tamanho"
if [ -f docs/RFC.md ] && [ "$(wc -w < docs/RFC.md)" -gt 20 ]; then
  n_links=0
  while read -r l; do
    [ -z "$l" ] && continue
    if [ -e "docs/$l" ]; then n_links=$((n_links + 1)); else fail "link quebrado no RFC: $l"; fi
  done < <(grep -oE '\(\./adrs/ADR-[0-9]{3}-[a-z0-9-]+\.md\)' docs/RFC.md | tr -d '()' | sort -u)
  [ "$n_links" -ge 2 ] && ok "$n_links ADRs linkados" || fail "RFC linka apenas $n_links ADR(s) (mínimo 2)"
  words=$(wc -w < docs/RFC.md)
  echo "  palavras=$words (alvo ~900-2000)"
  { [ "$words" -ge 900 ] && [ "$words" -le 2000 ]; } || warn "RFC fora do alvo de 2 a 4 páginas"
else
  warn "docs/RFC.md ainda não escrito"
fi

# ---------------------------------------------------------------------------
section "11. FDD: endpoints e códigos WEBHOOK_*"
if [ -f docs/FDD.md ] && [ "$(wc -w < docs/FDD.md)" -gt 20 ]; then
  n_ep=$(grep -cE '^#### (GET|POST|PATCH|PUT|DELETE) /' docs/FDD.md || true)
  echo "  endpoints=$n_ep"
  [ "$n_ep" -ge 4 ] || warn "FDD com $n_ep endpoints (a entrega final exige >= 4)"
  codes="$(grep -oE '\bWEBHOOK_[A-Z_]+\b' docs/FDD.md | sort -u | tr '\n' ' ')"
  echo "  codigos: ${codes:-nenhum}"
else
  warn "docs/FDD.md ainda não escrito"
fi

# ---------------------------------------------------------------------------
section "12. Menções a itens fora de escopo (revisão manual: só em Fora de escopo, Alternativas ou Questões em aberto)"
if [ ${#DOCS[@]} -gt 0 ] || [ "$n_adr" -gt 0 ]; then
  grep -niE 'e-?mail|dashboard|painel|rate limit|exactly-once|redis|ordena[cç][aã]o global|arquiv|m[uú]ltiplos workers|inbound' \
    "${DOCS[@]}" "${ADRS[@]}" 2>/dev/null | sed 's/^/  /' || true
fi

# ---------------------------------------------------------------------------
echo
echo "Resultado: $FAILS falha(s), $WARNS aviso(s)"
[ "$FAILS" -eq 0 ]
