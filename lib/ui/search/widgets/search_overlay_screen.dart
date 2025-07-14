import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/search_view_model.dart';

class SearchOverlayScreen extends StatefulWidget {
  const SearchOverlayScreen({super.key});

  @override
  State<SearchOverlayScreen> createState() => _SearchOverlayScreenState();
}

class _SearchOverlayScreenState extends State<SearchOverlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  void _openOverlay() {
    _controller.forward();
  }

  void _closeOverlay() {
    _controller.reverse();
    _searchController.clear();
    context.read<SearchViewModel>().clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta != null && details.primaryDelta! > 10) {
          _openOverlay();
        }
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent, // 👈 ensures gesture detection
            child: Center(child: Text('Swipe down to search')),
          ),

          // Overlay
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return IgnorePointer(
                ignoring: _controller.value == 0,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeOverlay, // 👈 Dismiss on tap anywhere
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      child: Column(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).padding.top + 20,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GestureDetector(
                              onTap:
                                  () {}, // 👈 prevent propagation when tapping input
                              child: TextField(
                                controller: _searchController,
                                onChanged: context
                                    .read<SearchViewModel>()
                                    .updateQuery,
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: Consumer<SearchViewModel>(
                              builder: (_, vm, __) => ListView.builder(
                                itemCount: vm.results.length,
                                itemBuilder: (_, index) =>
                                    ListTile(title: Text(vm.results[index])),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
