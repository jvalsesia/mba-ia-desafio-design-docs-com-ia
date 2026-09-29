# Tarefas: Pacote de Design Docs — Webhooks de Pedidos

> Plano: [`plan.md`](./plan.md) · Spec: [`../SPEC.md`](../SPEC.md)
>
> **Definição de pronto de toda tarefa:**
> - `bash tasks/verify-docs.sh` sem erros nos itens aplicáveis;
> - linhas novas no `docs/TRACKER.md` para todo ID criado;
> - entrada em `tasks/process-log.md` com o(s) prompt(s) usado(s) e o que precisou ser corrigido;
> - commit local.

## Fase 1: Fundação

### T1: Script de verificação e padronização de `docs/adrs/README.md` ✅
**Descrição:** transformar os comandos da §3 do SPEC em `tasks/verify-docs.sh`. Checks de documento que ainda não existe viram aviso, não falha. Atualizar `docs/adrs/README.md` para o padrão `ADR-NNN-titulo-em-kebab-case.md` e o template MADR da §5. Criar o `docs/TRACKER.md` com o cabeçalho exato da tabela.

**Aceite:**
- [ ] O script roda do início ao fim no estado atual e sai com código 0.
- [ ] Um Tracker de teste com um timestamp falso (ex.: `[09:16] Sofia`) faz o script falhar.
- [ ] `docs/adrs/README.md` descreve a nomenclatura e o índice (vazio) dos ADRs.

**Verificação:** `bash tasks/verify-docs.sh; echo $?` e teste negativo com uma cópia temporária no scratchpad.
**Dependências:** nenhuma · **Arquivos:** `tasks/verify-docs.sh`, `docs/adrs/README.md`, `docs/TRACKER.md` · **Tamanho:** S

## Fase 2: Decisões (ADRs)

### T2: ADR-001 (outbox no MySQL) e ADR-002 (worker separado em polling)
**Descrição:** escrever os dois ADRs no template MADR a partir da §2 e da §8 do SPEC. O ADR-001 cobre a transação atômica com `changeStatus` e descarta o síncrono e o Redis Streams. O ADR-002 cobre o polling de 2s, o processo separado, o `PrismaClient` próprio e a ordenação só por `order_id` com um único worker, e descarta trigger e worker no processo da API.

**Aceite:**
- [ ] Cada ADR tem Status, Contexto, Decisão, Alternativas Consideradas e Consequências (positivas, negativas e trade-off).
- [ ] Toda afirmação traz âncora `[hh:mm] Nome` ou caminho real.
- [ ] Linhas `ADR-00X`, `ADR-00X-ALT-NN` e `ADR-00X-CONS-NN` no Tracker.

**Verificação:** comandos 2, 3, 5, 8 e 9 do verify.
**Dependências:** T1 · **Arquivos:** `docs/adrs/ADR-001-outbox-no-mysql.md`, `docs/adrs/ADR-002-worker-separado-em-polling.md`, `docs/TRACKER.md`, `docs/adrs/README.md` · **Tamanho:** S

### T3: ADR-003 (retry com backoff + DLQ) e ADR-004 (HMAC-SHA256 por endpoint)
**Descrição:** o ADR-003 registra 1m/5m/30m/2h/12h, a ambiguidade "5 tentativas" × "quase 15h" (decisão: 1 envio + 5 retentativas) e a DLQ em tabela `webhook_dead_letter` com replay de ADMIN. Alternativas: retry indefinido, 3 tentativas e `failed` na outbox. O ADR-004 registra HMAC-SHA256 sobre o corpo, `X-Signature`, secret por endpoint gerada pela plataforma e rotação com grace de 24h. Alternativa: secret global.

**Aceite:**
- [ ] Seções obrigatórias presentes.
- [ ] A ambiguidade da contagem de tentativas está explícita, com as duas âncoras (`[09:17] Diego`, `[09:48] Larissa`).
- [ ] Linhas no Tracker.

**Verificação:** comandos 2, 3, 5, 8 e 9.
**Dependências:** T1 · **Arquivos:** `docs/adrs/ADR-003-retry-backoff-e-dlq.md`, `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md`, `docs/TRACKER.md`, `docs/adrs/README.md` · **Tamanho:** S

### T4: ADR-005 (at-least-once + X-Event-Id), ADR-006 (reuso de padrões) e ADR-007 (snapshot do payload)
**Descrição:** o ADR-005 descarta o exactly-once e transfere a deduplicação ao cliente. O ADR-006 cita explicitamente:
- `src/modules/*`
- `src/shared/errors/app-error.ts`
- `src/shared/errors/http-errors.ts`
- `src/middlewares/error.middleware.ts`
- `src/middlewares/auth.middleware.ts`
- `src/shared/logger/index.ts`
- `publishWebhookEvent(tx, …)`, contra a alternativa de injetar o repository.

O ADR-007 decide o snapshot na inserção, contra a renderização no envio.

