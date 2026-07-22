import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_yar/main.dart';

void main() {
  testWidgets('shows brand on welcome screen in LTR', (tester) async {
    await tester.pumpWidget(const GitYarApp());
    expect(find.text('Git Yar'), findsWidgets);
    expect(find.textContaining('See every branch'), findsOneWidget);
    expect(find.text('Open repository'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.ltr);
  });
}
