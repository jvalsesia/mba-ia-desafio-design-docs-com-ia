# ADR-005: Garantia de entrega at-least-once com deduplicação por `X-Event-Id`

## Status

**Aceito.** "At-least-once com X-Event-Id pra dedup do lado do cliente. Decisão." (`[09:26] Larissa`). Confirmado no resumo (`[09:48] Larissa`).

- **Decisores:** Larissa, Diego, Sofia, Bruno, Marcos
- **Relacionados:** [ADR-001](./ADR-001-outbox-no-mysql.md), [ADR-003](./ADR-003-retry-backoff-e-dlq.md), [ADR-007](./ADR-007-snapshot-do-payload-na-insercao.md)

## Contexto

Com outbox ([ADR-001](./ADR-001-outbox-no-mysql.md)), retentativas e replay de DLQ ([ADR-003](./ADR-003-retry-backoff-e-dlq.md)), o mesmo evento pode ser enviado mais de uma vez. Isso acontece, por exemplo, quando o cliente processa a requisição mas a resposta não chega à plataforma dentro do timeout, ou quando um ADMIN reprocessa um evento da DLQ.

Não há como a plataforma saber, sozinha, se o cliente já processou um evento. A questão é que garantia de entrega prometer e como o cliente distingue duplicatas (`[09:25] Bruno`).

## Decisão

**ADR-005:** A plataforma garante entrega **at-least-once**: o cliente pode receber o mesmo evento mais de uma vez e precisa estar preparado para isso (`[09:24] Diego`).

1. Todo evento recebe um **UUID gerado quando entra na outbox**, único por evento (`[09:25] Diego`). Esse UUID acompanha o evento em todas as tentativas e no replay.
2. O UUID é enviado no header **`X-Event-Id`**. O cliente deduplica por esse valor (`[09:25] Diego`).
3. A garantia e a necessidade de dedup serão **documentadas em destaque no portal de desenvolvedor** (`[09:26] Marcos`).

## Alternativas Consideradas

**ADR-005-ALT-01: Garantia exactly-once.** Descartado.
- Exigiria coordenação dos dois lados e "fica muito mais complexo". At-least-once com `event_id` "resolve 99% dos casos" e é o padrão de mercado (Stripe, GitHub) (`[09:25] Diego`).

## Consequências

### Positivas
- **ADR-005-CONS-01:** *(análise)* Combinada com a outbox (`[09:06] Diego`) e o retry ([ADR-003](./ADR-003-retry-backoff-e-dlq.md)), a garantia at-least-once (`[09:24] Diego`) faz com que nenhum evento commitado se perca por falha transitória dentro da janela de retentativas. Esgotada a janela, o evento fica preservado na DLQ.
- **ADR-005-CONS-02:** Segue um padrão que clientes de integração já conhecem, e a deduplicação por ID único é simples de implementar (`[09:25] Diego`).

### Negativas
- **ADR-005-CONS-03:** Transfere ao cliente a responsabilidade de deduplicar. Foi uma preocupação levantada pela Segurança: "Isso joga responsabilidade pro cliente" (`[09:25] Sofia`). A mitigação é documentar isso no portal (`[09:26] Marcos`).
- **ADR-005-CONS-04:** O `X-Event-Id` precisa ser estável entre as tentativas e o replay. O replay da DLQ **reaproveita** o `event_id` original em vez de gerar um novo, senão a deduplicação quebra (implicação direta de `[09:25] Diego` e `[09:18] Diego`).

### Trade-off
Troca-se a conveniência para o cliente (receber cada evento exatamente uma vez) por **simplicidade e robustez do lado da plataforma**, com um contrato explícito de deduplicação.

## Referências
- `TRANSCRICAO.md`: `[09:16]`, `[09:18]`, `[09:24]`–`[09:26]`, `[09:48]`
