# FDD: Sistema de Webhooks de Notificação de Pedidos

| Campo | Valor |
| --- | --- |
| **Autor** | Julio Valsesia |
| **Status** | Pronto para implementação (pendente de confirmação dos pontos RFC-CONF-01/02 e RFC-OPEN-02) |
| **Data** | 2026-09-29 |
| **Base** | [RFC](./RFC.md) · [ADRs](./adrs/README.md) · [PRD](./PRD.md) · [Tracker](./TRACKER.md) |

> **Convenções deste documento**
> - Cada item traz a origem, `[hh:mm] Nome` da [transcrição](../TRANSCRICAO.md) ou o caminho do arquivo no código.
> - **(novo)** marca um arquivo que ainda não existe e será criado.
> - *Proposta de design* marca uma escolha de implementação que a reunião não fechou, sempre ligada à decisão que a motivou.
> - O "porquê" de cada decisão está nos ADRs e não é repetido aqui.
> - Todos os caminhos HTTP da API são relativos ao prefixo `/api/v1`, montado em `src/app.ts` (`app.use('/api/v1', buildApiRouter(controllers))`).

---

## 1. Contexto e motivação técnica

**FDD-CTX-01:** Hoje os clientes B2B fazem polling em `GET /orders` para detectar mudanças de status (`[09:00] Marcos`). O OMS não tem eventos, filas nem notificação externa. A única porta de mudança de status é `OrderService.changeStatus` (`src/modules/orders/order.service.ts`), que roda dentro de `this.prisma.$transaction(async (tx) => …)` e executa, nesta ordem:
1. busca o pedido com os items;
2. rejeita a transição para o mesmo status (`ConflictError` com `INVALID_STATUS_TRANSITION`);
3. valida a transição com `canTransition` (`src/modules/orders/order.status.ts`);
4. debita estoque **somente** em `PENDING → PAID` (`shouldDebitStock`) e repõe estoque em cancelamentos a partir de `PAID`/`PROCESSING` (`shouldReplenishStock`);
5. atualiza `orders.status`;
6. insere em `order_status_history`.

Na reunião, a transação foi descrita como "pesada" e como "decrementa stock_quantity" (`[09:04] Bruno`). O código mostra que o estoque só é mexido nas duas transições acima. Este FDD segue o comportamento real.

**FDD-CTX-02:** A solução aprovada é outbox transacional + worker separado em polling + retry/DLQ + HMAC + at-least-once ([ADR-001](./adrs/ADR-001-outbox-no-mysql.md) a [ADR-007](./adrs/ADR-007-snapshot-do-payload-na-insercao.md)). A tecnicalidade central é que a inserção do evento precisa acontecer **dentro** da transação existente, sem acoplar a chamada HTTP a ela (`[09:40] Bruno`, `[09:41] Diego`).

## 2. Objetivos técnicos

| ID | Objetivo | Meta verificável | Origem |
| --- | --- | --- | --- |
| **FDD-OBJ-01** | Latência de notificação | p95 do tempo entre o commit da mudança de status e a entrega bem-sucedida (1ª tentativa) **< 10 s** | `[09:02] Marcos` |
| **FDD-OBJ-02** | Nenhuma mudança de status sem evento | 100% das mudanças de status com assinante geram linha na outbox **na mesma transação**; falha na inserção desfaz a mudança | `[09:40] Bruno` |
| **FDD-OBJ-03** | Tolerância a indisponibilidade do cliente | Retentativas cobrem **14h36min** após a primeira falha antes da DLQ | `[09:17] Diego` |
| **FDD-OBJ-04** | Zero infraestrutura e dependências novas | Nenhum pacote novo em `package.json`; só MySQL, Prisma, Pino e APIs nativas do Node 20 | `[09:07] Diego`, `[09:29] Bruno` |
| **FDD-OBJ-05** | Secrets nunca expostos | Secret só aparece nas respostas de criação (`[09:31] Marcos`) e de rotação (`[09:21] Sofia`); nunca em listagens nem em logs, porque um vazamento em log já ocorreu com um cliente (`[09:22] Diego`) | `[09:31] Marcos` |

## 3. Escopo e exclusões

**FDD-ESC-01 (dentro):**
- Evento `order.status_changed` para toda transição válida feita por `changeStatus`, filtrado pelos status assinados por cada webhook (`[09:33] Marcos`, `[09:34] Bruno`).
- CRUD de configuração, rotação de secret, histórico de entregas e replay de DLQ (`[09:31] Marcos`–`[09:36] Sofia`).
- Worker com retry e DLQ.

**FDD-ESC-02 (fora, por decisão da reunião):**
- Notificação por e-mail de falhas (`[09:37] Larissa`).
- Rate limiting de saída (`[09:39] Larissa`).
- Painel visual (`[09:40] Larissa`).
- Webhooks inbound (`[09:02] Marcos`).
- Arquivamento de linhas entregues (`[09:08] Diego`).
- Múltiplos workers (`[09:13] Diego`).
- Endurecimento de roles no CRUD (`[09:37] Sofia`).

**FDD-ESC-03 (fora, por consequência do código):**
- **Criação** e **exclusão** de pedidos não geram evento. `OrderService.create` e `OrderService.delete` não passam por `changeStatus` (`src/modules/orders/order.service.ts`), e a feature cobre só mudança de status (`[09:00] Marcos`).
- A reunião não discutiu uma **listagem de DLQ**. O ADMIN obtém o `id` do dead letter pelo log `webhook_dead_lettered` (§9.2).

## 4. Modelo de dados

**FDD-DADOS-01:** Os novos models entram em `prisma/schema.prisma` no padrão existente (`String @id @default(uuid()) @db.Char(36)`, `@@map` em snake_case), por uma migration nova em `prisma/migrations/` (novo) (`[09:51] Larissa`).

```prisma
enum WebhookOutboxStatus {
  PENDING      // pendente
  PROCESSING   // processando
  DELIVERED    // entregue
  FAILED       // falhou (movido para a DLQ)
}

model Webhook {
  id                      String    @id @default(uuid()) @db.Char(36)
  customerId              String    @db.Char(36)
  url                     String    @db.VarChar(2048)
  events                  Json                          // OrderStatus[] assinados
  secret                  String    @db.VarChar(128)
  previousSecret          String?   @db.VarChar(128)    // válida até previousSecretExpiresAt
  previousSecretExpiresAt DateTime?
  active                  Boolean   @default(true)
  createdAt               DateTime  @default(now())
  updatedAt               DateTime  @updatedAt

  customer    Customer            @relation(fields: [customerId], references: [id], onDelete: Cascade)
  outbox      WebhookOutbox[]
  deliveries  WebhookDelivery[]

  @@index([customerId, active])
  @@map("webhooks")
}

model WebhookOutbox {
  id            String              @id @default(uuid()) @db.Char(36) // = event_id = X-Event-Id
  webhookId     String              @db.Char(36)
  orderId       String              @db.Char(36)                      // sem FK: o evento sobrevive ao pedido
  eventType     String              @db.VarChar(64)
  payload       String              @db.MediumText                    // snapshot JSON serializado
  status        WebhookOutboxStatus @default(PENDING)
  attempts      Int                 @default(0)
  nextAttemptAt DateTime            @default(now())
  lastError     String?             @db.VarChar(500)
  requestId     String?             @db.VarChar(64)                   // correlação (§9.3)
  deliveredAt   DateTime?
  createdAt     DateTime            @default(now())
  updatedAt     DateTime            @updatedAt

  webhook    Webhook            @relation(fields: [webhookId], references: [id], onDelete: Cascade)
  deliveries WebhookDelivery[]

  @@index([status, createdAt])
  @@index([orderId])
  @@map("webhook_outbox")
}

model WebhookDelivery {
  id           String   @id @default(uuid()) @db.Char(36)
  webhookId    String   @db.Char(36)
  outboxId     String   @db.Char(36)
  attempt      Int                          // cumulativo por evento; 1 = envio inicial
  success      Boolean
  statusCode   Int?
  durationMs   Int
  errorCode    String?  @db.VarChar(64)
  responseBody String?  @db.Text             // truncado em 4 KB
  createdAt    DateTime @default(now())

  webhook Webhook       @relation(fields: [webhookId], references: [id], onDelete: Cascade)
  outbox  WebhookOutbox @relation(fields: [outboxId], references: [id], onDelete: Cascade)

  @@index([webhookId, createdAt])
  @@map("webhook_deliveries")
}

model WebhookDeadLetter {
  id            String    @id @default(uuid()) @db.Char(36)
  outboxId      String    @unique @db.Char(36)
  webhookId     String    @db.Char(36)
  payload       String    @db.MediumText
  errorCode     String    @db.VarChar(64)
  failureReason String    @db.VarChar(500)
  attempts      Int
  failedAt      DateTime  @default(now())
  replayedAt    DateTime?
  replayedById  String?   @db.Char(36)

  // sem FKs de propósito: a evidência sobrevive à exclusão do webhook ou do customer

  @@index([failedAt])
  @@map("webhook_dead_letter")
}
```

