import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, child) {
        switch (vm.state) {
          case Loading():
            return const Center(child: CircularProgressIndicator());
          case Choosing():
            return FutureBuilder(
              future: vm.getOptions(),
              builder: (_, options) {
                if (options.data != null) {
                  return ListView(
                    children: options.data!
                        .map(
                          (opt) => ListTile(
                            title: Text(opt),
                            onTap: () async => await vm.chooseOption(opt),
                          ),
                        )
                        .toList(),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            );
          case ShowingContent(:final content):
            return Center(child: Text('Selection: $content'));
        }
      },
    );
  }
}
