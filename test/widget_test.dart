
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_full/main.dart';

void main() {
  testWidgets('App loads text', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Gym Management App Working!'), findsOneWidget);
  });
}
