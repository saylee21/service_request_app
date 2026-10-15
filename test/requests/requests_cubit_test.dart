import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/domain/entities/request_status.dart';
import 'package:service_request_app/features/requests/domain/entities/service_request.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_stats.dart';
import 'package:service_request_app/features/requests/presentation/cubit/requests_cubit.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeRequestRepository requests;
  late FakeSyncRepository sync;
  late FakeConnectivity connectivity;
  late RequestsCubit cubit;

  setUp(() {
    requests = FakeRequestRepository();
    sync = FakeSyncRepository();
    connectivity = FakeConnectivity();
    cubit = RequestsCubit(
      requestRepository: requests,
      syncRepository: sync,
      connectivity: connectivity,
    );
  });

  tearDown(() async {
    await cubit.close();
    await connectivity.dispose();
  });

  test('init loads requests and stats', () async {
    requests.items.add(makeRequest(id: 'a'));
    sync.statsValue = const SyncStats(pending: 1);

    await cubit.init();

    expect(cubit.state.loading, isFalse);
    expect(cubit.state.requests.map((r) => r.id).toList(), <String>['a']);
    expect(cubit.state.stats.pending, 1);
    expect(cubit.state.online, isTrue);
  });

  test('setFilter narrows the list and clearing restores it', () async {
    requests.items.addAll(<ServiceRequest>[
      makeRequest(id: 'a'),
      makeRequest(id: 'b', status: RequestStatus.failed),
    ]);
    await cubit.init();

    await cubit.setFilter(RequestStatus.failed);
    expect(cubit.state.requests.map((r) => r.id).toList(), <String>['b']);

    await cubit.setFilter(null);
    expect(cubit.state.requests.length, 2);
  });

  test('retry delegates to the repository', () async {
    requests.items.add(makeRequest(id: 'a', status: RequestStatus.failed));
    await cubit.init();

    await cubit.retry('a');

    expect(requests.retried, <String>['a']);
  });

  test('a change notification reloads the list', () async {
    await cubit.init();
    requests.items.add(makeRequest(id: 'late'));
    requests.bus.notify();

    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.requests.map((r) => r.id).toList(), <String>['late']);
  });

  test('going offline flips the banner', () async {
    await cubit.init();

    connectivity.emit(false);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.online, isFalse);
  });
}
