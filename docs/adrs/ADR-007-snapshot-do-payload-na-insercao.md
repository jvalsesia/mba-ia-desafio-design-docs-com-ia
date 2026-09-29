# ADR-007: Payload do evento renderizado como snapshot no momento da inserção na outbox

## Status

**Aceito.** "Beleza, snapshot. Decidido." (`[09:52] Bruno`), com a proposta de `[09:52] Larissa` e a concordância de `[09:52] Diego`.

- **Decisores:** Larissa, Diego, Bruno (conversa pós-reunião)
- **Relacionados:** [ADR-001](./ADR-001-outbox-no-mysql.md), [ADR-005](./ADR-005-at-least-once-com-x-event-id.md)

## Contexto

Cada linha da outbox representa uma mudança de status de um pedido. Faltava decidir se a linha guarda o **payload já pronto** ou apenas uma referência (`order_id`), para renderizar o payload na hora do envio (`[09:51] Bruno`).

Entre a inserção e o envio podem passar de ~2 segundos, no caso normal ([ADR-002](./ADR-002-worker-separado-em-polling.md)), a ~15 horas, no pior caso de retry ([ADR-003](./ADR-003-retry-backoff-e-dlq.md)). Nesse intervalo, o pedido pode mudar novamente.

O payload é enxuto: identificadores, `from_status`, `to_status`, `customer_id` e campos básicos como `total_cents`, **sem os items** (`[09:43] Diego`). O formato completo está no [FDD](../FDD.md).

## Decisão

**ADR-007:** O payload JSON é **renderizado e gravado na outbox no momento da inserção**, dentro da transação de `changeStatus`. O worker envia exatamente esse conteúdo, sem consultar o pedido novamente (`[09:52] Larissa`, `[09:52] Diego`).

- O snapshot inclui o `event_id` gerado na inserção ([ADR-005](./ADR-005-at-least-once-com-x-event-id.md)), de modo que todas as tentativas e o replay enviam **o mesmo corpo**.
- O replay da DLQ reenfileira o payload gravado, e não uma nova renderização. A DLQ já guarda o payload (`[09:18] Diego`).

## Alternativas Consideradas

**ADR-007-ALT-01: Guardar só o `order_id` e renderizar o payload na hora do envio.** Descartado.
- Se o pedido mudar depois, o evento deixaria de refletir o estado do momento da mudança de status. "Senão tem caso esquisito" (`[09:52] Larissa`).
- Exemplo: um evento `PAID → PROCESSING` retentado horas depois sairia com dados de quando o pedido já estava `SHIPPED`.

## Consequências

### Positivas
- **ADR-007-CONS-01:** Cada evento é um fato imutável: reflete o estado no instante da transição (`[09:52] Larissa`).
- **ADR-007-CONS-02:** Corpo idêntico entre tentativas. A assinatura HMAC ([ADR-004](./ADR-004-hmac-sha256-secret-por-endpoint.md)) e a deduplicação por `X-Event-Id` ficam coerentes, e o worker não faz consultas extras ao pedido.

### Negativas
- **ADR-007-CONS-03:** Mais dados por linha da outbox, o que aumenta o crescimento da tabela, cujo arquivamento está fora de escopo (`[09:08] Diego`). O efeito é limitado porque o payload é enxuto e não traz items (`[09:43] Diego`).
- **ADR-007-CONS-04:** O tamanho do payload é conhecido já na inserção. O limite de 64KB (`[09:24] Larissa`) pode ser verificado ali, mas um erro nesse ponto ocorreria dentro da transação de `changeStatus`. O FDD define onde a validação ocorre.

### Trade-off
Troca-se armazenamento (payload completo por linha) por **fidelidade histórica e envio determinístico**.

## Referências
- `TRANSCRICAO.md`: `[09:08]`, `[09:18]`, `[09:24]`, `[09:43]`, `[09:51]`–`[09:52]`
- `src/modules/orders/order.service.ts` (`changeStatus`, onde o snapshot é montado)
