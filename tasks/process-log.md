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

---

## CP-C: Revisão adversarial do FDD

**Prompt usado:** subagente com contexto limpo. Além de conferir âncoras e rótulos de proposta, recebeu uma instrução explícita para verificar **correção técnica contra o código real**: "Would the proposed integration actually work (Express routing/mount order/mergeParams, Prisma schema validity incl. relations and back-relations, MySQL column types/limits, class constructors, Zod usage, Node 20 APIs)? Any claim about existing code that is false?"

**Resultado:** 9 achados técnicos e 6 âncoras fracas. Cerca de 30 âncoras foram conferidas e a maioria estava exata. Os achados mais relevantes, todos corrigidos:

| # | Problema | Correção |
|---|---|---|
| 1 | **Linhas presas para sempre em `PROCESSING`:** a recuperação só rodava no boot. Uma exceção no meio do tick deixava as linhas reservadas órfãs, e o replay delas passaria a retornar 409 | Lease de 60s em **todo** tick + try/catch por evento |
| 2 | **Um `X-Request-Id` longo derrubaria a mudança de status:** o `requestLogger` aceita qualquer header, a coluna tinha `VarChar(64)`, e o erro Prisma `P2000` não é tratado pelo `error.middleware.ts`, o que gera 500 e rollback | Truncamento explícito de todo texto de origem externa (FDD-DADOS-08) |
| 3 | **Afirmação falsa sobre o código:** "server.ts faz bootstrap com `createPrismaClient()`". Na verdade, ele importa o singleton `prisma`. O erro vinha dos ADRs 002 e 006 | FDD, ADR-002 e ADR-006 corrigidos |
| 4 | O schema Zod não produzia as mensagens `WEBHOOK_*` prometidas na matriz e aceitava `events: []`, duplicatas e `PENDING` (que nenhuma transição emite) | Schema completo com mensagens customizadas, `.min(1)`, unicidade e exclusão de `PENDING` |
| 5 | Pseudocódigo `w.events.includes(to)` não compila: `Json` é `Prisma.JsonValue` | Parse via schema |
| 6 | `*.secret` no Pino não cobre chave no topo do objeto logado | Redact em dois níveis |
| 7 | Replay de evento **já entregue** era permitido, e o histórico repetiria "tentativa 1" | Replay só de `FAILED`; `attempt` cumulativo no histórico |
| 8 | Faltavam as respostas 400 para UUID inválido; o exemplo de timestamps contradizia o backoff de 1 min | Corrigidos |
| 9 | ADR-006 dizia "estende as subclasses", mas o FDD estende `AppError` nos 404 | ADR-006 ajustado, com o motivo (`NotFoundError` fixa `NOT_FOUND`) |
| 10 | Âncoras fracas: "secret só na criação" apontava `[09:22] Diego` (vazamento), quando a origem é `[09:31] Marcos`; criptografia em repouso atribuída à Sofia | Realinhadas; o item foi marcado *(análise)* |
| 11 | Números sem rótulo de proposta: 4 KB, `limit`, `202`, tamanhos de coluna | Rotulados |

**Lição de processo:** até aqui, a IA revisava contra a transcrição. Pedir explicitamente uma revisão "isso funcionaria contra o código real?" trouxe à tona bugs de desenho (1, 2, 5, 6) que nenhuma checagem de rastreabilidade pegaria.

**Verify:** 0 falhas. 280 linhas no Tracker, 87% TRANSCRICAO, 34 CODIGO.

---

## T10 + CP-D: Consolidação do Tracker e revisão cruzada do pacote

**T10:** o Tracker foi reordenado na ordem de leitura (PRD → RFC → ADRs → FDD) e ganhou um resumo com contagens e legenda dos marcadores *(análise)* e *Proposta de design*.

**CP-D, prompt usado:** subagente com contexto limpo, focado no que as revisões por documento não enxergam:
- contradições **entre** documentos (números, rotas, roles, escopo, semântica de replay, IDs RFC-OPEN/CONF citados após renumeração);
- violações de altitude;
- referências internas quebradas;
- o checklist de aceite do enunciado item por item.

