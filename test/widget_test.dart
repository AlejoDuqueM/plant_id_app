import 'package:flutter_test/flutter_test.dart';

import 'package:plant_id_app/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla principal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PlantApp());

    expect(find.text('PlantID Gratis'), findsOneWidget);
    expect(find.text('Ninguna imagen seleccionada'), findsOneWidget);
  });
}
