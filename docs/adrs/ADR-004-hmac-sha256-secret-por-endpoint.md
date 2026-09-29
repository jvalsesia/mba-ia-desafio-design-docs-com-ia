# ADR-004: Autenticação das entregas por HMAC-SHA256 com secret por endpoint e rotação com grace period de 24h

## Status

**Aceito.** "Decidido: HMAC-SHA256 sobre o corpo do request, secret por endpoint, suporte a rotação com grace period de 24h." (`[09:22] Sofia`). Confirmado no resumo (`[09:48] Larissa`).

- **Decisores:** Sofia (Segurança), Larissa, Diego, Bruno
- **Relacionados:** [ADR-005](./ADR-005-at-least-once-com-x-event-id.md), [ADR-006](./ADR-006-reuso-dos-padroes-do-projeto.md)

## Contexto

A plataforma vai enviar eventos com dados de pedidos para endpoints fora da sua infraestrutura. O cliente precisa conseguir validar duas coisas: que a requisição veio de fato da plataforma e que ninguém adulterou o payload no caminho (`[09:19] Sofia`).

Já houve cliente que vazou secret no log da própria aplicação (`[09:22] Diego`). Por isso, o desenho precisa limitar o raio de um vazamento e permitir a troca da secret sem parar a integração.

## Decisão

**ADR-004:** Cada entrega é assinada com **HMAC-SHA256 sobre o corpo do request**, e a assinatura vai no header **`X-Signature`** (`[09:20] Sofia`).

1. **Algoritmo:** HMAC-SHA256, "padrão de mercado, todo cliente sério tem biblioteca pra isso" (`[09:20] Sofia`).
2. **Secret por endpoint:** cada webhook cadastrado tem sua própria secret, e não existe secret global da plataforma (`[09:21] Sofia`).
   - A configuração do webhook armazena URL, secret, `customer_id` e estado ativo (`[09:21] Bruno`, confirmado por `[09:21] Sofia`).
3. **Geração pela plataforma:** a secret é gerada pela plataforma e devolvida ao cliente na criação do webhook (`[09:31] Marcos`).
4. **Rotação pela API:** o cliente pede uma nova secret por um endpoint. A antiga continua válida **por 24 horas em paralelo** e depois é descartada (`[09:21] Sofia`).
5. **Assinatura durante o grace period.** A reunião não detalhou este ponto, então o que segue é uma proposta de design derivada de `[09:21] Sofia`:
   - Nas 24h, `X-Signature` carrega **duas assinaturas**, uma com cada secret (ex.: `v1=<hmac_nova>,v1=<hmac_antiga>`), e o cliente aceita a entrega se qualquer uma delas bater.
   - Assinar só com a nova tornaria o grace period inútil para quem ainda verifica com a antiga.
6. **Escopo da assinatura:** o HMAC cobre **somente o corpo** do request, como decidido (`[09:22] Sofia`). O header `X-Timestamp` com o momento do envio vai à parte, para que o cliente possa detectar ataques de replay se quiser (`[09:44] Diego`). O [FDD](../FDD.md) detalha a codificação dos headers.

Duas validações complementares ficam registradas como requisitos, sem ADR próprio, por decisão explícita da reunião:
- URL obrigatoriamente `https`, recusada no schema Zod (`[09:23] Sofia`).
- Limite de 64KB de payload. Acima disso, o evento é rejeitado com erro, sem truncar (`[09:23] Sofia`, `[09:24] Larissa`).

## Alternativas Consideradas

**ADR-004-ALT-01: Uma secret global da plataforma para todos os webhooks.** Descartado.
- "Senão se vaza uma, vaza tudo" (`[09:21] Sofia`).

**ADR-004-ALT-02: Rotação com corte imediato, sem período de convivência.** *Alternativa implícita, não debatida como opção na reunião.*
- Fica descartada pelo requisito da Sofia de que a antiga continue válida por 24h, "pra ele ter tempo de migrar os sistemas dele" (`[09:21] Sofia`).

## Consequências

### Positivas
- **ADR-004-CONS-01:** O cliente valida origem e integridade com biblioteca padrão de mercado (`[09:20] Sofia`).
- **ADR-004-CONS-02:** O vazamento de uma secret compromete só um endpoint (`[09:21] Sofia`), e a rotação permite reagir a vazamentos como o já ocorrido (`[09:22] Diego`) sem interromper a integração.

### Negativas
- **ADR-004-CONS-03:** O worker precisa da secret em claro para assinar. Ela não pode ser guardada como hash irreversível, como acontece hoje com `passwordHash` em `prisma/schema.prisma`. Isso exige cuidado extra com exposição em logs e respostas de API (ver [ADR-006](./ADR-006-reuso-dos-padroes-do-projeto.md) e o [FDD](../FDD.md)).
- **ADR-004-CONS-04:** A rotação adiciona estado (secret anterior e sua validade) e dupla assinatura durante 24h, o que aumenta a complexidade de implementação e de teste.
- **ADR-004-CONS-06:** *(análise)* Como o `X-Timestamp` não entra na assinatura, que cobre só o corpo, um intermediário poderia alterá-lo sem invalidar o HMAC. A detecção de replay pelo cliente fica limitada. Mitigações sem mudar a decisão: o corpo já traz o timestamp ISO 8601 do evento (`[09:43] Diego`), e a deduplicação por `X-Event-Id` ([ADR-005](./ADR-005-at-least-once-com-x-event-id.md)) neutraliza reentregas do mesmo evento.
- **ADR-004-CONS-05:** A geração de secret e o HMAC são críticos. A Sofia pediu pelo menos 2 dias úteis de revisão de segurança antes do deploy (`[09:46] Sofia`).

### Trade-off
Troca-se simplicidade (uma secret fixa e global) por **isolamento de vazamentos e rotação sem downtime**, ao custo de mais estado por webhook e de uma revisão de segurança dedicada.

## Referências
- `TRANSCRICAO.md`: `[09:19]`–`[09:24]`, `[09:31]`, `[09:44]`, `[09:46]`, `[09:48]`
- `prisma/schema.prisma` (padrão atual de armazenamento de credenciais: `passwordHash`)
