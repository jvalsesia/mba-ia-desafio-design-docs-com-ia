# RFC: Sistema de Webhooks de Notificação de Pedidos

## Metadados

| Campo | Valor |
| --- | --- |
| **Autor** | Julio Valsesia |
| **Status** | Em revisão |
| **Data** | 2026-09-29 |
| **Revisores** | Larissa (Tech Lead), Marcos (Product Manager), Bruno (Engenheiro Pleno, Pedidos), Diego (Engenheiro Sênior, Plataforma), Sofia (Engenheira de Segurança) |
| **Origem** | Reunião técnica registrada em [`TRANSCRICAO.md`](../TRANSCRICAO.md) |
| **Documentos relacionados** | [PRD](./PRD.md) · [FDD](./FDD.md) · [ADRs](./adrs/README.md) · [Tracker](./TRACKER.md) |

## Resumo executivo (TL;DR)

Propomos notificar clientes B2B, em menos de 10 segundos, sobre toda mudança de status dos seus pedidos, por meio de **webhooks outbound assinados**. A solução:
- grava o evento em uma **outbox no próprio MySQL**, na mesma transação que muda o status;
- entrega os eventos por um **worker em processo separado**, que faz polling a cada 2s;
- retenta com **backoff exponencial** até ~15h e move as falhas permanentes para uma **DLQ** com replay por ADMIN;
- assina cada entrega com **HMAC-SHA256** e uma secret por endpoint;
- garante **at-least-once**, com deduplicação pelo cliente via `X-Event-Id`.

Tudo é construído como um módulo a mais do OMS, sem infraestrutura nova. As decisões estão fechadas nos ADRs. Este documento consolida a proposta e lista o que ainda precisa de posição do time.

## Contexto e problema

Três clientes B2B (Atlas Comercial, MaxDistribuição e Nova Cargo) pediram formalmente para ser notificados quando o status de seus pedidos muda. Hoje eles consultam `GET /orders` periodicamente, o que torna a integração "lenta e cara", e a Atlas sinalizou que pode migrar para um concorrente se a feature não sair até o fim do trimestre (`[09:00] Marcos`). Para esses clientes, "tempo real" é qualquer coisa abaixo de 10 segundos (`[09:02] Marcos`). O fluxo é só de saída (`[09:02] Marcos`).

O OMS não tem hoje nenhum mecanismo de eventos, filas ou notificação externa. A mudança de status acontece em `OrderService.changeStatus` (`src/modules/orders/order.service.ts`), em uma transação que valida a máquina de estados, ajusta estoque quando aplicável, atualiza o pedido e grava o histórico. O desafio é notificar sem acoplar a disponibilidade de terceiros a essa transação e sem perder eventos (`[09:04] Bruno`).

## Proposta técnica

**RFC-PROP-01: Publicação transacional.** Ao mudar o status, `changeStatus` chama `publishWebhookEvent(tx, …)` dentro da própria transação (`[09:41] Bruno`).
- A função verifica quais webhooks ativos do customer assinam o novo status. Se nenhum assina, não grava nada (`[09:34] Bruno`).
- Havendo assinantes, grava na outbox o evento já renderizado como snapshot, com um `event_id` UUID.
- Se a gravação falhar, a mudança de status é desfeita (`[09:40] Bruno`).
- Decisões: [ADR-001](./adrs/ADR-001-outbox-no-mysql.md) e [ADR-007](./adrs/ADR-007-snapshot-do-payload-na-insercao.md).

**RFC-PROP-02: Entrega assíncrona.** Um processo Node separado da API, iniciado por `npm run worker`, lê a outbox a cada 2 segundos, pega em lote pequeno os eventos pendentes mais antigos e faz um POST HTTPS para cada endpoint (`[09:09] Diego`, `[09:11] Larissa`).
- Roda uma única instância, o que preserva a ordem por pedido no caminho sem falhas (`[09:12] Diego`).
- Decisão: [ADR-002](./adrs/ADR-002-worker-separado-em-polling.md).

**RFC-PROP-03: Resiliência.** A falha é tratada assim:
- Resposta de erro ou falta de resposta em 10s conta como falha (`[09:42] Diego`).
- O evento é retentado em 1m, 5m, 30m, 2h e 12h (`[09:17] Larissa`).
- Esgotadas as retentativas, vai para uma DLQ em tabela própria. Um ADMIN pode recolocá-lo na fila, com auditoria em log (`[09:18] Diego`, `[09:36] Sofia`).
- Decisão: [ADR-003](./adrs/ADR-003-retry-backoff-e-dlq.md).

