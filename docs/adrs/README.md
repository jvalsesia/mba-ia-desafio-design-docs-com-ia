# Architectural Decision Records

Este diretório guarda os ADRs (Architectural Decision Records) da feature **Sistema de Webhooks de Notificação de Pedidos**. Cada ADR registra uma decisão isolada, com contexto, alternativas e consequências. As decisões foram tomadas na reunião técnica registrada em [`TRANSCRICAO.md`](../../TRANSCRICAO.md).

## Convenções

- **Nome do arquivo:** `ADR-NNN-titulo-em-kebab-case.md`, numeração sequencial com 3 dígitos.
- **Formato:** variante do MADR com as seções `Status`, `Contexto`, `Decisão`, `Alternativas Consideradas`, `Consequências` (Positivas, Negativas e Trade-off) e `Referências`.
- **Rastreabilidade:** toda afirmação cita a origem, seja `[hh:mm] Nome` da transcrição ou o caminho de um arquivo do código. Os itens identificáveis (`ADR-NNN`, `ADR-NNN-ALT-NN`, `ADR-NNN-CONS-NN`) têm linha em [`../TRACKER.md`](../TRACKER.md).

## Índice

| ADR | Decisão | Status |
| --- | --- | --- |
| [ADR-001](./ADR-001-outbox-no-mysql.md) | Outbox transacional no MySQL | Aceito |
| [ADR-002](./ADR-002-worker-separado-em-polling.md) | Worker em processo separado com polling de 2s | Aceito |
| [ADR-003](./ADR-003-retry-backoff-e-dlq.md) | Retry com backoff 1m/5m/30m/2h/12h e DLQ em tabela separada | Aceito |
| [ADR-004](./ADR-004-hmac-sha256-secret-por-endpoint.md) | HMAC-SHA256 com secret por endpoint e rotação com grace de 24h | Aceito |
| [ADR-005](./ADR-005-at-least-once-com-x-event-id.md) | At-least-once com deduplicação por `X-Event-Id` | Aceito |
| [ADR-006](./ADR-006-reuso-dos-padroes-do-projeto.md) | Reuso dos padrões existentes do projeto | Aceito |
| [ADR-007](./ADR-007-snapshot-do-payload-na-insercao.md) | Snapshot do payload na inserção da outbox | Aceito |
