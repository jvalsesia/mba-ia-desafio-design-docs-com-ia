# PRD: Sistema de Webhooks de Notificação de Pedidos

| Campo | Valor |
| --- | --- |
| **Autor** | Julio Valsesia |
| **Product Manager** | Marcos |
| **Status** | Aprovado em reunião técnica, pronto para implementação |
| **Data** | 2026-09-29 |
| **Documentos relacionados** | [RFC](./RFC.md) · [FDD](./FDD.md) · [ADRs](./adrs/README.md) · [Tracker](./TRACKER.md) |

> Todos os itens citam a origem: `[hh:mm] Nome` na [transcrição da reunião](../TRANSCRICAO.md). O detalhamento técnico está no RFC, nos ADRs e no FDD. Este documento responde **por que** e **o quê**.

## 1. Resumo e contexto da feature

**PRD-CTX-01:** Hoje a plataforma de gestão de pedidos (OMS) não avisa os clientes quando o status de um pedido muda. Clientes B2B que integram sistemas com a plataforma precisam perguntar repetidamente se algo mudou (`[09:00] Marcos`).

Esta feature cria **notificações automáticas de mudança de status de pedido via webhook**. O cliente cadastra um endereço seguro (`https`) e escolhe quais status quer acompanhar. A partir daí, a plataforma envia uma mensagem assinada para esse endereço sempre que um pedido dele muda para um desses status, em menos de 10 segundos (`[09:02] Marcos`, `[09:33] Marcos`).

O fluxo é **somente de saída**, da plataforma para o cliente (`[09:02] Marcos`).

## 2. Problema e motivação

**PRD-PROB-01:** Três clientes B2B (Atlas Comercial, MaxDistribuição e Nova Cargo) fizeram um pedido formal para serem notificados em tempo real (`[09:00] Marcos`). Hoje eles consultam a listagem de pedidos de tempos em tempos, o que deixa a integração **lenta e cara** para eles (`[09:00] Marcos`).

**PRD-PROB-02:** Há risco comercial concreto. A Atlas sinalizou que pode migrar para um concorrente se a feature não for entregue até o fim do trimestre (`[09:00] Marcos`) e pediu a entrega até o fim de novembro (`[09:45] Marcos`).

**PRD-PROB-03:** Para os clientes, "tempo real" é qualquer coisa abaixo de 10 segundos. O essencial é não ficar "pendurado" nem precisar atualizar manualmente (`[09:02] Marcos`).

## 3. Público-alvo e cenários de uso

| Público | Necessidade | Origem |
| --- | --- | --- |
| **PRD-PUB-01:** Equipes de integração dos clientes B2B (Atlas, MaxDistribuição, Nova Cargo) | Receber mudanças de status sem fazer polling | `[09:00] Marcos` |
| **PRD-PUB-02:** Usuários da plataforma que representam o cliente e configuram os webhooks pela API | Cadastrar, ajustar e diagnosticar os webhooks do cliente | `[09:32] Marcos` |
| **PRD-PUB-03:** Administradores da plataforma (role ADMIN) | Reprocessar notificações que falharam definitivamente, com rastro de auditoria | `[09:36] Sofia` |

**Cenários de uso:**

- **PRD-CEN-01: Acompanhar apenas o que importa.** A Atlas cadastra um webhook para receber só `SHIPPED` e `DELIVERED`. Quando um pedido dela é despachado, o sistema dela é avisado em segundos (`[09:33] Marcos`).
- **PRD-CEN-02: Manutenção planejada no cliente.** O endpoint da MaxDistribuição fica fora do ar por 2 horas. A plataforma continua tentando e entrega as notificações quando o endpoint volta, sem ação manual (`[09:16] Diego`).
- **PRD-CEN-03: Suspeita de vazamento de secret.** A Nova Cargo desconfia que a secret vazou em um log. Ela pede uma nova pela API e tem 24h para atualizar os sistemas antes da antiga deixar de valer (`[09:21] Sofia`, `[09:22] Diego`).
- **PRD-CEN-04: "Não recebi a notificação".** O cliente consulta o histórico das últimas entregas daquele webhook, com sucesso ou falha, conteúdo enviado, resposta e tempo de resposta, e se autodiagnostica (`[09:34] Marcos`).
- **PRD-CEN-05: Falha definitiva.** Depois de esgotadas as tentativas, a notificação fica guardada. Quando o cliente corrige o problema, um ADMIN reenvia a notificação (`[09:18] Diego`, `[09:36] Sofia`).
- **PRD-CEN-06: Notificação repetida.** O cliente recebe a mesma notificação duas vezes, reconhece que é repetida pelo identificador único e a ignora (`[09:25] Diego`).