**RFC-PROP-04: Confiança na entrega.** Cada entrega é assinada e identificada:
- O corpo é assinado com HMAC-SHA256, usando uma secret exclusiva do endpoint, gerada pela plataforma e rotacionável com 24h de convivência (`[09:22] Sofia`).
- O cliente deduplica pelo `X-Event-Id`, porque a garantia é at-least-once (`[09:26] Larissa`).
- A URL precisa ser `https` (`[09:23] Sofia`), e o payload é limitado a 64KB (`[09:24] Larissa`).
- Decisões: [ADR-004](./adrs/ADR-004-hmac-sha256-secret-por-endpoint.md) e [ADR-005](./adrs/ADR-005-at-least-once-com-x-event-id.md).

**RFC-PROP-05: Superfície de API.** A API ganha endpoints autenticados para:
- cadastrar, listar, editar e remover webhooks de um customer (`[09:31] Marcos`, `[09:33] Bruno`);
- rotacionar a secret (`[09:21] Sofia`);
- consultar as últimas 100 entregas (`[09:34] Marcos`);
- reprocessar a DLQ, com role ADMIN (`[09:36] Larissa`).

O módulo `src/modules/webhooks` (novo) segue os padrões existentes de módulos, erros `WEBHOOK_*`, Pino, error middleware e `requireRole` (`[09:30] Larissa`). Decisão: [ADR-006](./adrs/ADR-006-reuso-dos-padroes-do-projeto.md).

```
 API (processo 1)                                  Worker (processo 2)
 ┌───────────────────────────────┐                 ┌─────────────────────────────┐
 │ PATCH /orders/:id/status      │                 │ a cada 2s: pendentes (lote) │
 │  └ changeStatus ($transaction)│   webhook_outbox│  ├ POST https + HMAC        │
 │     ├ orders / history        │ ──────────────▶ │  ├ 2xx → entregue           │
 │     └ publishWebhookEvent(tx) │     (MySQL)     │  ├ falha → backoff          │
 │ CRUD /webhooks, deliveries    │                 │  └ esgotou → dead letter    │
 │ POST /admin/.../replay (ADMIN)│ ◀────────────── │                             │
 └───────────────────────────────┘ replay recoloca └─────────────────────────────┘
```

Os contratos HTTP, o payload, a matriz de erros, o modelo de dados e a observabilidade estão especificados no [FDD](./FDD.md).

## Alternativas consideradas

| ID | Alternativa | Por que foi descartada (trade-off) |
| --- | --- | --- |
| **RFC-ALT-01** | Disparar o webhook **sincronamente** dentro de `changeStatus` | Latência e disponibilidade do cliente passariam a travar a mudança de status de outros pedidos, e uma falha do cliente não pode desfazer o status (`[09:04] Bruno`). "Síncrono está fora de questão" (`[09:06] Diego`). |
| **RFC-ALT-02** | **Redis Streams** ou fila externa similar | Exigiria nova infraestrutura para um time pequeno, o que seria overengineering (`[09:07] Larissa`, `[09:07] Diego`). A outbox no MySQL entrega a mesma assincronia com atomicidade transacional. |
| **RFC-ALT-03** | **Trigger** do banco para acionar o worker de forma reativa | O MySQL não tem `LISTEN/NOTIFY`, e a trigger não avisa processo externo sem gambiarras. O polling de 2s já cumpre a meta de < 10s (`[09:09] Diego`). |
| **RFC-ALT-04** | Garantia **exactly-once** | Exige coordenação dos dois lados e muito mais complexidade. At-least-once com `event_id` é o padrão de mercado e resolve a grande maioria dos casos (`[09:25] Diego`). Em troca, o cliente assume a deduplicação (`[09:25] Sofia`). |
| **RFC-ALT-05** | **Retry indefinido** ou apenas **3 tentativas** | O retry indefinido deixa eventos pendurados para sempre (`[09:15] Diego`). Com 3 tentativas, a janela seria de ~30 min e não cobriria manutenções de 2h já ocorridas (`[09:16] Diego`). |

## Questões em aberto

