# Regras de negócio

A especificação que os modelos implementam e que os testes protegem. Quando
esta página e o SQL discordarem, um dos dois está errado e vale parar para
descobrir qual.

---

## As duas bases

| | base | por quê |
|---|---|---|
| **Atingimento** | faturamento **bruto** | a venda foi do vendedor; o cancelamento posterior é do cliente |
| **Comissão** | faturamento **líquido** | a empresa não recebeu, então não há o que comissionar |

Dito assim parece arbitrário. Não é: o cancelamento não tira o vendedor da
faixa que ele conquistou, mas ele não é pago pela venda cancelada.

Essa separação é a fonte de erro mais provável do projeto inteiro, porque
trocar uma base pela outra é uma palavra num modelo e o total resultante
continua parecendo plausível. Daí existirem dois testes espelhados:
`assert_attainment_measured_on_gross` e `assert_commission_paid_on_net`.

```
atingimento = bruto ÷ meta
comissão    = (líquido venda cheia × % cheia) + (líquido recorrente × % recorrente)
```

---

## A tabela de faixas

| atingimento mínimo | venda cheia | recorrente |
|---|---|---|
| 120% | 6,00% | 3,00% |
| 110% | 5,00% | 2,50% |
| 100% | 4,00% | 2,00% |
| 90% | 3,00% | 1,50% |
| 80% | 2,00% | 1,00% |
| 70% | 1,00% | 0,50% |
| 50% | 0,50% | 0,25% |
| 0% | 0,00% | 0,00% |

A faixa é a **maior linha cujo mínimo o vendedor alcança**. Abaixo de 50% a
comissão é zero.

A tabela é um seed, não código. Mudança de regra é edição de CSV. Nenhum
modelo downstream tem percentual escrito dentro — é a diferença entre uma
mudança de regra levar cinco minutos e levar um deploy.

---

## As três regras de medição

A coluna `commission_rule` do cadastro decide como o vendedor é medido.

### `STANDARD`

Tabela normal. **Meta é obrigatória.** Meta vazia é erro, não zero.

Essa distinção não é preciosismo. Sem ela, uma meta em branco divide em
atingimento nulo, cai na última faixa e paga R$ 0,00 — para uma pessoa ou para
todas de uma vez, dependendo de onde veio o branco. A falha é total e se
apresenta como um relatório perfeitamente formatado cheio de zeros.
Guardado por `assert_standard_seller_has_target`.

### `RAMP_UP`

Vendedor novo, ainda dentro da janela de rampagem.

**100% é piso, não teto.** Ele não cai abaixo da faixa de 100%, e se superar,
fica com o que superou:

```
atingimento_para_faixa = max(atingimento, 100%)
```

Não exige meta: sem meta, o piso de 100% vale sozinho.

Esta é a regra que o mart original implementou ao contrário. Ver
[`03-incidentes.md`](03-incidentes.md).

### `CS`

Customer Success. Percentual fixo sobre o líquido, sem meta e sem faixa. O
percentual fica em `fixed_pct`, não no código.

As vendas de CS não são visíveis para os times de venda, e por isso **não
entram na soma de nenhum TL** — somar inflaria o atingimento de um líder com
faturamento que ele não liderou. Reaparecem no nível do diretor, onde a
operação inteira conta.

---

## Exceções pontuais

`manual_attainment_pct` substitui o atingimento calculado. Dois limites:

1. **Muda só a faixa, nunca a base de pagamento.** A comissão continua sendo
   calculada sobre o líquido real.
2. **`manual_attainment_reason` é obrigatório.** Sem justificativa escrita, a
   asserção `assert_manual_override_has_reason` falha e o processo trava.

O custo para quem cadastra é uma frase, no momento em que a pessoa já sabe a
resposta. O benefício é que daqui a seis meses a resposta está na mesma linha
que o número, em vez de na memória de alguém que talvez não trabalhe mais ali.

A linha do mart carrega as duas coisas lado a lado — `attainment_computed` (o
que a conta deu) e `attainment_applied` (o que foi usado) — de propósito.

---

## Quem entra no pagamento

`is_active = false` **não** significa "ignore a pessoa".

Quem saiu no meio do mês vendeu enquanto esteve lá, e esse faturamento é do
time. A pessoa entra na folha normalmente, conta na soma do TL, e sai com
`amount_payable = 0` e uma nota explicando que a comissão foi acertada em
rescisão.

A alternativa — pular a linha — faz a soma do time ficar menor que o dashboard
sem nada acusar. Silêncio é o pior resultado possível num pipeline de folha.

---

## Faturamento por time

Somado **venda a venda, pela data de cada venda**.

Para cada transação, a pergunta é: em que time essa pessoa estava **naquele
dia**? A resposta vem de `raw_team_periods` quando há um intervalo cobrindo a
data, e do cadastro quando não há.

`raw_team_periods` normalmente fica **vazia**, e aí o resultado é idêntico a
agrupar pelo time do cadastro. Só se preenche quando alguém trocou de time no
meio do mês, e **só o período antigo** — o resto cai sozinho no cadastro.

Intervalos sobrepostos são recusados por `assert_no_overlapping_team_periods`:
a mesma venda contaria para dois times e dois líderes seriam pagos por ela, com
os dois totais parecendo razoáveis isoladamente.

Faturamento de um time sem líder atual — um time dissolvido no meio do mês —
não chega a TL nenhum, mas continua contando para o diretor. A empresa faturou
de qualquer jeito.

---

## Comissão de liderança

**TL** — sobre o líquido do time, atingimento contra a meta do **time**.

| atingimento | % |
|---|---|
| ≥ 120% | 1,20% |
| 100% a 119,99% | 1,00% |
| < 100% | 0,80% |

**Diretor** — sobre o líquido da **operação inteira**, incluindo CS,
atingimento contra a meta da **empresa**.

| atingimento | % |
|---|---|
| ≥ 120% | 0,45% |
| 100% a 119,99% | 0,35% |
| 90% a 99,99% | 0,25% |
| 80% a 89,99% | 0,20% |
| 50% a 79,99% | 0,15% |
| < 50% | 0,00% |

A meta do diretor é a **meta da empresa**, não a soma das metas dos times. São
números diferentes: as metas de time são distribuídas individualmente e não
somam o compromisso da empresa. Trocar um denominador pelo outro muda o
atingimento, que muda a faixa — e nada no relatório indica qual dos dois foi
usado. Neste dataset a diferença entre as duas leituras é de R$ 2.829,35 em um
mês: R$ 9.902,74 contra R$ 12.732,09.

**TL de CS** — percentual fixo sobre o líquido do CS, sem time e sem meta.
