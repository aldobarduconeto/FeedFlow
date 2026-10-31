import 'package:flutter/material.dart';

import '../../services/online_catalog_service.dart';
import 'colors.dart';

Future<String?> showCountryPickerDialog(BuildContext context) async {
  final service = OnlineCatalogService.instance;
  final searchController = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FeedFlowColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final query = searchController.text.trim().toLowerCase();
          final filteredCountries = OnlineCatalogService.allCountries.where((c) {
            if (query.isEmpty) return true;
            final translated =
                OnlineCatalogService.countryDisplayName(c).toLowerCase();
            return c.toLowerCase().contains(query) ||
                translated.contains(query);
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selecionar País do Catálogo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: FeedFlowColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar país (ex: Brasil, Portugal...)',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (query.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Text(
                              'MAIS POPULARES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: FeedFlowColors.secondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          for (final country
                              in OnlineCatalogService.popularCountries)
                            _buildCountryTile(context, country, service),
                          const Divider(height: 16),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Text(
                              'TODOS OS PAÍSES (${OnlineCatalogService.allCountries.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: FeedFlowColors.secondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                        for (final country in filteredCountries)
                          _buildCountryTile(context, country, service),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

Widget _buildCountryTile(
  BuildContext context,
  String country,
  OnlineCatalogService service,
) {
  final isSelected = service.selectedCountry == country;
  final flag = OnlineCatalogService.countryFlag(country);
  final displayName = OnlineCatalogService.countryDisplayName(country);

  return ListTile(
    leading: Text(
      flag,
      style: const TextStyle(fontSize: 22),
    ),
    title: Text(
      displayName,
      style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? FeedFlowColors.primary : FeedFlowColors.textPrimary,
      ),
    ),
    subtitle: displayName != country ? Text(country) : null,
    trailing: isSelected
        ? Icon(Icons.check_circle_rounded, color: FeedFlowColors.primary)
        : null,
    onTap: () {
      service.setCountry(country);
      Navigator.pop(context, country);
    },
  );
}

Future<String?> showLanguagePickerDialog(BuildContext context) async {
  final service = OnlineCatalogService.instance;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: FeedFlowColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selecionar Idioma do Catálogo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FeedFlowColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final entry
                      in OnlineCatalogService.supportedLanguages.entries)
                    ListTile(
                      leading: const Icon(Icons.translate_rounded),
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: service.selectedLanguage == entry.key
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: service.selectedLanguage == entry.key
                              ? FeedFlowColors.primary
                              : FeedFlowColors.textPrimary,
                        ),
                      ),
                      subtitle: Text('Código: ${entry.key}'),
                      trailing: service.selectedLanguage == entry.key
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: FeedFlowColors.primary,
                            )
                          : null,
                      onTap: () {
                        service.setLanguage(entry.key);
                        Navigator.pop(context, entry.key);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
