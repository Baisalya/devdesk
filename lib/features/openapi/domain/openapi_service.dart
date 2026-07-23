import '../../api_tester/models/api_workspace_models.dart';
import 'openapi_models.dart';

abstract interface class OpenApiService {
  OpenApiDocument parse(String source, {String sourceName = 'openapi'});

  ApiCollection generateCollection(OpenApiDocument document);

  List<OpenApiChange> compare(
    OpenApiDocument previous,
    OpenApiDocument current,
  );

  String generateMarkdown(OpenApiDocument document);
}
