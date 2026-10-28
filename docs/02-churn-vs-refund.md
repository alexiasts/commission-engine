# Churn × refund: uma palavra, duas leituras

**Status: em aberto.** Nenhum código resolve isto. A decisão pertence a quem é
dono da definição.

---

## A pergunta

A regra de comissão diz que o pagamento é sobre o faturamento **pós churn**. A
origem oferece um campo chamado `is_refunded`.

Não são o mesmo evento:

- **refund** — o dinheiro voltou para o cliente
- **churn** — o contrato foi cancelado

Todo estorno implica um contrato cancelado. O contrário não é verdade: dá para
cancelar sem estornar. Toda venda cancelada e não estornada é paga sob uma
leitura e não sob a outra.

---

## Como isso apareceu

Não apareceu como erro. Apareceu como um padrão.

No fechamento, sete pessoas divergiam de um dashboard de referência. Sempre:

- o **bruto batendo ao centavo**
- o **líquido diferente**
- por **exatamente uma transação** em cada
- e sempre na **mesma direção**

Essa assinatura — bruto concordando, líquido discordando, por transações
inteiras e não por centavos — é o que distingue uma divergência de definição de
um erro de conta. Erro de arredondamento produz diferença fracionária. Erro de
filtro produz diferença no bruto também. Isto não era nenhum dos dois.

## O que foi descartado, e como

**Erro do motor.** A reconciliação contra a fonte dava diferença de realizado
igual a R$ 0,00 e comissão idêntica em 38 de 40 casos. Como a comissão sai do
líquido, se o líquido divergisse a comissão divergiria. Não divergiu.

**Horário de extração.** Reimportar não mudou nada. E `is_refunded` é estado
atual, não evento datado — um estorno novo teria aparecido na releitura.

Sobrou a hipótese semântica, que é também a mais chata: as duas partes estavam
certas, medindo coisas diferentes com a mesma palavra.

---

## O que este projeto faz a respeito

Três coisas, nenhuma delas "escolher".

**1. As duas leituras são calculadas em paralelo.** `int_sales_scoped` carrega
`net_amount_by_refund` e `net_amount_by_churn` lado a lado, o caminho todo.

**2. A definição que paga é uma variável.**

```yaml
vars:
  commission_base: "refund"   # ou "churn"
```

```bash
dbt build --vars '{"commission_base": "churn"}'
```

Isso transforma a discussão em experimento. Em vez de duas pessoas defendendo
leituras diferentes numa reunião, roda-se as duas e compara-se o resultado.

**3. A diferença é precificada por pessoa.**
`rpt_cancellation_reconciliation` mostra, para cada vendedor, quantas
transações estão em disputa, quanto líquido muda e quanto a comissão muda.

Vale reparar que a alíquota é idêntica nas duas leituras — ela é determinada
pelo atingimento, que é medido no **bruto**, e o bruto não muda. Só a base se
move. Isso simplifica a comparação e é mais uma consequência prática da
separação entre as duas bases.

### Neste dataset

| | |
|---|---|
| vendedores afetados | 12 |
| transações em disputa | 21 |
| diferença total de comissão | R$ 1.768,14 |
| direção | sempre a favor do vendedor sob a leitura `refund` |

A direção é a parte desconfortável. Se a definição correta for a de contrato
cancelado, o motor vem pagando **a maior** — e não só neste mês.

---

## Por que o teste é `warn` e não `error`

`warn_cancellation_definitions_disagree` avisa a cada execução e não derruba o
build.

Não é defeito: as duas leituras estão implementadas corretamente. Derrubar o
build treinaria as pessoas a ignorar pipeline vermelho, que é o começo de todo
desastre operacional. Passar em silêncio deixaria uma ambiguidade conhecida e
já precificada virar permanente por omissão.

Um aviso a cada execução é o meio-termo honesto: mantém o número na frente de
quem roda o fechamento, e para de aparecer no dia em que alguém responder a
pergunta.

---

## O que falta decidir

1. Qual campo a regra de comissão significa — estorno ou cancelamento de
   contrato?
2. A origem pode expor o cancelamento de contrato além do estorno?
3. Se a definição correta for a do dashboard, existe acerto retroativo ou a
   diferença é absorvida?

Enquanto não houver resposta, a leitura usada fica declarada na variável, onde
qualquer pessoa consegue ver qual foi usada e trocar para comparar.
