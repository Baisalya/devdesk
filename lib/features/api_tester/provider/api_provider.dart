import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/failure.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/json_utils.dart';
import '../models/api_environment.dart';
import '../models/api_history_entry.dart';
import '../models/api_request.dart';
import '../models/api_response.dart';
import '../utils/api_environment_utils.dart';

/// Current HTTP method selected.
final methodProvider = StateProvider<String>((ref) => 'GET');

/// Current URL.
final urlProvider = StateProvider<String>((ref) => '');

/// Request body.
final bodyProvider = StateProvider<String>((ref) => '');

final apiLoadingProvider = StateProvider<bool>((ref) => false);
final apiErrorProvider = StateProvider<String?>((ref) => null);

final apiRawResponseProvider = StateProvider<bool>((ref) => false);

final apiTimeoutProvider = StateProvider<Duration>((ref) {
  return const Duration(seconds: 30);
});

final apiClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Current list of headers or query parameters as key/value pairs.
class KeyValueNotifier extends StateNotifier<List<MapEntry<String, String>>> {
  KeyValueNotifier() : super([]);

  void add([MapEntry<String, String> entry = const MapEntry('', '')]) {
    state = [...state, entry];
  }

  void setEntries(Iterable<MapEntry<String, String>> entries) {
    state = entries.toList();
  }

  void clear() {
    state = [];
  }

  void updateKey(int index, String key) {
    if (index < 0 || index >= state.length) return;
    final pair = state[index];
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) MapEntry(key, pair.value) else state[i],
    ];
  }

  void updateValue(int index, String value) {
    if (index < 0 || index >= state.length) return;
    final pair = state[index];
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) MapEntry(pair.key, value) else state[i],
    ];
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final newList = [...state]..removeAt(index);
    state = newList;
  }

  Map<String, String> toMap() {
    return {
      for (final entry in state)
        if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value.trim(),
    };
  }
}

final headersProvider =
    StateNotifierProvider<KeyValueNotifier, List<MapEntry<String, String>>>(
  (ref) => KeyValueNotifier(),
);

final queryParamsProvider =
    StateNotifierProvider<KeyValueNotifier, List<MapEntry<String, String>>>(
  (ref) => KeyValueNotifier(),
);

/// Last API response.
final apiResponseProvider = StateProvider<ApiResponse?>((ref) => null);
final lastApiRequestProvider = StateProvider<ApiRequest?>((ref) => null);

class SaveSensitiveHeadersNotifier extends StateNotifier<bool> {
  SaveSensitiveHeadersNotifier() : super(false) {
    _load();
  }

  static const _storageKey = 'api_save_sensitive_headers';

  Future<void> _load() async {
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    state = box.get(_storageKey) == true;
  }

  Future<void> setValue(bool value) async {
    state = value;
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await box.put(_storageKey, value);
  }
}

final saveSensitiveHeadersProvider =
    StateNotifierProvider<SaveSensitiveHeadersNotifier, bool>((ref) {
  return SaveSensitiveHeadersNotifier();
});

class ApiEnvironmentsState {
  final String selectedName;
  final Map<String, ApiEnvironment> environments;

  const ApiEnvironmentsState({
    required this.selectedName,
    required this.environments,
  });

  ApiEnvironment get selected => environments[selectedName]!;

  ApiEnvironmentsState copyWith({
    String? selectedName,
    Map<String, ApiEnvironment>? environments,
  }) {
    return ApiEnvironmentsState(
      selectedName: selectedName ?? this.selectedName,
      environments: environments ?? this.environments,
    );
  }

  static ApiEnvironmentsState defaults() {
    return const ApiEnvironmentsState(
      selectedName: 'dev',
      environments: {
        'dev': ApiEnvironment(name: 'dev', baseUrl: ''),
        'staging': ApiEnvironment(name: 'staging', baseUrl: ''),
        'prod': ApiEnvironment(name: 'prod', baseUrl: ''),
      },
    );
  }
}

class ApiEnvironmentsNotifier extends StateNotifier<ApiEnvironmentsState> {
  ApiEnvironmentsNotifier() : super(ApiEnvironmentsState.defaults()) {
    _load();
  }

  static const _selectedKey = 'selected';
  static const _itemsKey = 'items';

  Future<void> _load() async {
    final box =
        await LocalStorage.openBox<dynamic>(LocalStorage.apiEnvironmentsBox);
    final defaults = ApiEnvironmentsState.defaults();
    final rawItems = box.get(_itemsKey);
    final environments = {...defaults.environments};
    if (rawItems is Map) {
      for (final entry in rawItems.entries) {
        if (entry.value is Map) {
          final env = ApiEnvironment.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (env.name.isNotEmpty) {
            environments[env.name] = env;
          }
        }
      }
    }
    final selected = box.get(_selectedKey) as String? ?? defaults.selectedName;
    state = ApiEnvironmentsState(
      selectedName: environments.containsKey(selected) ? selected : 'dev',
      environments: environments,
    );
  }

  Future<void> select(String name) async {
    if (!state.environments.containsKey(name)) return;
    state = state.copyWith(selectedName: name);
    await _persist();
  }