O model `Customer` ganha a relação inversa `webhooks Webhook[]`.

**Notas de desenho:**

| ID | Nota | Origem |
| --- | --- | --- |
| **FDD-DADOS-02** | A tabela de configuração guarda URL, secret, `customer_id` e o estado ativo | `[09:21] Bruno` |
| **FDD-DADOS-03** | A outbox tem os estados pendente/processando/falhou/entregue e é indexada por status e `created_at` | `[09:08] Diego` |
| **FDD-DADOS-04** | *Proposta de design:* uma linha da outbox por par (mudança de status, webhook assinante). Assim, retry e DLQ são independentes por endpoint. O `id` da linha é o `event_id` único enviado em `X-Event-Id` | `[09:25] Diego` |
| **FDD-DADOS-05** | *Proposta de design:* `payload` é `MEDIUMTEXT`, com a string JSON exata que será enviada. Os bytes são idênticos em todas as tentativas ([ADR-007](./adrs/ADR-007-snapshot-do-payload-na-insercao.md)), e um evento acima de 64KB ainda pode ser gravado. Com `TEXT` (máx. 65.535 bytes), a inserção falharia e desfaria a mudança de status | `[09:52] Larissa`, `[09:24] Larissa` |
| **FDD-DADOS-06** | DLQ em tabela própria, com payload, motivo e timestamp | `[09:18] Diego` |
| **FDD-DADOS-08** | *Proposta de design:* os tamanhos de coluna (`VarChar(2048)` para URL, `(128)` para secret, `(500)` para motivos, `(64)` para `requestId`) e o truncamento de `responseBody` em 4 KB são escolhas deste FDD. **Todo texto de origem externa é truncado antes de gravar:** `requestId` em 64 caracteres, porque o `requestLogger` aceita qualquer `x-request-id`; `lastError`/`failureReason` em 500; `responseBody` em 4 KB. Sem isso, o MySQL em modo estrito rejeita a escrita: um erro Prisma `P2000`, que o `error.middleware.ts` não trata, derrubaria a mudança de status com 500 | `src/middlewares/request-logger.middleware.ts` |
| **FDD-DADOS-07** | *Proposta de design:* `onDelete: Cascade` de `Webhook → Customer`, para não mudar o comportamento atual de `DELETE /customers/:id`. Exclusão do webhook remove em cascata a outbox e o histórico de entregas. A **DLQ é preservada**: `webhook_dead_letter` não tem FK e guarda uma cópia do payload, para manter a evidência de toda falha permanente ([ADR-003](./adrs/ADR-003-retry-backoff-e-dlq.md)) (ver §6.4) | `prisma/schema.prisma` |

## 5. Fluxos detalhados

### 5.1 FDD-FLUXO-01: Criação do evento na outbox (API, dentro da transação)

```
PATCH /orders/:id/status ─▶ OrderController.changeStatus ─▶ OrderService.changeStatus(id, input, userId, { requestId })
  prisma.$transaction(tx):
    1. tx.order.findUnique + validações existentes (mesmo status, canTransition)
    2. debitStock / replenishStock (quando aplicável)
    3. tx.order.update(status = to)
    4. tx.orderStatusHistory.create(...)
    5. publishWebhookEvent(tx, order, from, to, { requestId })          ◀── novo
         a. subs = tx.webhook.findMany({ customerId: order.customerId, active: true })
                     .filter(w => webhookEventsSchema.parse(w.events).includes(to))   // events é Prisma.JsonValue
         b. se subs vazio → retorna [] (nenhuma linha)
         c. timestamp = new Date().toISOString()
         d. para cada w: eventId = uuidv4(); payload = JSON.stringify({...})
         e. tx.webhookOutbox.createMany([{ id: eventId, webhookId: w.id, orderId, eventType,
                                           payload, requestId, status: PENDING, nextAttemptAt: now }])
    6. refetch do pedido (existente)
  commit ─▶ log "webhook_event_enqueued" (1 por eventId) ─▶ 200 (resposta inalterada)
  qualquer erro em 1–6 ─▶ rollback total ─▶ errorMiddleware (500 ou erro de domínio)
```

| Passo | Regra | Origem |
| --- | --- | --- |
| 5 | A chamada ocorre **dentro** do `tx`; se falhar, o status não muda | `[09:40] Bruno`, `[09:41] Diego` |
| 5a–b | O filtro por status assinado é feito **na inserção**; sem assinante, nada é gravado | `[09:34] Bruno` |
| 5d | Payload renderizado como snapshot e `eventId` UUID gerado na inserção (`uuid` já é dependência do projeto e é usado em `src/middlewares/request-logger.middleware.ts`) | `[09:52] Larissa`, `[09:25] Diego` |
| 5 | Assinatura `publishWebhookEvent(tx, order, fromStatus, toStatus)` + contexto opcional `{ requestId }` para correlação (§9.3). O `{ requestId }` é *proposta de design* | `[09:41] Bruno` |
| — | Log emitido **após** o commit, para não registrar evento que sofreu rollback. *Proposta de design* | `src/shared/logger/index.ts` |

### 5.2 FDD-FLUXO-02: Processamento pelo worker

```
src/worker.ts (novo)
  boot: import { prisma } from './config/database.js' (instância própria deste processo); agenda tick; SIGINT/SIGTERM → shutdown gracioso
  tick (a cada 2s; o tick só reserva e dispara, sem esperar os envios em voo):
    0. lease: UPDATE webhook_outbox SET status='PENDING' WHERE status='PROCESSING' AND updatedAt < now() - 60s
    1. claim: tx { ids = SELECT id FROM webhook_outbox
                          WHERE status='PENDING' AND nextAttemptAt <= now()
                            AND orderId NOT IN (pedidos com envio em voo neste processo)
                          ORDER BY createdAt ASC LIMIT 10;
                   UPDATE ... SET status='PROCESSING' WHERE id IN ids }
    2. agrupa por orderId → cada grupo vira uma tarefa assíncrona (em voo), sequencial por createdAt dentro do grupo;
       o tick NÃO aguarda as tarefas, e o próximo tick reserva eventos de outros pedidos enquanto um cliente lento responde
    3. por evento (try/catch individual: exceção inesperada → volta a PENDING com o backoff da tentativa, sem derrubar o lote):
       a. carrega webhook (url, secret, previousSecret*)
       b. pré-checagens não retentáveis → FLUXO-04 direto:
            webhook inativo            → WEBHOOK_INACTIVE
            bytes(payload) > 65 536    → WEBHOOK_PAYLOAD_TOO_LARGE
            secret ausente             → WEBHOOK_SECRET_REQUIRED
       c. POST url (headers §6.8, body = payload, redirect: 'manual', timeout 10s)
       d. grava WebhookDelivery (attempt = attempts + 1, success, statusCode, durationMs, errorCode, responseBody[0..4KB])
       e. 2xx → status DELIVERED, deliveredAt = now, attempts += 1 → log webhook_delivery_succeeded
          outro → FLUXO-03
    4. log webhook_worker_tick (métricas de fila, §9.1)
```

