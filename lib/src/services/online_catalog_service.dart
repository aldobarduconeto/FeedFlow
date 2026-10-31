import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/catalog_entry.dart';

class OnlineCatalogService extends ChangeNotifier {
  OnlineCatalogService._();
  static final OnlineCatalogService instance = OnlineCatalogService._();

  static const String catalogUrl =
      'https://infobubble.github.io/infobubble-support/data/catalog.js';

  // Configurações de País e Idioma (mantidas estritamente em memória volátil)
  String _selectedCountry = 'Brazil';
  String _selectedLanguage = 'pt';

  // Estado de consulta sob demanda (NÃO persistido)
  bool _isLoading = false;
  bool _hasConsulted = false;
  String? _error;
  List<CatalogDomainEntry> _domains = [];
  List<String> _categories = [];
  List<String> _languages = [];

  bool get isLoading => _isLoading;
  bool get hasConsulted => _hasConsulted;
  String? get error => _error;
  String get selectedCountry => _selectedCountry;
  String get selectedLanguage => _selectedLanguage;
  List<CatalogDomainEntry> get domains => List.unmodifiable(_domains);
  List<String> get categories => List.unmodifiable(_categories);

  String get selectedCountryDisplay => countryDisplayName(_selectedCountry);
  String get selectedLanguageDisplay =>
      supportedLanguages[_selectedLanguage] ?? _selectedLanguage;

  static const List<String> popularCountries = [
    'Brazil',
    'Portugal',
    'United States',
    'United Kingdom',
    'Spain',
    'France',
    'Germany',
    'Italy',
    'Canada',
    'Japan',
    'Argentina',
    'Mexico',
    'Colombia',
    'Chile',
    'Uruguay',
  ];

  static const Map<String, String> supportedLanguages = {
    'pt': 'Português',
    'en': 'Inglês',
    'es': 'Espanhol',
    'fr': 'Francês',
    'de': 'Alemão',
    'it': 'Italiano',
    'ja': 'Japonês',
    'zh': 'Chinês',
    'ru': 'Russo',
    'ar': 'Árabe',
    'nl': 'Holandês',
    'ko': 'Coreano',
    'uk': 'Ucraniano',
    'pl': 'Polonês',
    'tr': 'Turco',
    'hi': 'Hindi',
    'sv': 'Sueco',
    'da': 'Dinamarquês',
    'fi': 'Finlandês',
    'nb': 'Norueguês',
    'el': 'Grego',
    'cs': 'Tcheco',
    'ro': 'Romeno',
    'hu': 'Húngaro',
  };

  static String countryDisplayName(String country) {
    switch (country) {
      case 'Brazil':
        return 'Brasil';
      case 'Portugal':
        return 'Portugal';
      case 'United States':
        return 'Estados Unidos';
      case 'United Kingdom':
        return 'Reino Unido';
      case 'Spain':
        return 'Espanha';
      case 'France':
        return 'França';
      case 'Germany':
        return 'Alemanha';
      case 'Italy':
        return 'Itália';
      case 'Canada':
        return 'Canadá';
      case 'Japan':
        return 'Japão';
      case 'Argentina':
        return 'Argentina';
      case 'Mexico':
        return 'México';
      case 'Colombia':
        return 'Colômbia';
      case 'Chile':
        return 'Chile';
      case 'Uruguay':
        return 'Uruguai';
      case 'Paraguay':
        return 'Paraguai';
      case 'Bolivia':
        return 'Bolívia';
      case 'Peru':
        return 'Peru';
      case 'Ecuador':
        return 'Equador';
      case 'Venezuela':
        return 'Venezuela';
      case 'Switzerland':
        return 'Suíça';
      case 'Belgium':
        return 'Bélgica';
      case 'Netherlands':
        return 'Países Baixos';
      case 'Sweden':
        return 'Suécia';
      case 'Norway':
        return 'Noruega';
      case 'Denmark':
        return 'Dinamarca';
      case 'Finland':
        return 'Finlândia';
      case 'Ireland':
        return 'Irlanda';
      case 'Australia':
        return 'Austrália';
      case 'New Zealand':
        return 'Nova Zelândia';
      case 'South Africa':
        return 'África do Sul';
      case 'Angola':
        return 'Angola';
      case 'Mozambique':
        return 'Moçambique';
      case 'Cape Verde':
        return 'Cabo Verde';
      default:
        return country;
    }
  }

