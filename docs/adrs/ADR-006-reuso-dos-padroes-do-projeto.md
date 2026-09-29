# ADR-006: Reuso máximo dos padrões existentes do projeto no módulo de webhooks

## Status

**Aceito.** "Decisão: reuso máximo do que já existe. AppError, Pino, error middleware, padrão de módulos, padrão de schemas Zod, padrão de códigos de erro. Webhook fica como módulo igual aos outros." (`[09:30] Larissa`). Confirmado no resumo (`[09:48] Larissa`).

- **Decisores:** Larissa, Bruno, Diego, Sofia
- **Relacionados:** todos os demais ADRs, que se apoiam nesta estrutura

## Contexto

O OMS já tem convenções consolidadas, mapeadas diretamente no código:

| Padrão | Onde está no código |
| --- | --- |
| Um módulo por domínio, com `controller`, `service`, `repository`, `routes` e `schemas` | `src/modules/orders/`, `src/modules/customers/`, `src/modules/products/`, `src/modules/users/` (`src/modules/auth/` não tem repository) |
| Montagem dos routers por módulo | `src/routes/index.ts` (`buildApiRouter`) |
| Erro base com `statusCode` e `errorCode`, e subclasses por status HTTP | `src/shared/errors/app-error.ts` (`AppError`), `src/shared/errors/http-errors.ts` (`NotFoundError`, `ConflictError`, `UnprocessableEntityError`, `InvalidStatusTransitionError`, `InsufficientStockError`…) |
| Códigos de erro em `UPPER_SNAKE_CASE` | ex.: `INVALID_STATUS_TRANSITION`, `INSUFFICIENT_STOCK` em `src/shared/errors/http-errors.ts` |
| Tratamento centralizado de `AppError`, `ZodError` e erros do Prisma | `src/middlewares/error.middleware.ts` |
| Autenticação JWT e autorização por role | `src/middlewares/auth.middleware.ts` (`authenticate`, `requireRole`) |
| Validação de entrada com Zod | `src/middlewares/validate.middleware.ts` + `*.schemas.ts` |
| Logger estruturado Pino com `redact` de campos sensíveis (`req.headers.authorization`, `req.headers.cookie`, `*.password`, `*.passwordHash`, `*.token`, `*.accessToken`) | `src/shared/logger/index.ts` |
| Transação de mudança de status | `src/modules/orders/order.service.ts` (`changeStatus`) |

A feature precisa de endpoints REST, erros de domínio, validação, logs, autorização e um ponto de integração na transação de pedidos. Todos esses pontos já têm um padrão no projeto (`[09:27] Bruno`, `[09:29] Bruno`).

## Decisão

**ADR-006:** O módulo de webhooks segue **exatamente** os padrões existentes, sem introduzir frameworks ou bibliotecas novas para essas responsabilidades.

1. **Estrutura de módulo:** `src/modules/webhooks/` (novo), com `webhook.controller.ts`, `webhook.service.ts`, `webhook.repository.ts`, `webhook.routes.ts` e `webhook.schemas.ts`, espelhando `src/modules/orders/` (`[09:27] Bruno`). O processamento do worker também fica no módulo ([ADR-002](./ADR-002-worker-separado-em-polling.md), `[09:28] Bruno`). Os routers são registrados em `src/routes/index.ts`.
2. **Erros:** as classes de erro do módulo estendem as subclasses de `AppError` já existentes, com códigos **prefixados por `WEBHOOK_`**, por exemplo `WEBHOOK_NOT_FOUND`, `WEBHOOK_INVALID_URL` e `WEBHOOK_SECRET_REQUIRED` (`[09:28] Bruno`, `[09:29] Larissa`). O `error.middleware.ts` os trata **sem nenhuma alteração** (`[09:29] Bruno`).
3. **Logs:** o mesmo logger Pino, tanto na API quanto no worker (`[09:29] Bruno`).
4. **Autorização:**
   - O endpoint de replay da DLQ usa o `requireRole('ADMIN')` existente (`[09:36] Larissa`).
   - O CRUD de configuração exige apenas autenticação, por enquanto (`[09:37] Sofia`).
   - O `customer_id` do webhook **não vem do JWT**: é informado pelo chamador no body ou no path (`[09:32] Larissa`). O JWT atual é do usuário operador, e não do cliente (`[09:32] Bruno`). A escolha entre body e path fica para o [FDD](../FDD.md).