| ID | Regra | Origem |
| --- | --- | --- |
| **FDD-WORKER-01** | Processo separado, mesmo banco. O `src/worker.ts` (novo) importa o singleton `prisma` de `src/config/database.ts`, como `src/server.ts`. Por ser outro processo, a instância é própria | `[09:11] Diego`, `[09:30] Bruno` |
| **FDD-WORKER-02** | Polling de 2s, pendentes mais antigos primeiro, em lote pequeno. *Proposta de design:* lote de 10 | `[09:09] Diego`, `[09:08] Diego` |
| **FDD-WORKER-03** | Instância única; ordem preservada por `order_id` no caminho sem falhas | `[09:12] Diego` |
| **FDD-WORKER-04** | *Proposta de design:* envios **em voo** com trava por pedido. O tick de 2s não espera os envios em andamento; ele reserva novos eventos apenas de pedidos sem envio em voo, e dentro de cada pedido a ordem é mantida. Assim, um cliente lento (até 10s) atrasa só os eventos **dele**, e a espera dos demais continua em ~2s (RFC-RISK-01). Um limite de envios simultâneos, constante do módulo, protege o processo | `[09:42] Diego` |
| **FDD-WORKER-05** | *Proposta de design:* recuperação por *lease* em todo tick (passo 0). Linhas em `PROCESSING` há mais de 60s (timeout de 10s mais margem) voltam para `PENDING`, o que cobre worker morto no meio do envio e tick interrompido. Somado ao try/catch por evento (passo 3), nenhuma linha fica presa. A reentrega eventual é coberta pelo at-least-once | `[09:24] Diego` |
| **FDD-WORKER-06** | *Proposta de design:* só 2xx conta como sucesso. Redirecionamentos não são seguidos (`redirect: 'manual'`) e contam como falha | `[09:42] Diego` |
| **FDD-WORKER-07** | *Proposta de design:* o shutdown gracioso segue o molde de `src/server.ts` (SIGINT/SIGTERM → parar agendamento → aguardar envios em curso → `prisma.$disconnect()`) | `src/server.ts` |

### 5.3 FDD-FLUXO-03: Retry com backoff

Para uma falha na tentativa `n` (1 = envio inicial), com `BACKOFF = [1 min, 5 min, 30 min, 2 h, 12 h]`:
- se `n ≤ 5`: `status = PENDING`, `attempts = n`, `nextAttemptAt = now + BACKOFF[n-1]` e `lastError`; emite o log `webhook_delivery_failed`;
- se `n = 6`: vai para o FLUXO-04 com `WEBHOOK_RETRIES_EXHAUSTED`.

| Tentativa | Quando | Acumulado desde a 1ª falha |
| --- | --- | --- |
| 1 (envio inicial) | até ~2s após o commit | — |
| 2 | +1 min | 1 min |
| 3 | +5 min | 6 min |
| 4 | +30 min | 36 min |
| 5 | +2 h | 2 h 36 min |
| 6 (última) | +12 h | **14 h 36 min**, as "quase 15 horas" de `[09:17] Diego` |

A agenda vem de `[09:17] Larissa`. A contagem 1 + 5 é a interpretação do [ADR-003](./adrs/ADR-003-retry-backoff-e-dlq.md), pendente de confirmação em RFC-CONF-01. Se o time confirmar "5 envios no total", basta tirar o último elemento de `BACKOFF`.

*Proposta de design:* timeout, erro de rede e resposta não-2xx são todos retentáveis. Só as pré-checagens do passo 3b vão direto para a DLQ.

### 5.4 FDD-FLUXO-04: DLQ e replay

**Mover para a DLQ** (worker, em uma transação):
- a linha da outbox passa a `status = FAILED`, com `lastError` preenchido;
- faz-se um `upsert` em `webhook_dead_letter` por `outboxId`, com `payload`, `errorCode`, `failureReason`, `attempts`, `failedAt = now` e `replayedAt = null`;
- é emitido o log `webhook_dead_lettered` (nível `error`) com `deadLetterId`, `eventId`, `webhookId`, `orderId` e `errorCode` (`[09:18] Diego`).

**Replay** (`POST /admin/webhooks/dead-letter/:id/replay`, §6.7):
1. `authenticate` + `requireRole('ADMIN')` (`[09:36] Sofia`, `[09:36] Larissa`).
2. Dead letter inexistente → `404 WEBHOOK_DEAD_LETTER_NOT_FOUND`. Webhook ou linha da outbox já removidos (DELETE do webhook) → `404 WEBHOOK_NOT_FOUND`.
3. Linha da outbox em qualquer status diferente de `FAILED` (já reenfileirada, em processamento ou já entregue após replay) → `409 WEBHOOK_DEAD_LETTER_ALREADY_REPLAYED`. O replay só vale para evento em falha definitiva.
4. Webhook inativo → `409 WEBHOOK_INACTIVE`.
5. Em uma transação, a **mesma** linha da outbox volta a `PENDING`, com `attempts = 0`, `nextAttemptAt = now` e `lastError = null`. Como o id é o mesmo, o `X-Event-Id` também é, e a dedup do cliente continua funcionando ([ADR-005](./adrs/ADR-005-at-least-once-com-x-event-id.md)). O dead letter recebe `replayedAt = now` e `replayedById = req.user.id`.
6. Log `webhook_replayed` com `adminUserId`, `deadLetterId`, `eventId` e `requestId`, para auditoria (`[09:36] Sofia`).
7. Resposta `202`. O envio acontece no próximo tick do worker.

*Proposta de design:* zerar `attempts` concede uma nova agenda completa de retentativas. O campo `attempts` controla só a agenda. O `attempt` gravado em `webhook_deliveries` é **cumulativo** por evento, calculado como o número de entregas existentes para o `outboxId` + 1, então o histórico não repete "tentativa 1" após um replay. Se o evento falhar de novo, o `upsert` reaproveita o mesmo registro de DLQ e limpa `replayedAt`.

### 5.5 FDD-FLUXO-05: Rotação de secret

1. `POST /webhooks/:id/rotate-secret` gera `newSecret = crypto.randomBytes(32).toString('hex')`, com 64 caracteres hex (*proposta de design*).
2. Em uma única atualização: `previousSecret = secret`, `previousSecretExpiresAt = now + 24h` e `secret = newSecret` (`[09:21] Sofia`).
3. A resposta devolve `secret` **uma única vez**.
4. Enquanto `previousSecretExpiresAt > now`, o worker assina com as duas secrets (§6.8). Depois disso, ignora a anterior.

*Proposta de design:* se houver uma nova rotação dentro das 24h, a secret "anterior" passa a ser a atual e a mais antiga deixa de valer imediatamente.

## 6. Contratos públicos

Todos os endpoints de configuração exigem `Authorization: Bearer <jwt>` (`authenticate`), com qualquer role (`[09:37] Sofia`). O replay exige `ADMIN` (`[09:36] Sofia`). O `customer_id` **não** vem do JWT (`[09:32] Larissa`). Por *proposta de design* (RFC-OPEN-02), ele vai no path para criar e listar, e os demais recursos são endereçados pelo id do webhook.

