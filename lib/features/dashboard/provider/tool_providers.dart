import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tool_list.dart';
import '../../../core/storage/local_storage.dart';

/// State provider storing the search query typed by the user on the dashboard.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// A computed provider that filters the list of available tools based on the
/// [searchQueryProvider]. Case-insensitive matching is used.
final filteredToolsProvider = Provider<List<DevTool>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) {
    return tools;
  }
  return tools.where((tool) {
    return tool.name.toLowerCase().contains(query) ||
        tool.description.toLowerCase().contains(query);
  }).toList();
});

class DashboardPrefs {
  final Set<String> favouriteRoutes;
  final List<String> recentRoutes;

  const DashboardPrefs({
    this.favouriteRoutes = const {},
    this.recentRoutes = const [],
  });

  DashboardPrefs copyWith({
    Set<String>? favouriteRoutes,
    List<String>? recentRoutes,
  }) {
    return DashboardPrefs(
      favouriteRoutes: favouriteRoutes ?? this.favouriteRoutes,
      recentRoutes: recentRoutes ?? this.recentRoutes,
    );
  }
}

class DashboardPrefsNotifier extends StateNotifier<DashboardPrefs> {
  DashboardPrefsNotifier() : super(const DashboardPrefs()) {
    _load();
  }

  static const _favouritesKey = 'favourites';
  static const _recentKey = 'recent';
  static const _recentLimit = 8;

  Future<void> _load() async {
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.dashboardBox);
    final favourites =
        (box.get(_favouritesKey) as List?)?.cast<String>().toSet() ??
            <String>{};
    final recent =
        (box.get(_recentKey) as List?)?.cast<String>().toList() ?? <String>[];
    state = DashboardPrefs(
      favouriteRoutes: favourites,
      recentRoutes: recent.where(_isKnownRoute).toList(),
    );
  }

  bool isFavourite(String route) => state.favouriteRoutes.contains(route);

  Future<void> toggleFavourite(String route) async {
    final updated = {...state.favouriteRoutes};
    if (!updated.remove(route)) {
      updated.add(route);
    }
    state = state.copyWith(favouriteRoutes: updated);
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.dashboardBox);
    await box.put(_favouritesKey, updated.toList());
  }

  Future<void> markRecentlyUsed(String route) async {
    if (!_isKnownRoute(route)) return;
    final updated = [
      route,
      ...state.recentRoutes.where((item) => item != route),
    ].take(_recentLimit).toList();
    state = state.copyWith(recentRoutes: updated);
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.dashboardBox);
    await box.put(_recentKey, updated);
  }

  static bool _isKnownRoute(String route) {
    return tools.any((tool) => tool.route == route);
  }
}

final dashboardPrefsProvider =
    StateNotifierProvider<DashboardPrefsNotifier, DashboardPrefs>((ref) {
  return DashboardPrefsNotifier();
});

final favouritesProvider = Provider<Set<String>>((ref) {
  return ref.watch(dashboardPrefsProvider).favouriteRoutes;
});

final recentToolsProvider = Provider<List<DevTool>>((ref) {
  final recentRoutes = ref.watch(dashboardPrefsProvider).recentRoutes;
  return [
    for (final route in recentRoutes)
      if (tools.where((tool) => tool.route == route).isNotEmpty)
        tools.firstWhere((tool) => tool.route == route),
  ];
});
