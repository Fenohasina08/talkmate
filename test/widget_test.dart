import 'package:flutter_test/flutter_test.dart';
import 'package:talkmate/app/app.dart';

void main() {
  testWidgets('TalkMate affiche la page d’accueil', (tester) async {
    await tester.pumpWidget(const TalkMateApp());

    expect(find.text('TalkMate'), findsOneWidget);
    expect(find.text('Salama ! 👋'), findsOneWidget);
    expect(find.text('Ton prochain défi'), findsOneWidget);
  });
}