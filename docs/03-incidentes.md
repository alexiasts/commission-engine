# Três incidentes, e o que cada um deixou

Nenhum destes é hipotético. Cada um aconteceu, cada um custou dinheiro ou
tempo, e cada um saiu com um teste que impede a volta.

O que eles têm em comum é mais interessante que a causa de cada um: **nenhum
levantou exceção**. Todos produziram números plausíveis, relatórios bem
formatados e pipelines verdes. É por isso que a defesa é asserção, não
tratamento de erro — o que não falha alto não vai falhar sozinho.

---

## 1. O valor que virou data, que virou milissegundos

**Sintoma.** Comissões na casa dos trilhões de reais. Um mês somando
R$ 303.492.614.788.000,00.

**Cadeia.** Cinco camadas, cada uma se comportando corretamente dentro da
própria lógica:

1. a origem devolve tudo como texto, inclusive números. Uma venda de
   R$ 1.558,80 chega como `"1558.8"`, com ponto, porque o sistema é americano
2. o script escrevia esse texto direto na planilha, sem converter
3. a planilha está em pt-BR, onde ponto é separador de milhar. `1558.8` não é
   número válido, então o próximo palpite entra: **data**. Interpretou como 1º
   de agosto de 1558
4. por baixo, datas são números. Ao ler a célula de volta, o script recebeu um
   objeto de data
5. `Number(data)` em JavaScript devolve **milissegundos desde 1970**. Para uma
   data de 1558, algo como `-1,3 × 10¹³`

Quarenta vendas assim chegam nos trilhões.

**Por que foi pego.** Porque o número era absurdo. Vale insistir nesse ponto:
uma data em 1970 em vez de 1558 teria produzido um valor merely errado, e esse
teria sido pago.

**O que ficou.** A correção estrutural é o cast explícito para `DECIMAL` na
fronteira, em `stg_sales` — tipo declarado, nunca inferido, nunca `FLOAT`. O
teste `assert_amounts_within_plausible_bounds` é o cinto para esse par de
suspensórios: nenhuma linha pode cair fora da faixa que um humano reconheceria
como dinheiro.

**A lição transferível.** Toda conversão implícita é um palpite, e todo palpite
tem um caso em que acerta a sintaxe e erra a semântica. Tipagem na fronteira é
barata; descobrir isso na folha não é.

---

## 2. A rampagem com teto

**Sintoma.** Nenhum. É o que torna este o pior dos três.

**O que acontecia.** O mart marcava a faixa de quem estava `em_rampagem` como
"100% a 109,99%", qualquer que fosse o atingimento. Um vendedor novo fazendo
141% era pago como se tivesse feito 100%.

A regra é a oposta: **100% é piso, não teto**. Quem está rampando não cai
abaixo da faixa de 100%; se superar, fica com o que superou.

**Por que demorou.** Porque o número era plausível. Ninguém audita o
contracheque de quem está indo bem procurando um valor baixo demais — e o
vendedor novo, que não conhece a tabela ainda, também não.

**A segunda parte, que é a mais instrutiva.** A primeira correção destravou a
faixa acima de 120% e **deixou a do meio presa**. O vendedor de 141% foi
corrigido; o de 111,13% continuou errado, por mais um mês, sem que ninguém
percebesse — porque a verificação feita tinha sido "o caso que reportamos agora
está certo?", não "a função está certa?".

**O que ficou.** `assert_ramp_up_floor_not_ceiling` não testa um exemplo:
afirma que o insumo da faixa é igual a `max(atingimento, 100%)` para **todo**
vendedor em rampagem, em **toda** faixa. Um caso de teste teria passado depois
da correção parcial. A propriedade não passa.

Com o defeito injetado neste dataset, dois dos três vendedores em rampagem
perdem R$ 3.669,21 no mês:

| | faixa correta | com o defeito | diferença |
|---|---|---|---|
| 141,49% | 120% → R$ 7.837,91 | 100% → R$ 5.225,27 | −R$ 2.612,64 |
| 111,92% | 110% → R$ 5.282,81 | 100% → R$ 4.226,24 | −R$ 1.056,57 |
| 103,17% | 100% → R$ 3.860,51 | 100% → R$ 3.860,51 | — |

O terceiro não muda, porque já estava na faixa de 100%. É exatamente o tipo de
caso que faz uma correção parcial parecer completa.

---

## 3. A meta que apagou as regras de todo mundo

**Sintoma.** Quatro pessoas com comissão zero, R$ 4.577,11 a menos, de um mês
para o outro, sem nada ter mudado no processo.

**O que acontecia.** Uma rotina sincronizava a regra de medição de cada
vendedor com um flag da origem. Numa importação, a origem não marcou ninguém
como em rampagem — e o script leu isso como "ninguém está em rampagem" em vez
de "não veio informação". Tirou a regra de sete pessoas; quatro delas, sem meta
cadastrada (porque quem está rampando não precisa de meta), caíram para
atingimento nulo e comissão zero.

**A causa real** não é o script. É a ausência de distinção entre **vazio** e
**ausente**. Zero linhas num resultado pode significar "nenhum registro
satisfaz a condição" ou "a consulta não trouxe nada" — e as duas pedem reações
opostas.

**O que ficou.** Três defesas, e a terceira é a que mais importa:

1. a sincronização se recusa a rodar se a origem não indicar ninguém em
   rampagem — "nenhum" é tratado como suspeito, não como fato
2. nunca desmarca quem está sem meta, porque é exatamente quem a desmarcação
   quebra
3. marcar e desmarcar viraram duas operações separadas, com confirmações
   separadas

Neste repositório a equivalente é `assert_standard_seller_has_target`: um
vendedor `STANDARD` sem meta é erro, nunca zero.

---

## Um quarto, que não chegou a ser incidente

A cópia do fechamento para a planilha do financeiro falhava, e o erro estava
sendo engolido por um `try/catch` que existia para "não perder o fechamento".
A mensagem aparecia dentro de um alerta final, numa linha fácil de não ler.
Passaram-se horas adivinhando.

**A regra que ficou:** erro engolido para não perder o processo custa mais caro
do que o processo perdido. Quando um passo tem destino externo, a função que
faz só aquele passo precisa existir — e precisa falhar alto.

É a mesma ideia que sustenta `scripts/prove_guardrails.py`: não basta ter a
defesa, é preciso demonstrar que ela dispara.
