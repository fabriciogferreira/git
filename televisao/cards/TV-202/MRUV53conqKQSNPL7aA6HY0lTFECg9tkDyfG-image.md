# Análise da imagem

## Metadados da mídia (fonte OlieFlowAi)

| Campo | Valor |
| --- | --- |
| Projeto | TV-202 |
| Media `id` | `MRUV53conqKQSNPL7aA6HY0lTFECg9tkDyfG-image` |
| `name` | Não identificado na imagem. Nó TipTap `image` da thread «Página principal», versão `6kA41fUIrQ0AwiMqGELQ0blAmPAvSgQ2`. |
| `technical_name` | Não identificado na imagem. |
| `type` | image |
| `extension` | png |
| `created_at` | Não identificado na imagem. |
| Autor | Não identificado na imagem. |
| Arquivo local | `~/git/televisao/cards/TV-202/MRUV53conqKQSNPL7aA6HY0lTFECg9tkDyfG-image.md` |

## Contexto da tela

Recorte da tela de consulta do dashboard, em tema escuro. Não há barra de endereço, título do navegador nem URL visível na imagem. O conteúdo visível é o cartão de uma receita e o início da seção «Outras informações».

## Estrutura da interface

- Cartão com borda arredondada no topo, ocupando a maior parte do recorte.
- Cabeçalho do cartão à esquerda: ícone azul de documento e o título «TESTE 1».
- Selo cinza «Assinada» logo abaixo do título.
- Grade de dados no corpo do cartão: à esquerda, «Data da prescrição» e «Observações»; à direita, «Adição (D)».
- Botão com ícone de download na parte inferior do cartão.
- Abaixo do cartão, o título «Outras informações» e um subtítulo parcialmente cortado na borda esquerda.
- Dois cartões menores lado a lado: «Médico» e «Clínica».
- Mais abaixo, um título cortado («…egistro») e uma linha de texto cortada.
- Toast vermelho flutuante no canto inferior direito, sobre o conteúdo.

## Textos

- TESTE 1
- Assinada
- Data da prescrição
- 01/10/2026, 14:18:15
- Observações
- Vamos lá testar
- Adição (D)
- 0.05
- Baixar receita assinada
- Outras informações
- …elação com médico e clínica.
- Médico
- Allan Teste
- Médico atribuído
- Clínica
- Felipeeeee
- …egistro
- …istórico de criação e atualização.
- Documento assinado não encontrado para esta receita.

## Elementos interativos

- Botão «Baixar receita assinada», com ícone de download, na base do cartão da receita. Aparência de botão outline, sem estado de loading, foco ou desabilitado visível.
- Selo verde «Médico atribuído». Aparência de etiqueta, não de botão pressionado.
- Nenhum campo de formulário, checkbox, aba ou menu aberto está visível.

## Estados visuais

- Selo «Assinada» em cinza, indicando o estado exibido da receita.
- Selo verde «Médico atribuído».
- Toast vermelho com ícone de exclamação, aberto no canto inferior direito. O vermelho e o ícone indicam erro.

## Erros e problemas

Mensagem do toast, transcrita como aparece:

> Documento assinado não encontrado para esta receita.

O selo «Assinada» e o botão «Baixar receita assinada» aparecem ao mesmo tempo que esse erro. Não há stack trace, status HTTP, console nem DevTools na imagem.

## DevTools e informações técnicas

Nenhuma informação relevante identificada na imagem.

## Código visível

Nenhuma informação relevante identificada na imagem.

## Relações entre elementos

O toast de erro está sobre a área inferior da página, à direita dos cartões de médico e clínica. O botão «Baixar receita assinada» pertence ao cartão «TESTE 1», o mesmo que mostra o selo «Assinada». Não é possível determinar pela imagem se o toast foi disparado por esse botão; a posição só mostra que os dois estão na mesma tela.

## Interpretação

A imagem sugere a tela de visualização de uma consulta, com a receita «TESTE 1» marcada como assinada e o botão de baixar a receita assinada visível. Aparentemente o problema que chamou a atenção é o toast «Documento assinado não encontrado para esta receita.» enquanto a interface ainda trata a receita como assinada. Possivelmente o clique em baixar não entregou o PDF. Não é possível confirmar pela imagem a causa, o endpoint nem se o arquivo chegou a ser gravado.