As respostas de erro seguem o formato do `src/middlewares/error.middleware.ts`: `{ "error": { "code", "message", "details"? } }`. O JSON da API usa camelCase, como o restante do OMS. O payload **enviado ao cliente** usa snake_case, conforme especificado na reunião (`[09:43] Diego`).

Objeto `Webhook` nas respostas (a secret nunca aparece fora de 6.1 e 6.5):

```json
{
  "id": "4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10",
  "customerId": "c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d",
  "url": "https://hooks.atlas.example.com/oms",
  "events": ["SHIPPED", "DELIVERED"],
  "active": true,
  "previousSecretExpiresAt": null,
  "createdAt": "2026-11-03T13:00:00.000Z",
  "updatedAt": "2026-11-03T13:00:00.000Z"
}
```

#### 6.1 POST /customers/:customerId/webhooks

**FDD-CONTRATO-01:** Cadastra um webhook. A secret é gerada pela plataforma e devolvida só aqui (`[09:31] Marcos`).

```http
POST /api/v1/customers/c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d/webhooks
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{ "url": "https://hooks.atlas.example.com/oms", "events": ["SHIPPED", "DELIVERED"] }
```

`201 Created`

```json
{
  "id": "4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10",
  "customerId": "c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d",
  "url": "https://hooks.atlas.example.com/oms",
  "events": ["SHIPPED", "DELIVERED"],
  "active": true,
  "secret": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
  "previousSecretExpiresAt": null,
  "createdAt": "2026-11-03T13:00:00.000Z",
  "updatedAt": "2026-11-03T13:00:00.000Z"
}
```

| Status | Código | Quando |
| --- | --- | --- |
| 201 | — | Criado |
| 400 | `VALIDATION_ERROR` (detalhe `WEBHOOK_INVALID_URL` / `WEBHOOK_INVALID_EVENTS`) | URL não-`https`/inválida; `events` inválido (FDD-ERRO-04); `customerId` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 404 | `WEBHOOK_CUSTOMER_NOT_FOUND` | `customerId` inexistente |

#### 6.2 GET /customers/:customerId/webhooks

**FDD-CONTRATO-02:** Lista os webhooks do customer, sem a secret (`[09:33] Bruno`).

```http
GET /api/v1/customers/c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d/webhooks
Authorization: Bearer eyJhbGciOi...
```

`200 OK`

```json
{ "data": [ { "id": "4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10", "customerId": "c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d", "url": "https://hooks.atlas.example.com/oms", "events": ["SHIPPED", "DELIVERED"], "active": true, "previousSecretExpiresAt": null, "createdAt": "2026-11-03T13:00:00.000Z", "updatedAt": "2026-11-03T13:00:00.000Z" } ] }
```

| Status | Código | Quando |
| --- | --- | --- |
| 200 | — | Lista, possivelmente vazia |
| 400 | `VALIDATION_ERROR` | `customerId` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 404 | `WEBHOOK_CUSTOMER_NOT_FOUND` | `customerId` inexistente |

#### 6.3 PATCH /webhooks/:id

**FDD-CONTRATO-03:** Edita `url`, `events` e/ou `active` (`[09:33] Bruno`). O schema Zod é `strict()` e exige ao menos um campo, e o campo `secret` não é aceito (a rotação usa 6.5). Mudanças de `events` valem para **novos** eventos. *Proposta de design:* eventos já na outbox são enviados à URL vigente no momento do envio. Desativar (`active: false`) faz os eventos pendentes daquele webhook irem para a DLQ com `WEBHOOK_INACTIVE` no próximo tick (*proposta de design*).

```http
PATCH /api/v1/webhooks/4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{ "events": ["PAID", "SHIPPED", "DELIVERED", "CANCELLED"] }
```

`200 OK`: objeto `Webhook` atualizado, sem secret.

```json
{ "id": "4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10", "customerId": "c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d", "url": "https://hooks.atlas.example.com/oms", "events": ["PAID", "SHIPPED", "DELIVERED", "CANCELLED"], "active": true, "previousSecretExpiresAt": null, "createdAt": "2026-11-03T13:00:00.000Z", "updatedAt": "2026-11-04T09:12:00.000Z" }
```

| Status | Código | Quando |
| --- | --- | --- |
| 200 | — | Atualizado |
| 400 | `VALIDATION_ERROR` (detalhe `WEBHOOK_INVALID_URL` / `WEBHOOK_INVALID_EVENTS`) | Corpo vazio, campo desconhecido, URL não-`https`, `id` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 404 | `WEBHOOK_NOT_FOUND` | Webhook inexistente |

#### 6.4 DELETE /webhooks/:id

**FDD-CONTRATO-04:** Remove o webhook (`[09:33] Bruno`). *Proposta de design:* a remoção é física e apaga em cascata os eventos pendentes e o histórico de entregas daquele webhook. Os registros de DLQ são preservados como evidência, sem FK (FDD-DADOS-07), mas não podem mais ser reprocessados. Para pausar mantendo o histórico, use `PATCH { "active": false }`.

```http
DELETE /api/v1/webhooks/4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10
Authorization: Bearer eyJhbGciOi...
```

`204 No Content` (sem corpo)

```json
{ "error": { "code": "WEBHOOK_NOT_FOUND", "message": "Webhook not found" } }
```

↑ Exemplo de resposta `404`.

| Status | Código | Quando |
| --- | --- | --- |
| 204 | — | Removido |
| 400 | `VALIDATION_ERROR` | `id` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 404 | `WEBHOOK_NOT_FOUND` | Webhook inexistente |

#### 6.5 POST /webhooks/:id/rotate-secret

**FDD-CONTRATO-05:** Gera uma nova secret. A anterior continua válida por 24h (`[09:21] Sofia`). O caminho do endpoint é *proposta de design*: a reunião só definiu que existe "endpoint pro cliente conseguir pedir nova secret".

```http
POST /api/v1/webhooks/4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10/rotate-secret
Authorization: Bearer eyJhbGciOi...
```

`200 OK`

```json
{
  "id": "4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10",
  "secret": "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
  "previousSecretExpiresAt": "2026-11-05T10:00:00.000Z"
}
```

| Status | Código | Quando |
| --- | --- | --- |
| 200 | — | Nova secret gerada |
| 400 | `VALIDATION_ERROR` | `id` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 404 | `WEBHOOK_NOT_FOUND` | Webhook inexistente |

#### 6.6 GET /webhooks/:id/deliveries

**FDD-CONTRATO-06:** Histórico das últimas 100 entregas, com sucesso ou falha, payload, resposta e tempo de resposta (`[09:34] Marcos`). *Proposta de design:* cada tentativa é um item, a ordenação é da mais recente para a mais antiga, e o parâmetro `limit` é opcional, de 1 a 100 (padrão 100).

```http
GET /api/v1/webhooks/4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10/deliveries?limit=2
Authorization: Bearer eyJhbGciOi...
```

`200 OK`

```json
{
  "data": [
    {
      "id": "0e7c1b64-5b8f-4a0c-8d8e-3c1d2f4b6a70",
      "eventId": "7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b",
      "attempt": 2,
      "success": true,
      "statusCode": 200,
      "durationMs": 184,
      "errorCode": null,
      "payload": "{\"event_id\":\"7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b\",\"event_type\":\"order.status_changed\",...}",
      "responseBody": "{\"received\":true}",
      "createdAt": "2026-11-03T14:04:36.120Z"
    },
    {
      "id": "b1a2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
      "eventId": "7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b",
      "attempt": 1,
      "success": false,
      "statusCode": null,
      "durationMs": 10002,
      "errorCode": "WEBHOOK_DELIVERY_TIMEOUT",
      "payload": "{\"event_id\":\"7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b\",...}",
      "responseBody": null,
      "createdAt": "2026-11-03T14:03:24.001Z"
    }
  ]
}
```

