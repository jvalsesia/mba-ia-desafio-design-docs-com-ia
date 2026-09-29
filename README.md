# Da Reunião ao Documento: Design Docs Gerados por IA

> Entrega do desafio de design docs do MBA. O enunciado original está no [repositório base](https://github.com/devfullcycle/mba-ia-desafio-design-docs-com-ia). Este README documenta **como** o pacote foi produzido. Os artefatos de bastidores (`SPEC.md` e a pasta `tasks/`, com plano, diário do processo e script de verificação) ficam no [branch de trabalho](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/tree/jvalsesia/mba-ia-desafio-design-docs-com-ia), para manter o `main` só com a entrega.

## Sobre o desafio

Uma empresa que opera um Order Management System (Node.js + TypeScript + Prisma/MySQL) decidiu, em uma reunião de ~55 minutos, construir um **Sistema de Webhooks de Notificação de Pedidos**: avisar clientes B2B, em menos de 10 segundos, quando o status dos pedidos deles muda. Nada foi registrado além da transcrição da call ([`TRANSCRICAO.md`](./TRANSCRICAO.md)). A tarefa foi transformar essa conversa, junto com o código existente, em um pacote de design docs (PRD, RFC, FDD, ADRs e Tracker) acionável o bastante para o time começar a implementar, sem alterar uma linha do código da aplicação.

A regra que guiou todo o trabalho foi a **rastreabilidade**. Cada requisito, decisão, número ou restrição precisa apontar para uma fala `[hh:mm] Nome` ou para um arquivo real do repositório. Na prática, o desafio foi menos "gerar texto com IA" e mais montar um processo em que a IA produz, **outra instância da IA sem contexto tenta derrubar o que foi produzido**, e um script verifica mecanicamente o que é verificável.

## Ferramentas de IA utilizadas

| Ferramenta | Papel |
| --- | --- |
| **Claude Code** (CLI, modelo Claude Opus 5.5) | Agente principal. Leu o repositório e a transcrição, fez as perguntas de escopo, escreveu todos os documentos, o script de verificação e o diário do processo, e fez os commits |
| **Plugin [`agent-skills`](https://github.com/addyosmani/agent-skills)** (addyosmani), skills `spec-driven-development` (comando `/agent-skills:spec`) e `planning-and-task-breakdown` | Deu a estrutura do processo: spec com premissas explícitas e aprovação antes de produzir, depois o plano quebrado em tarefas com critério de aceite e checkpoints |
| **Plan mode do Claude Code** | Aprovação formal do plano antes da execução |
| **Subagentes do Claude Code** (tipo `general-purpose`, somente leitura) | **Revisores adversariais com contexto limpo** em cada checkpoint. Receberam só os arquivos e a missão de achar âncoras que não sustentam a afirmação, invenções, contradições com o código e itens descartados promovidos a requisito |
| [`tasks/verify-docs.sh`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/tasks/verify-docs.sh) (script gerado pela IA, no branch de trabalho) | Não é IA, mas foi a rede de segurança contra alucinação. Confere se todo `[hh:mm] Nome` citado existe na transcrição **com aquele falante**, se todo caminho citado existe, a cobertura do Tracker, a proporção de fontes, os links do RFC, os endpoints e códigos `WEBHOOK_*` do FDD e se `src/`, `prisma/` e `tests/` ficaram intocados |

## Workflow adotado

```
/agent-skills:spec ─▶ SPEC.md (base de fatos ancorada + critérios) ─▶ aprovação
      │
      ▼
plano (tasks/plan.md, tasks/todo.md) ─▶ aprovação em plan mode
      │
      ▼
T1 verify-docs.sh ─▶ ADRs ─▶ CP-A ─▶ RFC ─▶ CP-B ─▶ FDD ─▶ CP-C ─▶ PRD ─▶ Tracker ─▶ CP-D ─▶ README ─▶ revisão final
                      │        │                        (cada CP = revisão adversarial por subagente + correções + verify)
                      └── cada documento nasce com suas linhas no Tracker e passa no verify antes do commit
```

1. **Spec antes de qualquer documento.** Em vez de pedir "gere um PRD", o primeiro passo foi o [`SPEC.md`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/SPEC.md). A IA leu a transcrição inteira e os pontos do código, listou premissas e fez 3 perguntas de escopo (spec único ou por documento? como registrar o processo sem fabricar? quantos ADRs?). Depois montou uma **base de fatos** (§8 do SPEC) com:
   - requisitos funcionais e não funcionais com timestamp;
   - uma tabela explícita do que foi descartado ou adiado;
   - 13 pontos de integração no código (16 arquivos reais) e como cada um se liga à feature;
   - as divergências entre transcrição e código.

   Todos os documentos foram escritos **a partir dessa base**, e não de uma nova leitura livre da transcrição.
2. **Ordem de produção** conforme o enunciado: ADRs → RFC → FDD → PRD → Tracker → README. As decisões formam o esqueleto, e o PRD, por ser o mais alto nível, virou consolidação.
3. **Tracker incremental.** Cada documento nasceu com IDs em negrito (`PRD-FR-01`, `RFC-ALT-02`, `FDD-INT-05`, `ADR-003-CONS-04`…) e com as linhas correspondentes no Tracker. A origem foi registrada no momento em que cada item foi escrito.
4. **Checkpoint adversarial após cada documento** (CP-A a CP-D). Um subagente sem o histórico da conversa recebia os arquivos e uma lista de verificação específica daquele documento. Os achados eram corrigidos e registrados.
5. **Diário do processo.** Tudo o que está nas seções abaixo vem de [`tasks/process-log.md`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/tasks/process-log.md) (no branch de trabalho), escrito durante o trabalho, e não reconstruído no fim.

**Divisão de papéis.** A IA produziu e revisou. As decisões ficaram comigo:
- as três escolhas de escopo do spec (spec único, diário do processo versionado, 6 ADRs principais + 1);
- a aprovação do spec e do plano;
- a mudança na assinatura durante a rotação de secret (item 1 de "Iterações e ajustes");
- a autorização de push, PR e merge.

## Prompts customizados

O prompt 1 é o que digitei. Os prompts 2 a 4 foram redigidos pelo agente principal a partir das regras do SPEC que aprovei, e usados por ele mesmo (2) e pelos subagentes revisores (3 e 4). Estão aqui porque são eles que definem a qualidade do resultado.

**1. Início do processo** (comando do plugin, com o enunciado como argumento). A skill `spec-driven-development` transforma esse comando em entrevista → premissas → spec com aprovação.

```text
/agent-skills:spec @README.md
```

**2. Instrução para os ADRs**, derivada do SPEC. A restrição mais importante está no terceiro item: o que foi descartado na reunião só pode aparecer como descartado.

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

**3. Revisor adversarial** (usado nos checkpoints e adaptado para cada documento; este é o do CP-A). O ponto-chave é a regra (b): não basta o timestamp existir, a fala precisa **dizer** aquilo.

```text
You are an adversarial reviewer. READ-ONLY. [...] The hard rule: every requirement, decision,
constraint or number in the docs must be traceable to the transcript (the cited `[hh:mm] Nome`
must actually say it) or to real code. Nothing may be invented.
Hunt for, and report ONLY concrete, verified problems:
(a) claims with no anchor, or numbers/facts that appear nowhere in transcript or code;
(b) anchors where that speaker at that minute did NOT say what the ADR attributes to them
    (the same minute can have several speakers);
(c) postponed/discarded items presented as decisions (email alerts, outbound rate limiting,
    dashboard, archiving, multiple workers, exactly-once, inbound webhooks, CRUD role hardening);
(d) statements contradicting the code; (e) decisions misrepresented, overstated or missing;
(f) alternatives presented as "discussed" that were not.
Output: numbered findings with file+line, severity, exact text, evidence, concrete fix.
```

**4. Revisão técnica do FDD contra o código real** (acréscimo feito no CP-C, depois de perceber que as revisões anteriores só olhavam a transcrição):

```text
(a) Technical correctness against the ACTUAL code: read src/app.ts, src/routes/index.ts,
src/modules/orders/*.ts, src/middlewares/*.ts, src/shared/errors/*.ts, src/shared/logger/index.ts,
src/config/*.ts, src/server.ts, prisma/schema.prisma, package.json, tests/setup.ts. Would the
proposed integration actually work (Express routing/mount order/mergeParams, Prisma schema
validity incl. relations and back-relations, MySQL column types/limits, class constructors,
Zod usage, Node 20 APIs)? Any claim about existing code that is false?
```

## Iterações e ajustes

Houve **5 ciclos principais** de geração → revisão → correção (spec, ADRs, RFC, FDD e revisão cruzada do pacote), além da revisão final. As quatro revisões adversariais trouxeram **43 achados** (11 + 9 + 15 + 8), todos tratados. Os principais momentos em que a IA errou ou ficou rasa:

1. **Default aprovado que anulava a própria regra** (antes do ADR-004). Um dos defaults aprovados no SPEC era "durante as 24h de rotação, assinar só com a secret nova". Ao redigir o ADR, a IA percebeu que isso tornava o grace period inútil: um cliente que ainda verifica com a antiga rejeitaria todas as entregas. A IA parou e me devolveu a decisão, e escolhi **duas assinaturas no `X-Signature` durante as 24h**.

2. **Alternativa "discutida" que ninguém discutiu** (CP-A). O ADR-005 listava "at-most-once" como alternativa descartada na reunião, com âncora `[09:16] Diego`. Nessa fala, o Diego está argumentando contra 3 tentativas. A alternativa foi removida. No mesmo checkpoint:
   - O ADR-002 afirmava que o cliente recebe os eventos de um pedido em ordem. O revisor mostrou que um evento em backoff pode ser ultrapassado pelo seguinte do mesmo pedido. Isso virou uma limitação documentada e um ponto para confirmação no RFC.
   - "Latência mínima de 2s" era, na fala original, "2 segundos **no pior caso**".

3. **Âncora "emprestada" de uma fala vizinha** (CP-B). O RFC dizia que o risco de um usuário configurar webhook de outro cliente seria "aceito com auditoria via logs (`[09:37] Sofia`)". A Sofia só disse "por enquanto sim, mais pra frente a gente pode endurecer". A auditoria em log tinha sido pedida um minuto antes, para o **replay** da DLQ. Esse padrão de colar a âncora do trecho próximo apareceu mais de uma vez. Por isso, a partir dali, toda linha do Tracker com mais de uma afirmação passou a citar também as âncoras secundárias. No mesmo ciclo, a "contagem de tentativas" deixou de ser listada como questão em aberto **da reunião** (ninguém a questionou) e foi para uma subseção separada de pontos da análise do autor.

4. **Ambiguidade real na transcrição.** A reunião decidiu "5 tentativas", mas a agenda 1m/5m/30m/2h/12h tem **5 intervalos**, e só com 1 envio + 5 retentativas a soma dá as "quase 15 horas" que o Diego citou. A IA achou isso na fase de spec. A ambiguidade ficou registrada no ADR-003, com a interpretação adotada e um pedido de confirmação no RFC. Ela não foi resolvida em silêncio.

5. **Desenho que não funcionaria no código real** (durante a escrita do FDD e no CP-C). As revisões anteriores olhavam só a transcrição. Pedir explicitamente "isso funcionaria contra o código?" trouxe à tona:
   - um router montado na raiz com `authenticate` exigiria JWT até em `/auth/login` (pego pela própria IA ao revisar o texto);
   - linhas que podiam ficar presas para sempre em `PROCESSING`;
   - um `X-Request-Id` com mais de 64 caracteres derrubaria a mudança de status com um erro Prisma `P2000` que o error middleware não trata;
   - a afirmação falsa de que o `server.ts` chama `createPrismaClient()`. Ele importa um singleton, e o erro tinha se propagado para dois ADRs;
   - um payload em `TEXT` do MySQL (máx. 65.535 bytes) faria um evento acima de 64KB **desfazer a mudança de status**, em vez de ir para a DLQ.

6. **Promessa do PRD que o desenho do FDD não cumpria** (CP-D, revisão cruzada). O PRD prometia uma espera de ~2s, mas o worker do FDD esperava o envio mais lento de cada ciclo, então um único cliente com timeout de 10s atrasaria todos os outros acima da meta. Isso só aparece lendo os dois documentos lado a lado. O worker foi redesenhado com envios em voo e trava por pedido. No mesmo ciclo, o revisor notou que excluir um webhook apagava a DLQ em cascata, o que contradizia o ADR-003. A DLQ passou a ser preservada sem FK.

7. **Limites da verificação automática.** O script confirmava que cada timestamp **existe**, mas não que a fala **diz** aquilo. Foi estendido para conferir também as âncoras no corpo dos documentos, e não só no Tracker. Mesmo assim, os erros mais relevantes dos itens 2 e 3 só apareceram na revisão semântica. As duas camadas se mostraram necessárias.

8. **A própria rede de segurança tinha um furo** (revisão do README, depois do merge). O script conferia se `src/`, `prisma/` e `tests/` estavam intocados comparando com o `main`. Depois do merge da entrega, o `main` passou a conter o trabalho, e a checagem ficou tautológica: passaria mesmo com o código alterado. A base foi fixada no último commit do repositório base (`e7f6311`), e um teste com alteração proposital em `src/server.ts` confirmou que a checagem volta a falhar.

## Como navegar a entrega

| Ordem | Arquivo | O que é |
| --- | --- | --- |
| 1 | [`docs/PRD.md`](./docs/PRD.md) | Por que e o quê: problema, clientes, métricas, escopo e o que ficou de fora |
| 2 | [`docs/RFC.md`](./docs/RFC.md) | A proposta técnica em nível de arquitetura, alternativas descartadas, questões em aberto e pontos para confirmação |
| 3 | [`docs/adrs/`](./docs/adrs/README.md) | ADR-001 a ADR-007: uma decisão por arquivo (outbox, worker, retry/DLQ, HMAC, at-least-once, reuso de padrões, snapshot do payload) |
| 4 | [`docs/FDD.md`](./docs/FDD.md) | Como construir: modelo de dados, fluxos, 7 endpoints com exemplos, matriz `WEBHOOK_*`, resiliência, observabilidade e **integração com o sistema existente** |
| 5 | [`docs/TRACKER.md`](./docs/TRACKER.md) | A origem de cada item (transcrição ou código) |
| Bastidores ([branch de trabalho](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/tree/jvalsesia/mba-ia-desafio-design-docs-com-ia)) | [`SPEC.md`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/SPEC.md), [`tasks/plan.md`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/tasks/plan.md), [`tasks/todo.md`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/tasks/todo.md), [`tasks/process-log.md`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/tasks/process-log.md), [`tasks/verify-docs.sh`](https://github.com/jvalsesia/mba-ia-desafio-design-docs-com-ia/blob/jvalsesia/mba-ia-desafio-design-docs-com-ia/tasks/verify-docs.sh) | Spec aprovado, plano, diário de cada ciclo e o script de verificação. Para rodar o script: faça checkout do branch de trabalho e execute `bash tasks/verify-docs.sh` |

O código da aplicação (`src/`, `prisma/`, `tests/` e configurações) e a transcrição não foram alterados. O script de verificação, no branch de trabalho, confere isso contra o último commit do repositório base (`e7f6311`).