## 4. Objetivos e métricas de sucesso

| ID | Objetivo | Métrica | Meta | Origem |
| --- | --- | --- | --- | --- |
| **PRD-OBJ-01** | Notificação "em tempo real" | Tempo entre a mudança de status e a notificação recebida pelo cliente, quando o endpoint está disponível | **95% abaixo de 10 segundos** | `[09:02] Marcos` |
| **PRD-OBJ-02** | Entregar no prazo do cliente-âncora | Feature em produção | **Até o fim de novembro**, em até **3 sprints**, incluindo a revisão de segurança | `[09:45] Marcos`, `[09:47] Larissa` |
| **PRD-OBJ-03** | Substituir o polling dos clientes solicitantes | Clientes solicitantes com ao menos um webhook ativo | **3 de 3** (Atlas, MaxDistribuição, Nova Cargo) | `[09:00] Marcos` |
| **PRD-OBJ-04** | Confiabilidade: nenhuma mudança de status "silenciosa" | Mudanças de status com assinante que não geraram notificação | **0** | `[09:40] Bruno` |
| **PRD-OBJ-05** | Tolerar indisponibilidades comuns do cliente | Janela de novas tentativas antes de declarar falha definitiva | **≈ 14h36min**, "quase 15 horas" | `[09:17] Diego`, `[09:17] Marcos` |

## 5. Escopo

### 5.1 Incluso

**PRD-ESC-01:**
- Notificação de toda mudança de status de pedido, filtrada pelos status escolhidos em cada webhook.
- Gestão completa dos webhooks pela API: cadastro, listagem, edição, remoção e rotação de secret.
- Histórico de entregas.
- Novas tentativas automáticas.
- Reenvio manual por ADMIN.
- Assinatura de segurança em toda notificação.

Origem: `[09:31] Marcos`, `[09:33] Bruno`, `[09:34] Marcos`, `[09:48] Larissa`.

### 5.2 Fora de escopo

Itens descartados ou adiados na reunião:

| ID | Item | Situação | Origem |
| --- | --- | --- | --- |
| **PRD-OOS-01** | Aviso por e-mail ao cliente quando o webhook dele está falhando (ex.: 3 falhas seguidas) | **Adiado** para a próxima fase, "depois que a gente medir o impacto" | `[09:37] Larissa` |
| **PRD-OOS-02** | Painel ou dashboard visual para o cliente ver os webhooks | **Fora de escopo**: projeto separado do time de frontend; nesta fase, só API | `[09:40] Larissa` |
| **PRD-OOS-03** | Limite de taxa (rate limiting) das notificações enviadas a um cliente | **Em aberto**: observar em produção e decidir depois | `[09:39] Larissa` |
| **PRD-OOS-04** | Receber webhooks enviados pelos clientes (inbound) | **Fora de escopo**: os clientes querem só receber | `[09:02] Marcos` |
| **PRD-OOS-05** | Garantia de ordem global entre todos os pedidos | **Não oferecida**: os clientes não pediram; a ordem vale por pedido | `[09:14] Marcos` |
| **PRD-OOS-06** | Garantia de entrega "exatamente uma vez" | **Descartada**: a garantia é "pelo menos uma vez" | `[09:25] Diego` |
| **PRD-OOS-07** | Restringir a configuração de webhooks por perfil de usuário | **Adiado**: por enquanto, qualquer usuário autenticado | `[09:37] Sofia` |
| **PRD-OOS-08** | Arquivamento do histórico de notificações entregues | **Fora desta feature** | `[09:08] Diego` |

## 6. Requisitos funcionais

