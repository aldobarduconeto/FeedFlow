# FeedFlow

Aplicativo Flutter para acompanhar notícias de feeds RSS/Atom e ouvir podcasts.
As assinaturas, publicações, preferências e posições de leitura/reprodução são
armazenadas localmente. O aplicativo não usa um servidor de contas nem sincroniza
seus dados entre dispositivos.

## Navegação simplificada

O app tem três destinos principais: **Notícias**, **Podcasts** e **Explorar**.
As antigas abas **Início** e **Inscrições** foram reunidas em Notícias;
**Configurações** abre pelo botão de ajustes no cabeçalho, sem ocupar uma aba.

- **Notícias:** linha do tempo cronológica das fontes seguidas, busca por texto
  e filtros de mais recentes, não lidas, salvas e continuar leitura. Um menu
  permite filtrar por fonte; o botão de gerenciamento reúne as assinaturas de
  notícias. Os cards usam a apresentação editorial e abrem o leitor completo.
- **Podcasts:** inscrições em cards horizontais, episódios em andamento e
  recentes sem duplicação. Downloads ficam em **Episódios baixados**, uma seção
  recolhível com contagem. A fila **A seguir** abre pelo botão no cabeçalho da
  área e continua disponível no player.
- **Explorar:** catálogo por categoria, busca de fontes e prévias dos feeds.
  Seguir uma fonte é uma ação explícita; não há limite de assinaturas no app.
- **Adicionar por URL:** aceita RSS/Atom, páginas que anunciam seus feeds e canais
  do YouTube por `/channel/ID` ou por páginas que publiquem seu feed/ID. Sites
  sem um feed anunciado precisam da URL RSS/Atom direta.
- **Atualizar conteúdos:** ação única no cabeçalho principal, disponível em todas
  as três áreas. Também é possível puxar a lista de Notícias para atualizar ou
  usar **Configurações > Dados > Recarregar dados**. As sugestões se atualizam
  a cada 30 minutos enquanto o app está em primeiro plano.

No celular, a navegação inferior mostra apenas três opções. A partir de 720 px,
uma barra lateral compacta substitui a navegação inferior; a partir de 1200 px,
ela passa a mostrar rótulos ao lado dos ícones. O conteúdo tem largura limitada,
e a leitura de notícias mantém uma coluna confortável de até 840 px.
A troca entre as áreas preserva o estado dos filtros e da navegação; o mini
player continua acessível. As configurações abrem em uma tela com botão de voltar.

A importação e a exportação OPML foram removidas, incluindo telas, serviços,
seletor de arquivos e canais nativos de exportação. As fontes existentes
permanecem salvas; novas fontes são adicionadas por URL ou pelo catálogo.

## Limites de consulta e episódios baixados

Os limites solicitados às APIs de descoberta foram triplicados:

| Consulta | Limite anterior | Novo limite |
| --- | ---: | ---: |
| Busca geral (RSS Amplifier `/search`) | 20 | 60 |
| Busca de podcasts (p0dcasters `/search`) | 10 | 30 |
| Catálogo por categoria (RSS Amplifier `/feeds`), incluindo Podcasts | 30 | 90 |
| Itens recentes considerados por prévia RSS/Atom | 10 | 30 |

O aumento altera o parâmetro `limit` das consultas existentes; não adiciona
paginação por cursor ou carregamento de páginas consecutivas. Os serviços podem
retornar menos resultados do que o limite solicitado. As prévias do catálogo
continuam mostrando até três publicações por card; até 30 itens disponíveis no
RSS são considerados na prévia e na ordenação das sugestões. As fontes seguidas
continuam carregando os itens fornecidos pelo feed, sem esse corte de prévia.

Na aba **Podcasts**, a seção recolhível **Episódios baixados** aparece após as
inscrições, com contagem e indicação de reprodução offline. Toque para expandir
os cards completos ou consultar o estado vazio explicando como baixar. O filtro de programa também se aplica a essa seção.
Quando um download termina, o episódio passa para os baixados e deixa de
aparecer em **Continue ouvindo** e **Episódios recentes** dessa aba. Seu progresso
continua salvo e pode ser retomado no próprio card de download. A fila manual
**A seguir** é independente: um episódio baixado ainda pode estar nela.

## Cards de notícias e podcasts

Os cards de **Notícias** e **Podcasts** compartilham a mesma base visual:

- Notícias em formato de portal: imagem panorâmica no topo, categoria editorial,
  manchete com tipografia serifada, resumo, fonte, autor quando disponível, data
  e tempo de leitura. Favoritos e progresso aparecem em controles discretos.
