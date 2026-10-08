import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week6_app/main.dart';

void main() {
  testWidgets('App renders login page by default test', (WidgetTester tester) async {
    final container = ProviderContainer();
    final router = createRouter(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MyApp(router: router),
      ),
    );
    await tester.pump();

    expect(find.text('Login'), findsWidgets);
  });
}
