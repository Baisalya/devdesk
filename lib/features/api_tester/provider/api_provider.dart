import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/failure.dart';
import '../../../core/network/bounded_http.dart';
import '../../../core/security/data_redactor.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/json_utils.dart';
import '../models/api_environment.dart';
import '../models/api_history_entry.dart';
import '../models/api_request.dart';
import '../models/api_response.dart';
import '../models/api_workspace_models.dart';
import '../utils/api_environment_utils.dart';
import '../utils/api_workspace_executor.dart';
import '../utils/api_workspace_utils.dart';

/// Current HTTP method selected.
final methodProvider = StateProvider<String>((ref) => 'GET');

/// Current URL.
final urlProvider = StateProvider<String>((ref) => '');

/// Request body.
final bodyProvider = StateProvider<String>((ref) => '');

final apiLoadingProvider = StateProvider<bool>((ref) => false);
final apiErrorProvider = StateProvider<String?>((ref) => null);

final apiRawResponseProvider = StateProvider<bool>((ref) => false);

class ApiOperationController extends StateNotifier<int> {
  ApiOperationController() : super(0);

  OperationCancellationToken? _token;

  ({int id, OperationCancellationToken token}) start() {
    _token?.cancel();
    final token = OperationCancellationToken();
    _token = token;
    state += 1;
    return (id: state, token: token);
  }

  bool isCurrent(int id, OperationCancellationToken token) {
    return id == state && identical(token, _token) && !token.isCancelled;
  }

  void finish(OperationCancellationToken token) {
    if (identical(token, _token)) _token = null;
  }

  void cancel() {
    _token?.cancel();
    _token = null;
    state += 1;
  }
}

final apiOperationProvider =
    StateNotifierProvider<ApiOperationController, int>((ref) {
  return ApiOperationController();
});

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
    return ApiEnvironmentsState(
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

Future<void> saveRequestToHistory(ApiRequest request) async {
  final box = await LocalStorage.openBox<Map>(LocalStorage.apiHistoryBox);
  final safe = DataRedactor.deepRedact(request.toMap());
  await box.add(Map<String, dynamic>.from(safe as Map));
  final entries = <MapEntry<dynamic, DateTime>>[];
  for (final key in box.keys) {
    final raw = box.get(key);
    if (raw is! Map) continue;
    final timestamp = raw['timestamp'];
    entries.add(
      MapEntry(
        key,
        DateTime.fromMillisecondsSinceEpoch(timestamp is int ? timestamp : 0),
      ),
    );
  }
  entries.sort((a, b) => b.value.compareTo(a.value));
  for (final stale in entries.skip(100)) {
    await box.delete(stale.key);
  }
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

  if (ref.read(apiLoadingProvider)) {
    throw ApiFailure('Another API request is already running.');
  }
  final controller = ref.read(apiOperationProvider.notifier);
  final operation = controller.start();
  ref.read(apiLoadingProvider.notifier).state = true;
  ref.read(apiErrorProvider.notifier).state = null;
  try {
    final apiResponse = await executeApiRequest(
      request: request,
      client: client,
      timeout: timeout,
      cancellationToken: operation.token,
    );
    operation.token.throwIfCancelled();
    if (!controller.isCurrent(operation.id, operation.token)) {
      throw ApiFailure('Request cancelled.');
    }
    final safeRequest = request.sanitized();
    ref.read(lastApiRequestProvider.notifier).state = safeRequest;
    ref.read(apiResponseProvider.notifier).state = apiResponse;
    await saveRequestToHistory(safeRequest);
    operation.token.throwIfCancelled();
    if (controller.isCurrent(operation.id, operation.token)) {
      ref.invalidate(apiHistoryProvider);
    }
    return apiResponse;
  } on ApiFailure {
    rethrow;
  } catch (e) {
    throw ApiFailure('Request failed safely: ${DataRedactor.safeError(e)}');
  } finally {
    if (controller.isCurrent(operation.id, operation.token)) {
      ref.read(apiLoadingProvider.notifier).state = false;
    }
    controller.finish(operation.token);
  }
}

void cancelApiRequest(WidgetRef ref) {
  ref.read(apiOperationProvider.notifier).cancel();
  ref.invalidate(apiClientProvider);
  ref.read(apiLoadingProvider.notifier).state = false;
  ref.read(apiErrorProvider.notifier).state = 'Request cancelled.';
}

Future<ApiResponse> executeApiRequest({
  required ApiRequest request,
  required http.Client client,
  required Duration timeout,
  OperationCancellationToken? cancellationToken,
  int maxResponseBytes = BoundedHttpReader.defaultMaxResponseBytes,
  Duration connectTimeout = BoundedHttpReader.defaultConnectTimeout,
  Duration readIdleTimeout = BoundedHttpReader.defaultReadIdleTimeout,
}) async {
  final prepared = prepareApiRequest(request: request, timeout: timeout);
  final response = await ApiWorkspaceExecutor.execute(
    prepared: prepared,
    client: client,
    cancellationToken: cancellationToken,
    maxResponseBytes: maxResponseBytes,
    connectTimeout: connectTimeout,
    readIdleTimeout: readIdleTimeout,
  );
  return ApiResponse(
    method: response.method,
    url: response.url,
    statusCode: response.statusCode,
    headers: response.headers,
    body: response.body,
    duration: Duration(milliseconds: response.durationMs),
  );
}

/// Adapts the compact API tester to the same validated request model used by
/// workspaces and collection runs. No network path may bypass this model.
ApiPreparedRequest prepareApiRequest({
  required ApiRequest request,
  required Duration timeout,
}) {
  final method = request.method.toUpperCase();
  final rawBody = request.body ?? '';
  final contentType = request.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'content-type')
      .map((entry) => entry.value.toLowerCase())
      .firstOrNull;

  var bodyType = ApiRequestBodyType.none;
  var formFields = const <String, String>{};
  if (rawBody.isNotEmpty) {
    if (contentType?.contains('application/json') ?? false) {
      bodyType = ApiRequestBodyType.rawJson;
    } else if (contentType?.contains('application/x-www-form-urlencoded') ??
        false) {
      try {
        formFields = Uri.splitQueryString(rawBody);
      } on FormatException {
        throw ApiFailure(
          'URL-encoded form body is invalid.',
          code: 'DD-API-BODY-FORM',
          category: FailureCategory.validation,
          retryable: false,
        );
      }
      bodyType = ApiRequestBodyType.formUrlEncoded;
    } else if (contentType?.contains('multipart/form-data') ?? false) {
      throw ApiFailure(
        'Use the workspace form-fields editor for multipart requests; manual multipart boundaries are not accepted.',
        code: 'DD-API-BODY-MULTIPART',
        category: FailureCategory.validation,
        retryable: false,
      );
    } else {
      bodyType = ApiRequestBodyType.rawText;
    }
  }

  final source = ApiRequestItem(
    id: 'quick-request',
    name: 'Quick request',
    method: method,
    url: request.url,
    headers: request.headers,
    queryParams: request.queryParams,
    body: ApiRequestBody(
      type: bodyType,
      raw: rawBody,
      formFields: formFields,
    ),
    timeoutMs: timeout.inMilliseconds,
    followRedirects: request.followRedirects,
  );
  return ApiPreparedRequest(
    source: source,
    method: method,
    url: request.url,
    headers: request.headers,
    queryParams: request.queryParams,
    bodyType: bodyType,
    body: rawBody.isEmpty ? null : rawBody,
    formFields: formFields,
    timeout: timeout,
    followRedirects: request.followRedirects,
    unresolvedVariables: const [],
  );
}