- Podcasts com capa quadrada, título, duração, resumo e destaque do episódio em
  reprodução.
- Favoritos, progresso de leitura/reprodução e indicação de conteúdo offline.
- Ações de leitura ou abertura do episódio, reprodução, download e inclusão na
  fila; os controles se reorganizam quando falta espaço horizontal.
- Bordas arredondadas, sombras suaves e cores adaptadas aos temas claro,
  escuro e preto OLED. Imagens indisponíveis usam um placeholder.

## Inscrições em cards horizontais

A aba **Podcasts** exibe **Suas inscrições** em uma fileira horizontal com todos
os programas seguidos, ordenados pela publicação mais recente. Cada card tem
capa quadrada, nome e data relativa do último episódio disponível. Programas
identificados como podcasts também aparecem quando ainda não têm episódios.

- No celular, deslize os cards para os lados.
- No computador, arraste com o mouse, use o trackpad ou a barra de rolagem.
- Em ambos, use as setas **Ver mais inscrições** e **Ver inscrições anteriores**.
  Elas se desativam nos limites da lista e quando todos os cards cabem na tela.
- Com o foco na seção, as teclas de seta esquerda e direita também navegam.
- Toque ou clique em um card para abrir a página individual do programa.
  Ao voltar, o filtro selecionado pode ser removido pelo X em **Filtrando**.
- O botão **Gerenciar inscrições** mantém o acesso à lista de assinaturas.

As datas representam o episódio mais recente recebido do RSS, não o horário da
última sincronização. Capas ausentes usam um placeholder, sem inventar imagens.

## Página individual de cada podcast

Na aba **Podcasts**, toque no card de um programa para abrir sua página. O nome
da fonte nos cards de episódios também abre essa página. A seleção do programa
continua disponível como filtro ao voltar para a biblioteca.

- Capa grande e centralizada, nome do programa e botão **Último episódio**.
- Fundo imersivo com degradê extraído da capa do canal, inclusive quando o tema
  geral é claro ou OLED. Os textos usam contraste claro nessa página.
- A capa do canal é salva a partir do RSS; fontes antigas usam a imagem de um
  episódio até a próxima atualização. Falhas de imagem usam um placeholder e
  um fundo padrão.
- Descrição expansível, categoria, quantidade de episódios e data da publicação
  mais recente, conforme os dados disponíveis. Avaliações não são inventadas.
- Filtros de todos, não ouvidos e baixados; ordenação por mais recentes ou mais
  antigos. **Não ouvidos** usa a marcação local de ouvido/lido.
- Episódios em linhas editoriais com data, título, resumo e botão de reprodução.
  Baixados ficam em um grupo próprio. A ordem escolhida é aplicada em cada grupo.
- Menu por episódio para fila, download, favoritos e marcação de ouvido.
- Controle de seguir/deixar de seguir com confirmação antes de remover o
  programa, opção de copiar o feed e mini player no rodapé.

## Leitura e aparência

O leitor apresenta o texto do feed sem executar scripts. **Ler texto completo
do site** tenta extrair o artigo original, removendo navegação, barras laterais
e elementos comuns de publicidade. Se o site bloquear o acesso, exigir
JavaScript ou não disponibilizar o artigo, o conteúdo do feed continua acessível.

Em **Ajustar texto** ou nas configurações de aparência, escolha:

- Tema claro, escuro ou preto OLED.
- Tamanho da fonte e fonte com ou sem serifa.
- Margens e alinhamento do texto.

As preferências e o progresso são salvos localmente. O player e a página do
programa usam cores derivadas da capa. A página individual tem fundo imersivo
colorido; os demais fundos respeitam o tema OLED preto.

## Podcasts e reprodução

- Reprodução online ou de episódios baixados na pasta privada do aplicativo.
- Play/pause, avanço de 30 segundos, retorno de 15 segundos, busca na posição e
  retomada do ponto salvo.
- Velocidade de **0,8x a 2x**, em passos de 0,05x, lembrada por programa.
- **Capítulos:** Podlove Simple Chapters no RSS, JSON do Podcasting 2.0 e
  horários publicados na descrição. Toque para ir ao trecho. O app não inventa
  capítulos para episódios sem esses dados.
- **A seguir:** fila manual acessível pelo botão de fila em Podcasts e pelo
  player, separada de recentes e de **Continue ouvindo**.
  Use **Reproduzir a seguir** ou **Adicionar ao fim da fila**, arraste para
  ordenar e remova episódios individualmente ou limpe a fila. Ao terminar um
  episódio, o próximo começa automaticamente. A fila dura durante a sessão.

### Aprimorar diálogo

