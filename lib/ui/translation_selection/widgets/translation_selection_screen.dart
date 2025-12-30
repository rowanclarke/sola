import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';

class TranslationSelectionScreen extends StatelessWidget {
  const TranslationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Translation')),
      body: Consumer<HomeViewModel>(
        builder: (context, homeVm, _) {
          return FutureBuilder(
            future: homeVm.getOptions(),
            builder: (_, snapshot) {
              if (snapshot.data != null) {
                return ListView(
                  children: snapshot.data!
                      .map(
                        (translation) => ListTile(
                          title: Text(translation.id),
                          subtitle: Text(translation.title ?? ''),
                          onTap: () async {
                            await homeVm.chooseOption(translation);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      )
                      .toList(),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        },
      ),
    );
  }
}