  Future<void> updateBaseUrl(String name, String baseUrl) async {
    if (!state.environments.containsKey(name)) return;
    final updated = {...state.environments};
    updated[name] = updated[name]!.copyWith(baseUrl: baseUrl.trim());
    state = state.copyWith(environments: updated);
    await _persist();
  }

  Future<void> _persist() async {
    final box =
        await LocalStorage.openBox<dynamic>(LocalStorage.apiEnvironmentsBox);
    await box.put(_selectedKey, state.selectedName);
    await box.put(
      _itemsKey,
      state.environments.map((key, value) => MapEntry(key, value.toMap())),
    );
  }
}

final apiEnvironmentsProvider =
    StateNotifierProvider<ApiEnvironmentsNotifier, ApiEnvironmentsState>((ref) {
  return ApiEnvironmentsNotifier();
});

/// API history list (most recent first). Loads from Hive.
final apiHistoryProvider = FutureProvider<List<ApiHistoryEntry>>((ref) async {
  final box = await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
  final list = box.keys.map((key) {
    final value = box.get(key);
    return ApiHistoryEntry(
      key: key,
      request: ApiRequest.fromMap(Map<String, dynamic>.from(value ?? {})),
    );
  }).toList();
  list.sort((a, b) => b.request.timestamp.compareTo(a.request.timestamp));
  return list;
});

Future<void> saveRequestToHistory(
  ApiRequest request, {
  bool saveSensitiveHeaders = false,
}) async {
  final box = await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
  final stored =
      saveSensitiveHeaders ? request : request.withoutSensitiveHeaders();
  await box.add(stored.toMap());
}

Future<void> deleteApiHistoryEntry(dynamic key) async {
  final box = await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
  await box.delete(key);
}

Future<void> clearApiHistory() async {
  final box = await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
  await box.clear();
}

ApiRequest currentRequestFromProviders(WidgetRef ref) {
  final selectedEnv = ref.read(apiEnvironmentsProvider).selected;
  final variables = {'baseUrl': selectedEnv.baseUrl};
  final rawUrl = ref.read(urlProvider).trim();
  return ApiRequest(
    method: ref.read(methodProvider),
    url: ApiEnvironmentUtils.resolveVariables(rawUrl, variables),
    headers: ref.read(headersProvider.notifier).toMap(),
    queryParams: ref.read(queryParamsProvider.notifier).toMap(),
    body: ref.read(bodyProvider).isNotEmpty ? ref.read(bodyProvider) : null,
  );
}

void loadRequestIntoProviders(WidgetRef ref, ApiRequest request) {
  ref.read(methodProvider.notifier).state = request.method;
  ref.read(urlProvider.notifier).state = request.url;
  ref.read(headersProvider.notifier).setEntries(request.headers.entries);
  ref
      .read(queryParamsProvider.notifier)
      .setEntries(request.queryParams.entries);
  ref.read(bodyProvider.notifier).state = request.body ?? '';
}

String formatRequestBody(String input) {
  return JsonUtils.prettyPrint(input);
}

Future<ApiResponse> sendRequest(WidgetRef ref) async {
  final request = currentRequestFromProviders(ref);
  final client = ref.read(apiClientProvider);
  final timeout = ref.read(apiTimeoutProvider);

  ref.read(apiLoadingProvider.notifier).state = true;
  ref.read(apiErrorProvider.notifier).state = null;
  try {
    final apiResponse = await executeApiRequest(
      request: request,
      client: client,
      timeout: timeout,
    );
    ref.read(lastApiRequestProvider.notifier).state = request;
    ref.read(apiResponseProvider.notifier).state = apiResponse;
    await saveRequestToHistory(
      request,
      saveSensitiveHeaders: ref.read(saveSensitiveHeadersProvider),
    );
    ref.invalidate(apiHistoryProvider);
    return apiResponse;
  } on TimeoutException {
    throw ApiFailure('Request timed out after ${timeout.inSeconds} seconds');
  } on ApiFailure {
    rethrow;
  } catch (e) {
    throw ApiFailure('Request failed: $e');
  } finally {
    ref.read(apiLoadingProvider.notifier).state = false;
  }
}

Future<ApiResponse> executeApiRequest({
  required ApiRequest request,
  required http.Client client,
  required Duration timeout,
}) async {
  final uri = _buildUri(request);
  final stopwatch = Stopwatch()..start();
  try {
    final httpRequest = http.Request(request.method.toUpperCase(), uri)
      ..headers.addAll(request.headers);
    if ((request.body ?? '').isNotEmpty && request.method != 'GET') {
      httpRequest.body = request.body!;
    }
    final streamed = await client.send(httpRequest).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    stopwatch.stop();
    return ApiResponse(
      method: request.method,
      url: uri.toString(),
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
      duration: stopwatch.elapsed,
    );
  } on TimeoutException {
    throw ApiFailure('Request timed out after ${timeout.inSeconds} seconds');
  }
}

Uri _buildUri(ApiRequest request) {
  if (request.url.isEmpty) {
    throw ApiFailure('URL is required');
  }
  final uri = Uri.tryParse(request.url);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw ApiFailure('Enter a valid http or https URL');
  }
  if (request.queryParams.isEmpty) return uri;
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      ...request.queryParams,
    },
  );
}
