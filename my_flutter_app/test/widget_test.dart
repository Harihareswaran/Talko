import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/main.dart';

void main() {
  testWidgets('MyApp renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Chatbot App'), findsOneWidget);
  });
}