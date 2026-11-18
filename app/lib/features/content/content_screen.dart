import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';

final contentProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final res = await ref.watch(dioProvider).get('/content/$key');
  return res.data as Map<String, dynamic>;
});

/// Үйлчилгээний нөхцөл / нууцлалын бодлого — унших горим: нарийн багана,
/// тайван зай, том гарчиг.
class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key, required this.contentKey});

  final String contentKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider(contentKey));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const AppBackButton(),
      ),
      body: SafeArea(
        top: false,
        child: content.when(
          loading: () => const PageFrame(
            maxWidth: 680,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 32, width: 240),
                  SizedBox(height: 24),
                  Skeleton(height: 14),
                  SizedBox(height: 10),
                  Skeleton(height: 14),
                  SizedBox(height: 10),
                  Skeleton(height: 14, width: 180),
                ],
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(
                  icon: LucideIcons.triangleAlert,
                  title: apiErrorMessage(e),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  child: PrimaryButton(
                    label: 'Дахин оролдох',
                    icon: LucideIcons.refreshCw,
                    onPressed: () =>
                        ref.invalidate(contentProvider(contentKey)),
                  ),
                ),
              ],
            ),
          ),
          data: (c) => PageFrame(
            maxWidth: 680,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
              children: [
                Text(
                  c['title'] as String? ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Text(
                  c['body'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
