import 'package:carerounds/theme.dart';
import 'package:carerounds/widgets/message_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The coach's whole advantage over a blank chat box is that it reads the
/// client's real record. The "Based on" line is what makes that visible to the
/// worker — and its ABSENCE is meaningful, so both states are pinned here.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: careroundsLightTheme,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('renders the grounding line when the reply was grounded',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const MessageBody(
        body: 'She takes Lisinopril in the morning.',
        groundedIn: <String>['Client profile', '2 medications'],
      ),
    );

    expect(find.byKey(MessageBody.groundingKey), findsOneWidget);
    expect(
      find.text('Based on Client profile · 2 medications'),
      findsOneWidget,
    );
  });

  testWidgets('renders NO grounding line when nothing grounded the reply',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const MessageBody(body: 'I am not sure about that.'),
    );

    expect(find.byKey(MessageBody.groundingKey), findsNothing);
    expect(find.textContaining('Based on'), findsNothing);
  });

  testWidgets('the grounding line is not a tap target and not CTA-coloured',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const MessageBody(
        body: 'Her next appointment is Thursday.',
        groundedIn: <String>['1 appointment'],
      ),
    );

    // Provenance, not an action: salmon is reserved for CTAs, and an
    // InkWell here would invite a tap that goes nowhere.
    expect(
      find.descendant(
        of: find.byKey(MessageBody.groundingKey),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    final BuildContext context = tester.element(find.byType(MessageBody));
    final Text text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(MessageBody.groundingKey),
        matching: find.byType(Text),
      ),
    );
    expect(text.style?.color, isNot(context.hc.cta));
  });

  testWidgets('grounding and action citations can appear together',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const MessageBody(
        body: 'Logged that for you.',
        citations: <String>['journal:entry-1'],
        groundedIn: <String>['Client profile'],
      ),
    );

    expect(find.byKey(MessageBody.groundingKey), findsOneWidget);
    expect(
      find.byKey(MessageBody.citationChipKey('journal:entry-1')),
      findsOneWidget,
    );
  });
}