**Aceite:**
- [ ] Seções obrigatórias presentes.
- [ ] O ADR-006 referencia ≥ 4 caminhos reais existentes.
- [ ] Linhas no Tracker, incluindo ≥ 3 linhas CODIGO.

**Verificação:** comandos 2, 3, 4, 5, 7, 8 e 9.
**Dependências:** T1 · **Arquivos:** `docs/adrs/ADR-005-at-least-once-com-x-event-id.md`, `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md`, `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md`, `docs/TRACKER.md`, `docs/adrs/README.md` · **Tamanho:** M

### CP-A: Checkpoint dos ADRs
- [ ] `bash tasks/verify-docs.sh` passa.
- [ ] Revisão adversarial dos 7 ADRs (subagente com contexto limpo): âncoras sustentam as afirmações; nenhum item da §8.4 do SPEC virou decisão; nada contradiz o código.
- [ ] Achados e correções registrados em `tasks/process-log.md`.
- [ ] O índice em `docs/adrs/README.md` lista os 7 ADRs.

## Fase 3: Proposta

### T5: RFC
**Descrição:** o RFC traz:
- metadados (autor Julio Valsesia; status "Em revisão"; data; os 5 participantes como revisores);
- TL;DR;
- contexto e problema;
- proposta técnica em nível de arquitetura (componentes e fluxo macro, sem JSON, DDL ou matriz de erros);
- ≥ 2 alternativas descartadas com trade-off (síncrono, Redis Streams, trigger, exactly-once);
- ≥ 2 questões em aberto: rate limiting `[09:39]`, contagem de tentativas, `customer_id` body/path `[09:32]`, escala multi-worker `[09:13]`, endurecimento de roles `[09:37]`;
- impacto e riscos;
- decisões relacionadas com links relativos para os 7 ADRs.

**Aceite:**
- [ ] Todas as seções obrigatórias presentes.
- [ ] Entre ~900 e ~2000 palavras.
- [ ] ≥ 2 links de ADR resolvem.
- [ ] Linhas `RFC-*` no Tracker.

**Verificação:** comandos 5, 8, 9 e 10 + leitura comparando com os ADRs (sem repetição literal).
**Dependências:** CP-A · **Arquivos:** `docs/RFC.md`, `docs/TRACKER.md` · **Tamanho:** S

### CP-B: Checkpoint do RFC
- [ ] Verify passa.
- [ ] Revisão adversarial focada em: alternativas realmente discutidas e descartadas na reunião; questões em aberto realmente não decididas; nenhum detalhe de nível FDD.
- [ ] Registro no process-log.

## Fase 4: Implementação (FDD)

### T6: FDD fatia 1: contexto, objetivos, escopo, fluxos e integração
**Descrição:**
- **Contexto e motivação técnica**, **Objetivos técnicos** e **Escopo e exclusões**.
- **Fluxos detalhados:**
  - inserção na outbox dentro do `$transaction` de `changeStatus`, com filtro por status na inserção;
  - ciclo do worker (polling de 2s, lote pequeno, estados pendente/processando/entregue/falhou);
  - retry com agenda de backoff;
  - DLQ e replay.
- **Integração com o sistema existente**, com ≥ 4 caminhos reais da §8.5 do SPEC e o que muda em cada um. Arquivos novos com o marcador `(novo)`.
- Modelo de dados das tabelas novas no padrão `@db.Char(36)` / uuid.

**Aceite:**
- [ ] ≥ 4 caminhos reais na seção de integração (comando 4 sem INEXISTENTE).
- [ ] Os fluxos cobrem outbox, worker, retry e DLQ.
- [ ] As divergências da §8.6 do SPEC são tratadas sem contradizer o código.

**Verificação:** comandos 4, 5, 7, 8 e 9.
**Dependências:** CP-B · **Arquivos:** `docs/FDD.md`, `docs/TRACKER.md` · **Tamanho:** M

### T7: FDD fatia 2: contratos públicos e matriz de erros
**Descrição:** endpoints com headers de exemplo, request, response, status codes e semântica:
- `POST /customers/:customerId/webhooks`
- `GET /customers/:customerId/webhooks`
- `PATCH /webhooks/:id`
- `DELETE /webhooks/:id`
- `POST /webhooks/:id/rotate-secret`
- `GET /webhooks/:id/deliveries`
- `POST /admin/webhooks/dead-letter/:id/replay`

Mais o contrato de saída (payload JSON e headers `X-Event-Id`, `X-Signature`, `X-Timestamp`, `X-Webhook-Id` e `Content-Type`). A matriz de erros usa códigos `WEBHOOK_*`, com a classe base existente e o status HTTP no formato de resposta do `error.middleware.ts`.

**Aceite:**
- [ ] ≥ 4 headings `#### MÉTODO /rota` com request e response de exemplo.
- [ ] Todos os códigos da matriz começam com `WEBHOOK_` e mapeiam para uma subclasse existente de `AppError`.
- [ ] Caminhos propostos marcados como proposta quando não vêm da transcrição.