| Status | Código | Quando |
| --- | --- | --- |
| 200 | — | Lista, possivelmente vazia |
| 400 | `VALIDATION_ERROR` | `limit` fora de 1–100 ou `id` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 404 | `WEBHOOK_NOT_FOUND` | Webhook inexistente |

#### 6.7 POST /admin/webhooks/dead-letter/:id/replay

**FDD-CONTRATO-07:** Recoloca um evento da DLQ na outbox como pendente (`[09:18] Diego`, `[09:35] Diego`). Exige `ADMIN` (`[09:36] Sofia`). Sem corpo. *Proposta de design:* a resposta é `202 Accepted`, porque o envio é assíncrono.

```http
POST /api/v1/admin/webhooks/dead-letter/5e6f7a8b-9c0d-4e1f-a2b3-c4d5e6f7a8b9/replay
Authorization: Bearer eyJhbGciOi... (role ADMIN)
```

`202 Accepted`

```json
{
  "deadLetterId": "5e6f7a8b-9c0d-4e1f-a2b3-c4d5e6f7a8b9",
  "eventId": "7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b",
  "webhookId": "4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10",
  "status": "PENDING",
  "replayedAt": "2026-11-04T10:15:00.000Z"
}
```

| Status | Código | Quando |
| --- | --- | --- |
| 202 | — | Reenfileirado; entrega no próximo tick |
| 400 | `VALIDATION_ERROR` | `id` não é UUID |
| 401 | `UNAUTHORIZED` | Sem JWT válido |
| 403 | `FORBIDDEN` | Role diferente de `ADMIN` (`requireRole`) |
| 404 | `WEBHOOK_DEAD_LETTER_NOT_FOUND` | Dead letter inexistente |
| 404 | `WEBHOOK_NOT_FOUND` | Webhook do evento foi removido |
| 409 | `WEBHOOK_DEAD_LETTER_ALREADY_REPLAYED` | Evento não está mais em falha definitiva (já reenfileirado ou entregue) |
| 409 | `WEBHOOK_INACTIVE` | Webhook desativado |

#### 6.8 Entrega ao cliente: `POST {url do webhook}`

**FDD-CONTRATO-08:** Requisição que o worker envia ao endpoint do cliente.

```http
POST /oms HTTP/1.1
Host: hooks.atlas.example.com
Content-Type: application/json
X-Event-Id: 7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b
X-Webhook-Id: 4b1f8a2e-6a0e-4c43-9a51-2f0c1d7e9b10
X-Timestamp: 2026-11-03T14:03:24.001Z
X-Signature: v1=3b1f0c7e9a2d4b6f8e0a1c3e5d7f9b2a4c6e8d0f1a3b5c7e9d2f4a6c8e0b1d3f

{"event_id":"7d9e2c1a-3b4f-4e5d-9a8b-1c2d3e4f5a6b","event_type":"order.status_changed","timestamp":"2026-11-03T14:03:22.417Z","order_id":"a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d","order_number":"ORD-000123","from_status":"PROCESSING","to_status":"SHIPPED","customer_id":"c0a80121-7ac0-4e1c-9b2d-6f1e2a3b4c5d","total_cents":125990}
```

Resposta esperada do cliente: qualquer `2xx` em até 10s. O corpo é ignorado pela lógica e guardado, truncado, no histórico.

| Elemento | Especificação | Origem |
| --- | --- | --- |
| Corpo | JSON com `event_id`, `event_type` (`order.status_changed`), `timestamp` ISO 8601 do evento, `order_id`, `order_number` (formato `ORD-000123` de `reserveOrderNumber` em `src/modules/orders/order.service.ts`), `from_status`, `to_status`, `customer_id`, `total_cents`. **Sem items**: detalhes via `GET /orders/:id` | `[09:43] Diego` |
| `X-Event-Id` | UUID do evento, estável entre tentativas e replay; o cliente deduplica por ele | `[09:25] Diego` |
| `X-Signature` | `v1=` + hex de HMAC-SHA256(secret, **bytes exatos do corpo**). Durante o grace de rotação: `v1=<hmac_nova>,v1=<hmac_antiga>`, e o cliente aceita se qualquer uma bater. O prefixo `v1=` e o formato com duas assinaturas são *proposta de design* | `[09:20] Sofia`, `[09:21] Sofia` |
| `X-Timestamp` | Instante do envio desta tentativa, em ISO 8601 (*proposta de design* de formato), para o cliente detectar replay. Fica fora da assinatura (ver [ADR-004](./adrs/ADR-004-hmac-sha256-secret-por-endpoint.md)) | `[09:44] Diego` |
| `X-Webhook-Id` | Id do cadastro de webhook, para clientes com vários cadastros | `[09:44] Sofia` |
| `Content-Type` | `application/json` | `[09:44] Diego` |

Verificação do lado do cliente (referência para o portal do desenvolvedor, `[09:26] Marcos`):

```ts
import { createHmac, timingSafeEqual } from 'node:crypto';

function isValid(rawBody: Buffer, header: string, secret: string): boolean {
  const expected = Buffer.from(createHmac('sha256', secret).update(rawBody).digest('hex'));
  return header.split(',').some((part) => {
    const candidate = Buffer.from(part.trim().replace(/^v1=/, ''));
    return candidate.length === expected.length && timingSafeEqual(candidate, expected);
  });
}
```

## 7. Matriz de erros

Classes em `src/modules/webhooks/webhook.errors.ts` (novo), estendendo as classes de `src/shared/errors/http-errors.ts` e `src/shared/errors/app-error.ts` (`[09:28] Bruno`, `[09:29] Larissa`).

`NotFoundError` fixa o código em `NOT_FOUND` (`constructor(resource)`). Por isso, os `404` com prefixo `WEBHOOK_` estendem `AppError` diretamente. `ConflictError` aceita `code` como parâmetro e é reaproveitada.

```ts
// src/modules/webhooks/webhook.errors.ts (novo)
import { AppError, ConflictError } from '../../shared/errors/index.js';

export class WebhookNotFoundError extends AppError {
  constructor() {
    super('Webhook not found', 404, 'WEBHOOK_NOT_FOUND');
  }
}

export class WebhookDeadLetterAlreadyReplayedError extends ConflictError {
  constructor(deadLetterId: string) {
    super('Dead letter already replayed', 'WEBHOOK_DEAD_LETTER_ALREADY_REPLAYED', { deadLetterId });
  }
}
```

### 7.1 Erros da API (resposta HTTP)

| ID | Código | HTTP | Classe base | Quando | Endpoints |
| --- | --- | --- | --- | --- | --- |
| **FDD-ERRO-01** | `WEBHOOK_NOT_FOUND` | 404 | `AppError` | Id de webhook inexistente, ou webhook do evento removido (replay) | 6.3, 6.4, 6.5, 6.6, 6.7 |
| **FDD-ERRO-02** | `WEBHOOK_CUSTOMER_NOT_FOUND` | 404 | `AppError` | `customerId` inexistente | 6.1, 6.2 |
| **FDD-ERRO-03** | `WEBHOOK_INVALID_URL` | 400 | Zod → `ValidationError` | URL malformada ou não-`https`. A validação fica no schema Zod (`[09:23] Sofia`), então a resposta sai como `VALIDATION_ERROR` com `details: [{ "path": "url", "message": "WEBHOOK_INVALID_URL: url must use https" }]`, pelo `validate()` de `src/middlewares/validate.middleware.ts` | 6.1, 6.3 |
| **FDD-ERRO-04** | `WEBHOOK_INVALID_EVENTS` | 400 | Zod → `ValidationError` | `events` vazio, com duplicatas, com `PENDING` ou com valor fora de `OrderStatus`, pelas mensagens customizadas do schema (FDD-INT-08) | 6.1, 6.3 |
| **FDD-ERRO-05** | `WEBHOOK_DEAD_LETTER_NOT_FOUND` | 404 | `AppError` | Id de dead letter inexistente | 6.7 |
| **FDD-ERRO-06** | `WEBHOOK_DEAD_LETTER_ALREADY_REPLAYED` | 409 | `ConflictError` | Replay de evento cuja linha na outbox não está em `FAILED` (já reenfileirado, em processamento ou entregue) | 6.7 |
| **FDD-ERRO-07** | `WEBHOOK_INACTIVE` | 409 | `ConflictError` | Replay para webhook desativado | 6.7 |
| — | `UNAUTHORIZED` / `FORBIDDEN` | 401 / 403 | Existentes | `authenticate` / `requireRole('ADMIN')` sem alteração | todos / 6.7 |

