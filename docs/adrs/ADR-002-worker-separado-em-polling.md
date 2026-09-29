# ADR-002: Worker em processo separado, lendo a outbox por polling de 2 segundos

## Status

**Aceito.** "Vamos registrar isso como uma decisão. Worker em polling, 2s." (`[09:10] Larissa`). Processo separado anotado em `[09:11] Larissa` e confirmado no resumo (`[09:48] Larissa`).

- **Decisores:** Larissa, Diego, Bruno, Marcos
- **Relacionados:** [ADR-001](./ADR-001-outbox-no-mysql.md), [ADR-003](./ADR-003-retry-backoff-e-dlq.md), [ADR-006](./ADR-006-reuso-dos-padroes-do-projeto.md)

## Contexto

Com a outbox definida ([ADR-001](./ADR-001-outbox-no-mysql.md)), falta decidir **como** os eventos pendentes são lidos e **onde** roda o código que faz as chamadas HTTP. As restrições são:

- O requisito de latência é "abaixo de 10 segundos" (`[09:02] Marcos`).
- O MySQL não tem um mecanismo nativo de notificação a processos externos, como o `LISTEN/NOTIFY` do Postgres. Triggers só executam SQL (`[09:09] Diego`).
- A API roda a partir de `src/server.ts`. Se o envio rodasse dentro dela, um restart da API derrubaria o processamento (`[09:11] Diego`).
- Uma instância de `PrismaClient` pertence a um processo (`[09:30] Bruno`). O projeto cria a sua em `src/config/database.ts` (`createPrismaClient()`).

## Decisão

**ADR-002:** O processamento da outbox roda em um **worker em processo Node separado**, que faz **polling a cada 2 segundos** (`[09:09] Diego`, `[09:10] Larissa`, `[09:11] Diego`).

- **Entry point:** `src/worker.ts` (novo), no mesmo molde de `src/server.ts`, executado por um script `npm run worker` (novo) em `package.json` (`[09:11] Larissa`).
- **Lógica de processamento:** dentro do módulo, em `src/modules/webhooks/webhook.processor.ts` (novo). Na reunião, as opções de nome foram `webhook.worker.ts` ou `webhook.processor.ts` (`[09:28] Bruno`). Adotamos `processor` para não confundir com o entry point.
- **Conexão:** mesmo banco e mesma `DATABASE_URL`, mas um `PrismaClient` próprio do processo do worker, criado com o `createPrismaClient()` existente (`[09:11] Bruno`, `[09:11] Diego`, `[09:30] Bruno`).
- **Ciclo:** a cada 2s, busca os eventos pendentes mais antigos em lote pequeno, processa e atualiza o status (`[09:08] Diego`, `[09:09] Diego`).
- **Instância única:** roda **um único worker**, que processa em ordem de `created_at` da outbox. Com isso, no caminho feliz, o cliente recebe os eventos de um mesmo pedido na ordem em que aconteceram. Fica registrada como **limitação conhecida** a ausência de garantia de ordenação global: vale só por `order_id` e só enquanto houver um único worker (`[09:12] Diego`, `[09:13] Larissa`). Essa ordenação também não se sustenta quando um evento entra em retry (ver ADR-002-CONS-07).

## Alternativas Consideradas

**ADR-002-ALT-01: Reação por trigger do banco, em vez de polling.** Descartado.
- O MySQL não notifica processos externos, e avisar o worker exigiria improvisos como escrever em arquivo ou chamar um endpoint, que "fica esquisito" (`[09:09] Bruno`, `[09:09] Diego`).
- O polling de 2s já atende o requisito de < 10s.

**ADR-002-ALT-02: Worker rodando dentro do processo da API.** Descartado.
- Acopla o ciclo de vida do envio ao da API: se a API reinicia, perde o worker (`[09:11] Diego`).

**ADR-002-ALT-03: Múltiplos workers em paralelo.** Adiado.
- Perderia a garantia de ordenação por pedido. Escalar exigiria particionar por `order_id` ou usar lock pessimista. "Isso é problema do futuro, não agora" (`[09:13] Diego`).

## Consequências

### Positivas
- **ADR-002-CONS-01:** Atende o requisito de latência. A espera por polling é de até ~2s, contra a meta de 10s (`[09:09] Diego`). O "2 segundos no pior caso" foi aceito explicitamente (`[09:10] Larissa`, `[09:10] Marcos`). A meta só vale para entregas sem falha, porque o tempo de resposta do cliente se soma à espera (ver ADR-002-CONS-08).
- **ADR-002-CONS-02:** Isolamento de falhas. Restart da API não interrompe entregas (`[09:11] Diego`).
- **ADR-002-CONS-03:** Mesma stack e mesmo código de acesso a dados. Nenhuma tecnologia nova (`[09:11] Diego`).

### Negativas
- **ADR-002-CONS-04:** Consultas periódicas ao banco mesmo sem eventos. O custo é mitigado pelos índices em status e `created_at` da outbox (`[09:08] Diego`).
- **ADR-002-CONS-05:** Sem escala horizontal nesta fase. A vazão fica limitada a um worker, e a ordenação é garantida apenas por `order_id`, não globalmente (`[09:13] Larissa`). É aceitável porque os clientes nunca pediram ordenação global (`[09:14] Marcos`).
- **ADR-002-CONS-06:** Mais um processo para implantar e monitorar, com o entry point `src/worker.ts` (novo) (`[09:11] Larissa`).
- **ADR-002-CONS-07:** *(análise)* A ordem por pedido pode ser violada por retry. Se um evento de um pedido falha e entra no backoff de 1 minuto ([ADR-003](./ADR-003-retry-backoff-e-dlq.md), `[09:17] Diego`), o evento seguinte do mesmo pedido pode ser entregue antes dele. A garantia descrita em `[09:12] Diego` pressupõe que não haja falha. A reunião não decidiu se eventos posteriores do mesmo `order_id` devem esperar, e o ponto vai para as questões em aberto do [RFC](../RFC.md). Clientes que dependem da ordem podem usar `from_status`/`to_status` do payload para detectar a inversão.
- **ADR-002-CONS-08:** *(análise)* Com um único worker e timeout de 10s por chamada (`[09:42] Diego`), um cliente lento pode atrasar as entregas de outros clientes do mesmo lote além da meta de 10s (`[09:02] Marcos`). O [FDD](../FDD.md) define a mitigação dentro do processo único.

### Trade-off
Troca-se reatividade imediata e escala horizontal por **simplicidade operacional e ordenação por pedido**, dentro de uma latência que o produto já aceitou.

## Referências
- `TRANSCRICAO.md`: `[09:08]`–`[09:14]`, `[09:28]`, `[09:30]`, `[09:48]`
- `src/server.ts`, `src/config/database.ts`, `package.json`
