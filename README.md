# FeedFlow

Aplicativo Flutter para acompanhar feeds RSS e Atom e ouvir podcasts em um só
lugar. As contas e os dados são locais: o FeedFlow não usa um servidor de
autenticação nem sincroniza os dados entre dispositivos.

## Funcionalidades

- Cadastro e login local por nome de usuário e senha, sem solicitar e-mail.
- Geração de um ID aleatório e único para cada conta, exibido no perfil das
  configurações.
- Identificador da sessão salvo no `SharedPreferences`.
- Senhas guardadas no armazenamento seguro do sistema, por meio de
  `flutter_secure_storage`.
- Adição de feeds RSS ou Atom pela URL informada pelo usuário.
- Catálogo com uma lista curada de fontes RSS de notícias, tecnologia, ciência
  e podcasts na aba **Explorar**. As prévias são carregadas dos feeds atuais,
  podem ser filtradas por categoria e adicionadas em um toque. O app consulta
  até dez publicações recentes por feed para calcular a ordenação e exibe até
  três no cartão; seguir uma fonte é uma ação explícita do usuário.
- Atualização das sugestões ao abrir o app, ao usar **Configurações > Dados**
  e a cada 30 minutos enquanto o aplicativo está em primeiro plano. O
  temporizador é suspenso em segundo plano. A última consulta concluída aparece em destaque.
- Ordenação das sugestões por **Mais novos** (data de publicação mais recente)
  ou **Mais atualizados** (maior número de publicações nos últimos 30 dias,
  considerando até dez itens recentes de cada RSS).
- Filtros de notícias, tecnologia, ciência e podcasts, busca de fontes e opção
  de adicionar qualquer feed RSS ou Atom por URL.
- Lista de fontes seguidas, artigos e episódios na aba **Inscrições**, além da
  opção de adicionar uma URL RSS personalizada.
- Tela **Início** com artigos e episódios que têm progresso salvo em
  **Continue de onde parou** e itens recentes ainda não abertos em **Atualizações**. A lista
  completa de fontes e publicações fica na aba **Inscrições**.
- Atualização dos feeds cadastrados ao iniciar o app e ao solicitar uma
  recarga manual.
- Recarga manual de feeds seguidos e sugestões centralizada em
  **Configurações > Dados > Recarregar dados**.
- Perfil e opção de sair da conta disponíveis em **Configurações**.
- Layout compacto com navegação inferior em celulares na vertical; em telas
  grandes e na orientação horizontal, navegação por drawer e conteúdo central
  com largura limitada para melhor aproveitamento do espaço.
- Identificação de episódios com áudio e download no armazenamento privado do
  aplicativo, disponível nas telas **Início** e **Inscrições**. Depois
  de baixado, o player usa o arquivo local para reprodução offline.
- Reprodução de podcasts online ou baixados, com controles de play/pause,
  busca na posição e retomada do ponto salvo.
- Separação local dos feeds e artigos por conta.
- Ícone do FeedFlow aplicado às plataformas disponíveis e nas telas de entrada.

As opções de personalização e reprodução também são exibidas nas configurações
e salvas localmente. No estado atual, ainda não alteram o comportamento de
leitura, rede ou reprodução; a recarga manual, o perfil e a saída da conta são
as ações de configurações conectadas ao funcionamento do app.

## Dados e armazenamento

O `SharedPreferences` guarda o cadastro local (ID e nome de usuário), o ID da
sessão ativa, as configurações e os dados serializados das fontes e artigos. Os
dados do FeedFlow são armazenados por usuário, usando o ID da conta na chave de
armazenamento. O login aceita somente nome de usuário e senha. Contas antigas
criadas apenas com e-mail não são compatíveis; é necessário criar uma nova conta
local com nome de usuário.

Na criação da primeira conta após uma atualização, os feeds já salvos na versão
anterior são copiados para o perfil local. O cadastro antigo baseado em e-mail
não é migrado para autenticação por nome de usuário.

As senhas não são gravadas no `SharedPreferences`: ficam no armazenamento seguro
do dispositivo. Os arquivos de áudio baixados são salvos na pasta privada de
documentos do aplicativo. Encerrar a sessão não apaga a conta nem os seus feeds.

Como o login é somente local, ele serve para separar perfis neste dispositivo;
não verifica identidade em um serviço remoto e não permite recuperar uma conta
em outro dispositivo. Desinstalar o aplicativo ou limpar os dados pode remover
as informações locais.

## Uso

