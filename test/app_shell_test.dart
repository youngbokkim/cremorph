import 'package:crehooni/core/theme.dart';
import 'package:crehooni/data/supabase_service.dart';
import 'package:crehooni/ui/app_shell.dart';
import 'package:crehooni/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke coverage for the three panels.
///
/// No Supabase keys are defined under `flutter test`, so this exercises the
/// offline path: every screen must still build and show the bundled catalog.
void main() {
  setUpAll(() => SupabaseService.instance.initialise());

  /// Pumps [AppShell] into a viewport of [size] and waits for it to settle.
  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    // Pin the ratio too, so `size` is both the physical and the logical size
    // however the binding was left by earlier test files.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildAppTheme(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  const phone = Size(402, 874);
  const desktop = Size(1280, 1000);

  group('on a phone', () {
    testWidgets('opens on identify with bottom navigation', (tester) async {
      await pumpShell(tester, size: phone);

      expect(find.byType(NavigationBar), findsOne);
      expect(find.text('게코 사진으로 모프 찾기'), findsOne);
      expect(find.text('사진을 놓거나 눌러서 업로드'), findsOne);
      // Without keys the app says so rather than failing silently.
      expect(find.textContaining('오프라인 모드'), findsOne);
    });

    testWidgets('predicts offspring for the default pairing', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('교배 AI'));
      await tester.pumpAndSettle();

      expect(find.text('부모 모프 고르기'), findsOne);
      expect(find.byKey(const Key('breed-parent-search')), findsOne);
      expect(find.text('암컷'), findsOne);
      expect(find.text('수컷'), findsOne);

      tester
          .widget<AppButton>(find.widgetWithText(AppButton, '자손 모프 예측'))
          .onPressed
          ?.call();
      await tester.pumpAndSettle();

      // Lilly White (Ll) × Harlequin (ll) splits evenly, and because neither
      // parent is homozygous the lethal super form cannot appear.
      expect(find.text('확정 유전자 (멘델 비율)'), findsOne);
      expect(find.text('패턴 예측 (다지성 · 대략치)'), findsOne);
      expect(find.text('50%'), findsAtLeast(2));
      expect(find.textContaining('슈퍼 릴리'), findsNothing);
    });

    testWidgets('filters parent morphs from the search field', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('교배 AI'));
      await tester.pumpAndSettle();

      expect(find.text('27종'), findsOne);

      await tester.enterText(
        find.byKey(const Key('breed-parent-search')),
        '릴리',
      );
      await tester.pump();

      expect(find.text('3종'), findsOne);
    });

    testWidgets('answers a Korean breeding question in the chat', (
      tester,
    ) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('교배 AI'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('breed-chat-input')),
        '릴리화이트랑 아잔틱 섞으면?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // The reply echoes the cross and renders the outcome cards.
      expect(find.textContaining('릴리 화이트'), findsWidgets);
      expect(find.textContaining('아잔틱'), findsWidgets);
    });

    testWidgets('shows the gallery and opens a morph detail sheet', (
      tester,
    ) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('모프 도감').last);
      await tester.pumpAndSettle();

      expect(find.text('전체 28'), findsOne);

      // The first tile of the unfiltered grid.
      await tester.tap(find.text('노멀'));
      await tester.pumpAndSettle();

      expect(find.text('겉모습'), findsOne);
      expect(find.text('시세'), findsOne);
      expect(find.text('Normal / Wild Type'), findsWidgets);
    });

    testWidgets('filters the gallery by category', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('모프 도감').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('유전자'));
      await tester.pumpAndSettle();

      // Axanthic is a recessive colour gene, Flame is a pattern morph.
      expect(find.text('아잔틱'), findsOne);
      expect(find.text('플레임'), findsNothing);
    });
  });

  group('on a wide layout', () {
    testWidgets('uses header pills instead of bottom navigation', (
      tester,
    ) async {
      await pumpShell(tester, size: desktop);

      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('모프 도감'));
      await tester.pumpAndSettle();

      expect(find.text('전체 28'), findsWidgets);
    });

    testWidgets('lays the breeding panel out in two columns', (tester) async {
      await pumpShell(tester, size: desktop);

      await tester.tap(find.text('교배 AI'));
      await tester.pumpAndSettle();

      // Picker on the left, chat on the right, both visible at once.
      expect(find.text('부모 모프 고르기'), findsOne);
      expect(find.byKey(const Key('breed-parent-search')), findsOne);
      expect(find.byKey(const Key('breed-chat-input')), findsOne);

      await tester.tap(find.text('자손 모프 예측'));
      await tester.pumpAndSettle();

      expect(find.text('확정 유전자 (멘델 비율)'), findsOne);
    });
  });
}
