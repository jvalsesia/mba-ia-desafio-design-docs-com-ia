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

---

## Ciclo 2: RFC (T5)

**Instrução de trabalho:**

```text
Escreva docs/RFC.md em nível de ARQUITETURA (2 a 4 páginas, ~900–2000 palavras): metadados
(autor, status, data, os 5 participantes como revisores), TL;DR, contexto e problema, proposta
técnica (componentes e fluxo macro, SEM JSON, DDL ou matriz de erros; isso é do FDD),
alternativas descartadas na reunião com o trade-off de cada uma, questões em aberto que foram
LEVANTADAS na reunião e não decididas/adiadas, impacto e riscos, e links para os 7 ADRs.
Inclua como questões em aberto os achados do CP-A (ordenação sob retry, contagem de tentativas).
```

**Ajuste durante a escrita:**
- A mitigação do RFC-RISK-01 ("envio concorrente entre pedidos distintos do lote") não tem origem na reunião. Foi rotulada como *Proposta de design*.
- A rota de mudança de status citada no diagrama (`PATCH /orders/:id/status`) foi conferida em `src/modules/orders/order.routes.ts` antes de entrar no texto.

**Resultado do verify:** 0 falhas. O RFC tem 1692 palavras e linka os 7 ADRs. 81 linhas no Tracker, 93% TRANSCRICAO.

---

## CP-B: Revisão adversarial do RFC

**Prompt usado:** subagente com contexto limpo, focado no papel do RFC: altitude de arquitetura; alternativas **realmente discutidas e descartadas**; questões em aberto **realmente levantadas e não decididas**; cada âncora conferida na linha exata.

**Resultado:** 9 achados, 2 de severidade alta. Os mais instrutivos:

| # | O que a IA tinha escrito | Por que estava errado | Correção |
|---|---|---|---|
| 1 | RFC-RISK-04: "aceito nesta fase, com auditoria via logs (`[09:37] Sofia`)" | Sofia só disse "Por enquanto sim. Mais pra frente a gente pode endurecer". A auditoria em log foi pedida para o **replay** da DLQ (`[09:36] Sofia`), não para o CRUD. A IA "emprestou" uma fala vizinha | Auditoria removida; risco marcado *(análise)* |
| 2 | "Contagem de tentativas" listada como **questão em aberto da reunião** | A reunião decidiu "5 tentativas" sem nenhuma dúvida. A ambiguidade é uma análise do autor | Criada a subseção "Pontos para confirmação *(análise do autor)*", com RFC-CONF-01 e RFC-CONF-02; as questões em aberto passam a ter só o que a reunião deixou aberto (5 itens) |
| 3 | A questão de ordenação misturava a fala do Diego (`[09:13]`, escala) com a análise de ordenação sob retry | Uma única âncora cobria duas origens diferentes | Separadas: RFC-OPEN-03 (escala, reunião) e RFC-CONF-02 (retry, análise) |
| 4 | "Resposta de erro conta como falha"; "2xx → entregue" | A reunião só falou do timeout de 10s | Marcado como *Proposta de design* |
| 5 | Impacto "em quatro pontos" do código | Faltavam `src/app.ts` (`buildControllers`) e o logger (`redactPaths`), que o próprio ADR-006 exige | A lista passa a ter 6 pontos |
| 6–9 | Citações apontando para a fala errada (secret "gerada pela plataforma" atribuída a `[09:22] Sofia`, quando é de `[09:31] Marcos`); seta do replay invertida no diagrama | — | Citações corrigidas; diagrama refeito com a tabela `webhook_dead_letter` |

**Padrão identificado:** a IA tende a juntar em uma única citação afirmações de falas próximas ("colar" a âncora do bloco de conversa). A partir daqui, as linhas do Tracker que cobrem mais de uma afirmação citam as âncoras secundárias no resumo.

**Verify:** 0 falhas; RFC com 1837 palavras; 82 linhas no Tracker, 93% TRANSCRICAO.

---

## Ciclo 3: FDD (T6, T7, T8)

**Instrução de trabalho:**