| ID | Requisito | Origem |
| --- | --- | --- |
| **PRD-FR-01** | O usuário cadastra um webhook para um cliente, informando o endereço de destino e a lista de status de pedido que quer receber | `[09:31] Marcos` |
| **PRD-FR-02** | A plataforma gera a secret do webhook e a devolve ao usuário no momento do cadastro | `[09:31] Marcos` |
| **PRD-FR-03** | O cliente associado ao webhook é informado explicitamente na requisição, e não deduzido do usuário logado | `[09:32] Larissa` |
| **PRD-FR-04** | O usuário lista os webhooks de um cliente | `[09:33] Bruno` |
| **PRD-FR-05** | O usuário edita um webhook (endereço, status assinados, ativo/inativo) | `[09:33] Bruno` |
| **PRD-FR-06** | O usuário remove um webhook | `[09:33] Bruno` |
| **PRD-FR-07** | Cada webhook escolhe quais status de pedido quer receber. Mudanças para outros status não geram notificação para ele | `[09:33] Marcos` |
| **PRD-FR-08** | A cada mudança de status de um pedido, a plataforma notifica automaticamente os webhooks ativos do cliente que assinam o novo status | `[09:40] Bruno` |
| **PRD-FR-09** | A notificação informa o pedido (identificador e número), o status anterior, o novo status, o cliente, o valor total, o momento do evento e um identificador único do evento. **Não inclui os itens**: o cliente consulta o pedido se precisar | `[09:43] Diego` |
| **PRD-FR-10** | O usuário consulta o histórico das últimas 100 entregas de um webhook, com resultado, conteúdo enviado, resposta recebida e tempo de resposta | `[09:34] Marcos` |
| **PRD-FR-11** | O usuário solicita uma nova secret. A anterior continua válida por 24 horas | `[09:21] Sofia` |
| **PRD-FR-12** | Quando o cliente não recebe, a plataforma tenta de novo automaticamente com intervalos crescentes (1 min, 5 min, 30 min, 2 h, 12 h) | `[09:17] Larissa` |
| **PRD-FR-13** | Esgotadas as tentativas, a notificação é guardada como falha definitiva, com o conteúdo e o motivo | `[09:18] Diego` |
| **PRD-FR-14** | Um ADMIN reenvia manualmente uma notificação em falha definitiva, e fica registrado quem fez o reenvio | `[09:36] Sofia` |
| **PRD-FR-15** | O cadastro de endereço sem `https` é recusado com erro de validação | `[09:23] Sofia` |

## 7. Requisitos não funcionais

| ID | Requisito | Origem |
| --- | --- | --- |
| **PRD-NFR-01** | **Latência:** notificação em menos de 10 segundos após a mudança de status, com espera de até ~2s até o envio em condições normais. Um cliente com endpoint lento não deve atrasar as notificações dos demais (PRD-RISK-06) | `[09:02] Marcos`, `[09:10] Larissa` |
| **PRD-NFR-02** | **Autenticidade e integridade:** toda notificação é assinada (HMAC-SHA256) para o cliente verificar a origem e detectar adulteração | `[09:19] Sofia`, `[09:20] Sofia` |
| **PRD-NFR-03** | **Isolamento de credenciais:** cada webhook tem sua própria secret; não existe secret global | `[09:21] Sofia` |
| **PRD-NFR-04** | **Transporte seguro:** somente endereços `https` | `[09:23] Sofia` |
| **PRD-NFR-05** | **Tamanho máximo:** notificação limitada a 64KB; acima disso, erro, sem truncar | `[09:24] Larissa` |
| **PRD-NFR-06** | **Tempo de resposta do cliente:** o cliente tem até 10 segundos para confirmar o recebimento; depois disso, conta como falha e há nova tentativa | `[09:42] Diego` |
| **PRD-NFR-07** | **Garantia de entrega "pelo menos uma vez":** o cliente pode receber repetições e as identifica pelo identificador único do evento | `[09:24] Diego`, `[09:25] Diego` |
| **PRD-NFR-08** | **Ordem:** as notificações de um mesmo pedido chegam na ordem dos acontecimentos no funcionamento normal; não há garantia de ordem global | `[09:13] Larissa` |
| **PRD-NFR-09** | **Consistência:** o status de um pedido nunca muda sem que a notificação correspondente seja registrada | `[09:40] Bruno` |
| **PRD-NFR-10** | **Operação:** a entrega roda de forma independente da API, e reinícios da API não interrompem notificações | `[09:11] Diego` |
| **PRD-NFR-11** | **Custo de infraestrutura:** nenhuma infraestrutura nova (fila ou cache dedicados) | `[09:07] Diego` |

## 8. Decisões e trade-offs principais

