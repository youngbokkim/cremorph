import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import 'breed/breed_screen.dart';
import 'gallery/gallery_screen.dart';
import 'identify/identify_screen.dart';
import 'widgets/app_chrome.dart';
import 'widgets/common.dart';

/// The three panels of the app, matching the original tab bar.
enum AppTab {
  identify('모프 식별', Icons.center_focus_strong_outlined),
  breed('교배 AI', Icons.hub_outlined),
  gallery('모프 도감', Icons.grid_view_outlined);

  const AppTab(this.labelKo, this.icon);

  final String labelKo;
  final IconData icon;
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  AppTab _tab = AppTab.identify;

  void _select(AppTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);

    return Scaffold(
      backgroundColor: AppColors.soil,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: ContentWidth(
            child: Column(
              children: [
                _Header(tab: _tab, onSelect: _select, showTabs: !compact),
                Expanded(
                  child: PanelTransition(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      AppTab.identify => const IdentifyScreen(),
                      AppTab.breed => const BreedScreen(),
                      AppTab.gallery => const GalleryScreen(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: compact
          ? _BottomTabs(tab: _tab, onSelect: _select)
          : null,
    );
  }
}

/// The `@keyframes rise` panel entrance: fade and slide up over 350ms.
class PanelTransition extends StatefulWidget {
  const PanelTransition({required this.child, super.key});

  final Widget child;

  @override
  State<PanelTransition> createState() => _PanelTransitionState();
}

class _PanelTransitionState extends State<PanelTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.tab,
    required this.onSelect,
    required this.showTabs,
  });

  final AppTab tab;
  final ValueChanged<AppTab> onSelect;
  final bool showTabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CrestLogo(size: 52),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  style: AppText.brand,
                  children: const [
                    TextSpan(text: 'CRE'),
                    TextSpan(
                      text: 'HOONI',
                      style: TextStyle(color: AppColors.amber),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: AppText.sub,
                  children: [
                    const TextSpan(text: '크레스티드게코 모프 식별 · 교배 '),
                    TextSpan(
                      text: 'Correlophus ciliatus',
                      style: AppText.latin,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTabs)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: brand),
                const SizedBox(width: 24),
                _PillTabs(tab: tab, onSelect: onSelect),
              ],
            )
          else
            brand,
          const SizedBox(height: 22),
          const Divider(height: 1),
          const _OfflineNotice(),
        ],
      ),
    );
  }
}

/// The `.tab` pills used on wide layouts.
class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.tab, required this.onSelect});

  final AppTab tab;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in AppTab.values)
          _Pill(
            label: item.labelKo,
            active: item == tab,
            onTap: () => onSelect(item),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.cream : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: BorderSide(color: active ? AppColors.cream : AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: AppText.tab.copyWith(
              color: active ? AppColors.ink : AppColors.cream,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation for phones, where header pills would crowd the brand.
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.tab, required this.onSelect});

  final AppTab tab;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF14100B),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.amber.withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => AppText.bodySmall.copyWith(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? AppColors.amber
                  : AppColors.muted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? AppColors.amber
                  : AppColors.muted,
            ),
          ),
        ),
        child: NavigationBar(
          height: 62,
          selectedIndex: tab.index,
          onDestinationSelected: (index) => onSelect(AppTab.values[index]),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final item in AppTab.values)
              NavigationDestination(icon: Icon(item.icon), label: item.labelKo),
          ],
        ),
      ),
    );
  }
}

/// Explains the reduced feature set when Supabase is not reachable.
class _OfflineNotice extends ConsumerWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(supabaseServiceProvider);
    final reason = service.unavailableReason;
    if (service.isAvailable || reason == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(reason, style: AppText.sub)),
        ],
      ),
    );
  }
}

/// The shared footer disclosure from the web version.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(
            '크래후니는 공개된 크레스티드게코 유전 규칙(릴리 화이트 불완전 우성·치사 슈퍼폼, '
            '아잔틱·팬텀 열성, 카푸치노 불완전 우성, 패턴은 다지성)을 사용합니다. '
            '할리퀸·핀·달마 확률은 근사치입니다. 사진 속 개체의 건강·성별은 판정하지 않습니다.',
            style: AppText.foot,
          ),
        ],
      ),
    );
  }
}
