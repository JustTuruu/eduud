import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

final contentProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final res = await ref.watch(dioProvider).get('/content/$key');
  return res.data as Map<String, dynamic>;
});

/// Үйлчилгээний нөхцөл / нууцлалын бодлого / FAQ.
class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key, required this.contentKey});

  final String contentKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider(contentKey));
    return Scaffold(
      appBar: AppBar(),
      body: AppBackground(
          child: content.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.coral)),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (c) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(c['title'] as String? ?? '',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),
            Text(c['body'] as String? ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkSoft, height: 1.7)),
          ],
        ),
      )),
    );
  }
}
