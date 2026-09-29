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
| RFC-PROP-01 | `docs/RFC.md` | Proposta técnica | publishWebhookEvent(tx) grava snapshot na outbox dentro de changeStatus, com filtro por status | TRANSCRICAO | [09:41] Bruno |
| RFC-PROP-02 | `docs/RFC.md` | Proposta técnica | Worker em processo separado com polling de 2s e instância única; npm run worker em [09:11] Larissa; polling em [09:09] Diego | TRANSCRICAO | [09:11] Diego |
| RFC-PROP-03 | `docs/RFC.md` | Proposta técnica | Retry 1m/5m/30m/2h/12h; timeout em [09:42] Diego; DLQ em [09:18] Diego; ADMIN e auditoria em [09:36] Sofia | TRANSCRICAO | [09:17] Larissa |
| RFC-PROP-04 | `docs/RFC.md` | Proposta técnica | HMAC-SHA256 com secret por endpoint; at-least-once em [09:26] Larissa; https em [09:23] Sofia; 64KB em [09:24] Larissa | TRANSCRICAO | [09:22] Sofia |
| RFC-PROP-05 | `docs/RFC.md` | Proposta técnica | API de CRUD, rotação, deliveries e replay no módulo webhooks seguindo os padrões do projeto | TRANSCRICAO | [09:30] Larissa |
| RFC-ALT-01 | `docs/RFC.md` | Alternativa descartada | Disparo síncrono dentro de changeStatus | TRANSCRICAO | [09:06] Diego |
| RFC-ALT-02 | `docs/RFC.md` | Alternativa descartada | Redis Streams ou fila externa: infra nova, overengineering | TRANSCRICAO | [09:07] Diego |
| RFC-ALT-03 | `docs/RFC.md` | Alternativa descartada | Trigger do banco em vez de polling | TRANSCRICAO | [09:09] Diego |
| RFC-ALT-04 | `docs/RFC.md` | Alternativa descartada | Exactly-once: coordenação dos dois lados, complexidade | TRANSCRICAO | [09:25] Diego |
| RFC-ALT-05 | `docs/RFC.md` | Alternativa descartada | Retry indefinido ou apenas 3 tentativas | TRANSCRICAO | [09:16] Diego |
| RFC-OPEN-01 | `docs/RFC.md` | Questão em aberto | Rate limiting de saída: observar e decidir depois | TRANSCRICAO | [09:39] Larissa |
| RFC-OPEN-02 | `docs/RFC.md` | Questão em aberto | customer_id no body ou no path; path proposto como design | TRANSCRICAO | [09:32] Larissa |
| RFC-OPEN-03 | `docs/RFC.md` | Questão em aberto (adiada) | Escala multi-worker: particionar por order_id ou lock pessimista | TRANSCRICAO | [09:13] Diego |
| RFC-OPEN-04 | `docs/RFC.md` | Questão em aberto | Endurecimento da autorização do CRUD (hoje qualquer role autenticada); pergunta de [09:36] Marcos | TRANSCRICAO | [09:37] Sofia |
| RFC-OPEN-05 | `docs/RFC.md` | Questão em aberto (adiada) | Aviso por e-mail ao cliente sobre webhook com falha: próxima fase | TRANSCRICAO | [09:37] Larissa |
| RFC-CONF-01 | `docs/RFC.md` | Ponto para confirmação (análise) | 5 tentativas decididas versus 5 intervalos e quase 15h; adotado 1 envio + 5 retentativas | TRANSCRICAO | [09:17] Diego |
| RFC-CONF-02 | `docs/RFC.md` | Ponto para confirmação (análise) | Evento em backoff pode ser ultrapassado pelo seguinte do mesmo pedido | TRANSCRICAO | [09:12] Diego |
| RFC-RISK-01 | `docs/RFC.md` | Risco (análise) | Worker único: cliente lento (timeout 10s) atrasa os demais além da meta de 10s de [09:02] Marcos | TRANSCRICAO | [09:42] Diego |
| RFC-RISK-02 | `docs/RFC.md` | Risco | Crescimento da outbox sem arquivamento nesta fase | TRANSCRICAO | [09:08] Diego |
| RFC-RISK-03 | `docs/RFC.md` | Risco | Vazamento de secret (precedente real) | TRANSCRICAO | [09:22] Diego |
| RFC-RISK-04 | `docs/RFC.md` | Risco (análise) | Usuário autenticado configura webhook de outro customer; endurecimento posterior | TRANSCRICAO | [09:37] Sofia |
| RFC-RISK-05 | `docs/RFC.md` | Risco | Estouro do prazo da Atlas (fim de novembro, 3 sprints) | TRANSCRICAO | [09:46] Larissa |
| FDD-CTX-01 | `docs/FDD.md` | Contexto | changeStatus em transação: valida, estoque só em PENDING→PAID ou cancelamento, update e history | CODIGO | src/modules/orders/order.service.ts |
| FDD-CTX-02 | `docs/FDD.md` | Contexto | Inserção do evento dentro da transação existente sem acoplar HTTP | TRANSCRICAO | [09:40] Bruno |
| FDD-OBJ-01 | `docs/FDD.md` | Objetivo técnico | p95 commit→entrega abaixo de 10s | TRANSCRICAO | [09:02] Marcos |
| FDD-OBJ-02 | `docs/FDD.md` | Objetivo técnico | Nenhuma mudança de status sem evento; falha na outbox desfaz a mudança | TRANSCRICAO | [09:40] Bruno |
| FDD-OBJ-03 | `docs/FDD.md` | Objetivo técnico | Retentativas cobrem 14h36min antes da DLQ | TRANSCRICAO | [09:17] Diego |
| FDD-OBJ-04 | `docs/FDD.md` | Objetivo técnico | Zero infraestrutura e dependências novas | TRANSCRICAO | [09:07] Diego |
| FDD-OBJ-05 | `docs/FDD.md` | Objetivo técnico | Secret só nas respostas de criação e rotação, nunca em logs | TRANSCRICAO | [09:22] Diego |
| FDD-ESC-01 | `docs/FDD.md` | Escopo | Evento order.status_changed filtrado por status, CRUD, rotação, deliveries, replay, worker | TRANSCRICAO | [09:33] Marcos |
| FDD-ESC-02 | `docs/FDD.md` | Exclusão | E-mail, rate limit, painel, inbound, arquivamento, multi-worker, roles do CRUD fora; e-mail em [09:37] Larissa | TRANSCRICAO | [09:40] Larissa |
| FDD-ESC-03 | `docs/FDD.md` | Exclusão | Criação e exclusão de pedido não passam por changeStatus e não geram evento | CODIGO | src/modules/orders/order.service.ts |
| FDD-DADOS-01 | `docs/FDD.md` | Modelo de dados | Novos models no padrão uuid Char(36) do schema | TRANSCRICAO | [09:51] Larissa |
| FDD-DADOS-02 | `docs/FDD.md` | Modelo de dados | Configuração com url, secret, customer_id e estado ativo | TRANSCRICAO | [09:21] Bruno |
| FDD-DADOS-03 | `docs/FDD.md` | Modelo de dados | Outbox com estados pendente/processando/falhou/entregue e índices em status e created_at | TRANSCRICAO | [09:08] Diego |
| FDD-DADOS-04 | `docs/FDD.md` | Proposta de design | Uma linha de outbox por webhook assinante; id da linha é o event_id | TRANSCRICAO | [09:25] Diego |
| FDD-DADOS-05 | `docs/FDD.md` | Proposta de design | Payload em MEDIUMTEXT com os bytes exatos do snapshot (evita rollback acima de 64KB) | TRANSCRICAO | [09:52] Larissa |
| FDD-DADOS-06 | `docs/FDD.md` | Modelo de dados | DLQ em tabela própria com payload, motivo e timestamp | TRANSCRICAO | [09:18] Diego |
| FDD-DADOS-07 | `docs/FDD.md` | Proposta de design | Cascade Webhook→Customer para não alterar DELETE /customers/:id | CODIGO | prisma/schema.prisma |
| FDD-FLUXO-01 | `docs/FDD.md` | Fluxo | publishWebhookEvent(tx) após history; filtro na inserção; snapshot; rollback em falha; filtro em [09:34] Bruno | TRANSCRICAO | [09:41] Bruno |
| FDD-FLUXO-02 | `docs/FDD.md` | Fluxo | Worker: claim de lote pendente, envio, registro de entrega, sucesso ou falha | TRANSCRICAO | [09:09] Diego |
| FDD-FLUXO-03 | `docs/FDD.md` | Fluxo | Retry 1m/5m/30m/2h/12h; 6ª falha vai para DLQ | TRANSCRICAO | [09:17] Larissa |
| FDD-FLUXO-04 | `docs/FDD.md` | Fluxo | DLQ e replay ADMIN reenfileirando a mesma linha; auditoria em log | TRANSCRICAO | [09:36] Sofia |
| FDD-FLUXO-05 | `docs/FDD.md` | Fluxo | Rotação: secret anterior válida por 24h; duas assinaturas no grace | TRANSCRICAO | [09:21] Sofia |
| FDD-WORKER-01 | `docs/FDD.md` | Restrição | Processo separado, mesmo banco, PrismaClient próprio | TRANSCRICAO | [09:30] Bruno |
| FDD-WORKER-02 | `docs/FDD.md` | Regra | Polling de 2s, mais antigos primeiro, lote pequeno (10 proposto); lote em [09:08] Diego | TRANSCRICAO | [09:09] Diego |
| FDD-WORKER-03 | `docs/FDD.md` | Limitação | Instância única; ordem por order_id no caminho sem falhas | TRANSCRICAO | [09:12] Diego |
| FDD-WORKER-04 | `docs/FDD.md` | Proposta de design | Paralelismo entre pedidos distintos, sequencial dentro do pedido | TRANSCRICAO | [09:42] Diego |
| FDD-WORKER-05 | `docs/FDD.md` | Proposta de design | Recuperação de PROCESSING para PENDING no boot, coberta por at-least-once | TRANSCRICAO | [09:24] Diego |
| FDD-WORKER-06 | `docs/FDD.md` | Proposta de design | Só 2xx é sucesso; redirects não seguidos; timeout de 10s | TRANSCRICAO | [09:42] Diego |
| FDD-WORKER-07 | `docs/FDD.md` | Proposta de design | Shutdown gracioso no molde de server.ts | CODIGO | src/server.ts |
| FDD-CONTRATO-01 | `docs/FDD.md` | Contrato | POST /customers/:customerId/webhooks com url e events; secret devolvida na criação | TRANSCRICAO | [09:31] Marcos |
| FDD-CONTRATO-02 | `docs/FDD.md` | Contrato | GET /customers/:customerId/webhooks sem secret | TRANSCRICAO | [09:33] Bruno |
| FDD-CONTRATO-03 | `docs/FDD.md` | Contrato | PATCH /webhooks/:id para url, events e active | TRANSCRICAO | [09:33] Bruno |
| FDD-CONTRATO-04 | `docs/FDD.md` | Contrato | DELETE /webhooks/:id com cascata (proposta) | TRANSCRICAO | [09:33] Bruno |
| FDD-CONTRATO-05 | `docs/FDD.md` | Contrato | POST /webhooks/:id/rotate-secret; anterior válida por 24h | TRANSCRICAO | [09:21] Sofia |
| FDD-CONTRATO-06 | `docs/FDD.md` | Contrato | GET /webhooks/:id/deliveries, últimas 100, sucesso/falha, payload, resposta e tempo | TRANSCRICAO | [09:34] Marcos |
| FDD-CONTRATO-07 | `docs/FDD.md` | Contrato | POST /admin/webhooks/dead-letter/:id/replay exige ADMIN; endpoint em [09:18] Diego | TRANSCRICAO | [09:36] Sofia |
| FDD-CONTRATO-08 | `docs/FDD.md` | Contrato | Entrega: payload enxuto sem items; headers de [09:44] Diego e X-Webhook-Id de [09:44] Sofia | TRANSCRICAO | [09:43] Diego |
| FDD-ERRO-01 | `docs/FDD.md` | Erro | WEBHOOK_NOT_FOUND 404 estendendo AppError | TRANSCRICAO | [09:28] Bruno |
| FDD-ERRO-02 | `docs/FDD.md` | Erro | WEBHOOK_CUSTOMER_NOT_FOUND 404; NotFoundError fixa código NOT_FOUND | CODIGO | src/shared/errors/http-errors.ts |
| FDD-ERRO-03 | `docs/FDD.md` | Erro | WEBHOOK_INVALID_URL via Zod como VALIDATION_ERROR com detalhe | TRANSCRICAO | [09:23] Sofia |
| FDD-ERRO-04 | `docs/FDD.md` | Erro | WEBHOOK_INVALID_EVENTS via Zod com OrderStatus | CODIGO | src/middlewares/validate.middleware.ts |
| FDD-ERRO-05 | `docs/FDD.md` | Erro | WEBHOOK_DEAD_LETTER_NOT_FOUND 404 | TRANSCRICAO | [09:18] Diego |
| FDD-ERRO-06 | `docs/FDD.md` | Erro | WEBHOOK_DEAD_LETTER_ALREADY_REPLAYED 409 via ConflictError | CODIGO | src/shared/errors/http-errors.ts |
| FDD-ERRO-07 | `docs/FDD.md` | Erro | WEBHOOK_INACTIVE 409 no replay de webhook desativado | TRANSCRICAO | [09:21] Bruno |
| FDD-ERRO-08 | `docs/FDD.md` | Erro de entrega | WEBHOOK_DELIVERY_TIMEOUT após 10s, retentável | TRANSCRICAO | [09:42] Diego |
| FDD-ERRO-09 | `docs/FDD.md` | Erro de entrega | WEBHOOK_DELIVERY_HTTP_ERROR para não-2xx, retentável (proposta) | TRANSCRICAO | [09:14] Larissa |
| FDD-ERRO-10 | `docs/FDD.md` | Erro de entrega | WEBHOOK_DELIVERY_NETWORK_ERROR para cliente fora do ar, retentável | TRANSCRICAO | [09:14] Larissa |
| FDD-ERRO-11 | `docs/FDD.md` | Erro de entrega | WEBHOOK_PAYLOAD_TOO_LARGE acima de 64KB: erra, não trunca; limite em [09:24] Larissa | TRANSCRICAO | [09:23] Sofia |
| FDD-ERRO-12 | `docs/FDD.md` | Erro de entrega | WEBHOOK_SECRET_REQUIRED como invariante do worker | TRANSCRICAO | [09:28] Bruno |
| FDD-ERRO-13 | `docs/FDD.md` | Erro de entrega | WEBHOOK_INACTIVE para evento de webhook desativado | TRANSCRICAO | [09:21] Bruno |
| FDD-ERRO-14 | `docs/FDD.md` | Erro de entrega | WEBHOOK_RETRIES_EXHAUSTED na 6ª falha | TRANSCRICAO | [09:17] Larissa |
| FDD-RES-01 | `docs/FDD.md` | Resiliência | Timeout de 10s com AbortSignal.timeout | TRANSCRICAO | [09:42] Diego |
| FDD-RES-02 | `docs/FDD.md` | Resiliência | Backoff fixo 1m/5m/30m/2h/12h via nextAttemptAt | TRANSCRICAO | [09:17] Larissa |
| FDD-RES-03 | `docs/FDD.md` | Resiliência | Fallback para DLQ com replay manual | TRANSCRICAO | [09:18] Diego |
| FDD-RES-04 | `docs/FDD.md` | Resiliência | Limite de 64KB verificado no worker, não na transação | TRANSCRICAO | [09:24] Larissa |
| FDD-RES-05 | `docs/FDD.md` | Resiliência | Recuperação de crash coberta por at-least-once | TRANSCRICAO | [09:24] Diego |
| FDD-RES-06 | `docs/FDD.md` | Resiliência | Isolamento entre clientes por paralelismo entre pedidos | TRANSCRICAO | [09:42] Diego |
| FDD-RES-07 | `docs/FDD.md` | Resiliência | Falha de banco no tick: loga e segue; estado na outbox | TRANSCRICAO | [09:06] Diego |
| FDD-RES-08 | `docs/FDD.md` | Resiliência | Worker parado acumula PENDING sem perda | TRANSCRICAO | [09:11] Diego |
| FDD-OBS-01 | `docs/FDD.md` | Métrica | Latência commit→entrega com SLO p95 abaixo de 10s | TRANSCRICAO | [09:02] Marcos |
| FDD-OBS-02 | `docs/FDD.md` | Métrica | Pendentes e idade do mais antigo; alerta de worker parado | TRANSCRICAO | [09:11] Diego |
| FDD-OBS-03 | `docs/FDD.md` | Métrica | Tentativas por resultado | TRANSCRICAO | [09:42] Diego |
| FDD-OBS-04 | `docs/FDD.md` | Métrica | Duração da tentativa perto do timeout | TRANSCRICAO | [09:42] Diego |
| FDD-OBS-05 | `docs/FDD.md` | Métrica | Dead letters e replays; base para decidir o aviso por e-mail | TRANSCRICAO | [09:37] Larissa |
| FDD-OBS-06 | `docs/FDD.md` | Métrica | Eventos enfileirados por status; base para decidir rate limiting | TRANSCRICAO | [09:39] Larissa |
| FDD-OBS-07 | `docs/FDD.md` | Log | webhook_event_enqueued com requestId e ids | CODIGO | src/shared/logger/index.ts |
| FDD-OBS-08 | `docs/FDD.md` | Log | webhook_delivery_succeeded e webhook_delivery_failed | TRANSCRICAO | [09:29] Bruno |
| FDD-OBS-09 | `docs/FDD.md` | Log | webhook_dead_lettered para evidência | TRANSCRICAO | [09:18] Diego |
| FDD-OBS-10 | `docs/FDD.md` | Log | webhook_replayed com adminUserId para auditoria | TRANSCRICAO | [09:36] Sofia |
| FDD-OBS-11 | `docs/FDD.md` | Log | Logs de CRUD e rotação sem o valor da secret | TRANSCRICAO | [09:22] Diego |
| FDD-OBS-12 | `docs/FDD.md` | Log | webhook_worker_tick com métricas de fila | TRANSCRICAO | [09:29] Bruno |
| FDD-OBS-13 | `docs/FDD.md` | Segurança | Adicionar *.secret e *.previousSecret aos redactPaths | CODIGO | src/shared/logger/index.ts |
| FDD-OBS-14 | `docs/FDD.md` | Tracing | Correlação X-Request-Id → eventId → webhookId → attempt | CODIGO | src/middlewares/request-logger.middleware.ts |
| FDD-INT-01 | `docs/FDD.md` | Integração | changeStatus chama publishWebhookEvent(tx) dentro do $transaction | CODIGO | src/modules/orders/order.service.ts |
| FDD-INT-02 | `docs/FDD.md` | Integração | Controller repassa req.id como requestId | CODIGO | src/modules/orders/order.controller.ts |
| FDD-INT-03 | `docs/FDD.md` | Integração | Máquina de estados sem alteração; events com z.nativeEnum(OrderStatus) | CODIGO | src/modules/orders/order.status.ts |
| FDD-INT-04 | `docs/FDD.md` | Integração | Novos models e relação Customer.webhooks; migration nova | CODIGO | prisma/schema.prisma |
| FDD-INT-05 | `docs/FDD.md` | Integração | Erros WEBHOOK_ estendem AppError e ConflictError sem mudar shared | CODIGO | src/shared/errors/app-error.ts |
| FDD-INT-06 | `docs/FDD.md` | Integração | Error middleware sem alteração | CODIGO | src/middlewares/error.middleware.ts |
| FDD-INT-07 | `docs/FDD.md` | Integração | authenticate nos routers e requireRole ADMIN no replay | CODIGO | src/middlewares/auth.middleware.ts |
| FDD-INT-08 | `docs/FDD.md` | Integração | validate() com schemas do módulo; refine https | CODIGO | src/middlewares/validate.middleware.ts |
| FDD-INT-09 | `docs/FDD.md` | Integração | Três routers montados com prefixo; customer-scoped com mergeParams antes de /customers | CODIGO | src/routes/index.ts |
| FDD-INT-10 | `docs/FDD.md` | Integração | Wiring de repository, service e controller em buildControllers | CODIGO | src/app.ts |
| FDD-INT-11 | `docs/FDD.md` | Integração | src/worker.ts no molde de server.ts com createPrismaClient | CODIGO | src/config/database.ts |
| FDD-INT-12 | `docs/FDD.md` | Integração | Redact e logger.child no worker | CODIGO | src/shared/logger/index.ts |
| FDD-INT-13 | `docs/FDD.md` | Integração | Scripts worker e worker:dev; npm run worker em [09:11] Larissa | CODIGO | package.json |
| FDD-INT-14 | `docs/FDD.md` | Integração | Limpeza das tabelas novas no beforeEach; tests/webhooks.test.ts novo | CODIGO | tests/setup.ts |
| FDD-DEP-01 | `docs/FDD.md` | Dependência | Node 20 nativo (fetch, AbortSignal.timeout, crypto); nenhum pacote novo | CODIGO | package.json |
| FDD-DEP-02 | `docs/FDD.md` | Dependência | Mesmo MySQL e DATABASE_URL; migration aditiva | CODIGO | src/config/env.ts |
| FDD-DEP-03 | `docs/FDD.md` | Compatibilidade | Contratos existentes inalterados; DELETE customer remove webhooks em cascata | CODIGO | src/modules/orders/order.routes.ts |
| FDD-DEP-04 | `docs/FDD.md` | Compatibilidade | Ordem de deploy migration→API→worker; eventos acumulam sem perda | TRANSCRICAO | [09:06] Diego |
| FDD-DEP-05 | `docs/FDD.md` | Dependência | Cliente: https, 2xx em 10s, HMAC e dedup documentados no portal | TRANSCRICAO | [09:26] Marcos |
| FDD-DEP-06 | `docs/FDD.md` | Restrição | Revisão de segurança de 2 dias úteis antes do deploy | TRANSCRICAO | [09:46] Sofia |
| FDD-AC-01 | `docs/FDD.md` | Critério de aceite | Mudança com assinante cria 1 linha PENDING por webhook assinante | TRANSCRICAO | [09:34] Bruno |
| FDD-AC-02 | `docs/FDD.md` | Critério de aceite | Sem assinante nenhuma linha é criada | TRANSCRICAO | [09:34] Bruno |
| FDD-AC-03 | `docs/FDD.md` | Critério de aceite | Falha na outbox mantém status, histórico e estoque | TRANSCRICAO | [09:40] Bruno |
| FDD-AC-04 | `docs/FDD.md` | Critério de aceite | Worker entrega em até 2s mais resposta, com todos os headers | TRANSCRICAO | [09:44] Diego |
| FDD-AC-05 | `docs/FDD.md` | Critério de aceite | X-Signature HMAC-SHA256 do corpo; duas assinaturas no grace | TRANSCRICAO | [09:20] Sofia |
| FDD-AC-06 | `docs/FDD.md` | Critério de aceite | Agenda de retry correta e DLQ na 6ª falha | TRANSCRICAO | [09:17] Larissa |
| FDD-AC-07 | `docs/FDD.md` | Critério de aceite | Timeout de 10s gera falha e retry | TRANSCRICAO | [09:42] Diego |
| FDD-AC-08 | `docs/FDD.md` | Critério de aceite | Payload acima de 64KB vai direto para DLQ | TRANSCRICAO | [09:24] Larissa |
| FDD-AC-09 | `docs/FDD.md` | Critério de aceite | Replay ADMIN 202 com mesmo id; OPERATOR 403; log de auditoria | TRANSCRICAO | [09:36] Sofia |
| FDD-AC-10 | `docs/FDD.md` | Critério de aceite | URL http recusada com WEBHOOK_INVALID_URL | TRANSCRICAO | [09:23] Sofia |
| FDD-AC-11 | `docs/FDD.md` | Critério de aceite | Secret ausente de GET, PATCH e logs | TRANSCRICAO | [09:22] Diego |
| FDD-AC-12 | `docs/FDD.md` | Critério de aceite | Deliveries retorna no máximo 100, mais recentes primeiro | TRANSCRICAO | [09:34] Marcos |
| FDD-AC-13 | `docs/FDD.md` | Critério de aceite | npm test, lint e build sem regressão | CODIGO | package.json |
| FDD-RISK-01 | `docs/FDD.md` | Risco | Cliente lento atrasa outros com worker único | TRANSCRICAO | [09:42] Diego |
| FDD-RISK-02 | `docs/FDD.md` | Risco | Inversão de ordem sob retry | TRANSCRICAO | [09:12] Diego |
| FDD-RISK-03 | `docs/FDD.md` | Risco | Secret em claro no banco; criptografia em repouso para a revisão de segurança | TRANSCRICAO | [09:46] Sofia |
| FDD-RISK-04 | `docs/FDD.md` | Risco | Crescimento da outbox e das entregas sem arquivamento | TRANSCRICAO | [09:08] Diego |
| FDD-RISK-05 | `docs/FDD.md` | Risco | Usuário autenticado configura webhook de outro customer | TRANSCRICAO | [09:37] Sofia |
| FDD-RISK-06 | `docs/FDD.md` | Risco (análise) | SSRF por URL https arbitrária; levado à revisão de segurança | TRANSCRICAO | [09:46] Sofia |
| FDD-RISK-07 | `docs/FDD.md` | Risco | Entregas duplicadas cobertas pelo contrato at-least-once | TRANSCRICAO | [09:26] Marcos |
