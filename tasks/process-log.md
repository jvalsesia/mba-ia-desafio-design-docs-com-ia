# Diário do Processo

Registro cronológico de como o pacote foi produzido: prompts usados, o que a IA entregou, o que estava errado ou raso e como foi corrigido. É a fonte única das seções "Prompts customizados" e "Iterações e ajustes" do `README.md`. Nada entra no README que não esteja aqui.

**Ferramentas:**
- Claude Code (modelo Claude Opus 5.5) como agente principal no terminal, com leitura do repositório e escrita dos documentos.
- Plugin `agent-skills` (addyosmani/agent-skills), com as skills `spec-driven-development` e `planning-and-task-breakdown`.
- Subagentes do Claude Code para revisão adversarial com contexto limpo (a partir do CP-A).

---

## Ciclo 0: Especificação (2026-09-29)

**Prompt do usuário:**

```text
/agent-skills:spec @README.md
```

**O que a IA fez:**
- Leu o enunciado, a transcrição inteira e os pontos do código citados no enunciado (`changeStatus`, erros, `requireRole`, logger, schema).
- Levantou premissas e fez 3 perguntas de escopo: spec único ou por documento; como registrar o processo sem fabricar; quantos ADRs.
- Gerou o `SPEC.md` com a base de fatos ancorada em timestamps, a lista de ADRs, 12 comandos de verificação e os limites.

**Achados relevantes nesta etapa** (a IA confrontou transcrição e código, em vez de só resumir a transcrição):
- **Ambiguidade na contagem de retentativas:** o resumo diz "total 5 tentativas" `[09:48] Larissa`, mas a progressão 1m/5m/30m/2h/12h soma "quase 15 horas" `[09:17] Diego`, o que só fecha com 1 envio + 5 retentativas. Registrado como questão em aberto, com default.
- **Transcrição × código, estoque:** `[09:04] Bruno` diz que toda mudança de status "decrementa stock_quantity". Em `src/modules/orders/order.status.ts`, o débito só ocorre em PENDING→PAID.
- **Transcrição × código, vínculo usuário–cliente:** "usuários que representam o cliente" `[09:32] Marcos` não têm vínculo modelado. `User` não se relaciona com `Customer` em `prisma/schema.prisma`.
- **Critério "nenhum arquivo inexistente citado" × arquivos novos propostos** (`src/worker.ts`, `src/modules/webhooks/`): resolvido com o marcador `(novo)` e uma allowlist na verificação.

**Decisões do usuário:** spec único; log em `tasks/`; 6 ADRs principais + 1 (snapshot do payload); aprovou o spec e os defaults das 4 questões em aberto (`aprovo`).

**Correções nesta etapa:** nenhuma ainda. Os comandos de verificação foram testados contra um Tracker de exemplo antes da aprovação (timestamps, proporções, caminhos e regex de IDs).

---

## Ciclo 0b: Plano

**Prompt do usuário:** `aprovo` (aprovação do SPEC → fase de plano).

**O que a IA fez:** gerou `tasks/plan.md` e `tasks/todo.md` com 12 tarefas e 4 checkpoints. O Tracker passa a ser alimentado incrementalmente e o FDD foi dividido em 3 fatias.

---

## T1: Script de verificação

**Prompt do usuário:** aprovação do plano (plan mode → `ExitPlanMode` aprovado).

**O que a IA fez:**
- Transformou os 12 comandos da §3 do SPEC em `tasks/verify-docs.sh`.
- Criou o cabeçalho do `docs/TRACKER.md` e reescreveu `docs/adrs/README.md`, que sugeria o padrão `0001-titulo.md`, incompatível com o `ADR-NNN-*` exigido.

**Ajuste durante a tarefa:** na primeira versão, o script travaria na seção 12 quando ainda não houvesse documentos. O `grep` recebia uma lista de arquivos vazia e ficava lendo stdin. Foi corrigido com uma guarda antes da execução.

**Teste negativo:** foi montada uma cópia temporária com:
- um ADR mal nomeado e sem seções;
- um Tracker com `[09:16] Sofia` (Sofia não fala às 09:16);
- um caminho CODIGO inexistente;
- um ID duplicado.

O script falhou em todos os casos (10 falhas, exit 1). No repositório real: 0 falhas, 4 avisos (documentos ainda não escritos).

---

## Ciclo 1: ADRs (T2, T3, T4)

**Instrução de trabalho** (derivada do SPEC §2 e §5; a IA escreveu os ADRs a partir da base de fatos da §8, e não de um resumo livre da transcrição):

```text
Escreva os ADR-001 a ADR-007 no template MADR do SPEC §5 (Status, Contexto, Decisão,
Alternativas Consideradas, Consequências com Positivas/Negativas/Trade-off, Referências).
Regras:
- toda afirmação cita [hh:mm] Nome da transcrição ou um caminho real do código;
- cada alternativa precisa ter sido discutida na reunião (ou ser plausível e marcada como tal),
  com o trade-off que levou ao descarte;
- itens da tabela §8.4 do SPEC (e-mail, rate limit, dashboard, arquivamento, multi-worker)
  só podem aparecer como adiados/fora de escopo, nunca como decisão;
- arquivos novos propostos levam o marcador "(novo)";
- IDs inline em negrito: ADR-NNN, ADR-NNN-ALT-NN, ADR-NNN-CONS-NN, cada um com linha no Tracker.
```

