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
