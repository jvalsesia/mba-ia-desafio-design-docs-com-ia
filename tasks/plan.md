# Plano de Execução: Pacote de Design Docs — Webhooks de Pedidos

> Fonte da verdade: [`SPEC.md`](../SPEC.md) (aprovado em 2026-09-29). Tarefas detalhadas em [`todo.md`](./todo.md).

## Visão geral

Produzir 7 ADRs, RFC, FDD, PRD, Tracker e README do processo, nessa ordem, a partir da base de fatos da §8 do SPEC. Cada tarefa entrega documentos **completos e verificados**, junto com as linhas correspondentes no Tracker. O pacote nunca fica em estado "documento pronto sem rastreabilidade".

## Decisões de execução

- **Tracker incremental:** cada tarefa de documento acrescenta suas próprias linhas ao `docs/TRACKER.md`. A tarefa de Tracker só consolida (cobertura, proporções, duplicatas). Motivo: rastrear no momento da escrita evita reconstruir a origem depois, que é justamente quando a alucinação escapa.
- **Verificação antes da escrita:** o `tasks/verify-docs.sh` é a primeira tarefa. Todo documento posterior nasce sendo checado.
- **FDD em 3 fatias:** é o documento maior e de maior risco (caminhos reais, contratos, erros). Cada fatia fecha seções inteiras e passa na verificação.
- **Revisão adversarial por checkpoint:** um subagente sem o contexto da conversa confronta os documentos com `TRANSCRICAO.md` e o código. Os achados e as correções vão para `tasks/process-log.md`, que é a matéria-prima honesta da seção "Iterações e ajustes" do README.
- **Defaults da §10 do SPEC aplicados:**
  - retentativas: 1 envio + 5 retentativas;
  - rotas: `/customers/:customerId/webhooks` para criar e listar, `/webhooks/:id` para o resto;
  - rotação: duas assinaturas durante o grace de 24h (revisto; ver SPEC §10);
  - tracing: correlação de IDs.
- **Commits:** um por tarefa, no branch atual, só local. Push e PR exigem pedir antes.

## Grafo de dependências

```
T1 verify-docs.sh + adrs/README
 ├─ T2 ADR-001/002 ─┐
 ├─ T3 ADR-003/004 ─┼─ CP-A (ADRs) ── T5 RFC ── CP-B ── T6 FDD-1 ── T7 FDD-2 ── T8 FDD-3 ── CP-C
 └─ T4 ADR-005/006/007 ┘                                                                    │
                                                          T9 PRD ── T10 Tracker ── CP-D ── T11 README ── T12 Revisão final
```

T2, T3 e T4 são independentes entre si. As demais tarefas são sequenciais: cada documento cita os anteriores.

## Lista de tarefas (índice)

### Fase 1: Fundação
- [x] T1: Script de verificação e padronização de `docs/adrs/README.md`

### Fase 2: Decisões (ADRs)
- [x] T2: ADR-001 (outbox) e ADR-002 (worker em polling)
- [x] T3: ADR-003 (retry/DLQ) e ADR-004 (HMAC)
- [x] T4: ADR-005 (at-least-once), ADR-006 (reuso de padrões) e ADR-007 (snapshot)
- [x] **CP-A:** checkpoint dos ADRs

### Fase 3: Proposta
- [x] T5: RFC
- [x] **CP-B:** checkpoint do RFC

### Fase 4: Implementação (FDD)
- [x] T6: FDD fatia 1: contexto, objetivos, escopo, fluxos, integração com o sistema existente
- [x] T7: FDD fatia 2: contratos públicos e matriz de erros
- [x] T8: FDD fatia 3: resiliência, observabilidade, dependências, critérios de aceite, riscos
- [x] **CP-C:** checkpoint do FDD

### Fase 5: Produto e rastreabilidade
- [x] T9: PRD
- [x] T10: Consolidação do Tracker
- [x] **CP-D:** checkpoint do pacote técnico

### Fase 6: Processo e fechamento
- [x] T11: README do processo
- [ ] T12: Revisão final contra o checklist do enunciado

## Riscos e mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Âncora `[hh:mm] Nome` que existe mas não sustenta a afirmação | Alto | O comando 5 só pega timestamp inexistente, então a revisão adversarial confere o conteúdo da fala em cada checkpoint |
| Proporção de TRANSCRICAO cair abaixo de 70% por excesso de linhas CODIGO no FDD | Médio | Medir com o comando 6 a cada tarefa. Manter ~8–12 linhas CODIGO (mínimo 5) e registrar cada integração pela âncora da transcrição quando ela existir (ex.: `changeStatus` → `[09:40] Bruno`) |
| RFC passar de 4 páginas ou repetir o FDD | Médio | Limite de ~2000 palavras (comando 10). RFC escrito antes do FDD, sem JSON nem matriz de erros |
| Item descartado ou adiado virar requisito (e-mail, rate limit, dashboard…) | Alto | Comando 12 + tabela §8.4 do SPEC como lista negra na revisão |
| Caminho proposto (novo) ser lido como "arquivo inexistente citado" | Médio | Marcador `(novo)` + allowlist no comando 4 + nota explícita na seção de integração do FDD |
| README com prompts ou iterações fabricados | Alto | O README é escrito exclusivamente a partir de `tasks/process-log.md`, alimentado durante o trabalho |
| Divergência transcrição × código (estoque, User×Customer) contradizer um dos lados | Médio | Seguir a §8.6 do SPEC: descrever o comportamento real do código e citar a fala como contexto |

## Questões em aberto

Nenhuma bloqueante. As quatro da §10 do SPEC seguem os defaults aprovados e aparecem como questões em aberto no RFC quando forem pontos da reunião (retentativas, `customer_id`).