```text
Escreva docs/FDD.md, o documento de IMPLEMENTAÇÃO, acionável para um dev começar a codar.
Seções obrigatórias do enunciado + "Integração com o sistema existente" com >= 4 caminhos REAIS
(conferir cada um no repositório antes de citar). Antes de escrever, leia no código: src/app.ts
(prefixo /api/v1), order.controller.ts, order.routes.ts, validate.middleware.ts, env.ts,
server.ts, schema.prisma completo e o formato do orderNumber. Contratos com request, response
e status para os 7 endpoints + o contrato de saída (payload snake_case de [09:43] Diego). Matriz
de erros WEBHOOK_* mapeada para as classes que EXISTEM em http-errors.ts. Toda escolha não
fechada na reunião leva "Proposta de design" e a âncora da decisão que a motivou.
Não re-argumente decisões: linke o ADR.
```

**Achados da própria IA ao ler o código, antes de escrever** (viraram decisões explícitas no FDD):
- `NotFoundError` fixa o código em `NOT_FOUND` (o construtor só recebe `resource`). Um `WEBHOOK_NOT_FOUND` precisa estender `AppError` diretamente. Sem essa leitura, o FDD mandaria "reusar `NotFoundError`", o que não compila com o código desejado.
- `validate()` converte todo `ZodError` em `VALIDATION_ERROR`. Como a Sofia decidiu que a checagem `https` é "só uma validação no schema Zod" (`[09:23] Sofia`), o código `WEBHOOK_INVALID_URL` citado por Bruno aparece como `details[].message`, e não como `error.code`. Essa tensão entre duas falas foi resolvida explicitamente.
- O MySQL `TEXT` guarda no máximo 65.535 bytes. Com o payload em `TEXT`, um evento acima de 64KB faria a inserção falhar **dentro** da transação e bloquearia a mudança de status. Decisão: `MEDIUMTEXT` e checagem de tamanho no worker.

**Bug no próprio desenho, pego durante a revisão do texto:** a primeira versão montava o router de webhooks na raiz (`router.use(buildWebhookRouter())`). Como os routers do projeto fazem `router.use(authenticate)` internamente, isso exigiria JWT em **todas** as rotas, inclusive `/auth/login`. Corrigido para três routers montados com prefixo, com `mergeParams` na rota aninhada em customers.

**Ajuste de rastreabilidade:** os sub-itens `FDD-FLUXO-02a…g` não seriam capturados pela checagem de cobertura (o regex exige limite de palavra após o número). Foram renomeados para `FDD-WORKER-01…07`.

**Resultado do verify:** 0 falhas, 0 avisos. FDD com 7 endpoints e 13 códigos `WEBHOOK_*`. Tracker com 195 linhas: 83% TRANSCRICAO, 33 CODIGO, cobertura de 100%.

---

## Ciclo 4: PRD (T9)

Escrito em paralelo com a revisão adversarial do FDD, porque não depende do conteúdo técnico em revisão.

**Instrução de trabalho:**

```text
Escreva docs/PRD.md em LINGUAGEM DE PRODUTO, com as 12 seções do enunciado. Sem nomes de
tabelas, arquivos ou classes: isso é do FDD. >= 8 requisitos funcionais só da §8.2 do SPEC;
objetivos com meta numérica ancorada (não invente baseline nem porcentagens que ninguém disse);
"Fora de escopo" a partir da §8.4 do SPEC; riscos em tabela com probabilidade, impacto e
mitigação; decisões como trade-offs vistos pelo cliente, linkando os ADRs.
```

**Cuidado aplicado:** a meta "95% abaixo de 10s" (PRD-OBJ-01) traduz o limite de 10s de `[09:02] Marcos` em um percentil mensurável. O número 95% é a forma de medir, não um requisito novo, e o FDD usa o mesmo p95 (FDD-OBJ-01). Nenhum baseline de latência foi inventado, porque hoje não há notificação.

**Resultado do verify:** 0 falhas. O PRD tem 15 requisitos funcionais, 11 não funcionais e 8 itens fora de escopo. Tracker com 279 linhas: 88% TRANSCRICAO, 33 CODIGO, cobertura de 100%.
