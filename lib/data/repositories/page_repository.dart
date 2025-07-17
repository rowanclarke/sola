import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/services/file_service.dart';
import '../../domain/models/page_model.dart';

class PageRepository {
  final FileService bibleService;
  final RendererRepository rendererRepository;

  final String book;

  PageRepository(this.bibleService, this.rendererRepository, this.book);

  Future<List<PageModel>> getPages(double width, double height) async {
    await rendererRepository.render(
      book,
      width,
      height,
      () async => await bibleService.readAsString(book),
    );
    return await Future.wait(
      List.generate(
        rendererRepository.numPages,
        (n) => rendererRepository.getPage(n),
      ),
    );
  }
}
