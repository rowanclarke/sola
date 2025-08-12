import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/usfm_repository.dart';
import '../../domain/models/page_model.dart';

class PageRepository {
  final UsfmRepository usfmRepository;
  final RendererRepository rendererRepository;

  PageRepository(this.usfmRepository, this.rendererRepository);

  Future<List<PageModel>> getPages(
    String book,
    double width,
    double height,
  ) async {
    await rendererRepository.render(book, width, height);
    return await Future.wait(
      List.generate(
        rendererRepository.numPages,
        (n) => rendererRepository.getPage(n),
      ),
    );
  }
}
