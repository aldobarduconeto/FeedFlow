abstract final class FeedCategories {
  static const defaultCategories = <String>[
    'Notícias',
    'Tecnologia',
    'Ciência',
    'Economia & Negócios',
    'Cultura & Geek',
    'Esportes',
    'Design & Arte',
    'Saúde & Bem-Estar',
    'Podcasts',
    'Personalizados',
  ];

  static const exploreCategories = <String>[
    'Tudo',
    'Notícias',
    'Tecnologia',
    'Ciência',
    'Economia & Negócios',
    'Cultura & Geek',
    'Esportes',
    'Design & Arte',
    'Saúde & Bem-Estar',
    'Podcasts',
  ];
}

class SuggestedFeed {
  const SuggestedFeed({
    required this.name,
    required this.description,
    required this.url,
    required this.category,
    this.isPodcast = false,
  });

  final String name;
  final String description;
  final String url;
  final String category;
  final bool isPodcast;
}

const suggestedFeeds = <SuggestedFeed>[
  // NOTÍCIAS
  SuggestedFeed(
    name: 'Agência Brasil',
    description: 'Notícias nacionais e serviço público oficial.',
    url: 'https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml',
    category: 'Notícias',
  ),
  SuggestedFeed(
    name: 'G1',
    description: 'Manchetes, reportagens e últimas notícias do Brasil.',
    url: 'https://g1.globo.com/rss/g1/',
    category: 'Notícias',
  ),
  SuggestedFeed(
    name: 'BBC News Brasil',
    description: 'Jornalismo internacional e análises aprofundadas.',
    url: 'https://feeds.bbci.co.uk/portuguese/rss.xml',
    category: 'Notícias',
  ),
  SuggestedFeed(
    name: 'El País Brasil',
    description: 'Cobertura global e artigos de opinião.',
    url: 'https://brasil.elpais.com/rss/brasil_completo.xml',
    category: 'Notícias',
  ),

  // TECNOLOGIA
  SuggestedFeed(
    name: 'Tecnoblog',
    description: 'Notícias de tecnologia, análises e cultura digital.',
    url: 'https://tecnoblog.net/feed/',
    category: 'Tecnologia',
  ),
  SuggestedFeed(
    name: 'MacMagazine',
    description: 'Universo Apple, produtos e tendências tecnológicas.',
    url: 'https://macmagazine.com.br/feed/',
    category: 'Tecnologia',
  ),
  SuggestedFeed(
    name: 'Olhar Digital',
    description: 'Inovação, internet, segurança e gadgets.',
    url: 'https://olhardigital.com.br/feed/',
    category: 'Tecnologia',
  ),
  SuggestedFeed(
    name: 'The Verge',
    description: 'O futuro da tecnologia, ciência, arte e cultura.',
    url: 'https://www.theverge.com/rss/index.xml',
    category: 'Tecnologia',
  ),
  SuggestedFeed(
    name: 'Ars Technica',
    description: 'Tecnologia aprofundada, software e hardware.',
    url: 'https://feeds.arstechnica.com/arstechnica/index',
    category: 'Tecnologia',
  ),

  // CIÊNCIA
  SuggestedFeed(
    name: 'NASA News',
    description: 'Missões espaciais, astronomia e exploração cósmica.',
    url: 'https://www.nasa.gov/feed/',
    category: 'Ciência',
  ),
  SuggestedFeed(
    name: 'Revista Galileu',
    description: 'Ciência, universo, meio ambiente e sociedade.',
    url: 'https://revistagalileu.globo.com/rss/ultimas/feed.xml',
    category: 'Ciência',
  ),
  SuggestedFeed(
    name: 'Scientific American',
    description: 'Pesquisas e avanços científicos mundiais.',
    url: 'https://www.scientificamerican.com/feed/',
    category: 'Ciência',
  ),

  // ECONOMIA & NEGÓCIOS
  SuggestedFeed(
    name: 'InfoMoney',
    description: 'Mercados, ações, investimentos e finanças pessoais.',
    url: 'https://www.infomoney.com.br/feed/',
    category: 'Economia & Negócios',
  ),
  SuggestedFeed(
    name: 'Exame',
    description: 'Negócios, economia, inovação e ESG.',
    url: 'https://exame.com/feed/',
    category: 'Economia & Negócios',
  ),
  SuggestedFeed(
    name: 'Valor Econômico',
    description: 'Macroeconomia, políticas fiscais e empresas.',
    url: 'https://valor.globo.com/rss/valor/',
    category: 'Economia & Negócios',
  ),

  // CULTURA & GEEK
  SuggestedFeed(
    name: 'Omelete',
    description: 'Cinema, séries de TV, quadrinhos e cultura pop.',
    url: 'https://www.omelete.com.br/feed/',
    category: 'Cultura & Geek',
  ),
  SuggestedFeed(
    name: 'Jovem Nerd',
    description: 'Novidades geek, games, entretenimento e humor.',
    url: 'https://jovemnerd.com.br/feed/',
    category: 'Cultura & Geek',
  ),
  SuggestedFeed(
    name: 'Rolling Stone Brasil',
    description: 'Música, cultura contemporânea, filmes e entrevistas.',
    url: 'https://rollingstone.uol.com.br/rss/',
    category: 'Cultura & Geek',
  ),

  // ESPORTES
  SuggestedFeed(
    name: 'Globo Esporte (ge)',
    description: 'Futebol, basquete, vôlei, automobilismo e resultados.',
    url: 'https://ge.globo.com/rss/ge/',
    category: 'Esportes',
  ),
  SuggestedFeed(
    name: 'Trivela',
    description: 'Futebol brasileiro e internacional com análises táticas.',
    url: 'https://trivela.com.br/feed/',
    category: 'Esportes',
  ),

  // DESIGN & ARTE
  SuggestedFeed(
    name: 'Smashing Magazine',
    description: 'Design de interfaces, tipografia e desenvolvimento web.',
    url: 'https://www.smashingmagazine.com/feed/',
    category: 'Design & Arte',
  ),
  SuggestedFeed(
    name: 'UX Collective',
    description: 'Artigos sobre experiência do usuário e design thinking.',
    url: 'https://uxdesign.cc/feed',
    category: 'Design & Arte',
  ),

  // SAÚDE & BEM-ESTAR
  SuggestedFeed(
    name: 'VivaBem UOL',
    description: 'Saúde integral, alimentação, longevidade e medicina.',
    url: 'https://noticias.uol.com.br/saude/ultimas-noticias/index.xml',
    category: 'Saúde & Bem-Estar',
  ),

  // PODCASTS
  SuggestedFeed(
    name: 'NerdCast',
    description: 'Debates descontraídos sobre cinema, história, RPG e ciência.',
    url: 'https://jovemnerd.com.br/feed-nerdcast/',
    category: 'Podcasts',
    isPodcast: true,
  ),
  SuggestedFeed(
    name: 'Podcast Unesp',
    description: 'Divulgação científica e acadêmica em formato de áudio.',
    url: 'https://podcast.unesp.br/rss',
    category: 'Podcasts',
    isPodcast: true,
  ),
  SuggestedFeed(
    name: 'Café da Manhã',
    description: 'O resumo das notícias mais importantes do dia pela Folha.',
    url: 'https://feeds.simplecast.com/82fxu2yq',
    category: 'Podcasts',
    isPodcast: true,
  ),
  SuggestedFeed(
    name: 'Os Sócios Podcast',
    description: 'Empreendedorismo, negócios, finanças e desenvolvimento.',
    url: 'https://anchor.fm/s/549c4038/podcast/rss',
    category: 'Podcasts',
    isPodcast: true,
  ),
];