**Resultado:** 8 achados (3 médios). Números, rotas, links relativos e IDs estavam consistentes entre todos os documentos. Os problemas encontrados:

| # | Problema | Correção |
|---|---|---|
| 1 | O FDD citava "§8.1/8.2/8.3" (seções de observabilidade que são a §9) e "6.1…6.8" sem headings numerados | Referências corrigidas e endpoints numerados. O regex do verify foi ajustado para os headings numerados |
| 2 | **O PRD prometia uma espera máxima de ~2s, mas o desenho do worker não cumpria:** o tick "sem sobreposição" esperava o grupo mais lento, então um cliente com timeout de 10s atrasava todos acima da meta | Worker redesenhado com **envios em voo e trava por pedido**: o tick não espera os envios em andamento. PRD, RFC e ADR-002 alinhados |
| 3 | **DELETE do webhook apagava a DLQ em cascata**, o que contradizia o ADR-003 ("toda falha permanente fica persistida") | `webhook_dead_letter` sem FK, preservada como evidência; replay de evento de webhook removido retorna 404 |
| 4 | O FDD manda falhas não retentáveis direto para a DLQ, mas RFC e ADR-003 diziam "só após esgotar as tentativas" | Uma linha em RFC-PROP-03 e no ADR-003, como proposta de design |
| 5 | O ADR-006 tratava `WEBHOOK_INVALID_URL` e `WEBHOOK_SECRET_REQUIRED` como códigos de resposta da API | Esclarecido: o primeiro é detalhe de `VALIDATION_ERROR` e o segundo é motivo interno do worker |
| 6–8 | ADRs citando "questões em aberto do RFC" sem o ID (e em outra subseção); lista de impacto do RFC incompleta; formato de header no ADR-004 (altitude de FDD); risco de acesso entre clientes ausente no PRD; âncora CODIGO errada em FDD-DEP-03 | IDs RFC-CONF-01/02 e RFC-OPEN-02 citados; lista completada; formato movido para o FDD; PRD-RISK-07 criado; âncora corrigida |

**Lição de processo:** revisar cada documento isoladamente não bastou. O achado 2 só aparece quando se lê a promessa do PRD ao lado do pseudocódigo do FDD.

**Verify:** 0 falhas. 281 linhas no Tracker, 87% TRANSCRICAO, 34 CODIGO, cobertura de 100%.

---

## T12: Revisão final contra o checklist do enunciado

Conferido item por item, com os comandos registrados no histórico da sessão:

- **PRD:** as 12 seções presentes ("Fora de escopo" em §5.2); 15 FRs; meta quantitativa (95% abaixo de 10s, 3 de 3 clientes, fim de novembro); 8 itens fora de escopo; 7 riscos com probabilidade, impacto e mitigação.
- **RFC:** 8 seções; 5 participantes como revisores; 5 alternativas com trade-off; 5 questões em aberto da reunião, mais 2 pontos para confirmação separados; links para os 7 ADRs; 1837 palavras.
- **FDD:** as 12 seções, incluindo "Integração com o sistema existente" com 19 caminhos reais; 7 endpoints com request, response e tabela de status, mais o contrato de saída; matriz `WEBHOOK_*` com 13 códigos; métricas (§9.1), logs (§9.2) e tracing (§9.3).
- **ADRs:** 7 arquivos no padrão, com as 5 seções; as 6 decisões principais cobertas; 5 ADRs citam arquivos reais do código.
- **Tracker:** formato exato; cobertura de 100%; 87% TRANSCRICAO com timestamp e falante validados contra a transcrição; 34 linhas CODIGO com caminho existente.
- **README:** 6 seções; ferramentas listadas; 4 prompts em bloco de código; 7 iterações concretas.
- **Consistência:** `bash tasks/verify-docs.sh` com 0 falhas e 0 avisos, incluindo "nenhum arquivo protegido alterado" contra `main` e "todos os caminhos existentes citados resolvem".

**Ciclos principais:** 5 ciclos de geração → revisão → correção (spec, ADRs, RFC, FDD, revisão cruzada) e a revisão final. Ao todo, as quatro revisões adversariais trouxeram 11 + 9 + 15 + 8 achados, todos tratados.