| ID | Decisão (visão de produto) | Trade-off aceito | Detalhe |
| --- | --- | --- | --- |
| **PRD-DEC-01** | Notificação **assíncrona**, registrada junto com a mudança de status | Espera de até ~2s antes do envio, em troca de nunca travar a operação de pedidos por causa de um cliente lento (`[09:04] Bruno`, `[09:10] Larissa`) | [ADR-001](./adrs/ADR-001-outbox-no-mysql.md), [ADR-002](./adrs/ADR-002-worker-separado-em-polling.md) |
| **PRD-DEC-02** | 5 novas tentativas ao longo de ~15h, depois falha definitiva com reenvio manual | Uma notificação pode chegar horas depois, mas nada fica pendurado para sempre (`[09:15] Diego`, `[09:17] Marcos`) | [ADR-003](./adrs/ADR-003-retry-backoff-e-dlq.md) |
| **PRD-DEC-03** | Assinatura por webhook, com troca de secret sem interrupção | O cliente precisa implementar a verificação da assinatura (`[09:20] Sofia`) | [ADR-004](./adrs/ADR-004-hmac-sha256-secret-por-endpoint.md) |
| **PRD-DEC-04** | "Pelo menos uma vez", em vez de "exatamente uma vez" | O cliente precisa ignorar repetições. O Marcos documenta isso em destaque no portal (`[09:25] Sofia`, `[09:26] Marcos`) | [ADR-005](./adrs/ADR-005-at-least-once-com-x-event-id.md) |
| **PRD-DEC-05** | A notificação reflete o pedido **no momento da mudança**, e não no momento do envio | Mais dados guardados por notificação (`[09:52] Larissa`) | [ADR-007](./adrs/ADR-007-snapshot-do-payload-na-insercao.md) |
| **PRD-DEC-06** | Conteúdo enxuto, sem itens do pedido | O cliente consulta o pedido quando precisa de detalhes (`[09:43] Diego`) | [FDD §6](./FDD.md) |

## 9. Dependências

| ID | Dependência | Responsável | Origem |
| --- | --- | --- | --- |
| **PRD-DEP-01** | Documentação no portal do desenvolvedor: como integrar via API, verificar a assinatura e tratar repetições | Marcos | `[09:26] Marcos`, `[09:40] Marcos` |
| **PRD-DEP-02** | Revisão de segurança de pelo menos 2 dias úteis antes do deploy, com foco em assinatura e geração de secret | Sofia | `[09:46] Sofia` |
| **PRD-DEP-03** | Clientes com endpoint `https` que responda em até 10s, verifique a assinatura e ignore repetições | Clientes B2B | `[09:23] Sofia`, `[09:42] Diego`, `[09:25] Diego` |
| **PRD-DEP-04** | Confirmação do prazo com a Atlas e atualização dos clientes | Marcos | `[09:47] Marcos`, `[09:49] Marcos` |
| **PRD-DEP-05** | Painel visual, se vier a existir: projeto separado do time de frontend | Time de frontend | `[09:40] Larissa` |

## 10. Riscos e mitigação

| ID | Risco | Probabilidade | Impacto | Mitigação | Origem |
| --- | --- | --- | --- | --- | --- |
| **PRD-RISK-01** | Atraso na entrega e perda da Atlas para o concorrente | Média | Alto | Escopo enxuto (sem e-mail, painel ou rate limit), estimativa de 3 sprints validada pelo time e prazo confirmado com o cliente | `[09:00] Marcos`, `[09:47] Larissa` |
| **PRD-RISK-02** | Cliente não trata notificações repetidas e processa o mesmo evento duas vezes | Média | Médio | Identificador único em toda notificação, documentação em destaque no portal | `[09:25] Sofia`, `[09:26] Marcos` |
| **PRD-RISK-03** | Vazamento da secret de um cliente (já aconteceu antes, em log do cliente) | Média | Alto | Secret por webhook (vazamento isolado), rotação com 24h de convivência, revisão de segurança | `[09:22] Diego`, `[09:21] Sofia` |
| **PRD-RISK-04** | Cliente com muitos pedidos mudando ao mesmo tempo recebe um volume alto de chamadas | Baixa | Médio | Monitorar o volume em produção e decidir sobre limite de taxa na próxima fase | `[09:38] Diego`, `[09:39] Larissa` |
| **PRD-RISK-05** | Webhook do cliente falha por horas sem que o cliente perceba, já que não há aviso por e-mail nesta fase | Média | Médio | Histórico de entregas consultável pelo cliente, reenvio por ADMIN e medição para decidir o aviso na próxima fase | `[09:37] Larissa`, `[09:34] Marcos` |
| **PRD-RISK-06** | Um cliente com endpoint lento atrasa as notificações de outros clientes | Média | Alto | Limite de 10s por chamada, envio de um cliente não bloqueia os demais e monitoramento do tempo de entrega (ver [FDD](./FDD.md)) | `[09:42] Diego` |
| **PRD-RISK-07** | Sem restrição por perfil nesta fase, um usuário autenticado pode configurar webhooks de qualquer cliente | Média | Médio | Aceito nesta fase, com endurecimento previsto para depois; ações registradas com o usuário responsável | `[09:37] Sofia` |

