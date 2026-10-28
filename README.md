# Commission Engine

Motor de cálculo de comissões de vendas em dbt + DuckDB, com as regras de
negócio codificadas como testes.

Reimplementação, com dados sintéticos, de um sistema que roda em produção e
decide quanto ~40 vendedores recebem por mês. O que está aqui não é a
automação da planilha — é a camada de modelagem e de garantia: as regras, as
asserções que as protegem, a reconciliação entre duas definições concorrentes
de uma métrica e a preservação do que foi efetivamente pago.

```
dbt build   ->  20 modelos, 32 testes, 0 falhas, 2 avisos intencionais
```

---

## Rodar

Não precisa de credencial, de conta em nuvem nem de banco. Roda inteiro no
disco, em alguns segundos.

```bash
pip install -r requirements.txt
export DBT_PROFILES_DIR=$PWD
dbt build
```

E as duas demonstrações que dão nome ao projeto:

```bash
python scripts/prove_guardrails.py      # os testes pegam o que dizem pegar
python scripts/prove_point_in_time.py   # a folha sobrevive a mudança retroativa
```

A linhagem completa, as descrições de coluna e o SQL compilado de cada modelo
e cada teste ficam no site de documentação, reconstruído a cada push:
**[linhagem e catálogo](https://SEU-USUARIO.github.io/commission-engine/)**.

---

## O problema

Comissão é um cálculo pequeno cercado de armadilhas grandes. O resultado vai
direto para o contracheque de uma pessoa, erro para menos ninguém reclama
porque ninguém sabe, e erro para mais só aparece na auditoria. As três coisas
que tornam isso difícil não são a aritmética:

**As duas bases são diferentes de propósito.** O atingimento é medido sobre o
faturamento **bruto** — um cancelamento não rebaixa o vendedor de faixa, porque
a venda foi dele. A comissão é paga sobre o **líquido** — ele não recebe por
venda que a empresa não recebeu. Trocar uma pela outra é uma palavra num modelo
e nunca parece errado num total.

**A origem é uma fotografia do presente.** Quando alguém é desligado, as vendas
históricas dessa pessoa podem sumir retroativamente. Reprocessar um mês fechado
não reproduz o mês fechado: produz a resposta de hoje para uma pergunta que foi
respondida em outubro.

**As palavras não são precisas.** A regra diz que a comissão é sobre o
faturamento "pós churn". A fonte só oferece `is_refunded`. Cancelar um contrato
e devolver o dinheiro não são o mesmo evento, e a diferença entre as duas
leituras é dinheiro de verdade.

---

## O pipeline

```
seeds (CSV sintético)
  raw_sales_transactions ······ 2.374 vendas, 2 meses
  raw_seller_roster ·········· 22 vendedores: meta, time, regra, exceções
  raw_commission_tiers ······· a tabela de faixas
  raw_team_periods ··········· troca de time no meio do mês
  raw_leadership · raw_leader_tiers
        │
        ▼  staging  — tipagem explícita, normalização, nada de lógica
        │
        ▼  intermediate
  int_sales_scoped ··········· time por venda, pela DATA da venda
  int_seller_month ··········· bruto e líquido, por tipo de venda
  int_seller_attainment ······ atingimento, exceções, faixa
        │
        ▼  marts
  fct_seller_commission ······ a folha: 1 linha por vendedor
  fct_team_month ············· faturamento por time
  fct_leader_commission ······ TL, Diretor e CS
  rpt_cancellation_reconciliation ··· churn × refund, precificado
        │
        ▼  snapshot
  snap_payroll ··············· o que foi pago, congelado
```

---

## As decisões que definem o projeto

**Faixa de comissão é dado, não código.** `raw_commission_tiers` é uma tabela.
Mudança de regra em janeiro é edição de CSV, não deploy. Nenhum modelo
downstream tem percentual escrito dentro.

**100% é piso, não teto.** Vendedor em rampagem não pode cair abaixo da faixa
de 100%, e se superar, fica com o que superou. O mart original fazia o
contrário e prendia todo mundo em rampagem na faixa de 100% a 109,99% —
incluindo quem fez 141%. Com o defeito injetado, dois dos três vendedores em
rampagem deste dataset perdem R$ 3.669,21 no mês, e nada no relatório indica
isso. Ver [`docs/03-incidentes.md`](docs/03-incidentes.md).

**O faturamento do time é somado venda a venda, pela data.** Um time foi
dissolvido no dia 16 e os vendedores migraram. Agrupar pelo time *atual* do
vendedor daria o mês inteiro ao time novo. A atribuição acontece por
transação, contra um intervalo de vigência.

**Exceção sem justificativa escrita é erro, e trava o processo.** Um
atingimento pode ser substituído à mão — um acerto de rescisão, um percentual
que a empresa validou diferente. O que não pode é a exceção existir sem
explicação ao lado. Daqui a seis meses a resposta para "por que essa pessoa
recebeu isso?" precisa estar na mesma linha que o número.

**O denominador do diretor é a meta da EMPRESA.** Não a soma das metas dos
times — são números diferentes, e substituir um pelo outro muda a faixa sem
deixar rastro. Neste dataset a diferença entre as duas leituras é de R$ 2.829,35
em um mês (R$ 9.902,74 contra R$ 12.732,09).

**A chave é e-mail, nunca nome.** Nome não é único, não é estável entre
sistemas, e o modo de falha de um quase-casamento é uma linha vazia em vez de
um erro.

---

## O que os testes garantem

Testes genéricos cobrem unicidade, nulos e domínios. O que vale olhar são os
singulares, porque cada um é uma regra de negócio escrita como asserção — e
quase todos vieram de um incidente real:

| teste | o que impede |
|---|---|
| `assert_ramp_up_floor_not_ceiling` | rampagem tratada como teto, em qualquer faixa |
| `assert_commission_paid_on_net` | pagar por venda estornada |
| `assert_attainment_measured_on_gross` | cancelamento rebaixando o vendedor de faixa |
| `assert_sale_types_cover_net` | tipo de venda novo caindo fora das duas pernas |
| `assert_no_overlapping_team_periods` | mesma venda contando para dois times |
| `assert_manual_override_has_reason` | exceção sem justificativa |
| `assert_sales_belong_to_known_seller` | venda que não chega a nenhuma folha |
| `assert_standard_seller_has_target` | meta vazia virando comissão zero |
| `assert_team_totals_reconcile_to_sellers` | divergência entre os dois caminhos de soma |
| `assert_amounts_within_plausible_bounds` | contrato de dados no valor |

E quatro com severidade `warn`, para o que não é defeito mas não pode passar
em silêncio: a divergência churn × refund, vendedor cadastrado sem nenhuma
venda, atingimento acima de 200% e o denominador do diretor.

### A suíte verde não prova nada sozinha

Ela mostra que nada está errado hoje, não que os testes perceberiam se
estivesse. Então cada defeito que o projeto existe para evitar é injetável por
variável, e `scripts/prove_guardrails.py` coloca um de cada vez e mostra qual
asserção pegou:

```
ramp_ceiling             caught  -> assert_ramp_up_floor_not_ceiling
commission_on_gross      caught  -> assert_commission_paid_on_net
override_without_reason  caught  -> assert_manual_override_has_reason
overlapping_periods      caught  -> assert_no_overlapping_team_periods
```

Roda no CI a cada push.

---

## A folha é congelada, não recalculada

`scripts/prove_point_in_time.py` simula o que acontece de verdade: a origem
deixa de devolver parte do histórico de uma vendedora depois do fechamento.

```
1. fechamento: R$ 4.565,14  sobre bruto R$ 148.707,30  (104,72% atingido, faixa 100%)
2. a origem perde 11 transações retroativamente
3. reprocessando hoje:  R$ 1.887,87  (85,71% atingido, faixa 80%)
   o reprocessamento derrubaria uma faixa inteira, R$ 2.677,27 a menos
4. o snapshot mantém as duas versões, cada uma com sua janela de validade
```

O valor pago continua no registro. O ajuste vira uma diferença visível, a ser
acertada no mês seguinte de propósito — em vez de uma descoberta por acidente.

---

## A pergunta em aberto

`rpt_cancellation_reconciliation` não escolhe um lado: ele precifica a
discordância. Neste dataset, 12 vendedores têm 21 transações canceladas sem
estorno, e as duas leituras diferem em R$ 1.768,14 no mês — sempre na mesma
direção.

Em produção isso apareceu como vendedores cujo bruto batia ao centavo com o
dashboard de referência e cujo líquido não batia, cada um errado por
exatamente uma transação. Bruto concordando e líquido discordando, por
transações inteiras, é a assinatura de uma divergência de definição, não de um
erro de conta — reprocessar não resolve, porque nada está quebrado.

Detalhe em [`docs/02-churn-vs-refund.md`](docs/02-churn-vs-refund.md).

---

## Os dados

Inteiramente sintéticos e gerados de forma determinística por
`scripts/generate_seeds.py`. Nenhuma pessoa, empresa, e-mail, produto ou valor
real aparece aqui; o domínio `lumina-idiomas.example` é reservado para
documentação. O CI regenera os seeds e falha se o resultado divergir do que
está commitado.

O cenário cobre, de propósito: três vendedores em rampagem em faixas
diferentes, um time dissolvido no meio do mês, uma saída com acerto em
rescisão, uma exceção manual documentada, um vendedor sem nenhuma venda, um
abaixo do piso de 50%, e Customer Success com regra própria.

Código e colunas em inglês; documentação e comentários de regra de negócio em
português, que é o idioma em que as regras foram escritas.

---

## Estrutura

```
models/staging/          tipagem e normalização
models/intermediate/     onde mora a lógica de negócio
models/marts/            a folha, os times, a liderança, a reconciliação
tests/                   14 asserções de regra de negócio
snapshots/               o registro do que foi pago
scripts/generate_seeds.py        os dados sintéticos
scripts/prove_guardrails.py      injeção de defeitos
scripts/prove_point_in_time.py   mudança retroativa da origem
docs/                    regras, decisões e incidentes
```

## Documentação

- [`PUBLICAR.md`](PUBLICAR.md) — como publicar este repositório no GitHub, do zero
- [`docs/01-regras-de-negocio.md`](docs/01-regras-de-negocio.md) — a especificação completa
- [`docs/02-churn-vs-refund.md`](docs/02-churn-vs-refund.md) — a divergência de definição, precificada
- [`docs/03-incidentes.md`](docs/03-incidentes.md) — três falhas de produção e o teste que cada uma deixou
- [`docs/04-decisoes.md`](docs/04-decisoes.md) — as decisões de arquitetura e por quê
