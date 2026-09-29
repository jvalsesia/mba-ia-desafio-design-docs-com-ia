# Spec: Pacote de Design Docs — Sistema de Webhooks de Notificação de Pedidos

> Status: **rascunho para aprovação** · Data: 2026-09-29 · Autor: Julio Valsesia (com Claude Code)
> Enunciado de origem: `README.md` (versão original, commit `e7f6311`)

## 1. Objetivo

Produzir, a partir de `TRANSCRICAO.md` e do código do OMS, um **pacote documental** (PRD, RFC, FDD, 7 ADRs, Tracker e README do processo) acionável o bastante para o time de engenharia começar a implementar a feature de webhooks outbound de mudança de status de pedido.

**Leitores:** avaliador do desafio (checklist de aceite do enunciado) e, na ficção do cenário, o time da reunião (Larissa, Marcos, Bruno, Diego e Sofia).

**Princípio inegociável:** todo requisito, decisão, restrição ou número registrado nos documentos tem origem identificável: `[hh:mm] Nome` da transcrição ou um caminho real de arquivo do código. O que não tiver âncora é removido ou marcado explicitamente como *proposta de design* ligada à âncora mais próxima.

**Não é objetivo:** implementar a feature. A entrega é 100% documental.

## 2. Mapa de documentos (ordem de produção)

Um spec único cobre os 6 entregáveis, porque todos consomem a mesma base de fatos (§8). A ordem segue o enunciado: as decisões formam o esqueleto.

| Id | Arquivo | Altura | Depende de |
|---|---|---|---|
| `adrs` | `docs/adrs/ADR-001..007-*.md` | Decisão pontual | base de fatos (§8) |
| `rfc` | `docs/RFC.md` | Arquitetura (2 a 4 páginas) | `adrs` |
| `fdd` | `docs/FDD.md` | Implementação | `adrs`, `rfc` |
| `prd` | `docs/PRD.md` | Produto / negócio | `adrs`, `rfc`, `fdd` |
| `tracker` | `docs/TRACKER.md` | Transversal | todos acima |
| `readme` | `README.md` | Processo | todos acima + `tasks/process-log.md` |

Ordem: `adrs → rfc → fdd → prd → tracker → readme → revisão final`. O Tracker recebe linhas incrementalmente a cada documento e é consolidado no fim.

### ADRs planejados (6 decisões principais + 1 secundária)

| ADR | Decisão | Âncora principal | Alternativa(s) real(is) |
|---|---|---|---|
| ADR-001 | Outbox transacional no MySQL | `[09:06] Diego`, `[09:08] Larissa` | Disparo síncrono no service `[09:04] Bruno`; Redis Streams `[09:07] Larissa` |
| ADR-002 | Worker em processo separado com polling de 2s | `[09:09] Diego`, `[09:10] Larissa`, `[09:11] Diego` | Trigger do MySQL / LISTEN-NOTIFY `[09:09] Bruno`; worker dentro do processo da API `[09:11] Diego` |
| ADR-003 | Retry com backoff exponencial (1m/5m/30m/2h/12h) e DLQ em tabela separada | `[09:17] Larissa`, `[09:18] Diego` | Retry indefinido `[09:15] Diego`; 3 tentativas `[09:16] Bruno`; marcar `failed` na própria outbox `[09:17] Larissa` |
| ADR-004 | HMAC-SHA256 com secret por endpoint e rotação com grace period de 24h | `[09:20] Sofia`, `[09:21] Sofia`, `[09:22] Sofia` | Secret global da plataforma `[09:21] Sofia` |
| ADR-005 | Entrega at-least-once com `X-Event-Id` para deduplicação | `[09:24] Diego`, `[09:26] Larissa` | Exactly-once `[09:25] Diego` |
| ADR-006 | Reuso dos padrões do projeto (módulo, AppError, `WEBHOOK_*`, Pino, error middleware, `requireRole`, Zod) | `[09:27] Bruno`–`[09:30] Larissa`, `[09:41] Bruno` | Injetar o repository inteiro no `OrderService` `[09:41] Diego` (no lugar de `publishWebhookEvent(tx, …)`) |
| ADR-007 | Payload renderizado como snapshot na inserção da outbox | `[09:52] Larissa`, `[09:52] Diego` | Guardar só o `order_id` e renderizar no envio `[09:51] Bruno` |

