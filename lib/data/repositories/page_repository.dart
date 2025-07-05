import '../../domain/models/page_model.dart';
import '../services/page_service.dart';

class PageRepository {
  final PageService service;
  PageRepository(this.service);

  Future<List<PageModel>> getPages() async {
    final apiModels = await service.fetchPages();
    return apiModels.map((a) => a.toDomain()).toList();
  }
}