## 11. Critérios de aceitação

| ID | Critério (Dado / Quando / Então) | Origem |
| --- | --- | --- |
| **PRD-AC-01** | **Dado** um webhook ativo assinando `SHIPPED`, **quando** um pedido do cliente muda para `SHIPPED`, **então** o endpoint recebe uma notificação assinada em menos de 10 segundos | `[09:02] Marcos`, `[09:33] Marcos` |
| **PRD-AC-02** | **Dado** um webhook que não assina `PAID`, **quando** um pedido muda para `PAID`, **então** nenhuma notificação é enviada a ele | `[09:34] Bruno` |
| **PRD-AC-03** | **Dado** um endpoint fora do ar, **quando** ele volta dentro da janela de ~15h, **então** a notificação é entregue sem ação manual | `[09:16] Diego`, `[09:17] Diego` |
| **PRD-AC-04** | **Dado** que todas as tentativas falharam, **quando** um ADMIN solicita o reenvio, **então** a notificação é reenviada com o **mesmo** identificador do evento, e um usuário sem perfil ADMIN recebe recusa | `[09:36] Sofia`, `[09:25] Diego` |
| **PRD-AC-05** | **Dado** um cadastro com endereço `http://`, **então** ele é recusado com erro de validação | `[09:23] Sofia` |
| **PRD-AC-06** | **Dada** uma rotação de secret, **durante as 24h seguintes** notificações verificadas com a secret antiga **ou** com a nova são aceitas pelo cliente, e depois disso só com a nova | `[09:21] Sofia` |
| **PRD-AC-07** | **Dado** um webhook com entregas, **quando** o usuário consulta o histórico, **então** vê até as 100 mais recentes, com resultado, conteúdo, resposta e tempo | `[09:34] Marcos` |
| **PRD-AC-08** | **Dada** uma falha ao registrar a notificação, **então** a mudança de status do pedido também não acontece | `[09:40] Bruno` |
| **PRD-AC-09** | A secret aparece apenas no cadastro e na rotação, e nunca em listagens | `[09:22] Diego` |

## 12. Estratégia de testes e validação

| ID | Etapa | O que valida | Origem |
| --- | --- | --- | --- |
| **PRD-TEST-01** | Testes automatizados de unidade e integração, no mesmo padrão da suíte atual do projeto | Filtro por status, assinatura, agenda de tentativas, falha definitiva, reenvio, validação `https` e ocultação da secret (critérios técnicos no [FDD §12](./FDD.md)) | `[09:46] Larissa` |
| **PRD-TEST-02** | Teste ponta a ponta: mudança de status real → notificação recebida por um endpoint de teste | PRD-AC-01, PRD-AC-03 e PRD-AC-08 | `[09:46] Larissa` |
| **PRD-TEST-03** | Revisão de segurança dedicada, de pelo menos 2 dias úteis, antes do deploy | Assinatura, geração e armazenamento de secret, exposição em logs | `[09:46] Sofia` |
| **PRD-TEST-04** | Revisão do desenho por Bruno e Diego com a Larissa antes de começar a codar | Aderência ao desenho aprovado | `[09:50] Larissa` |
| **PRD-TEST-05** | Validação em produção: acompanhar tempo de entrega, falhas definitivas e volume por cliente | PRD-OBJ-01 e PRD-OBJ-04; insumo para decidir o aviso por e-mail e o rate limit (PRD-OOS-01, PRD-OOS-03) | `[09:37] Larissa`, `[09:39] Larissa` |