O ADR-006 é o que **referencia explicitamente o código** (`src/modules/*`, `src/shared/errors/*`, `src/middlewares/*`, `src/shared/logger/index.ts`). Formato de payload, headers, timeout de 10s e limite de 64KB ficam **só no FDD**, porque a própria reunião os classificou como não arquiteturais (`[09:23] Sofia`, `[09:24] Larissa`).

## 3. Comandos

Não há build: o entregável é Markdown. Os comandos abaixo são as verificações automáticas e ficam consolidados em `tasks/verify-docs.sh`, que é criado na fase de implementação.

```bash
# Rodar todas as verificações (sai com código != 0 se alguma falhar)
bash tasks/verify-docs.sh

# 1. Código da aplicação intocado (deve imprimir nada)
git diff --stat main -- src prisma tests package.json package-lock.json tsconfig.json tsconfig.build.json vitest.config.ts .eslintrc.json .prettierrc docker-compose.yml .env.example TRANSCRICAO.md

# 2. ADRs: entre 5 e 8 arquivos, nome no padrão (a segunda linha deve imprimir nada)
ls docs/adrs/ADR-[0-9][0-9][0-9]-*.md | wc -l
ls docs/adrs | grep -vE '^(README\.md|ADR-[0-9]{3}-[a-z0-9]+(-[a-z0-9]+)*\.md)$'

# 3. ADRs: seções obrigatórias (deve imprimir nada)
for f in docs/adrs/ADR-*.md; do for s in "Status" "Contexto" "Decisão" "Alternativas Consideradas" "Consequências"; do
  grep -q "^## $s" "$f" || echo "$f: falta '## $s'"; done; done

# 4. Todo caminho de código EXISTENTE citado existe (arquivos novos propostos ficam na allowlist)
grep -ohE '\b(src|prisma|tests)/[A-Za-z0-9_./-]+\.(ts|prisma|sql|json)\b' docs/*.md docs/adrs/*.md README.md \
  | sort -u | grep -vE '^(src/worker\.ts|src/modules/webhooks/|tests/webhooks)' \
  | while read -r p; do [ -e "$p" ] || echo "INEXISTENTE: $p"; done

# 5. Todo timestamp do Tracker existe na transcrição com o falante correto (deve imprimir nada)
grep -oE '\[[0-9]{2}:[0-9]{2}\] [A-Z][a-z]+' docs/TRACKER.md | sort -u \
  | while read -r t; do grep -qF "$t:" TRANSCRICAO.md || echo "TIMESTAMP INVÁLIDO: $t"; done

# 6. Proporção de fontes no Tracker (TRANSCRICAO >= 70%, CODIGO >= 5 linhas)
awk -F'|' '/^\| *[A-Z]+-[A-Z0-9]/ {n++; if ($6 ~ /TRANSCRICAO/) t++; if ($6 ~ /CODIGO/) c++}
  END {printf "linhas=%d transcricao=%.0f%% codigo=%d\n", n, 100*t/n, c}' docs/TRACKER.md

# 7. Caminhos com Fonte=CODIGO existem (deve imprimir nada)
awk -F'|' '$6 ~ /CODIGO/ {gsub(/[ `]/, "", $7); print $7}' docs/TRACKER.md | sort -u \
  | while read -r p; do [ -e "$p" ] || echo "INEXISTENTE: $p"; done

# 8. Cobertura: IDs usados nos documentos que faltam no Tracker (meta: nada; mínimo aceito: 80%)
comm -23 \
  <(grep -ohE '\b((PRD|RFC|FDD)-[A-Z]+-[0-9]{2}|ADR-[0-9]{3}(-[A-Z]+-[0-9]{2})?)\b' docs/PRD.md docs/RFC.md docs/FDD.md docs/adrs/ADR-*.md | sort -u) \
  <(awk -F'|' '/^\| *[A-Z]+-/ {gsub(/ /, "", $2); print $2}' docs/TRACKER.md | sort -u)