### 7.2 Motivos de falha de entrega (worker)

Estes motivos não são respostas HTTP da API. Eles ficam gravados em `webhook_deliveries.errorCode`, `webhook_outbox.lastError` e `webhook_dead_letter.errorCode`.

| ID | Código | Retentável? | Quando | Origem |
| --- | --- | --- | --- | --- |
| **FDD-ERRO-08** | `WEBHOOK_DELIVERY_TIMEOUT` | Sim | Sem resposta em 10s | `[09:42] Diego` |
| **FDD-ERRO-09** | `WEBHOOK_DELIVERY_HTTP_ERROR` | Sim | Resposta não-2xx, com `statusCode` gravado (*proposta de design*) | `[09:14] Larissa` |
| **FDD-ERRO-10** | `WEBHOOK_DELIVERY_NETWORK_ERROR` | Sim | DNS, conexão recusada, TLS inválido | `[09:14] Larissa` |
| **FDD-ERRO-11** | `WEBHOOK_PAYLOAD_TOO_LARGE` | Não, vai direto para a DLQ | Corpo acima de 64KB (65.536 bytes): "erra", não trunca | `[09:23] Sofia`, `[09:24] Larissa` |
| **FDD-ERRO-12** | `WEBHOOK_SECRET_REQUIRED` | Não, vai direto para a DLQ | Webhook sem secret no momento do envio. O código citado por Bruno fica como invariante do worker, já que a secret é gerada pela plataforma (`[09:31] Marcos`) | `[09:28] Bruno` |
| **FDD-ERRO-13** | `WEBHOOK_INACTIVE` | Não, vai direto para a DLQ | Webhook desativado com evento pendente | `[09:21] Bruno` |
| **FDD-ERRO-14** | `WEBHOOK_RETRIES_EXHAUSTED` | — (terminal) | Falha na 6ª tentativa | `[09:17] Larissa` |

## 8. Estratégias de resiliência

| ID | Estratégia | Detalhe | Origem |
| --- | --- | --- | --- |
| **FDD-RES-01** | Timeout | `fetch(url, { signal: AbortSignal.timeout(10_000) })`, nativo do Node 20 | `[09:42] Diego` |
| **FDD-RES-02** | Retry com backoff | Agenda fixa 1m/5m/30m/2h/12h via `nextAttemptAt`, sem jitter | `[09:17] Larissa` |
| **FDD-RES-03** | Fallback: DLQ | Após a 6ª falha ou em uma falha não retentável, o evento vai para `webhook_dead_letter`, com replay manual por ADMIN | `[09:18] Diego` |
| **FDD-RES-04** | Limite de tamanho | 64KB verificados no worker, antes do envio. *Proposta de design:* validar na inserção lançaria erro dentro da transação de `changeStatus` e bloquearia a mudança de status ([ADR-007](./adrs/ADR-007-snapshot-do-payload-na-insercao.md)) | `[09:24] Larissa` |
| **FDD-RES-05** | Recuperação de crash | *Lease* de 60s em todo tick (`PROCESSING → PENDING`, FDD-WORKER-05). A reentrega eventual é coberta pelo at-least-once | `[09:24] Diego` |
| **FDD-RES-06** | Isolamento entre clientes | Envios em voo com trava por pedido; o tick não bloqueia em cliente lento (FDD-WORKER-04) | `[09:42] Diego` |
| **FDD-RES-07** | Indisponibilidade do banco no worker | *Proposta de design:* uma exceção no tick é logada (`webhook_worker_tick_failed`) e o próximo tick é agendado normalmente. As linhas que já estavam em `PROCESSING` voltam pelo *lease* (FDD-RES-05). Nenhum evento se perde, porque o estado vive na outbox (`[09:06] Diego`) | `[09:06] Diego` |
| **FDD-RES-08** | Worker parado | Os eventos se acumulam em `PENDING` sem perda e são entregues quando o worker volta. O alarme vem da métrica de idade do pendente mais antigo (§9.1) | `[09:11] Diego` |

## 9. Observabilidade

O projeto não tem biblioteca de métricas nem de tracing, só o Pino (`src/shared/logger/index.ts`), e a decisão foi "não vamos botar nada novo" (`[09:29] Bruno`). Por isso, esta seção é uma **proposta de design** apoiada em logs estruturados:
- as métricas são emitidas como campos de log e agregadas pela ferramenta de logs em uso;
- o tracing é feito por correlação de IDs.

Se o time adotar um backend de métricas depois, os nomes abaixo continuam valendo.

### 9.1 Métricas

| ID | Métrica | Tipo | Fonte | Uso / alerta sugerido |
| --- | --- | --- | --- | --- |
| **FDD-OBS-01** | `webhook_delivery_latency_ms` (commit → 2xx na 1ª tentativa) | histograma | `deliveredAt - createdAt` no log `webhook_delivery_succeeded` | SLO: p95 < 10.000 ms (`[09:02] Marcos`) |
| **FDD-OBS-02** | `webhook_outbox_pending` e `webhook_outbox_oldest_pending_age_s` | gauge | `count` e `min(createdAt)` de `PENDING` com `nextAttemptAt <= now`, a cada tick | Alerta se a idade passar de 30s: worker parado ou atrasado |
| **FDD-OBS-03** | `webhook_delivery_attempts_total{result}` | contador | `result` ∈ `success`, `timeout`, `http_error`, `network_error` | Taxa de falha por webhook |
| **FDD-OBS-04** | `webhook_delivery_duration_ms` | histograma | `durationMs` da tentativa | Clientes lentos, perto do timeout de 10s |
| **FDD-OBS-05** | `webhook_dead_letter_total` e `webhook_replay_total` | contador | logs `webhook_dead_lettered` e `webhook_replayed` | Qualquer novo dead letter gera aviso ao time. Serve de base para decidir o aviso por e-mail futuro (`[09:37] Larissa`) |
| **FDD-OBS-06** | `webhook_events_enqueued_total{to_status}` | contador | log `webhook_event_enqueued` | Volume por status, que informa a decisão futura de rate limiting (`[09:39] Larissa`) |

### 9.2 Logs

