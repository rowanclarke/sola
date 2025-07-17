import '../../pagination/view_model/pagination_view_model.dart';
import '../../search/view_model/search_view_model.dart';

class HomeViewModel {
  final PaginationViewModel pagination;
  final SearchViewModel search;

  HomeViewModel({required this.pagination, required this.search}) {
    search.onItemSelected = handleItemSelected;
  }

  Future<void> init(double width, double height) async {
    await pagination.loadPages(width, height);
    search.loadModel();
  }

  void handleItemSelected(int page) {
    pagination.setPage(page);
  }
}