O controle do player aplica processamento real ao sinal de áudio: atenua graves
em torno de 200 Hz, realça a presença da voz em torno de 2 kHz e reserva margem
de volume para reduzir saturação. Desativar o controle remove essa equalização.
O efeito não separa vozes de música e não é um cancelador de ruído por IA.

| Plataforma | Implementação | Requisitos e limites |
| --- | --- | --- |
| Android | Filtros de áudio libmpv/FFmpeg via media_kit | Bibliotecas nativas incluídas no pacote de áudio |
| iOS | Mesmo perfil de filtros nativos | Requer compilação e validação em ambiente Apple |
| macOS | Mesmo perfil de filtros nativos | Requer compilação e validação em ambiente Apple |
| Windows | Mesmo perfil de filtros nativos | Bibliotecas nativas do media_kit |
| Linux | Mesmo perfil de filtros nativos | libmpv instalado no sistema |
| Web | Web Audio: filtros biquad e ganho | Navegador compatível, autorização de reprodução e servidor de áudio com CORS |

No navegador, fontes que recusam CORS são abertas por reprodução comum e o
controle de efeito fica indisponível para aquele episódio. A ativação do efeito
e a reprodução podem depender de um gesto do usuário. Falhas do motor são
exibidas no player; a preferência só é ativada após aplicar o filtro.

A cobertura acima descreve as implementações adicionadas, não uma certificação
de testes em todos os dispositivos. As últimas tentativas de executar testes e validações foram recusadas;
ainda não houve compilação nem verificação auditiva em dispositivo para essas
integrações. Os novos limites de consulta e a seção de baixados também ainda
não foram verificados por testes automatizados.

Referências técnicas: [media_kit](https://github.com/media-kit/media-kit),
[filtros de áudio do mpv](https://mpv.io/manual/stable/#audio-filters),
[Web Audio](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
e [capítulos do Podcasting 2.0](https://podcasting2.org/docs/podcast-namespace/tags/chapters).

## Armazenamento e limitações atuais

O `SharedPreferences` guarda fontes, publicações, configurações, aparência e
velocidades por programa. Downloads ficam no armazenamento privado do app.
Limpar dados ou desinstalar o aplicativo pode remover esse conteúdo.

As opções legadas de rede, intervalo de atualização, retenção, pular silêncios e
reprodução automática das configurações ainda não controlam os respectivos
serviços. A fila tem avanço automático próprio. O salvamento de progresso é
feito pelos serviços de leitura e reprodução.

## Executar e verificar

Requer Flutter compatível com o SDK Dart indicado em `pubspec.yaml`:

```bash
flutter pub get
flutter run
```

No Linux, instale `libmpv-dev` e `mpv` pelo gerenciador de pacotes da distribuição
antes de compilar. As bibliotecas de áudio de Android, iOS, macOS e Windows são
fornecidas pelos plugins `media_kit_libs_audio`; a compilação pode precisar baixar
os binários nativos. Os alvos Apple precisam de macOS e Xcode.

```bash
flutter analyze
flutter test
```

## Estrutura principal

- `lib/src/services/feed_service.dart`: RSS/Atom, descoberta por URL, assinaturas,
  persistência, downloads e progresso.
- `lib/src/services/podcast_player_service.dart`: fila, transporte, velocidade
  por programa e preferência de aprimoramento de diálogo.
- `lib/src/services/podcast_audio_engine.dart`: ponte para o motor de áudio.
- `lib/src/services/effects_backend_native.dart`: reprodução e filtros nativos.
- `lib/src/services/effects_backend_web.dart`: reprodução e Web Audio.
- `lib/src/services/audio_backend.dart`: contrato e perfil compartilhado do efeito.
- `lib/src/services/chapter_service.dart`: capítulos e horários da descrição.
- `lib/src/services/reader_service.dart`: limpeza e extração do texto dos artigos.
- `lib/src/services/appearance_service.dart`: preferências persistidas de aparência.
- `lib/src/app.dart`: navegação de três áreas, cabeçalho e configurações.
- `lib/src/views/news_page.dart`: linha do tempo, busca, filtros e fontes de notícias.
- `lib/src/views/widget/feed_content_card.dart`: cards de notícias e episódios.
- `lib/src/views/podcast_show_page.dart`: página individual de programa, capa,
  filtros, ordenação e ações por episódio.
- `lib/src/views/podcast_player_page.dart`: player completo e controles.
- `lib/src/views/article_reader.dart`: leitor e progresso.

O ícone principal é `assets/icon.png`. Para gerar novamente as variações:

```bash
dart run flutter_launcher_icons
```