5. **Validação:** schemas Zod no padrão `*.schemas.ts`, incluindo a exigência de URL `https` (`[09:23] Sofia`).
6. **Integração com pedidos:** `OrderService.changeStatus` chama uma **função pura** `publishWebhookEvent(tx, order, fromStatus, toStatus)` (novo), que recebe o client da transação corrente (`[09:41] Bruno`). Não se injeta um repository de webhooks inteiro no `OrderService` (`[09:41] Diego`).
7. **Dados:** modelos Prisma novos seguem o padrão de ID `String @id @default(uuid()) @db.Char(36)` de `prisma/schema.prisma` (`[09:51] Larissa`). O worker usa o mesmo `createPrismaClient()` de `src/config/database.ts`, em instância própria (`[09:30] Bruno`).

## Alternativas Consideradas

**ADR-006-ALT-01: Injetar um `WebhookRepository` completo no `OrderService`.** Descartado.
- A função `publishWebhookEvent(tx, …)`, que recebe o `tx`, basta para inserir na outbox dentro da transação e acopla menos: "função pura recebendo o tx. Não precisa injetar repository inteiro" (`[09:41] Diego`).

**ADR-006-ALT-02: Estrutura e convenções próprias para o módulo (outro logger, outro formato de erro).** Descartado implicitamente.
- "Não vamos botar nada novo" (`[09:29] Bruno`). Isso quebraria a uniformidade das respostas de erro, que hoje são todas `{ error: { code, message, details } }` via `error.middleware.ts`, e exigiria mudar o middleware.

## Consequências

### Positivas
- **ADR-006-CONS-01:** Zero alterações em `src/middlewares/error.middleware.ts`. Os erros `WEBHOOK_*` saem no mesmo formato JSON que o resto da API (`[09:29] Bruno`).
- **ADR-006-CONS-02:** Curva de aprendizado baixa. Quem conhece `src/modules/orders/` navega em `src/modules/webhooks/` (novo) sem surpresa (`[09:27] Bruno`).
- **ADR-006-CONS-03:** Mudança mínima em código crítico. `changeStatus` ganha uma chamada dentro da transação, e não uma nova dependência injetada (`[09:41] Bruno`).

### Negativas
- **ADR-006-CONS-04:** Os `redactPaths` atuais do logger (`src/shared/logger/index.ts`) cobrem os headers `authorization` e `cookie` e as chaves `*.password`, `*.passwordHash`, `*.token` e `*.accessToken`, todas com um nível de profundidade. Nenhuma cobre a secret do webhook. O reuso do Pino exige acrescentar caminhos como `*.secret` e `*.previousSecret` para não vazar secrets ([ADR-004](./ADR-004-hmac-sha256-secret-por-endpoint.md)). É uma proposta de design derivada do padrão do código.
- **ADR-006-CONS-05:** O `requireRole` só conhece as roles `ADMIN` e `OPERATOR` (`prisma/schema.prisma`, `UserRole`). Não existe um vínculo usuário–cliente, e o `customer_id` vem do chamador, não do JWT (`[09:32] Larissa`). Na prática, **qualquer usuário autenticado pode gerenciar os webhooks de qualquer customer**. O endurecimento do CRUD ficou para depois (`[09:37] Sofia`) e é registrado como risco aceito nesta fase.
- **ADR-006-CONS-06:** `changeStatus` passa a depender de uma função do módulo de webhooks. Uma falha nela faz rollback da mudança de status, o que é intencional ([ADR-001](./ADR-001-outbox-no-mysql.md)).

### Trade-off
Troca-se liberdade de desenho no módulo novo por **consistência com a base existente e menor superfície de mudança**, herdando também as limitações atuais: logger sem redact de secret e modelo de roles sem vínculo com o cliente.

## Referências
- `TRANSCRICAO.md`: `[09:23]`, `[09:27]`–`[09:30]`, `[09:36]`–`[09:37]`, `[09:41]`, `[09:48]`, `[09:51]`
- `src/modules/orders/order.service.ts`, `src/routes/index.ts`, `src/shared/errors/app-error.ts`, `src/shared/errors/http-errors.ts`, `src/middlewares/error.middleware.ts`, `src/middlewares/auth.middleware.ts`, `src/middlewares/validate.middleware.ts`, `src/shared/logger/index.ts`, `src/config/database.ts`, `prisma/schema.prisma`