**Verificação:** comandos 5, 8, 9 e 11.
**Dependências:** T6 · **Arquivos:** `docs/FDD.md`, `docs/TRACKER.md` · **Tamanho:** M

### T8: FDD fatia 3: resiliência, observabilidade, dependências, aceite e riscos
**Descrição:**
- **Resiliência:** timeout de 10s, backoff, limite de 64KB e fallback para a DLQ.
- **Observabilidade:**
  - métricas: pendentes na outbox, idade do mais antigo, entregas por resultado, latência, tamanho da DLQ;
  - logs Pino com campos padronizados e `redact` da secret;
  - tracing por correlação `X-Request-Id` → `event_id` → `webhook_id` → tentativa.
- **Dependências e compatibilidade**, com `crypto` nativo e sem lib nova.
- **Critérios de aceite técnicos** e **Riscos e mitigação**.

**Aceite:**
- [ ] A seção de observabilidade cita métricas, logs e tracing.
- [ ] Cada valor numérico tem âncora.
- [ ] Os riscos têm mitigação.

**Verificação:** comandos 5, 6, 8, 9 e 12.
**Dependências:** T7 · **Arquivos:** `docs/FDD.md`, `docs/TRACKER.md` · **Tamanho:** S

### CP-C: Checkpoint do FDD
- [ ] Verify passa.
- [ ] Revisão adversarial: contratos coerentes com a transcrição; nenhum arquivo "existente" inexistente; sem duplicação argumentativa dos ADRs; um dev consegue começar a codar.
- [ ] Registro no process-log.

## Fase 5: Produto e rastreabilidade

### T9: PRD
**Descrição:** as 12 seções obrigatórias em linguagem de produto:
- ≥ 8 requisitos funcionais (§8.2 do SPEC);
- requisitos não funcionais;
- objetivo com meta quantitativa (entrega < 10s `[09:02] Marcos`; adoção pelos 3 clientes; prazo de fim de novembro);
- **Fora de escopo** com ≥ 2 itens da §8.4;
- ≥ 2 riscos com probabilidade, impacto e mitigação;
- critérios de aceitação;
- estratégia de testes e validação.

Sem nomes de tabelas ou arquivos.

**Aceite:**
- [ ] 12 seções presentes.
- [ ] `grep -c 'PRD-FR-'` indica ≥ 8 FRs distintos.
- [ ] Riscos em tabela com probabilidade, impacto e mitigação.

**Verificação:** comandos 5, 8, 9 e 12.
**Dependências:** CP-C · **Arquivos:** `docs/PRD.md`, `docs/TRACKER.md` · **Tamanho:** S

### T10: Consolidação do Tracker
**Descrição:** fechar a cobertura em 100% dos IDs, remover duplicatas, conferir as proporções (≥ 70% TRANSCRICAO, ≥ 5 CODIGO) e agrupar por documento, com uma nota de legenda no topo.

**Aceite:**
- [ ] Comando 8 vazio.
- [ ] Comando 9 vazio.
- [ ] Comando 6 dentro das metas.
- [ ] Comandos 5 e 7 vazios.

**Verificação:** `bash tasks/verify-docs.sh`.
**Dependências:** T9 · **Arquivos:** `docs/TRACKER.md` · **Tamanho:** S

### CP-D: Checkpoint do pacote técnico
- [ ] Verify passa por inteiro.
- [ ] Revisão adversarial cruzada PRD × RFC × FDD × ADRs: sem contradição entre documentos, sem duplicação de altura.
- [ ] Registro no process-log.

## Fase 6: Processo e fechamento

### T11: README do processo
**Descrição:** substituir o enunciado pelas seções obrigatórias:
- Sobre o desafio
- Ferramentas de IA utilizadas
- Workflow adotado
- Prompts customizados (≥ 2, em bloco de código, copiados do process-log)
- Iterações e ajustes (≥ 2 concretas, do process-log, com a contagem de ciclos)
- Como navegar a entrega

Manter um link para o enunciado original (repositório base).

**Aceite:**
- [ ] 6 seções presentes.
- [ ] Todo prompt e toda iteração citados existem no process-log.

**Verificação:** checklist do README + `diff` manual contra o process-log.
**Dependências:** CP-D · **Arquivos:** `README.md` · **Tamanho:** S

### T12: Revisão final contra o checklist do enunciado
**Descrição:** percorrer item por item os critérios de aceite do enunciado original (§9 do SPEC), corrigir o que faltar e registrar o ciclo final no process-log.

**Aceite:**
- [ ] Todos os itens marcados, com evidência (saída do verify ou trecho do documento).
- [ ] `git diff --stat main -- src prisma tests …` vazio.

**Verificação:** `bash tasks/verify-docs.sh` + checklist.
**Dependências:** T11 · **Arquivos:** quaisquer de `docs/`, `README.md`, `tasks/process-log.md` · **Tamanho:** S