# 9. IDs duplicados no Tracker (deve imprimir nada)
awk -F'|' '/^\| *[A-Z]+-/ {gsub(/ /, "", $2); print $2}' docs/TRACKER.md | sort | uniq -d

# 10. RFC: links para ADRs resolvem (>= 2) e tamanho de 2 a 4 páginas (~900–2000 palavras)
grep -oE '\(\./adrs/ADR-[0-9]{3}-[a-z0-9-]+\.md\)' docs/RFC.md | tr -d '()' | sort -u \
  | while read -r l; do [ -e "docs/$l" ] && echo "ok $l" || echo "QUEBRADO $l"; done
wc -w docs/RFC.md

# 11. FDD: >= 4 endpoints e códigos WEBHOOK_*
grep -cE '^#### (GET|POST|PATCH|PUT|DELETE) /' docs/FDD.md
grep -oE '\bWEBHOOK_[A-Z_]+\b' docs/FDD.md | sort -u

# 12. Varredura de itens fora de escopo (revisão manual: só podem aparecer em Fora de escopo / Alternativas / Questões em aberto)
grep -niE 'e-?mail|dashboard|painel|rate limit|exactly-once|redis|ordena[cç][aã]o global|arquiv|m[uú]ltiplos workers|inbound' docs/*.md docs/adrs/*.md
```

## 4. Estrutura do projeto

```
SPEC.md                    → este spec (fonte da verdade do trabalho)
README.md                  → substituído pelo README do processo (entregável)
TRANSCRICAO.md             → fonte primária, somente leitura
docs/
  PRD.md RFC.md FDD.md TRACKER.md
  adrs/README.md           → atualizado para o padrão ADR-NNN-titulo-em-kebab-case.md
  adrs/ADR-001..007-*.md
tasks/
  plan.md                  → plano de execução (fase Plan)
  todo.md                  → lista de tarefas (fase Tasks)
  process-log.md           → diário de prompts, falhas da IA e correções (insumo do README)
  verify-docs.sh           → verificações da §3
src/ prisma/ tests/ + configs → somente leitura (contexto)
```

## 5. Estilo de escrita (o "code style" dos documentos)

**Idioma:** português, com termos técnicos consagrados em inglês (outbox, worker, backoff, DLQ, at-least-once).

**Títulos de seção:** os títulos de seção obrigatória usam exatamente o nome dado no enunciado, para que o avaliador os encontre (ex.: `## Integração com o sistema existente`, `## Fora de escopo`).

**IDs inline:** todo item rastreável recebe um ID em negrito no próprio documento, e esse mesmo ID é uma linha do Tracker.

| Documento | Padrões de ID |
|---|---|
| PRD | `PRD-FR-01`, `PRD-NFR-01`, `PRD-OBJ-01`, `PRD-OOS-01`, `PRD-RISK-01`, `PRD-AC-01`, `PRD-DEP-01` |
| RFC | `RFC-PROP-01`, `RFC-ALT-01`, `RFC-OPEN-01`, `RFC-RISK-01` |
| FDD | `FDD-FLUXO-01`, `FDD-CONTRATO-01`, `FDD-ERRO-01`, `FDD-RES-01`, `FDD-OBS-01`, `FDD-INT-01`, `FDD-AC-01`, `FDD-RISK-01` |
| ADR | `ADR-001` (decisão), `ADR-001-ALT-01`, `ADR-001-CONS-01` |

**Citação de origem no corpo:** use o formato curto da transcrição entre crases e o caminho de código em crases.

```markdown
**PRD-FR-06** — O cliente consulta o histórico das últimas 100 entregas de um webhook,
com resultado (sucesso/falha), payload, resposta e tempo de resposta. (`[09:34] Marcos`)

**FDD-INT-01** — `src/modules/orders/order.service.ts` → dentro do `prisma.$transaction`
de `changeStatus`, após `tx.orderStatusHistory.create(...)`, chamar
`publishWebhookEvent(tx, order, from, to)` (novo). Falha na inserção propaga e faz rollback. (`[09:40] Bruno`, `[09:41] Bruno`)
```

**Linha do Tracker** (sem `|` dentro das células; uma origem por linha; itens com várias origens usam a principal e citam as demais no resumo):

```markdown
| ID | Documento | Tipo | Conteúdo (resumo) | Fonte | Localização |
| --- | --- | --- | --- | --- | --- |
| ADR-003-ALT-02 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Alternativa descartada | 3 tentativas: janela curta demais para manutenção de 2h | TRANSCRICAO | [09:16] Diego |
| FDD-INT-03 | `docs/FDD.md` | Integração | Replay de DLQ protegido por `requireRole('ADMIN')` | CODIGO | src/middlewares/auth.middleware.ts |
```

**Arquivos novos propostos:** sempre com o marcador `(novo)` e só dentro da allowlist `src/worker.ts`, `src/modules/webhooks/**`, `tests/webhooks*` e migration Prisma nova (sem caminho fixo). Nunca citar como existente algo que não existe.

**Propostas sem decisão na reunião:** marcar como `> Proposta de design:` e ligá-las à âncora que motivou a proposta (ex.: caminho do endpoint de rotação, a partir de `[09:21] Sofia`). Toda proposta relevante aparece também como questão em aberto no RFC ou como risco.

**Fronteira entre alturas (sem duplicação):**
- **RFC:** abordagem, alternativas e questões em aberto. Sem JSON de payload, sem matriz de erros, sem DDL. Aponta para os ADRs e o FDD.
- **ADR:** uma decisão por arquivo, com contexto, alternativas e trade-off. Sem contratos HTTP.
- **FDD:** fluxos, contratos com exemplos, erros, resiliência, observabilidade e integração com arquivos reais. Não re-argumenta as decisões, só linka o ADR.
- **PRD:** problema, clientes, escopo, métricas e critérios de aceitação em linguagem de produto. Sem nomes de tabelas ou arquivos.

**Template de ADR (variante MADR):** `# ADR-NNN: Título` · `## Status` · `## Contexto` · `## Decisão` · `## Alternativas Consideradas` · `## Consequências` (subseções `### Positivas`, `### Negativas`, `### Trade-off`) · `## Referências` (âncoras + links).

## 6. Estratégia de verificação (o "testing strategy" dos documentos)

1. **Automática:** `tasks/verify-docs.sh` (§3) roda antes de cada commit e é obrigatória no fim de cada documento.
2. **Checklist do enunciado:** cada critério de aceite do README original é conferido item por item (§9) antes do commit final.
3. **Revisão adversarial com contexto limpo:** ao terminar cada documento, um subagente sem o histórico da conversa recebe o documento, `TRANSCRICAO.md` e o código, e caça:
   - (a) afirmações sem âncora;
   - (b) âncoras que não dizem o que o documento afirma;
   - (c) itens descartados ou adiados tratados como requisito;
   - (d) contradições com o código;
   - (e) duplicação entre alturas.

   Os achados e as correções vão para `tasks/process-log.md`.
4. **Ciclos esperados:** de 3 a 5 ciclos de geração → revisão → ajuste de prompt → regeneração, todos registrados no log.

## 7. Limites

- **Sempre:**
  - Ancorar cada item em `[hh:mm] Nome` ou em um caminho real.
  - Registrar prompts, falhas da IA e correções em `tasks/process-log.md` no momento em que acontecem.
  - Rodar `tasks/verify-docs.sh` antes de commitar.
  - Fazer commits pequenos, um por documento ou ciclo de revisão, no branch atual.
  - Respeitar a fronteira de altura entre documentos.
- **Perguntar antes:**
  - `git push`, abrir PR ou tornar o repositório público.
  - Mudar a lista de ADRs aprovada na §2.
  - Resolver uma questão em aberto da §10 de forma diferente da default proposta.
  - Adicionar qualquer arquivo fora de `docs/`, `tasks/`, `README.md` e `SPEC.md`.
- **Nunca:**
  - Alterar `src/`, `prisma/`, `tests/`, configurações ou `TRANSCRICAO.md`.
  - Inventar requisito, número, métrica ou decisão sem âncora.
  - Promover item descartado ou adiado a requisito.
  - Citar como existente um arquivo que não existe.
  - Fabricar prompts ou iterações no README: tudo sai do `process-log.md`.

## 8. Base de fatos (extração dirigida da transcrição e do código)

Esta seção é a **fonte única** que alimenta todos os documentos. O item que não estiver aqui não entra sem antes ser adicionado com âncora.

### 8.1 Contexto de negócio
- Três clientes B2B (Atlas Comercial, MaxDistribuição e Nova Cargo) pediram notificação em tempo real. Hoje eles fazem polling em `GET /orders`, e a Atlas ameaça migrar para o concorrente. `[09:00] Marcos`
- "Tempo real" significa menos de 10s, sem atualização manual. `[09:02] Marcos`
- Somente outbound: o cliente recebe, não envia. `[09:02] Marcos`, `[09:03] Sofia`
- Prazo: a Atlas quer a feature até o fim de novembro. Estimativa de 3 sprints, incluindo a revisão de segurança. `[09:45] Marcos`, `[09:46] Larissa`, `[09:47] Larissa`
- Pelo menos 2 dias úteis de revisão de segurança antes do deploy, com foco em HMAC e na geração de secret. `[09:46] Sofia`
- A garantia at-least-once será documentada no portal do desenvolvedor. `[09:26] Marcos`, `[09:40] Marcos`

### 8.2 Requisitos funcionais (≥ 8 para o PRD)
1. Cadastrar webhook (`POST`) com `url` e lista de status. A secret é gerada pela plataforma e devolvida na criação. `[09:31] Marcos`
2. O `customer_id` vai no body ou no path, **não** vem do JWT. `[09:32] Larissa`
3. Editar (`PATCH`), remover (`DELETE`) e listar (`GET`) os webhooks de um customer. `[09:33] Bruno`
4. Filtro de eventos por endpoint (lista de status), aplicado **na inserção** da outbox: se nenhum webhook quer aquele status, não insere. `[09:33] Marcos`, `[09:34] Bruno`
5. Histórico de entregas `GET /webhooks/:id/deliveries` com as últimas 100 entregas: sucesso/falha, payload, resposta e tempo de resposta. `[09:34] Marcos`
6. Rotação de secret pela API, com a secret antiga válida por mais 24h. `[09:21] Sofia`
7. Replay manual da DLQ via `POST /admin/webhooks/dead-letter/:id/replay`, que recoloca o evento na outbox como pendente. `[09:18] Diego`, `[09:35] Diego`
8. O replay exige role `ADMIN` e registra em log quem o executou. `[09:36] Sofia`, `[09:36] Larissa`
9. O CRUD de configuração fica aberto a qualquer role autenticada, por enquanto. `[09:37] Sofia`
10. Disparo automático em toda mudança de status do pedido. `[09:40] Bruno`
11. Retry automático com backoff e DLQ. `[09:17] Larissa`
12. Recusar URL `http` com erro de validação no schema Zod. `[09:23] Sofia`

### 8.3 Requisitos não funcionais e contratos secundários
- Latência de entrega abaixo de 10s. Polling de 2s dá latência mínima de ~2s. `[09:02] Marcos`, `[09:10] Larissa`
- Timeout HTTP de 10s: o que passar disso é falha e vai para retry. `[09:42] Diego`
- Payload máximo de 64KB. Se passar, dá erro e não trunca. `[09:23] Sofia`, `[09:24] Diego`, `[09:24] Larissa`
- Payload JSON com `event_id`, `event_type` (`order.status_changed`), timestamp ISO 8601, `order_id`, `order_number`, `from_status`, `to_status`, `customer_id` e campos básicos do pedido como `total_cents`. **Sem items.** `[09:43] Diego`
- Headers: `X-Event-Id`, `X-Signature`, `X-Timestamp`, `Content-Type: application/json` `[09:44] Diego` e `X-Webhook-Id` `[09:44] Sofia`
- Ordenação garantida só por `order_id` e só com um único worker (limitação conhecida). `[09:12] Diego`, `[09:13] Larissa`
- A outbox tem índice em status (pendente/processando/falhou/entregue) e em `created_at`, e o worker lê os pendentes mais antigos em lote pequeno. `[09:08] Diego`
- IDs em UUID, seguindo o padrão do projeto. `[09:51] Larissa`
- O worker usa o mesmo banco e a mesma `DATABASE_URL`, mas um `PrismaClient` próprio porque roda em outro processo. `[09:11] Diego`, `[09:30] Bruno`

### 8.4 Fora de escopo, adiado ou descartado (NUNCA como requisito)
| Item | Situação | Âncora |
|---|---|---|
| Aviso por e-mail ao cliente quando o webhook falha | Adiado para a próxima fase | `[09:37] Larissa` |
| Rate limiting de saída | Em aberto: observar e decidir depois | `[09:39] Diego`, `[09:39] Larissa` |
| Dashboard / painel visual | Fora de escopo (projeto do time de front) | `[09:40] Larissa` |
| Webhooks inbound | Fora de escopo | `[09:02] Marcos` |
| Arquivamento de entregues após ~30 dias | Fora do escopo desta feature | `[09:08] Diego` |
| Múltiplos workers / ordenação global | Futuro (particionar por `order_id` ou lock pessimista) | `[09:13] Diego` |
| Endurecer as roles do CRUD | Futuro | `[09:37] Sofia` |
| Exactly-once, disparo síncrono, Redis, trigger, retry indefinido, secret global, truncar payload, renderizar no envio, incluir items no payload | Alternativas descartadas | ver §2 e `[09:23] Sofia`, `[09:43] Diego` |

### 8.5 Ganchos no código (verificados)
| Arquivo | O que existe | Uso previsto |
|---|---|---|
| `src/modules/orders/order.service.ts` | `changeStatus` em `this.prisma.$transaction(async (tx) => …)`: valida a transição, debita/repõe estoque, atualiza o pedido e cria o `orderStatusHistory` | Chamar `publishWebhookEvent(tx, …)` dentro da mesma transação |
| `src/modules/orders/order.status.ts` | Máquina de estados (`canTransition`, `shouldDebitStock`, `shouldReplenishStock`) | Os eventos cobrem só transições válidas; o filtro usa os valores do enum `OrderStatus` |
| `prisma/schema.prisma` | Enums `OrderStatus` e `UserRole` (`ADMIN`/`OPERATOR`) e ids `String @id @default(uuid()) @db.Char(36)` | Novos models de webhook config, outbox, dead letter e deliveries no mesmo padrão |
| `src/shared/errors/app-error.ts`, `http-errors.ts`, `index.ts` | `AppError(message, statusCode, errorCode, details)` e subclasses como `InvalidStatusTransitionError` e `InsufficientStockError` | Erros `WEBHOOK_*` como subclasses das classes existentes |
| `src/middlewares/error.middleware.ts` | Trata `AppError`, `ZodError` e Prisma `P2002`/`P2025` | Não muda: pega os erros do módulo novo |
| `src/middlewares/auth.middleware.ts` | `authenticate` e `requireRole(...roles)` | `requireRole('ADMIN')` no replay |
| `src/middlewares/validate.middleware.ts` | Validação Zod | Schemas `https`, lista de status etc. |
| `src/middlewares/request-logger.middleware.ts` | `X-Request-Id` e log `http_request` com `durationMs` | Base de correlação (tracing) API → outbox → worker |
| `src/shared/logger/index.ts` | Pino com `redact` de campos sensíveis | Mesmo logger no worker; incluir secret no `redact` (proposta ancorada no padrão do código) |
| `src/server.ts`, `src/config/database.ts` | Entry point da API e `createPrismaClient()` | Modelo para o `src/worker.ts` (novo) com `PrismaClient` próprio |
| `src/routes/index.ts` | `buildApiRouter` registra os routers dos módulos | Registrar `/webhooks` e `/admin/webhooks` |
| `package.json` | Scripts `dev`, `start` etc. | Novo script `worker` `[09:11] Larissa` |
| `tests/setup.ts` | `deleteMany` por tabela no `beforeEach` | As tabelas novas entram na limpeza (estratégia de testes do FDD/PRD) |

### 8.6 Divergências entre transcrição e código (tratar explicitamente, sem contradizer)
- **Estoque:** `[09:04] Bruno` diz que a transação "decrementa stock_quantity". No código, o débito só ocorre em `PENDING→PAID` e a reposição em cancelamentos a partir de `PAID`/`PROCESSING` (`order.status.ts`). Os documentos descrevem o comportamento real.
- **"Usuários que representam o cliente"** `[09:32] Marcos`: o model `User` não tem vínculo com `Customer`, e as roles são só `ADMIN`/`OPERATOR`. É consistente com a decisão de passar o `customer_id` no body/path. O fato de não haver isolamento por customer entra como risco ou questão em aberto.
- **Criação do pedido** (`create`) não passa por `changeStatus`, então não gera evento. Só mudanças de status geram, o que é consistente com o escopo "status mudou".

## 9. Critérios de sucesso

A entrega está pronta quando **todos** os critérios de aceite do enunciado original passam, cada um com um verificador:

| Critério | Verificação |
|---|---|
| PRD: seções obrigatórias, ≥ 8 FRs, ≥ 1 objetivo com meta quantitativa (ex.: entrega < 10s `[09:02] Marcos`), ≥ 2 itens fora de escopo, ≥ 2 riscos com probabilidade/impacto/mitigação | Checklist manual + contagem `grep -c 'PRD-FR-'` |
| RFC: metadados com os 5 participantes como revisores, ≥ 2 alternativas com trade-off, ≥ 2 questões em aberto, ≥ 2 links para ADRs, 2 a 4 páginas | Comando 10 + checklist |
| FDD: seções obrigatórias, ≥ 4 endpoints com request/response/status, matriz `WEBHOOK_*`, integração com ≥ 4 caminhos reais, observabilidade com métricas + logs + tracing | Comandos 4 e 11 + checklist |
| ADRs: 7 arquivos no padrão, seções obrigatórias, cobrem as 6 decisões principais, ADR-006 cita código | Comandos 2 e 3 |
| Tracker: formato exato, ≥ 80% de cobertura (meta 100%), ≥ 70% TRANSCRICAO com timestamp válido, ≥ 5 CODIGO com caminho real | Comandos 5 a 9 |
| README: as 6 seções, ≥ 1 ferramenta, ≥ 2 prompts em bloco de código, ≥ 2 iterações concretas | Checklist, com conteúdo tirado de `tasks/process-log.md` |
| Consistência: nada contradiz transcrição/código; nenhum arquivo inexistente citado; código intocado | Comandos 1, 4 e 12 + revisão adversarial |

## 10. Questões em aberto (preciso da sua decisão, ou aceito a default)

1. **Contagem de tentativas.** O resumo diz "total 5 tentativas" `[09:48] Larissa`, mas a progressão 1m/5m/30m/2h/12h tem **5 intervalos** e soma "quase 15 horas entre primeira falha e última tentativa" `[09:17] Diego`, o que só fecha com **1 envio inicial + 5 retentativas (6 envios)**.
   → *Default:* o FDD adota 1 envio + 5 retentativas, explica a ambiguidade e o RFC a registra como questão em aberto.
2. **Onde vai o `customer_id` (body ou path).** Ficou indefinido em `[09:32] Larissa`.
   → *Default:* rotas aninhadas `/customers/:customerId/webhooks` para criar e listar, seguindo o padrão de recurso do projeto, e `/webhooks/:id` para PATCH/DELETE/deliveries/rotação. Fica marcado como proposta e aparece como questão em aberto no RFC.
3. **Assinatura durante o grace period da rotação.** A reunião não definiu se, nas 24h, o envio leva uma ou duas assinaturas.
   → *Decisão (revista em 2026-09-29):* nas 24h, `X-Signature` leva **duas assinaturas**, uma com a secret nova e outra com a antiga (ex.: `v1=<hmac_nova>,v1=<hmac_antiga>`), e o cliente aceita se qualquer uma bater. O default original (só a nova) anulava o grace period, porque quem ainda usa a secret antiga falharia na verificação. Fica marcado como proposta ancorada em `[09:21] Sofia`.
4. **Tracing.** Não há tracing distribuído no projeto, e a reunião não tratou do tema.
   → *Default:* o FDD define tracing por correlação de IDs (`X-Request-Id` da requisição de mudança de status → `event_id` → `webhook_id` → tentativa), sem adicionar dependência nova. Fica marcado como proposta ancorada em `src/middlewares/request-logger.middleware.ts`.
