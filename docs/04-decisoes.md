# Decisões de arquitetura

Cada uma com a alternativa que foi descartada, porque uma decisão sem
alternativa não é decisão.

---

## 1. A planilha é a fonte da verdade da meta, não o data warehouse

**Decisão.** Meta, time e regra de medição ficam no cadastro, mesmo existindo
meta na origem.

**Alternativa descartada.** Ler a meta direto da origem, que já a calcula.

**Por quê.** A origem é uma fotografia do presente. Quando um líder foi
desligado, as vendas dele em agosto sumiram retroativamente. Meta gravada no
cadastro é meta que não se move depois que a folha rodou.

Além disso: nem todo mundo tem meta na origem — CS não está lá, e quem passou o
mês sem vender também não aparece. E exceções precisam de lugar.

**O custo.** Alguém digita. É um custo real e aceito conscientemente: a
alternativa é um número que muda sozinho depois do pagamento.

---

## 2. Chave é e-mail, nunca nome

**Decisão.** Todo cruzamento entre origem e cadastro é por e-mail,
normalizado para minúsculas.

**Alternativa descartada.** Cruzar por nome, que é o que estava lá antes.

**Por quê.** Nome não é único — duas pessoas com o mesmo primeiro nome no mesmo
time. Não é estável — a origem traz o nome completo, o cadastro traz o curto. E
o modo de falha é o pior possível: um quase-casamento produz uma **linha
vazia**, não um erro. A pessoa aparece no relatório com todas as colunas em
branco e comissão zero.

`assert_sales_belong_to_known_seller` transforma esse silêncio em falha.

---

## 3. A faixa de comissão é dado

**Decisão.** `raw_commission_tiers` e `raw_leader_tiers` são seeds. Nenhum
percentual aparece em nenhum modelo.

**Alternativa descartada.** `case when atingimento >= 1.2 then 0.06 ...`

**Por quê.** Regra de comissão muda — por campanha, por ano, por reestruturação
de time. Se mudar significa editar SQL, revisar e fazer deploy, a mudança vai
atrasar ou vai acontecer errado às pressas. Se significa editar um CSV, a
pessoa que é dona da regra consegue fazer sozinha.

O `join` contra a faixa também deixa a seleção explícita e auditável: a coluna
`tier_floor` viaja junto com o pagamento, então dá para ver qual linha da
tabela produziu aquele número.

---

## 4. A folha é congelada, não recalculada

**Decisão.** O fechamento termina com um snapshot append-only do pagamento.

**Alternativa descartada.** Reprocessar o mês quando alguém perguntar.

**Por quê.** Reprocessar um mês fechado não reproduz o mês fechado. A origem
responde a pergunta de hoje: vendas podem ter sumido, estornos podem ter
entrado depois. Isso é tolerável num dashboard e intolerável numa folha, onde a
pergunta de auditoria é "quanto essa pessoa recebeu e por quê", e "roda de novo
e vê" não é resposta quando os insumos se moveram.

O snapshot é append-only de propósito: uma mudança posterior grava uma linha
**nova**, com janela de validade própria, e a linha que foi paga fica como
estava. A diferença entre as duas passa a ser visível — o que permite acertar
no mês seguinte, de propósito, em vez de descobrir por acidente.

`scripts/prove_point_in_time.py` demonstra o cenário inteiro: a vendedora cujo
reprocessamento a derrubaria de faixa inteira, R$ 2.677,27 abaixo do que foi
pago.

---

## 5. A definição em disputa é uma variável, não uma opinião

**Decisão.** `commission_base` escolhe entre `refund` e `churn`, e as duas
leituras são calculadas lado a lado o caminho todo.

**Alternativa descartada.** Escolher uma e seguir em frente.

**Por quê.** Ninguém no projeto é dono dessa definição. Escolher sozinho seria
chutar com o dinheiro dos outros. Variabilizar transforma a discussão em
experimento: roda-se as duas e compara-se, com o custo na mesa.

O relatório de reconciliação é a outra metade: não decide, precifica. Detalhe
em [`02-churn-vs-refund.md`](02-churn-vs-refund.md).

---

## 6. Atribuição de time por transação, com intervalo de vigência

**Decisão.** `raw_team_periods` guarda intervalos fechados. Cada venda pergunta
em que time a pessoa estava **naquele dia**.

**Alternativa descartada.** Agrupar pelo time atual do vendedor.

**Por quê.** Um time foi dissolvido no dia 16 e os vendedores migraram.
Agrupar pelo time atual daria o mês inteiro ao time novo — e o erro é
invisível, porque os dois totais continuam parecendo razoáveis.

**O detalhe que faz funcionar na prática:** a tabela normalmente fica **vazia**,
e aí o resultado é idêntico ao modelo simples. Só se preenche o **período
antigo** de quem trocou; o resto cai sozinho no cadastro. Uma estrutura
permanente que custa zero nos meses em que ninguém se move é muito mais
provável de sobreviver do que um remendo que precisa ser lembrado.

---

## 7. Severidade `error` trava, `warn` não

**Decisão.** Dez asserções derrubam o build. Quatro avisam.

**O critério.** `error` é para o que está **errado**: uma regra violada, uma
venda órfã, uma exceção sem justificativa. `warn` é para o que está
**indefinido ou suspeito**: a divergência de definição, um vendedor sem
vendas, atingimento acima de 200%.

**Por quê o critério importa.** Um build vermelho precisa significar "pare". No
momento em que ele significa "provavelmente é aquele aviso de sempre", a
proteção inteira virou enfeite — e isso acontece por acumulação de testes
rigorosos demais, não por falta deles.

A contrapartida é que `warn` não pode virar depósito. Cada um dos quatro tem
uma condição de encerramento escrita: o churn × refund sai quando a definição
for decidida, o vendedor sem vendas sai quando for confirmado como afastamento.

---

## 8. Provar que a defesa dispara

**Decisão.** Cada defeito que o projeto previne é injetável por variável, e um
script coloca um de cada vez para mostrar qual asserção pega.

**Alternativa descartada.** Confiar na suíte verde.

**Por quê.** Suíte verde mostra que nada está errado hoje. Não mostra que os
testes perceberiam se estivesse — e um teste que nunca falhou é
indistinguível de um teste que não funciona.

Isso também resolve um problema de comunicação: "temos cobertura de testes" é
uma afirmação que ninguém consegue avaliar. Quatro defeitos reais, injetados,
e o nome da asserção que pegou cada um, qualquer pessoa avalia em dez segundos.
