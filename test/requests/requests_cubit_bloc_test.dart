import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/domain/entities/request_status.dart';
import 'package:service_request_app/features/requests/domain/entities/service_request.dart';
import 'package:service_request_app/features/requests/presentation/cubit/requests_cubit.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeRequestRepository requests;
  late FakeSyncRepository sync;
  late FakeConnectivity connectivity;

  setUp(() {
    requests = FakeRequestRepository();
    sync = FakeSyncRepository();
    connectivity = FakeConnectivity();
  });

  blocTest<RequestsCubit, RequestsState>(
    'init emits loading, then the loaded list',
    build: () {
      requests.items.add(makeRequest(id: 'a'));
      return RequestsCubit(
        requestRepository: requests,
        syncRepository: sync,
        connectivity: connectivity,
      );
    },
    act: (RequestsCubit cubit) => cubit.init(),
    expect: () => <Matcher>[
      isA<RequestsState>().having(
        (RequestsState s) => s.loading,
        'loading',
        true,
      ),
      isA<RequestsState>()
          .having((RequestsState s) => s.loading, 'loading', false)
          .having(
            (RequestsState s) => s.requests.map((r) => r.id).toList(),
            'ids',
            <String>['a'],
          ),
    ],
  );

  blocTest<RequestsCubit, RequestsState>(
    'setFilter narrows the visible list',
    build: () {
      requests.items.addAll(<ServiceRequest>[
        makeRequest(id: 'a'),
        makeRequest(id: 'b', status: RequestStatus.failed),
      ]);
      return RequestsCubit(
        requestRepository: requests,
        syncRepository: sync,
        connectivity: connectivity,
      );
    },
    act: (RequestsCubit cubit) async {
      await cubit.init();
      await cubit.setFilter(RequestStatus.failed);
    },
    skip: 2,
    expect: () => <Matcher>[
      isA<RequestsState>().having(
        (RequestsState s) => s.filter,
        'filter',
        RequestStatus.failed,
      ),
      isA<RequestsState>().having(
        (RequestsState s) => s.requests.map((r) => r.id).toList(),
        'ids',
        <String>['b'],
      ),
    ],
  );
}
