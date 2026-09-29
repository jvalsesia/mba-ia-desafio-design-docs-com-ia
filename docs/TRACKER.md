# Tracker de Rastreabilidade

Cada linha liga um item registrado nos documentos à sua origem. O ID é o mesmo que aparece em negrito no documento.

- **Fonte `TRANSCRICAO`:** a Localização é `[hh:mm] Nome` da fala em [`TRANSCRICAO.md`](../TRANSCRICAO.md).
- **Fonte `CODIGO`:** a Localização é o caminho do arquivo no repositório.
- Itens com mais de uma origem usam a principal na Localização e citam as demais no resumo.

| ID | Documento | Tipo | Conteúdo (resumo) | Fonte | Localização |
| --- | --- | --- | --- | --- | --- |
| ADR-001 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Decisão | Outbox em tabela webhook_outbox no MySQL, inserida na mesma transação da mudança de status | TRANSCRICAO | [09:08] Larissa |
| ADR-001-ALT-01 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Alternativa descartada | Disparo HTTP síncrono no changeStatus: cliente lento trava outros pedidos e falha não pode dar rollback | TRANSCRICAO | [09:04] Bruno |
| ADR-001-ALT-02 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Alternativa descartada | Redis Streams ou similar: infra nova, overengineering para time pequeno | TRANSCRICAO | [09:07] Diego |
| ADR-001-CONS-01 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Consequência positiva | Evento existe se e somente se a transação commitou, sem inconsistência | TRANSCRICAO | [09:06] Diego |
| ADR-001-CONS-02 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Consequência positiva | Nenhuma infraestrutura nova, reuso do MySQL existente | TRANSCRICAO | [09:07] Diego |
| ADR-001-CONS-03 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Consequência negativa | Tabela cresce; índices em status e created_at; arquivamento fora de escopo | TRANSCRICAO | [09:08] Diego |
| ADR-001-CONS-04 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Consequência negativa | Falha ao inserir na outbox faz rollback da mudança de status (intencional) | TRANSCRICAO | [09:40] Bruno |
| ADR-001-CONS-05 | `docs/adrs/ADR-001-outbox-no-mysql.md` | Consequência negativa | Entrega depende do intervalo de leitura do worker | TRANSCRICAO | [09:10] Larissa |
| ADR-002 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Decisão | Worker em processo separado (src/worker.ts novo, npm run worker) com polling de 2s | TRANSCRICAO | [09:10] Larissa |
| ADR-002-ALT-01 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Alternativa descartada | Trigger do banco: MySQL não notifica processo externo como LISTEN/NOTIFY | TRANSCRICAO | [09:09] Diego |
| ADR-002-ALT-02 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Alternativa descartada | Worker dentro do processo da API: restart da API perde o worker | TRANSCRICAO | [09:11] Diego |
| ADR-002-ALT-03 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Alternativa adiada | Múltiplos workers em paralelo: perde ordenação; particionar por order_id no futuro | TRANSCRICAO | [09:13] Diego |
| ADR-002-CONS-01 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Consequência positiva | Espera de polling de até ~2s (pior caso aceito) atende a meta de menos de 10s | TRANSCRICAO | [09:10] Larissa |
| ADR-002-CONS-02 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Consequência positiva | Restart da API não interrompe entregas | TRANSCRICAO | [09:11] Diego |
| ADR-002-CONS-03 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Consequência positiva | Mesma stack e mesmo banco, nenhuma tecnologia nova | TRANSCRICAO | [09:11] Diego |
| ADR-002-CONS-04 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Consequência negativa | Consultas periódicas ao banco mesmo sem eventos, mitigadas por índice | TRANSCRICAO | [09:08] Diego |
| ADR-002-CONS-05 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Limitação conhecida | Ordenação só por order_id e com worker único; sem ordenação global | TRANSCRICAO | [09:13] Larissa |
| ADR-002-CONS-06 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Consequência negativa | Mais um processo para implantar e monitorar | TRANSCRICAO | [09:11] Larissa |
| ADR-002-CONS-07 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Limitação (análise) | Retry com backoff pode inverter a ordem de eventos do mesmo pedido; derivada de [09:17] Diego | TRANSCRICAO | [09:12] Diego |
| ADR-002-CONS-08 | `docs/adrs/ADR-002-worker-separado-em-polling.md` | Risco (análise) | Worker único com timeout de 10s: cliente lento atrasa outros além da meta de 10s | TRANSCRICAO | [09:42] Diego |
| ADR-003 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Decisão | Backoff 1m/5m/30m/2h/12h e DLQ em tabela webhook_dead_letter com replay ADMIN | TRANSCRICAO | [09:17] Larissa |
| ADR-003-ALT-01 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Alternativa descartada | Retry indefinido: evento pendurado para sempre se o cliente sumir | TRANSCRICAO | [09:15] Diego |
| ADR-003-ALT-02 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Alternativa descartada | 3 tentativas: janela de ~30min não cobre manutenção de 2h | TRANSCRICAO | [09:16] Diego |
| ADR-003-ALT-03 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Alternativa descartada | Marcar failed na própria outbox em vez de tabela de DLQ | TRANSCRICAO | [09:18] Diego |
| ADR-003-CONS-01 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Consequência positiva | Cobre indisponibilidade de até ~14h36min; janela aceita pelo produto | TRANSCRICAO | [09:17] Marcos |
| ADR-003-CONS-02 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Consequência positiva | Falha permanente persistida com payload e motivo para debug e reprocessamento | TRANSCRICAO | [09:18] Diego |
| ADR-003-CONS-03 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Consequência positiva | Replay restrito a ADMIN e auditado em log | TRANSCRICAO | [09:36] Sofia |
| ADR-003-CONS-04 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Consequência negativa | Evento pode chegar ~15h atrasado e duplicado; exige dedup por X-Event-Id | TRANSCRICAO | [09:17] Diego |
| ADR-003-CONS-05 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Consequência negativa | Reprocessamento manual; aviso por e-mail ao cliente adiado para próxima fase | TRANSCRICAO | [09:37] Larissa |
| ADR-003-CONS-06 | `docs/adrs/ADR-003-retry-backoff-e-dlq.md` | Ambiguidade | 5 tentativas no resumo versus 5 intervalos e quase 15h; adotado 1 envio + 5 retentativas | TRANSCRICAO | [09:48] Larissa |
| ADR-004 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Decisão | HMAC-SHA256 sobre o corpo no X-Signature, secret por endpoint, rotação com grace de 24h | TRANSCRICAO | [09:22] Sofia |
| ADR-004-ALT-01 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Alternativa descartada | Secret global da plataforma: se vaza uma, vaza tudo | TRANSCRICAO | [09:21] Sofia |
| ADR-004-ALT-02 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Alternativa implícita | Rotação com corte imediato, excluída pelo requisito de grace de 24h | TRANSCRICAO | [09:21] Sofia |
| ADR-004-CONS-01 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Consequência positiva | Cliente valida origem e integridade com biblioteca padrão | TRANSCRICAO | [09:20] Sofia |
| ADR-004-CONS-02 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Consequência positiva | Vazamento limitado a um endpoint e reversível por rotação (caso real de vazamento) | TRANSCRICAO | [09:22] Diego |
| ADR-004-CONS-03 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Consequência negativa | Secret precisa ficar recuperável para assinar, ao contrário do passwordHash existente | CODIGO | prisma/schema.prisma |
| ADR-004-CONS-04 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Consequência negativa | Rotação adiciona estado e dupla assinatura durante 24h (proposta derivada da rotação) | TRANSCRICAO | [09:21] Sofia |
| ADR-004-CONS-05 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Restrição | Revisão de segurança de pelo menos 2 dias úteis antes do deploy | TRANSCRICAO | [09:46] Sofia |
| ADR-004-CONS-06 | `docs/adrs/ADR-004-hmac-sha256-secret-por-endpoint.md` | Risco (análise) | X-Timestamp fora da assinatura (HMAC só do corpo) limita a detecção de replay | TRANSCRICAO | [09:44] Diego |
| ADR-005 | `docs/adrs/ADR-005-at-least-once-com-x-event-id.md` | Decisão | At-least-once com UUID gerado na outbox enviado em X-Event-Id para dedup | TRANSCRICAO | [09:26] Larissa |
| ADR-005-ALT-01 | `docs/adrs/ADR-005-at-least-once-com-x-event-id.md` | Alternativa descartada | Exactly-once: exige coordenação dos dois lados, muito mais complexo | TRANSCRICAO | [09:25] Diego |
| ADR-005-CONS-01 | `docs/adrs/ADR-005-at-least-once-com-x-event-id.md` | Consequência positiva (análise) | Outbox + retry + at-least-once: evento commitado não se perde na janela de retry; derivada de [09:06] Diego | TRANSCRICAO | [09:24] Diego |
| ADR-005-CONS-02 | `docs/adrs/ADR-005-at-least-once-com-x-event-id.md` | Consequência positiva | Padrão de mercado (Stripe, GitHub), dedup simples por ID | TRANSCRICAO | [09:25] Diego |
| ADR-005-CONS-03 | `docs/adrs/ADR-005-at-least-once-com-x-event-id.md` | Consequência negativa | Responsabilidade de dedup transferida ao cliente; documentar no portal | TRANSCRICAO | [09:25] Sofia |
| ADR-005-CONS-04 | `docs/adrs/ADR-005-at-least-once-com-x-event-id.md` | Restrição | event_id estável entre tentativas e replay da DLQ | TRANSCRICAO | [09:25] Diego |
| ADR-006 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Decisão | Reuso máximo: AppError, Pino, error middleware, módulos, Zod, códigos WEBHOOK_ | TRANSCRICAO | [09:30] Larissa |
| ADR-006-ALT-01 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Alternativa descartada | Injetar repository inteiro no OrderService em vez de publishWebhookEvent(tx) | TRANSCRICAO | [09:41] Diego |
| ADR-006-ALT-02 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Alternativa descartada | Convenções próprias no módulo (logger ou formato de erro novos) | TRANSCRICAO | [09:29] Bruno |
| ADR-006-CONS-01 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Consequência positiva | Error middleware trata erros WEBHOOK_ sem alteração | CODIGO | src/middlewares/error.middleware.ts |
| ADR-006-CONS-02 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Consequência positiva | Módulo webhooks espelha a estrutura dos módulos existentes | TRANSCRICAO | [09:27] Bruno |
| ADR-006-CONS-03 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Consequência positiva | changeStatus ganha uma chamada, não uma dependência injetada | TRANSCRICAO | [09:41] Bruno |
| ADR-006-CONS-04 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Consequência negativa | redact do Pino não cobre a secret; precisa ser estendido | CODIGO | src/shared/logger/index.ts |
| ADR-006-CONS-05 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Consequência negativa | Roles só ADMIN e OPERATOR, sem vínculo usuário-cliente: qualquer autenticado gerencia webhooks de qualquer customer | CODIGO | prisma/schema.prisma |
| ADR-006-CONS-06 | `docs/adrs/ADR-006-reuso-dos-padroes-do-projeto.md` | Consequência negativa | changeStatus passa a depender do módulo de webhooks dentro da transação | CODIGO | src/modules/orders/order.service.ts |
| ADR-007 | `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md` | Decisão | Payload renderizado e gravado na outbox na inserção (snapshot) | TRANSCRICAO | [09:52] Larissa |
| ADR-007-ALT-01 | `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md` | Alternativa descartada | Guardar só order_id e renderizar no envio: evento não refletiria o estado da transição | TRANSCRICAO | [09:51] Bruno |
| ADR-007-CONS-01 | `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md` | Consequência positiva | Evento imutável fiel ao instante da transição | TRANSCRICAO | [09:52] Larissa |
| ADR-007-CONS-02 | `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md` | Consequência positiva (análise) | Corpo idêntico entre tentativas, coerente com HMAC e dedup por event_id | TRANSCRICAO | [09:25] Diego |
| ADR-007-CONS-03 | `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md` | Consequência negativa | Mais dados por linha, limitado por payload enxuto sem items | TRANSCRICAO | [09:43] Diego |
| ADR-007-CONS-04 | `docs/adrs/ADR-007-snapshot-do-payload-na-insercao.md` | Consequência negativa | Limite de 64KB conhecido na inserção; FDD define onde validar | TRANSCRICAO | [09:24] Larissa |