| ID | Evento (`msg`) | Nível | Campos | Processo |
| --- | --- | --- | --- | --- |
| **FDD-OBS-07** | `webhook_event_enqueued` | info | `requestId`, `eventId`, `webhookId`, `orderId`, `fromStatus`, `toStatus` | API |
| **FDD-OBS-08** | `webhook_delivery_succeeded` / `webhook_delivery_failed` | info / warn | `eventId`, `webhookId`, `orderId`, `attempt`, `statusCode`, `durationMs`, `errorCode`, `nextAttemptAt`, `requestId` | Worker |
| **FDD-OBS-09** | `webhook_dead_lettered` | error | `deadLetterId`, `eventId`, `webhookId`, `orderId`, `errorCode`, `attempts` | Worker |
| **FDD-OBS-10** | `webhook_replayed` | info | `adminUserId`, `deadLetterId`, `eventId`, `webhookId`, `requestId`: auditoria de quem fez o replay | API (`[09:36] Sofia`) |
| **FDD-OBS-11** | `webhook_secret_rotated`, `webhook_created`, `webhook_updated`, `webhook_deleted` | info | `webhookId`, `customerId`, `userId`, `requestId`. **Nunca** o valor da secret | API |
| **FDD-OBS-12** | `webhook_worker_tick` / `webhook_worker_tick_failed` | debug / error | `claimed`, `pending`, `oldestPendingAgeS`, `durationMs` / `err` | Worker |

**FDD-OBS-13 (proteção de secrets):** acrescentar `'secret'`, `'previousSecret'`, `'newSecret'` (chaves no topo do objeto logado) e `'*.secret'`, `'*.previousSecret'`, `'*.newSecret'` (um nível abaixo) aos `redactPaths` de `src/shared/logger/index.ts`, que hoje cobrem só headers de autorização, `password`, `passwordHash`, `token` e `accessToken` ([ADR-006](./adrs/ADR-006-reuso-dos-padroes-do-projeto.md)). O worker usa `logger.child({ component: 'webhook-worker' })`.

### 9.3 Tracing (correlação)

**FDD-OBS-14:** A cadeia de correlação é **`X-Request-Id` → `eventId` → `webhookId` → `attempt`**:
1. O `requestLogger` (`src/middlewares/request-logger.middleware.ts`) já gera ou propaga o `X-Request-Id` e o coloca em `req.id`.
2. O controller repassa esse valor a `changeStatus`, que grava `requestId` na linha da outbox.
3. Todos os logs do worker para aquele evento carregam `requestId`, `eventId`, `webhookId` e `attempt`.
4. O `X-Event-Id` enviado ao cliente permite rastrear ponta a ponta um chamado de suporte do cliente ("não recebi o evento X").

A instrumentação com OpenTelemetry fica fora de escopo, porque adicionaria dependência nova (`[09:29] Bruno`).

## 10. Integração com o sistema existente

| ID | Arquivo (real) | O que existe hoje | Como o módulo de webhooks se integra |
| --- | --- | --- | --- |
| **FDD-INT-01** | `src/modules/orders/order.service.ts` | `changeStatus(id, input, userId)` com `this.prisma.$transaction(async (tx) => …)` | Após `tx.orderStatusHistory.create(...)` e antes do refetch, chamar `await publishWebhookEvent(tx, order, from, to, { requestId })`, importada de `src/modules/webhooks/webhook.publisher.ts` (novo). A assinatura ganha um 4º parâmetro opcional `meta?: { requestId?: string }`. Um erro propaga e faz rollback (`[09:40] Bruno`, `[09:41] Bruno`). O construtor `OrderService(orderRepository, prisma)` não muda |
| **FDD-INT-02** | `src/modules/orders/order.controller.ts` | `changeStatus` chama `this.orders.changeStatus(req.params.id!, req.body, req.user.id)` | Passar `{ requestId: req.id }` como 4º argumento (§9.3). O publisher trunca o valor em 64 caracteres (FDD-DADOS-08) |
| **FDD-INT-03** | `src/modules/orders/order.status.ts` | Máquina de estados (`canTransition`) e enum `OrderStatus` | Sem alteração. Só transições válidas chegam à publicação. O schema de `events` usa `z.nativeEnum(OrderStatus)` (como `updateOrderStatusSchema` em `src/modules/orders/order.schemas.ts`), sem `PENDING`, que nenhuma transição produz (FDD-INT-08) |
| **FDD-INT-04** | `prisma/schema.prisma` | Models com `@db.Char(36)` + `uuid()`, enums, `@@map` | Novos `Webhook`, `WebhookOutbox`, `WebhookDelivery`, `WebhookDeadLetter`, enum `WebhookOutboxStatus`, relação `Customer.webhooks` (§4). Migration nova via `npm run db:migrate` |
| **FDD-INT-05** | `src/shared/errors/app-error.ts`, `src/shared/errors/http-errors.ts`, `src/shared/errors/index.ts` | `AppError(message, statusCode, errorCode, details)`, `ConflictError(message, code, details)` etc. | Estendidos em `src/modules/webhooks/webhook.errors.ts` (novo), com códigos `WEBHOOK_*` (§7). Nenhuma mudança nos arquivos compartilhados |
| **FDD-INT-06** | `src/middlewares/error.middleware.ts` | Trata `AppError` → `{ error: { code, message, details } }`, `ZodError` e Prisma `P2002`/`P2025` | **Sem alteração.** Erros `WEBHOOK_*` saem no formato padrão (`[09:29] Bruno`) |
| **FDD-INT-07** | `src/middlewares/auth.middleware.ts` | `authenticate` e `requireRole(...roles)` | `router.use(authenticate)` em cada router do módulo, todos montados com prefixo (FDD-INT-09); `requireRole('ADMIN')` no replay (`[09:36] Larissa`) |
| **FDD-INT-08** | `src/middlewares/validate.middleware.ts` | `validate({ body, query, params })` → `ValidationError` | Todos os endpoints validam `params`/`body`/`query` com schemas de `src/modules/webhooks/webhook.schemas.ts` (novo), incluindo `url: z.string().url({ message: 'WEBHOOK_INVALID_URL: invalid url' }).refine(u => u.startsWith('https://'), 'WEBHOOK_INVALID_URL: url must use https')` (`[09:23] Sofia`) e `events: z.array(z.nativeEnum(OrderStatus).refine(s => s !== OrderStatus.PENDING, 'WEBHOOK_INVALID_EVENTS: PENDING is never emitted')).min(1, 'WEBHOOK_INVALID_EVENTS: at least one status').refine(a => new Set(a).size === a.length, 'WEBHOOK_INVALID_EVENTS: duplicated status')`. `PENDING` fica de fora porque nenhuma transição leva a ele (`src/modules/orders/order.status.ts`) |
| **FDD-INT-09** | `src/routes/index.ts` | `buildApiRouter(controllers)` monta `/auth`, `/users`, `/customers`, `/products` e `/orders`, cada router com `router.use(authenticate)` interno; tipo `Controllers` | Acrescentar `webhooks` em `Controllers` e montar três routers **com prefixo**, nunca na raiz. Um router na raiz com `router.use(authenticate)` exigiria JWT até em `/auth/login`. Os três são: `router.use('/customers/:customerId/webhooks', buildCustomerWebhookRouter(...))` com `Router({ mergeParams: true })`, registrado **antes** de `'/customers'`; `router.use('/webhooks', buildWebhookRouter(...))`; e `router.use('/admin/webhooks', buildWebhookAdminRouter(...))` |
| **FDD-INT-10** | `src/app.ts` | `buildControllers(prisma)` instancia repository → service → controller | Instanciar `WebhookRepository`, `WebhookService` e `WebhookController` (novos) no mesmo padrão |
| **FDD-INT-11** | `src/server.ts`, `src/config/database.ts` | Bootstrap que importa o singleton `prisma` (criado em `database.ts` ao carregar o módulo), com SIGINT/SIGTERM e `prisma.$disconnect()` | `src/worker.ts` (novo) segue o mesmo molde, com instância própria de `PrismaClient` (`[09:30] Bruno`). A lógica fica em `src/modules/webhooks/webhook.processor.ts` (novo) |
| **FDD-INT-12** | `src/shared/logger/index.ts` | Pino com `redactPaths` | Novos caminhos de redact (FDD-OBS-13); `logger.child` no worker |
| **FDD-INT-13** | `package.json` | Scripts `dev`, `start`, `db:*` e `test` | `"worker": "node --env-file=.env dist/worker.js"` e `"worker:dev": "tsx watch --env-file=.env src/worker.ts"`, espelhando `start`/`dev` (`[09:11] Larissa`). Nenhuma dependência nova |
| **FDD-INT-14** | `tests/setup.ts` | `deleteMany` por tabela no `beforeEach` | Acrescentar `webhookDelivery`, `webhookDeadLetter`, `webhookOutbox` e `webhook` antes de `customer`. Os testes novos ficam em `tests/webhooks.test.ts` (novo), com Vitest + Supertest, como `tests/orders.test.ts` |

