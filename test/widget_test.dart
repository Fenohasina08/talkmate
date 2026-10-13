
import 'package:flutter_test/flutter_test.dart';
import 'package:talkmate/app/app.dart';

void main() {
  testWidgets('TalkMate affiche la page de connexion', (tester) async {
    await tester.pumpWidget(const TalkMateApp());

    expect(
      find.text('Bienvenue sur TalkMate 👋'),
      findsOneWidget,
    );

    expect(
      find.text('Adresse e-mail'),
      findsOneWidget,
    );

    expect(
      find.text('Se connecter'),
      findsOneWidget,
    );

    expect(
      find.text('Pas encore de compte ? Créer un compte'),
      findsOneWidget,
    );
  });
}
