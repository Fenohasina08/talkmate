import 'package:flutter_test/flutter_test.dart';
import 'package:talkmate/app/app.dart';
import 'package:talkmate/core/router/app_router.dart';

void main() {
  testWidgets('TalkMate affiche la page de connexion', (tester) async {
    final authState = TestAuthState(isLoggedIn: false);
    final router = createAppRouter(testAuthState: authState);

    await tester.pumpWidget(TalkMateApp(router: router));

    await tester.pumpAndSettle();

    expect(find.text('Bienvenue sur TalkMate 👋'), findsOneWidget);

    expect(find.text('Adresse e-mail'), findsOneWidget);

    expect(find.text('Se connecter'), findsOneWidget);

    expect(find.text('Pas encore de compte ? Créer un compte'), findsOneWidget);

    router.dispose();
    authState.dispose();
  });
}
