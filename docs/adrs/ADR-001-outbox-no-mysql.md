# ADR-001: Outbox transacional no MySQL para eventos de mudança de status

## Status

**Aceito.** Decidido na reunião técnica da feature (`[09:08] Larissa`: "Tá decidido então: outbox em MySQL") e confirmado no resumo final (`[09:48] Larissa`).

- **Decisores:** Larissa (Tech Lead), Diego (Plataforma), Bruno (Pedidos), Sofia (Segurança), Marcos (Produto)
- **Relacionados:** [ADR-002](./ADR-002-worker-separado-em-polling.md), [ADR-003](./ADR-003-retry-backoff-e-dlq.md), [ADR-006](./ADR-006-reuso-dos-padroes-do-projeto.md), [ADR-007](./ADR-007-snapshot-do-payload-na-insercao.md)

## Contexto

Três clientes B2B querem ser notificados quando o status dos seus pedidos muda, sem precisar consultar `GET /orders` periodicamente (`[09:00] Marcos`). Para eles, "tempo real" é qualquer coisa abaixo de 10 segundos (`[09:02] Marcos`). A notificação é só de saída, da plataforma para o cliente (`[09:02] Marcos`).

A mudança de status acontece em `OrderService.changeStatus` (`src/modules/orders/order.service.ts`), dentro de um `this.prisma.$transaction(async (tx) => …)` que:
- valida a transição na máquina de estados (`src/modules/orders/order.status.ts`);
- debita ou repõe estoque, nas transições em que isso se aplica;
- atualiza `orders`;
- insere em `order_status_history`.

O Bruno descreveu essa transação como "já pesada" (`[09:04] Bruno`). A aplicação não tem hoje nenhum broker, fila ou mecanismo de eventos: `package.json` não traz dependência desse tipo, e o banco é o MySQL acessado via Prisma (`prisma/schema.prisma`).

Dois problemas surgem se a notificação for feita no mesmo fluxo da mudança de status:
1. Um cliente lento travaria a mudança de status de outros pedidos (`[09:04] Bruno`).
2. Com o cliente fora do ar, não faz sentido dar rollback na mudança de status (`[09:04] Bruno`).

## Decisão

**ADR-001:** Adotar o **padrão Outbox** em uma tabela `webhook_outbox` no **mesmo MySQL** da aplicação (`[09:06] Diego`, `[09:08] Larissa`).

- O evento é inserido na outbox **na mesma transação SQL** que atualiza `orders` e `order_status_history` (`[09:06] Diego`). Se a inserção na outbox falhar, a transação inteira faz rollback: "não pode ter caso de status mudar e evento não sair" (`[09:40] Bruno`, `[09:41] Diego`).
- A leitura e o envio HTTP ficam a cargo de um worker separado ([ADR-002](./ADR-002-worker-separado-em-polling.md)).
- A outbox tem um campo de status (pendente, processando, falhou, entregue) e índices em status e `created_at` (`[09:08] Diego`).
- A chave primária é UUID, seguindo o padrão do projeto (`[09:51] Larissa`), que em `prisma/schema.prisma` é `String @id @default(uuid()) @db.Char(36)`.
- Só se insere evento quando ao menos um webhook do customer assina aquele status. O filtro acontece na inserção, não no envio (`[09:34] Bruno`).

## Alternativas Consideradas

**ADR-001-ALT-01: Disparo HTTP síncrono dentro de `changeStatus`.** Descartado.
- Acopla a latência e a disponibilidade de cada cliente à transação de status: um cliente lento trava outros pedidos, e uma falha do cliente não pode desfazer a mudança de status (`[09:04] Bruno`).
- "Síncrono está fora de questão" (`[09:06] Diego`).

**ADR-001-ALT-02: Fila externa, como Redis Streams "ou alguma coisa parecida".** Descartado.
- Exigiria subir e operar infraestrutura nova (`[09:07] Larissa`).
- Para um time pequeno, subir um Redis Cluster para esse caso é overengineering (`[09:07] Diego`).
- Além disso, sem outbox, a publicação na fila ficaria fora da transação do MySQL e perderia a atomicidade.

## Consequências

### Positivas
- **ADR-001-CONS-01:** Consistência forte entre estado e evento. Se a transação commitou, o evento existe; se deu rollback, o evento some junto. "Não tem inconsistência possível" (`[09:06] Diego`).
- **ADR-001-CONS-02:** Zero infraestrutura nova. Reusa o MySQL e o Prisma que já existem (`[09:07] Diego`).

### Negativas
- **ADR-001-CONS-03:** A tabela cresce continuamente. O desempenho depende dos índices em status e `created_at` e da leitura em lotes pequenos (`[09:08] Diego`, pergunta de `[09:07] Bruno`). O arquivamento de linhas entregues (após ~30 dias) **fica fora do escopo desta feature** (`[09:08] Diego`).
- **ADR-001-CONS-04:** A transação de `changeStatus` ganha mais uma escrita, e uma falha na outbox passa a bloquear a mudança de status. É um efeito intencional, para preservar a garantia (`[09:40] Bruno`).
- **ADR-001-CONS-05:** A entrega deixa de ser imediata e passa a depender do intervalo de leitura do worker (ver [ADR-002](./ADR-002-worker-separado-em-polling.md)).

### Trade-off
Troca-se latência mínima e simplicidade de envio por **atomicidade e ausência de infraestrutura nova**. O time aceita uma tabela a mais no banco transacional e um processo leitor, em vez de um broker dedicado.

## Referências
- `TRANSCRICAO.md`: `[09:03]`–`[09:08]`, `[09:34]`, `[09:40]`–`[09:41]`, `[09:48]`, `[09:51]`
- `src/modules/orders/order.service.ts` (`changeStatus`), `src/modules/orders/order.status.ts`, `prisma/schema.prisma`, `package.json`
