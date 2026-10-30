import 'package:crm_mobile/models/pbx_call_model.dart';
import 'package:crm_mobile/services/pbx_call_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

const _provisioned = PbxMe(
  provisioned: true,
  outboundSuspended: false,
  extensionNumber: '101',
  deviceType: 'desk_phone',
  registered: true,
  canClickToCall: true,
);

void main() {
  test('explicit policy denial never probes telephony me', () async {
    var meCalls = 0;
    final result = await PbxCallLauncher.resolveMe(
      fetchPolicyEnabled: () async => false,
      fetchTelephonyMe: () async {
        meCalls++;
        return _provisioned;
      },
    );

    expect(result, isNull);
    expect(meCalls, 0);
  });

  test('approved pilot resolves telephony me', () async {
    var meCalls = 0;
    final result = await PbxCallLauncher.resolveMe(
      fetchPolicyEnabled: () async => true,
      fetchTelephonyMe: () async {
        meCalls++;
        return _provisioned;
      },
    );

    expect(result, same(_provisioned));
    expect(meCalls, 1);
  });

  test('policy failure falls back to telephony me', () async {
    var meCalls = 0;
    final result = await PbxCallLauncher.resolveMe(
      fetchPolicyEnabled: () async => throw Exception('policy unavailable'),
      fetchTelephonyMe: () async {
        meCalls++;
        return _provisioned;
      },
    );

    expect(result, same(_provisioned));
    expect(meCalls, 1);
  });

  test('unauthenticated discovery makes no requests', () async {
    var policyCalls = 0;
    var meCalls = 0;
    final result = await PbxCallLauncher.resolveMe(
      authenticated: false,
      fetchPolicyEnabled: () async {
        policyCalls++;
        return true;
      },
      fetchTelephonyMe: () async {
        meCalls++;
        return _provisioned;
      },
    );

    expect(result, isNull);
    expect(policyCalls, 0);
    expect(meCalls, 0);
  });
}