**Correção antes de escrever, em um default aprovado:** ao redigir o ADR-004, a IA percebeu que o default aprovado para a questão 3 do SPEC ("assinar só com a secret nova durante as 24h de rotação") anulava o próprio grace period. Um cliente que ainda verifica com a secret antiga rejeitaria todas as entregas. A IA voltou ao usuário, que escolheu **duas assinaturas no `X-Signature` durante as 24h**. SPEC §10 e plano atualizados.

**Ajuste na verificação:** o script só conferia os timestamps do Tracker. Foi estendido para conferir também toda âncora `[hh:mm] Nome` citada no corpo dos documentos, porque uma âncora inventada no ADR passaria despercebida se o Tracker estivesse correto.

**Resultado do verify:** 0 falhas. 58 linhas no Tracker, 91% TRANSCRICAO, 5 CODIGO, cobertura de 100%. As menções da seção 12 (Redis, arquivamento, multi-worker, e-mail, exactly-once) aparecem só como alternativa descartada, limitação ou fora de escopo.

---

## CP-A: Revisão adversarial dos ADRs

**Prompt usado** (subagente `general-purpose` com contexto limpo, somente leitura):

```text
You are an adversarial reviewer. READ-ONLY. [...] The hard rule: every requirement, decision,
constraint or number in the docs must be traceable to the transcript (the cited `[hh:mm] Nome`
must actually say it) or to real code. [...]
Hunt for, and report ONLY concrete, verified problems:
(a) claims with no anchor [...]; (b) anchors where that speaker at that minute did NOT say what
the ADR attributes to them [...]; (c) postponed/discarded items presented as decisions [...];
(d) statements contradicting the code [...]; (e) decisions misrepresented, overstated or missing
[...]; (f) sections, trade-off, and alternatives presented as "discussed" that were not.
Output: numbered findings with file+line, severity, exact text, evidence, concrete fix.
```

**Resultado:** 11 achados, nenhum de alucinação grave. Nenhum falante estava errado nas falas citadas e nenhum item adiado foi promovido a decisão. Os problemas reais foram estes:

| # | O que a IA tinha escrito | Correção aplicada |
|---|---|---|
| 1 | ADR-005-ALT-02, "at-most-once", apresentado como alternativa descartada na reunião, com a âncora `[09:16] Diego` | Ninguém propôs isso na reunião. **Alternativa removida** do ADR e do Tracker |
| 2 | ADR-002 afirmava que o cliente recebe eventos do mesmo pedido em ordem | O retry com backoff de 1 min pode inverter a ordem. Novo **ADR-002-CONS-07** *(análise)*, que vira questão em aberto no RFC |
| 3 | "Latência mínima de ~2s … com folga" | A fala é "2 segundos **no pior caso**" `[09:10] Larissa`. Texto corrigido e novo **ADR-002-CONS-08**: com worker único e timeout de 10s, um cliente lento atrasa os outros |
| 4 | ADR-006 omitia a decisão "customer_id no body ou path, não do JWT" `[09:32] Larissa` | Decisão adicionada. A consequência "qualquer autenticado gerencia webhooks de qualquer customer" ficou explícita |
| 5 | ADR-004 dizia "o formato exato do que é assinado fica no FDD", reabrindo algo já decidido | Corrigido para "HMAC só do corpo" `[09:22] Sofia`. Novo **ADR-004-CONS-06** *(análise)*: o `X-Timestamp` fica fora da assinatura |
| 6 | Afirmações sem âncora ("clientes lentos não consomem recursos da API"; "sem outbox a fila perderia a atomicidade") | A primeira foi removida; a segunda foi marcada *(análise)*. Criado o marcador *(análise)* no `docs/adrs/README.md` |
| 7 | ADR-006 dizia que `auth` tem repository e listava o `redact` incompleto | Corrigido a partir do código real (`redactPaths` completos) |
| 8–11 | Âncoras do Tracker desalinhadas do texto (ADR-002-CONS-03, ADR-007-CONS-01/02, ADR-005-CONS-01); 64KB sem "erro caso ultrapasse"; ADR-004-ALT-02 apresentada como debatida | Âncoras realinhadas; "rejeitado com erro, sem truncar"; ALT-02 rotulada "alternativa implícita" |

**Lição de processo:** a verificação automática confirmava que cada timestamp **existe**, mas não que a fala **diz** o que o documento atribui a ela. Três dos achados (at-most-once, ordenação, latência) eram exatamente isso. A revisão semântica continua obrigatória em todos os checkpoints.

**Verify após as correções:** 0 falhas. 60 linhas no Tracker, 91% TRANSCRICAO, cobertura de 100%.
