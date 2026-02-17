import 'package:sola/core/models/book.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/core/models/rendering_config.dart';

/// RendererService formats structured Bible content into renderable pages.
/// Applies rendering configurations and creates verse-to-page indexes for navigation.
class RendererService {
  /// Renders a structured Book into a list of formatted Pages.
  /// Applies formatting options (poetry, spacing, layout) from the RenderingConfig.
  List<PageModel> renderBook(Book book, RenderingConfig config) {
    throw UnimplementedError();
  }

  /// Previews the first page of a rendered book.
  /// Useful for showing a quick preview before full rendering.
  PageModel previewFirstPage(Book book, RenderingConfig config) {
    throw UnimplementedError();
  }
}
