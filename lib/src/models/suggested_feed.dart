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
  SuggestedFeed(
    name: 'Agência Brasil',
    description: 'Notícias nacionais e serviço público.',
    url: 'https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml',
    category: 'Notícias',
  ),
  SuggestedFeed(
    name: 'G1',
    description: 'Manchetes e notícias do Brasil e do mundo.',
    url: 'https://g1.globo.com/rss/g1/',
    category: 'Notícias',
  ),
  SuggestedFeed(
    name: 'BBC News Brasil',
    description: 'Notícias e análises do Brasil e do mundo.',
    url: 'https://feeds.bbci.co.uk/portuguese/rss.xml',
    category: 'Notícias',
  ),
  SuggestedFeed(
    name: 'MacMagazine',
    description: 'Apple, tecnologia e cultura digital.',
    url: 'https://macmagazine.com.br/feed/',
    category: 'Tecnologia',
  ),
  SuggestedFeed(
    name: 'Tecnoblog',
    description: 'Tecnologia, produtos e internet.',
    url: 'https://tecnoblog.net/feed/',
    category: 'Tecnologia',
  ),
  SuggestedFeed(
    name: 'NASA',
    description: 'Missões, descobertas e exploração espacial.',
    url: 'https://www.nasa.gov/feed/',
    category: 'Ciência',
  ),
  SuggestedFeed(
    name: 'NerdCast',
    description: 'Conversas e histórias sobre cultura pop e ciência.',
    url: 'https://jovemnerd.com.br/feed-nerdcast/',
    category: 'Podcasts',
    isPodcast: true,
  ),
  SuggestedFeed(
    name: 'Podcast Unesp',
    description: 'Ciência, inovação e conhecimento em áudio.',
    url: 'https://podcast.unesp.br/rss',
    category: 'Podcasts',
    isPodcast: true,
  ),
];
