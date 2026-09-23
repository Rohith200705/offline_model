import 'package:flutter_test/flutter_test.dart';

import 'package:photo_organizer/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoOrganizerApp());
    expect(find.byType(PhotoOrganizerApp), findsOneWidget);
  });
}