## Não determinável pela imagem

- URL e ambiente (a thread do card aponta um link de preview; a imagem em si não mostra a barra de endereço).
- Se o toast apareceu logo após o clique em «Baixar receita assinada».
- Status HTTP, corpo da resposta e endpoint.
- Se o PDF assinado existe no armazenamento.
- Regra de negócio esperada além do texto do card.
- Permissões do usuário logado.

# Resumo para Coding Agent

## Contexto visual

Consulta em tema escuro. Receita «TESTE 1» com selo «Assinada», data 01/10/2026 14:18:15, observação «Vamos lá testar», adição (D) 0.05, médico «Allan Teste» e clínica «Felipeeeee». Botão «Baixar receita assinada» visível.

## Problema observado

Toast de erro: «Documento assinado não encontrado para esta receita.» A receita continua exibida como «Assinada» e o botão de download continua na tela.

## Evidências

- Texto do toast: «Documento assinado não encontrado para esta receita.»
- Selo: «Assinada»
- Botão: «Baixar receita assinada»
- Título da receita: «TESTE 1»
- Médico: «Allan Teste»; clínica: «Felipeeeee»
- URL, HTTP status, console e DevTools: não identificados na imagem

## Hipóteses

- A interface considera a receita assinada, mas a API responde que o documento assinado não existe. Hipótese, não fato.
- O arquivo pode não ter sido gravado, ou o caminho gravado não existe no disco consultado no download. Hipótese, não fato.

## Informações não determináveis

- Causa do erro.
- Endpoint e status HTTP.
- Se o comportamento é só desta receita ou de toda assinatura.
- Conteúdo esperado do PDF.

## Elementos técnicos identificados

- URL: Não identificado na imagem.
- Domínio: Não identificado na imagem.
- Rota: Não identificado na imagem.
- Página: tela de consulta com receita, médico e clínica. Nome exato da rota não identificado na imagem.
- Componente aparente: cartão de receita com botão «Baixar receita assinada» e toast de erro.
- Elemento HTML aparente: botão e alerta/toast.
- ID: Não identificado na imagem.
- Classes: Não identificado na imagem.
- HTTP method: Não identificado na imagem.
- HTTP status: Não identificado na imagem.
- Endpoint: Não identificado na imagem.
- Erro: Documento assinado não encontrado para esta receita.
- Mensagem: Documento assinado não encontrado para esta receita.
- Console: Não identificado na imagem.
- DevTools: Não identificado na imagem.
- Outros: receita «TESTE 1»; selo «Assinada».

## Mensagem original do cliente

Ver Consulta - Não consigo baixar a receita assinada

Problema encontrado
Download da receita assinada não pega

Impacto
Baixo, mas não pega a funcionalidade completa.

Passos para reproduzir
Deixei no anexo o resultado pronto. Mas se for reproduzir: assinar uma receita e clicar em baixar

Resultado atual
Assinei o documento, mas o botão de 'baixar' não pega

Resultado esperado
Deveria poder baixar normalmente

Referências e anexos
https://televisao.dashboard.enterscience.com.br/dashboard/consultations/view/01a0f85d-c802-7363-aeb5-398f09510ef4

Usuário:
@ agccontessoto@gmail.com

A senha que acompanhava essa mensagem no fórum não entra neste arquivo.

## Instrução para o Coding Agent

Trate o toast e o selo «Assinada» como contexto. Não implemente só com a captura. Antes de alterar código, localize a rota de download da receita assinada, o ponto em que o status passa a SIGNED e o disco em que o PDF é gravado. Confirme no código que o texto «Documento assinado não encontrado para esta receita.» e o botão «Baixar receita assinada» são os elementos da imagem. O resultado esperado informado pelo cliente é baixar o documento normalmente depois de assinado. Preserve o restante do fluxo de receita.

PRONTO PARA INVESTIGAÇÃO

## Classificação

PRONTO PARA INVESTIGAÇÃO