| ID | Questão | Origem | Encaminhamento proposto |
| --- | --- | --- | --- |
| **RFC-OPEN-01** | **Rate limiting de saída:** um cliente com dezenas de pedidos mudando por minuto recebe dezenas de chamadas | `[09:38] Diego`, `[09:39] Larissa` | Fora desta fase. Observar em produção e decidir depois, com base nas métricas de volume do FDD |
| **RFC-OPEN-02** | **Contagem de tentativas:** o resumo diz "5 tentativas" (`[09:48] Larissa`), mas os 5 intervalos somam "quase 15 horas" (`[09:17] Diego`) | `[09:17] Diego` | FDD e [ADR-003](./adrs/ADR-003-retry-backoff-e-dlq.md) adotam 1 envio + 5 retentativas. **Pedimos confirmação da Larissa e do Diego** |
| **RFC-OPEN-03** | **`customer_id` no body ou no path:** ficou em aberto na reunião | `[09:32] Larissa` | O FDD propõe path (`/customers/:customerId/webhooks`) para criar e listar. A confirmar |
| **RFC-OPEN-04** | **Escala e ordenação:** com mais de um worker, a ordem por pedido se perde. Mesmo com um só, um evento em retry pode ser ultrapassado pelo seguinte do mesmo pedido | `[09:13] Diego` | Adiado. Particionar por `order_id` ou usar lock pessimista quando for preciso escalar. Decidir se eventos do mesmo pedido devem esperar o anterior em retry |
| **RFC-OPEN-05** | **Autorização do CRUD:** qualquer usuário autenticado gerencia webhooks de qualquer customer | `[09:37] Sofia` | "Por enquanto sim. Mais pra frente a gente pode endurecer". Aceito nesta fase e registrado como risco |
| **RFC-OPEN-06** | **Aviso ao cliente sobre webhook com falha** (ex.: e-mail após falhas seguidas) | `[09:37] Larissa` | Próxima fase, "depois que a gente medir o impacto" |

## Impacto e riscos

**Impacto no código:** a mudança em código existente se concentra em quatro pontos:
- a transação de `changeStatus`, que ganha uma chamada;
- o registro de rotas em `src/routes/index.ts`;
- novos modelos em `prisma/schema.prisma`;
- um script novo em `package.json`.

O restante é módulo novo. O `error.middleware.ts` não muda ([ADR-006](./adrs/ADR-006-reuso-dos-padroes-do-projeto.md)).

**Impacto operacional e no cliente:**
- Há um processo a mais para implantar e monitorar.
- O cliente precisa expor um endpoint `https`, validar o HMAC e deduplicar por `X-Event-Id`. O Marcos documenta isso no portal (`[09:26] Marcos`).

**Prazo:** estimativa de 3 sprints, incluindo pelo menos 2 dias úteis de revisão de segurança antes do deploy (`[09:46] Larissa`, `[09:46] Sofia`). A Atlas espera a feature até o fim de novembro (`[09:45] Marcos`).

| ID | Risco | Mitigação |
| --- | --- | --- |
| **RFC-RISK-01** | Com worker único, um cliente lento, com até 10s por chamada, atrasa as entregas dos demais além da meta de 10s | *Proposta de design:* envio concorrente entre pedidos distintos dentro do lote, preservando a ordem por pedido. Métricas de latência e de fila no FDD e revisão de escala (RFC-OPEN-04). Timeout de 10s em `[09:42] Diego` |
| **RFC-RISK-02** | Crescimento contínuo da outbox, já que o arquivamento está fora do escopo | Índices em status e `created_at` e leitura em lote pequeno. Arquivamento posterior (`[09:08] Diego`) |
| **RFC-RISK-03** | Vazamento de secret, que já aconteceu com um cliente | Secret por endpoint, rotação com grace de 24h, `redact` no logger e revisão da Sofia (`[09:22] Diego`) |
| **RFC-RISK-04** | Configuração de webhook de outro customer por um usuário autenticado | Aceito nesta fase (RFC-OPEN-05), com auditoria via logs (`[09:37] Sofia`) |
| **RFC-RISK-05** | Estouro do prazo da Atlas | Escopo enxuto, sem painel, e-mail ou rate limit, e estimativa de 3 sprints validada pelo time (`[09:46] Larissa`) |

## Decisões relacionadas

| ADR | Decisão |
| --- | --- |
| [ADR-001](./adrs/ADR-001-outbox-no-mysql.md) | Outbox transacional no MySQL |
| [ADR-002](./adrs/ADR-002-worker-separado-em-polling.md) | Worker em processo separado com polling de 2s |
| [ADR-003](./adrs/ADR-003-retry-backoff-e-dlq.md) | Retry 1m/5m/30m/2h/12h e DLQ em tabela separada |
| [ADR-004](./adrs/ADR-004-hmac-sha256-secret-por-endpoint.md) | HMAC-SHA256, secret por endpoint, rotação com grace de 24h |
| [ADR-005](./adrs/ADR-005-at-least-once-com-x-event-id.md) | At-least-once com `X-Event-Id` |
| [ADR-006](./adrs/ADR-006-reuso-dos-padroes-do-projeto.md) | Reuso dos padrões existentes do projeto |
| [ADR-007](./adrs/ADR-007-snapshot-do-payload-na-insercao.md) | Snapshot do payload na inserção |
