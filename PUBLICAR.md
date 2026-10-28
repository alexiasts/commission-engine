# Como publicar este repositório no GitHub

Passo a passo para quem nunca publicou nada no GitHub. Leva uns 20 minutos na
primeira vez.

Não tem terminal em lugar nenhum: tudo pelo GitHub Desktop, que é um aplicativo
com botões. Nada aqui é irreversível — repositório publicado pode ser apagado,
renomeado ou trocado de público para privado depois.

---

## Antes de começar

Descompacte o `commission-engine.zip` num lugar que você vá lembrar — por
exemplo `Documentos/commission-engine`. Essa pasta vai ser o repositório.

---

## Passo 1 — Criar a conta no GitHub

Se você já tem, pule.

1. Vá em **github.com** e clique em **Sign up**
2. E-mail, senha, nome de usuário

**O nome de usuário aparece na URL do seu portfólio**, então vale pensar dois
segundos nele: `github.com/alexiasantos` fica melhor num currículo do que
`github.com/alexia_1998_xyz`. Dá para mudar depois, mas os links antigos quebram.

3. Confirme o e-mail

Conta gratuita basta para tudo que está aqui.

---

## Passo 2 — Instalar o GitHub Desktop

1. **desktop.github.com** → **Download**
2. Instale e abra
3. **Sign in to GitHub.com** → entre com a conta do passo 1
4. Ele pede nome e e-mail para assinar os commits — use os mesmos da conta,
   senão o GitHub não liga os commits ao seu perfil e o quadradinho verde de
   contribuição não aparece

---

## Passo 3 — Adicionar a pasta

1. No GitHub Desktop: **File → Add local repository**
2. **Choose...** e selecione a pasta `commission-engine`
3. Vai aparecer um aviso de que a pasta não é um repositório Git, com um link
   **create a repository**. Clique nele
4. Na tela que abre:
   - **Name:** `commission-engine`
   - **Description:** `Motor de comissões em dbt + DuckDB, com as regras de negócio como testes`
   - **Git ignore:** deixe como está (o projeto já tem o seu)
   - **License:** `MIT License` — é a licença permissiva padrão; sem licença
     nenhuma, tecnicamente ninguém pode usar nem copiar o código
5. **Create repository**

Até aqui nada saiu do seu computador.

---

## Passo 4 — O primeiro commit

Um commit é um ponto salvo. O GitHub Desktop já deve mostrar os ~50 arquivos
do lado esquerdo, todos marcados.

No campo **Summary**, embaixo à esquerda, escreva:

```
Motor de comissões: dbt + DuckDB, regras de negócio como testes
```

E no campo **Description**, maior, logo abaixo:

```
Pipeline de cálculo de comissões com as regras codificadas como asserções.

- bruto para atingimento, líquido para pagamento, cada um com seu teste
- 100% como piso na rampagem, afirmado como propriedade em todas as faixas
- faturamento do time atribuído venda a venda, pela data
- exceção manual bloqueada sem justificativa escrita
- churn x refund precificado lado a lado, em vez de decidido unilateralmente
- folha congelada em snapshot, porque a origem é foto do presente
- quatro defeitos reais injetáveis, para provar que as travas disparam

Dados sintéticos, gerados de forma determinística.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

As duas últimas linhas registram que o projeto foi construído em par com o
Claude. É uma divulgação, não uma exigência: mantenha se achar que ajuda, tire
se preferir — o que importa é que o README e a sua conversa sobre o projeto
digam a mesma coisa.

Clique em **Commit to main**.

---

## Passo 5 — Publicar

1. Botão **Publish repository**, no topo
2. **Name:** `commission-engine`
3. ⚠️ **Desmarque "Keep this code private"**

   Precisa ser público por dois motivos: é um portfólio, e o site de
   documentação (GitHub Pages) só funciona em repositório público na conta
   gratuita.

4. **Publish repository**

Pronto, está no ar: `github.com/SEU-USUARIO/commission-engine`.

---

## Passo 6 — Ligar o site de documentação

O repositório já vem com a automação pronta; falta só autorizar.

1. Abra o repositório no navegador
2. **Settings** (a aba, no topo do repositório — não a do seu perfil)
3. Menu da esquerda: **Pages**
4. Em **Source**, troque de `Deploy from a branch` para **GitHub Actions**
5. Só isso. Não precisa salvar nada

---

## Passo 7 — Fazer rodar

As automações rodam a cada envio. Como o Pages só foi ligado agora, force uma
rodada:

1. Aba **Actions**
2. Na esquerda, clique em **docs**
3. **Run workflow** → **Run workflow**
4. Espere uns 2 minutos e recarregue

Dois workflows existem:

| workflow | o que faz |
|---|---|
| **ci** | instala tudo, roda os 32 testes, confere que os dados sintéticos batem com o gerador, injeta os quatro defeitos e confirma que cada teste pega o seu, e roda a prova do snapshot |
| **docs** | gera o site de linhagem e publica no Pages |

Quando o **ci** terminar com ✅ verde, isso é a prova de que qualquer pessoa
consegue clonar e rodar — que é o que separa um repositório de um texto sobre
um repositório.

O endereço do site aparece em **Settings → Pages**, e vai ser
`https://SEU-USUARIO.github.io/commission-engine/`.

---

## Passo 8 — Os dois retoques finais

**No README**, troque `SEU-USUARIO` pelo seu nome de usuário, no link do site de
documentação. Dá para editar direto no navegador: abra o `README.md` no
GitHub, clique no lápis ✏️, corrija, e **Commit changes**.

**Na página do repositório**, clique na engrenagem ⚙️ ao lado de "About",
no canto superior direito:

- **Description:** `Motor de comissões em dbt + DuckDB, com as regras de negócio como testes`
- **Website:** a URL do Pages
- **Topics:** `dbt`, `duckdb`, `analytics-engineering`, `data-quality`,
  `data-testing`, `sql`

Os topics são o que faz o repositório aparecer em busca, e a descrição é a
única coisa que alguém lê antes de decidir se abre.

---

## Depois: mudar alguma coisa

Sempre o mesmo ciclo, no GitHub Desktop:

1. edite os arquivos na pasta, normalmente
2. o Desktop mostra o que mudou, linha por linha
3. escreva um Summary e clique em **Commit to main**
4. clique em **Push origin**, no topo

O push é o que manda para o GitHub. Commit sozinho só salva no seu computador.

---

## Quando der errado

| o que aparece | o que é |
|---|---|
| ❌ no workflow **docs**, erro mencionando `pages` | o passo 6 não foi feito, ou foi feito depois da rodada. Refaça e rode de novo pelo Actions |
| ❌ no workflow **ci**, no passo `Regenerate seeds` | algum arquivo de `seeds/` foi editado à mão. Rode `python scripts/generate_seeds.py` e faça commit do resultado |
| O site do Pages abre em branco | ainda está publicando. Espere 2 minutos e recarregue com Ctrl+Shift+R |
| **Publish repository** desabilitado | falta fazer o commit do passo 4 |
| Os commits não aparecem no seu perfil | o e-mail do passo 2 é diferente do e-mail da conta. GitHub Desktop: **Settings → Git** |

---

## Uma coisa para decidir antes

O README descreve o projeto como reimplementação de um sistema que roda em
produção. Nenhum dado, nome ou número real está aqui — tudo é sintético e
gerado por script. Ainda assim, vale conferir com quem é de direito se o
código original é seu antes de publicar, e decidir se você quer manter essa
frase no README ou falar do projeto de forma mais genérica.

Se quiser trocar o nome fictício da empresa, ele está só em
`scripts/generate_seeds.py` (a constante `DOMAIN`). Troque, rode o script de
novo, e faça commit dos `seeds/` regerados.