  static String countryFlag(String country) {
    switch (country) {
      case 'Brazil':
        return '🇧🇷';
      case 'Portugal':
        return '🇵🇹';
      case 'United States':
        return '🇺🇸';
      case 'United Kingdom':
        return '🇬🇧';
      case 'Spain':
        return '🇪🇸';
      case 'France':
        return '🇫🇷';
      case 'Germany':
        return '🇩🇪';
      case 'Italy':
        return '🇮🇹';
      case 'Canada':
        return '🇨🇦';
      case 'Japan':
        return '🇯🇵';
      case 'Argentina':
        return '🇦🇷';
      case 'Mexico':
        return '🇲🇽';
      case 'Colombia':
        return '🇨🇴';
      case 'Chile':
        return '🇨🇱';
      case 'Uruguay':
        return '🇺🇾';
      case 'Paraguay':
        return '🇵🇾';
      case 'Bolivia':
        return '🇧🇴';
      case 'Peru':
        return '🇵🇪';
      case 'Angola':
        return '🇦🇴';
      case 'Mozambique':
        return '🇲🇿';
      case 'Cape Verde':
        return '🇨🇻';
      default:
        return '🌐';
    }
  }

  static const List<String> allCountries = [
    'Afghanistan', 'Albania', 'Algeria', 'American Samoa', 'Andorra', 'Angola',
    'Antarctica', 'Antigua & Barbuda', 'Argentina', 'Armenia', 'Aruba', 'Australia',
    'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados',
    'Belarus', 'Belgium', 'Belize', 'Benin', 'Bermuda', 'Bhutan', 'Bolivia',
    'Bosnia & Herzegovina', 'Botswana', 'Brazil', 'British Virgin Islands',
    'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cambodia', 'Cameroon',
    'Canada', 'Cape Verde', 'Cayman Islands', 'Central African Republic', 'Chad',
    'Chile', 'China', 'Christmas Island', 'Colombia', 'Comoros',
    'Congo - Brazzaville', 'Congo - Kinshasa', 'Cook Islands', 'Costa Rica',
    'Croatia', 'Cuba', 'Curaçao', 'Cyprus', 'Czechia', 'Côte d’Ivoire', 'Denmark',
    'Djibouti', 'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt',
    'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini',
    'Ethiopia', 'Falkland Islands', 'Faroe Islands', 'Fiji', 'Finland', 'France',
    'French Polynesia', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana',
    'Greece', 'Greenland', 'Grenada', 'Guadeloupe', 'Guam', 'Guatemala',
    'Guernsey', 'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras',
    'Hong Kong SAR China', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran',
    'Iraq', 'Ireland', 'Isle of Man', 'Israel', 'Italy', 'Jamaica', 'Japan',
    'Jersey', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kosovo', 'Kuwait',
    'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya',
    'Liechtenstein', 'Lithuania', 'Luxembourg', 'Macao SAR China', 'Madagascar',
    'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands',
    'Martinique', 'Mauritania', 'Mauritius', 'Mayotte', 'Mexico', 'Micronesia',
    'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Montserrat', 'Morocco',
    'Mozambique', 'Myanmar (Burma)', 'Namibia', 'Nepal', 'Netherlands',
    'New Caledonia', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'Niue',
    'Norfolk Island', 'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau',
    'Palestinian Territories', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru',
    'Philippines', 'Poland', 'Portugal', 'Puerto Rico', 'Qatar', 'Romania',
    'Russia', 'Rwanda', 'Réunion', 'Samoa', 'San Marino', 'Saudi Arabia',
    'Senegal', 'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore',
    'Sint Maarten', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia',
    'South Africa', 'South Georgia & South Sandwich Islands', 'South Korea',
    'South Sudan', 'Spain', 'Sri Lanka', 'St. Helena', 'St. Kitts & Nevis',
    'St. Lucia', 'St. Vincent & Grenadines', 'Sudan', 'Suriname', 'Sweden',
    'Switzerland', 'Syria', 'São Tomé & Príncipe', 'Taiwan', 'Tajikistan',
    'Tanzania', 'Thailand', 'Timor-Leste', 'Togo', 'Tokelau', 'Tonga',
    'Trinidad & Tobago', 'Tunisia', 'Turkmenistan', 'Turks & Caicos Islands',
    'Tuvalu', 'Türkiye', 'U.S. Virgin Islands', 'Uganda', 'Ukraine',
    'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay',
    'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam',
    'Wallis & Futuna', 'Yemen', 'Zambia', 'Zimbabwe', 'Åland Islands'
  ];

  void detectDefaultLocale() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final lang = locale.languageCode.toLowerCase();
      final country = locale.countryCode?.toUpperCase();

