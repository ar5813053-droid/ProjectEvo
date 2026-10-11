import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_evo/app.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProjectEvoApp()));
    await tester.pump();
    expect(find.textContaining('ProjectEVO'), findsWidgets);
  });
}