1. Abra o aplicativo e crie uma conta local com um nome de usuário de 3 a 24
   caracteres ou entre com uma conta por nome de usuário já criada neste
   dispositivo. Contas antigas que usavam somente e-mail precisam ser recriadas.
   Um ID aleatório é gerado para cada nova conta.
2. Abra **Explorar** pelo menu inferior no celular em retrato ou pelo drawer em
   telas largas e na orientação paisagem. Escolha uma sugestão e toque em
   **Seguir**, ou use **Adicionar por URL** para informar um feed personalizado.
   Consulte sua lista completa de fontes e publicações em **Inscrições**.
3. Informe a URL completa `http://` ou `https://` do feed e escolha uma
   categoria. A fonte só é salva depois que o FeedFlow consegue carregar e
   interpretar o RSS ou Atom.
4. Na tela **Início**, retome artigos e episódios com progresso salvo ou
   confira **Atualizações** para ver os itens recentes ainda não abertos. A aba
   **Inscrições** reúne as fontes e suas publicações. Para buscar novidades de
   suas fontes e do catálogo de sugestões, use
   **Configurações > Dados > Recarregar dados**.
5. Na aba **Inscrições**, encontre as fontes seguidas e suas publicações; use os
   botões dos episódios para baixar e ouvir offline ou para reproduzir, pausar,
   avançar e retomar. Na tela inicial, episódios com áudio também podem ser
   baixados.

O catálogo **Explorar** reúne sugestões de fontes RSS definidas no aplicativo e
consulta o conteúdo atual desses feeds; a lista de fontes recomendadas não é
gerada por um serviço remoto. A aba **Inscrições** mostra apenas as fontes que
você adicionou à sua conta local. O app não cria artigos de
demonstração. Fontes fora do catálogo podem ser incluídas por **Adicionar por
URL**.

### Atualização e ordenação do catálogo

- Ao abrir o aplicativo, a tela **Explorar** consulta as sugestões RSS.
- Use **Configurações > Dados > Recarregar dados** para atualizar manualmente
  as fontes seguidas e as sugestões. A consulta automática do catálogo ocorre
  a cada 30 minutos enquanto o aplicativo está em primeiro plano e também
  quando ele volta do segundo plano. A atualização das fontes seguidas ocorre
  ao iniciar o app ou por essa recarga manual.
- O destaque **Última atualização** indica quando a consulta ao catálogo foi
  concluída. Cada cartão também mostra a data da publicação mais recente
  disponível no feed, quando o RSS fornece essa informação.
- **Mais novos** ordena pelas datas das publicações recentes. **Mais
  atualizados** prioriza a quantidade de itens publicados nos últimos 30 dias,
  usando até os dez itens mais recentes fornecidos por cada feed.
- Uma falha em um RSS não impede a exibição das outras sugestões. O cartão da
  fonte com erro indica que a prévia está indisponível no momento.

## Estrutura principal

- `lib/src/services/auth_service.dart`: cadastro local, login, sessão e IDs.
- `lib/src/services/feed_service.dart`: leitura RSS/Atom, persistência,
  atualização, posição de reprodução e download de podcasts.
- `lib/src/services/suggestion_service.dart`: atualização das prévias RSS do
  catálogo de sugestões sem seguir ou salvar as fontes automaticamente.
- `lib/src/services/podcast_player_service.dart`: reprodução multiplataforma e
  retomada da posição dos episódios.
- `lib/src/models/feed_source.dart`: modelo das fontes.
- `lib/src/models/feed.dart`: modelo dos artigos e episódios.
- `lib/src/views/auth_page.dart`: telas de cadastro e login.
- `lib/src/views/explore.dart`: catálogo dinâmico **Explorar**, com
  fontes e episódios de podcast.
- `lib/src/views/settings.dart`: preferências, perfil, ID da conta, recarga dos
  dados e saída da conta.
- `lib/src/views/home.dart`: artigos, episódios e gerenciamento das fontes.
- `lib/src/views/home.dart`: painéis **Continue de onde parou** e **Atualizações**.
## Executar

Requer Flutter instalado e as dependências resolvidas:

```bash
flutter pub get
flutter run
```

Para analisar o código:

```bash
flutter analyze
```

O repositório ainda não contém testes automatizados.

O ícone principal é `assets/icon.png`. Para gerar novamente as variações para
Android, iOS, macOS, Windows e Web após substituí-lo, execute:

```bash
dart run flutter_launcher_icons
```

No Linux, o CMake instala a versão de 512 px no tema Hicolor com o ID da
aplicação, para que o ambiente desktop possa encontrá-la.