      if (lang == 'pt') {
        _selectedLanguage = 'pt';
        _selectedCountry = (country == 'PT') ? 'Portugal' : 'Brazil';
      } else if (lang == 'es') {
        _selectedLanguage = 'es';
        _selectedCountry = 'Spain';
      } else if (lang == 'en') {
        _selectedLanguage = 'en';
        _selectedCountry = (country == 'GB') ? 'United Kingdom' : 'United States';
      } else if (supportedLanguages.containsKey(lang)) {
        _selectedLanguage = lang;
      }
    } catch (_) {
      // Mantém 'Brazil' e 'pt' como padrão amigável
    }
  }

  void setCountry(String country) {
    if (_selectedCountry == country) return;
    _selectedCountry = country;
    _hasConsulted = false;
    _domains = [];
    notifyListeners();
  }

  void setLanguage(String lang) {
    if (_selectedLanguage == lang) return;
    _selectedLanguage = lang;
    notifyListeners();
  }

  /// Consulta os dados do catálogo online sob demanda.
  /// NÃO persiste no disco ou SharedPreferences — mantém estritamente na RAM.
  Future<void> consultCatalog({bool force = false}) async {
    if (_isLoading) return;
    if (_hasConsulted && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(catalogUrl));
      request.headers.add('User-Agent', 'FeedFlow-App/1.3.0');
      request.headers.add('Accept-Encoding', 'gzip');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'Servidor retornou status HTTP ${response.statusCode}',
          uri: Uri.parse(catalogUrl),
        );
      }

      final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
      final text = utf8.decode(bytes);

      const prefix = 'window.CATALOG_DATA=';
      var jsonStr = text;
      if (jsonStr.startsWith(prefix)) {
        jsonStr = jsonStr.substring(prefix.length).trim();
      }
      if (jsonStr.endsWith(';')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final rawCountries =
          (data['countries'] as List?)?.cast<String>() ?? allCountries;
      _categories = (data['categories'] as List?)?.cast<String>() ?? [];
      _languages = (data['languages'] as List?)?.cast<String>() ?? [];

      final countryIndex = rawCountries.indexOf(_selectedCountry);

      final rawDomains = (data['domains'] as List?) ?? [];
      final List<CatalogDomainEntry> filtered = [];

      for (final raw in rawDomains) {
        if (raw is! List || raw.length < 7) continue;

        final domainCountry = raw[1] as int?;
        // Filtra estritamente pelo país selecionado
        if (countryIndex >= 0 && domainCountry != countryIndex) {
          continue;
        }

        final host = raw[0].toString();
        final rank = raw[2] as int?;
        final avgLen = raw[3] as int?;
        final langIndices = (raw[4] as List?)?.cast<int>() ?? [];
        final groups = (raw[5] as List?) ?? [];
        final summary = raw[6]?.toString();

        final domainLangs = langIndices
            .where((i) => i >= 0 && i < _languages.length)
            .map((i) => _languages[i])
            .toList();

        final List<CatalogFeedLink> feedLinks = [];
        final Set<String> domainCats = {};

        for (final g in groups) {
          if (g is! List || g.length < 3) continue;
          final catIndex = g[0] as int;
          final isPod = (g[1] == 1);
          final urls = (g[2] as List?)?.cast<String>() ?? [];

          final catName = (catIndex >= 0 && catIndex < _categories.length)
              ? _categories[catIndex]
              : 'Geral';
          domainCats.add(catName);

          for (final u in urls) {
            feedLinks.add(
              CatalogFeedLink(
                url: u,
                categoryName: catName,
                isPodcast: isPod,
              ),
            );
          }
        }

        filtered.add(
          CatalogDomainEntry(
            host: host,
            countryIndex: domainCountry ?? -1,
            countryName: _selectedCountry,
            rank: rank,
            avgLen: avgLen,
            languages: domainLangs,
            feeds: feedLinks,
            summary: summary,
            categories: domainCats.toList(),
          ),
        );
      }

      // Ordena por relevância (rank menor = maior tráfego) e feeds
      filtered.sort((a, b) {
        final rankA = a.rank ?? 9999999;
        final rankB = b.rank ?? 9999999;
        return rankA.compareTo(rankB);
      });

      _domains = filtered;
      _hasConsulted = true;
      _error = null;
    } catch (e) {
      _error = 'Não foi possível consultar o catálogo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpa os dados em memória volátil quando o usuário quiser liberar RAM.
  void clearMemory() {
    _domains = [];
    _hasConsulted = false;
    _error = null;
    notifyListeners();
  }
}
