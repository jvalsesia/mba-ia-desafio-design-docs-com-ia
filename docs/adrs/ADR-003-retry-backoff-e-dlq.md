# ADR-003: Retry com backoff exponencial (1m/5m/30m/2h/12h) e DLQ em tabela separada

## Status

**Aceito.** "Decidido: 5 tentativas, backoff 1m/5m/30m/2h/12h" (`[09:17] Larissa`). DLQ em tabela separada proposta em `[09:18] Diego` e confirmada no resumo (`[09:48] Larissa`). Replay manual anotado em `[09:19] Larissa`. Role ADMIN no replay decidida em `[09:36] Larissa`.

> **Ponto de atenção sobre a contagem de tentativas:** veja [Interpretação da contagem de tentativas](#interpretação-da-contagem-de-tentativas). O ponto está registrado como questão em aberto no [RFC](../RFC.md).

- **Decisores:** Larissa, Diego, Bruno, Marcos, Sofia
- **Relacionados:** [ADR-001](./ADR-001-outbox-no-mysql.md), [ADR-002](./ADR-002-worker-separado-em-polling.md), [ADR-005](./ADR-005-at-least-once-com-x-event-id.md), [ADR-006](./ADR-006-reuso-dos-padroes-do-projeto.md)

## Contexto

O endpoint do cliente pode estar fora do ar, lento ou respondendo com erro. A reunião levantou três pontos:
- Já houve cliente com indisponibilidade de duas horas por manutenção planejada (`[09:16] Diego`).
- O retry não pode deixar eventos "pendurados para sempre" quando o cliente some (`[09:15] Diego`).
- É preciso guardar evidência do que falhou, para debug e reprocessamento (`[09:18] Diego`).

A chamada HTTP tem timeout de 10 segundos, e passar disso conta como falha a retentar (`[09:42] Diego`). O detalhamento fica no [FDD](../FDD.md).

## Decisão

**ADR-003:** Falhas de entrega são retentadas com **backoff exponencial em uma agenda fixa**. Esgotada a agenda, o evento vira **falha permanente** e é movido para uma **DLQ em tabela separada**.

1. **Agenda de retentativas:** 1 min → 5 min → 30 min → 2 h → 12 h (`[09:17] Diego`, `[09:17] Larissa`). O intervalo total entre a primeira falha e a última tentativa é de "quase 15 horas" (`[09:17] Diego`), e o Marcos o aceitou como limite razoável (`[09:17] Marcos`).
2. **DLQ:** tabela `webhook_dead_letter`, separada da outbox, com o payload, o motivo da falha e o timestamp (`[09:18] Diego`).
3. **Replay manual:** `POST /admin/webhooks/dead-letter/:id/replay` recoloca o evento na outbox como pendente (`[09:18] Diego`, `[09:35] Diego`).
   - Exige role `ADMIN`, porque mexer na fila de entrega "não é coisa de operador" (`[09:36] Sofia`).
   - Reusa o `requireRole` existente em `src/middlewares/auth.middleware.ts` (`[09:36] Larissa`).
   - Registra em log quem executou o replay, para auditoria (`[09:36] Sofia`).

### Interpretação da contagem de tentativas

A reunião usa "5 tentativas" (`[09:15] Diego`, `[09:17] Larissa`, `[09:48] Larissa`), mas a agenda tem **5 intervalos**, e a soma deles (1m + 5m + 30m + 2h + 12h = **14h36min**) é o que corresponde às "quase 15 horas entre primeira falha e última tentativa" (`[09:17] Diego`). Se fossem 5 envios no total, haveria só 4 intervalos (2h36min), o que contradiz a janela discutida.

**Adotamos: 1 envio inicial + 5 retentativas (6 envios no máximo).** Essa leitura preserva a janela de cobertura, que foi o argumento que derrubou a alternativa de 3 tentativas. O ponto fica aberto para confirmação do time no [RFC](../RFC.md).

## Alternativas Consideradas

**ADR-003-ALT-01: Retry indefinido com backoff.** Descartado.
- O evento pode ficar pendurado para sempre se o cliente sumir (`[09:15] Diego`).

**ADR-003-ALT-02: Apenas 3 tentativas, mais agressivo.** Descartado.
- Proposto por `[09:16] Bruno`. Cobriria só cerca de 30 minutos e mataria o evento durante indisponibilidades comuns, como a manutenção planejada de 2h que um cliente já teve (`[09:16] Diego`).

**ADR-003-ALT-03: Marcar o evento como `failed` na própria outbox, em vez de usar uma tabela de DLQ.** Descartado.
- Levantado por `[09:17] Larissa`. A tabela separada mantém "mais limpa a leitura da outbox principal" e fica como evidência para debug e reprocessamento (`[09:18] Diego`).

## Consequências

### Positivas
- **ADR-003-CONS-01:** Cobre indisponibilidades de até ~14h36min sem intervenção, incluindo janelas de manutenção de 2h (`[09:16] Diego`, `[09:17] Marcos`).
- **ADR-003-CONS-02:** Toda falha permanente fica persistida com payload e motivo, o que permite diagnóstico e reprocessamento controlado (`[09:18] Diego`).
- **ADR-003-CONS-03:** O replay é restrito a ADMIN e auditado em log, sem criar mecanismo de autorização novo (`[09:36] Sofia`, `[09:36] Larissa`).

### Negativas
- **ADR-003-CONS-04:** Um evento pode chegar até ~15h atrasado, e o replay e as retentativas podem gerar entregas duplicadas. Por isso, o cliente precisa deduplicar pelo `X-Event-Id` ([ADR-005](./ADR-005-at-least-once-com-x-event-id.md)).
- **ADR-003-CONS-05:** O reprocessamento da DLQ é manual e depende de um ADMIN. Não há aviso automático ao cliente sobre o webhook com problema, porque a notificação por e-mail **foi adiada para uma próxima fase** (`[09:37] Larissa`).
- **ADR-003-CONS-06:** A contagem exata de tentativas depende de confirmação (ver acima).

### Trade-off
Troca-se o **frescor da entrega** (um evento pode chegar horas depois) pela **resiliência a indisponibilidades reais** do cliente, com um teto que impede eventos eternos.

## Referências
- `TRANSCRICAO.md`: `[09:14]`–`[09:19]`, `[09:35]`–`[09:37]`, `[09:42]`, `[09:48]`
- `src/middlewares/auth.middleware.ts` (`requireRole`)
