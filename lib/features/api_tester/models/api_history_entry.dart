import 'api_request.dart';

class ApiHistoryEntry {
  final dynamic key;
  final ApiRequest request;

  const ApiHistoryEntry({
    required this.key,
    required this.request,
  });
}
