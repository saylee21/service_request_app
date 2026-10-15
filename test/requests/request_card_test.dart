import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/domain/entities/request_status.dart';
import 'package:service_request_app/features/requests/presentation/widgets/request_card.dart';

import '../helpers/fakes.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('a failed request exposes a Retry action', (tester) async {
    bool retried = false;
    await tester.pumpWidget(
      wrap(
        RequestCard(
          request: makeRequest(
            id: 'a',
            status: RequestStatus.failed,
            serverMessage: 'Invalid payload',
          ),
          onTap: () {},
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Invalid payload'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('a pending request has no Retry action', (tester) async {
    await tester.pumpWidget(
      wrap(
        RequestCard(
          request: makeRequest(id: 'a'),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Retry'), findsNothing);
  });
}