Estrutura final do módulo:
- `src/modules/webhooks/` (novo): `webhook.controller.ts`, `webhook.service.ts`, `webhook.repository.ts`, `webhook.routes.ts`, `webhook.schemas.ts`, `webhook.errors.ts`, `webhook.publisher.ts`, `webhook.processor.ts` e `webhook.signer.ts`;
- `src/worker.ts` (novo) (`[09:27] Bruno`, `[09:28] Bruno`).

## 11. Dependências e compatibilidade

| ID | Item | Detalhe |
| --- | --- | --- |
| **FDD-DEP-01** | Runtime | Node ≥ 20 (`engines` em `package.json`): `fetch`, `AbortSignal.timeout` e `node:crypto` (HMAC, `randomBytes`) nativos. **Nenhum pacote novo**, só `uuid`, `zod`, `pino` e `@prisma/client`, que já existem |
| **FDD-DEP-02** | Banco | O mesmo MySQL e a mesma `DATABASE_URL` (`src/config/env.ts`). Migration aditiva: só tabelas novas e uma relação nova em `customers`, sem mudança em colunas existentes |
| **FDD-DEP-03** | Compatibilidade da API | Os contratos existentes não mudam. `PATCH /orders/:id/status` mantém request e response. A latência da transação cresce com uma consulta a `webhooks` e um `createMany` quando há assinante. `DELETE /customers/:id` passa a remover os webhooks em cascata |
| **FDD-DEP-04** | Ordem de deploy | 1) migration → 2) API → 3) worker. Com a API no ar e o worker ainda não, os eventos se acumulam em `PENDING` sem perda (FDD-RES-08) |
| **FDD-DEP-05** | Requisitos do cliente | Endpoint `https`, resposta 2xx em até 10s, validação do HMAC e dedup por `X-Event-Id`, documentados no portal (`[09:26] Marcos`) |
| **FDD-DEP-06** | Revisão de segurança | Pelo menos 2 dias úteis da Sofia antes do deploy, com foco em HMAC e geração de secret (`[09:46] Sofia`) |

## 12. Critérios de aceite técnicos

| ID | Critério | Como verificar |
| --- | --- | --- |
| **FDD-AC-01** | Mudança de status com webhook assinante cria 1 linha `PENDING` na outbox por webhook ativo assinante, com o payload do §6.8 | Teste de integração (`tests/webhooks.test.ts` (novo)): `PATCH /orders/:id/status` e depois consulta a `webhook_outbox` |
| **FDD-AC-02** | Sem assinante para o status (ou webhook inativo) → nenhuma linha | Mesmo teste, com `events` que não incluem o status |
| **FDD-AC-03** | Falha ao inserir na outbox → status do pedido, histórico e estoque inalterados | Teste com `publishWebhookEvent` forçado a lançar: o pedido continua no status anterior e `order_status_history` não ganha registro |
| **FDD-AC-04** | O worker entrega um evento pendente em ≤ 2s + tempo de resposta, com todos os headers do §6.8 | Teste com receptor HTTP local no teste; assert de headers e corpo |
| **FDD-AC-05** | `X-Signature` = `v1=` + HMAC-SHA256 hex do corpo; no grace, duas assinaturas, ambas válidas | Teste unitário de `webhook.signer.ts` com vetor conhecido e com rotação |
| **FDD-AC-06** | Falha agenda `nextAttemptAt` em +1m/+5m/+30m/+2h/+12h; a 6ª falha move para a DLQ com `WEBHOOK_RETRIES_EXHAUSTED` | Teste unitário do processor com relógio controlado (`vi.useFakeTimers`) |
| **FDD-AC-07** | Timeout de 10s gera falha `WEBHOOK_DELIVERY_TIMEOUT` e retry | Receptor local que não responde |
| **FDD-AC-08** | Payload acima de 64KB não é enviado e vai direto para a DLQ com `WEBHOOK_PAYLOAD_TOO_LARGE` | Teste unitário do processor |
| **FDD-AC-09** | Replay: `ADMIN` → 202 e outbox `PENDING` com o **mesmo** id; `OPERATOR` → 403; log `webhook_replayed` com `adminUserId` | Teste de integração |
| **FDD-AC-10** | URL `http://` → 400 com detalhe `WEBHOOK_INVALID_URL` | Teste de integração |
| **FDD-AC-11** | Secret presente só nas respostas de criação e rotação; ausente de GET, PATCH e dos logs | Teste de integração + assert sobre a saída do logger |
| **FDD-AC-12** | `GET /webhooks/:id/deliveries` retorna no máximo 100 itens, do mais recente para o mais antigo | Teste de integração |
| **FDD-AC-13** | Nenhuma regressão: `npm test` e `npm run lint` passam; `npm run build` compila `dist/worker.js` | CI/local |

## 13. Riscos e mitigação

| ID | Risco | Prob. | Impacto | Mitigação |
| --- | --- | --- | --- | --- |
| **FDD-RISK-01** | Um cliente lento (até 10s por chamada) atrasa outros clientes com worker único | Média | Alto (meta de 10s) | Paralelismo entre pedidos (FDD-RES-06); alerta em FDD-OBS-02/04; revisão de escala (RFC-OPEN-03) (`[09:42] Diego`) |
| **FDD-RISK-02** | Inversão de ordem de eventos do mesmo pedido quando um está em retry | Baixa | Médio | Payload traz `from_status`/`to_status`; ponto para confirmação RFC-CONF-02 (`[09:12] Diego`) |
| **FDD-RISK-03** | *(análise)* Secret em claro no banco, necessária para assinar ([ADR-004](./adrs/ADR-004-hmac-sha256-secret-por-endpoint.md)) | Média | Alto | Secret por endpoint e rotação (`[09:21] Sofia`); `redact` (FDD-OBS-13); fora de respostas de leitura. *(análise)* Criptografia em repouso não foi discutida e é sugerida como item da revisão de segurança já prevista (`[09:46] Sofia`) |
| **FDD-RISK-04** | Crescimento da outbox e de `webhook_deliveries` sem arquivamento nesta fase | Alta | Médio | Índices em `status, createdAt` e `webhookId, createdAt`; arquivamento em fase futura (`[09:08] Diego`) |
| **FDD-RISK-05** | Usuário autenticado configura webhook de outro customer (sem vínculo usuário–cliente) | Média | Médio | Aceito nesta fase; logs com `userId` (FDD-OBS-11); endurecimento posterior (`[09:37] Sofia`) |
| **FDD-RISK-06** | *(análise)* URL `https` arbitrária pode apontar para endereços internos da infraestrutura (SSRF) | Baixa | Alto | Não discutido na reunião: item levado à revisão de segurança da Sofia antes do deploy (`[09:46] Sofia`) |
| **FDD-RISK-07** | Entregas duplicadas (crash recovery, timeout com processamento do lado do cliente, replay) | Média | Baixo | Contrato at-least-once + `X-Event-Id` estável, documentado no portal (`[09:26] Marcos`) |
