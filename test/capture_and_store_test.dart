import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/ble/neurosky_ble.dart';
import 'package:overmind/src/game/games/balloon_game.dart';
import 'package:overmind/src/game/games/falcon_game.dart';
import 'package:overmind/src/game/games/seesaw_game.dart';
import 'package:overmind/src/game/battle_theme.dart';
import 'package:overmind/src/state/battle_theme_controller.dart';
import 'package:overmind/src/state/eeg_store.dart';
import 'package:overmind/src/state/progress_controller.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:vector_math/vector_math_64.dart';

import 'fake_audio.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'game_logic_test_helpers.dart';

/// path_provider apuntando a un dir temporal real.
class _TmpPathProvider extends PathProviderPlatform {
  _TmpPathProvider(this.dir);
  final Directory dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
  @override
  Future<String?> getTemporaryPath() async => dir.path;
}

class _FakeDeviceInfo extends DeviceInfoPlatform {
  _FakeDeviceInfo(this.sdk);
  final int sdk;
  @override
  Future<AndroidDeviceInfo> androidInfo() async =>
      AndroidDeviceInfo.fromMap(<String, Object?>{
        'codename': 'REL',
        'id': '34',
        'manufacturer': 'test',
        'model': 'test',
        'product': 'test',
        'tags': <String>[],
        'board': 'test',
        'brand': 'test',
        'device': 'test',
        'project': 'test',
        'fingerprint': 'fp',
        'supportedAbis32': <String>[],
        'supportedAbis64': <String>[],
        'supported32BitAbis': <String>[],
        'supported64BitAbis': <String>[],
        'systemFeatures': <String>[],
        'version': <String, Object?>{
          'baseOS': null,
          'codename': 'REL',
          'previewSdkInt': false,
          'release': '14',
          'sdkInt': sdk,
          'securityPatch': 'p',
        },
        'display': 'x',
      });
}

class _StubPermissions extends PermissionHandlerPlatform {
  _StubPermissions(this.granted);
  final bool granted;
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      granted ? PermissionStatus.granted : PermissionStatus.denied;
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async =>
      <Permission, PermissionStatus>{
        for (final p in permissions)
          p: granted ? PermissionStatus.granted : PermissionStatus.denied,
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installFakeAudio();

  group('Persistencia con path_provider', () {
    late Directory tmp;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('overmind_test');
      PathProviderPlatform.instance = _TmpPathProvider(tmp);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('ProgressController record -> persiste -> load roundtrip', () async {
      final p = ProgressController();
      p.record('g', 100);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(File('${tmp.path}/progress.json').existsSync(), isTrue);

      final q = ProgressController();
      await q.load();
      expect(q.best['g'], 100);
      expect(q.mentalPoints, 100);
      expect(q.streakDays, 1);
      expect(q.lastPlayedDay, isNotNull);
    });

    test('ProgressController.load tolera json corrupto', () async {
      File('${tmp.path}/progress.json').writeAsStringSync('{no es json');
      final p = ProgressController();
      await p.load(); // no lanza
      expect(p.best, isEmpty);
    });

    test('BattleThemeController setTheme -> load roundtrip', () async {
      final c = BattleThemeController();
      c.setTheme(BattleTheme.superpoderes);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final p = BattleThemeController();
      await p.load();
      expect(p.theme.id, 'superpoderes');
    });

    test('BattleThemeController.load sin archivo deja el default', () async {
      final c = BattleThemeController();
      await c.load();
      expect(c.theme.id, BattleTheme.evangelion.id);
    });
  });

  group('NeuroSkyBle.ensurePermissions (Android mockeado)', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      DeviceInfoPlatform.instance = _FakeDeviceInfo(34);
      PermissionHandlerPlatform.instance = _StubPermissions(true);
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      PermissionHandlerPlatform.instance = _StubPermissions(true);
    });

    test('Android 12+ con permisos concedidos -> null', () async {
      expect(await NeuroSkyBle.ensurePermissions(), isNull);
    });

    test('Android <=11 usa permiso de ubicación', () async {
      DeviceInfoPlatform.instance = _FakeDeviceInfo(30);
      expect(await NeuroSkyBle.ensurePermissions(), isNull);
    });

    test('permisos denegados -> mensaje de error', () async {
      PermissionHandlerPlatform.instance = _StubPermissions(false);
      final err = await NeuroSkyBle.ensurePermissions();
      expect(err, isNotNull);
    });
  });

  group('EegStore extra', () {
    test('scanBle publica error de permisos sin tocar el escáner', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      DeviceInfoPlatform.instance = _FakeDeviceInfo(34);
      PermissionHandlerPlatform.instance = _StubPermissions(false);
      final store = EegStore();
      final list = await store.scanBle();
      expect(list, isEmpty);
      expect(store.permissionError, isNotNull);
      expect(store.isScanning, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    test('connectBle con slots llenos lanza StateError', () async {
      final store = EegStore();
      for (var i = 0; i < EegStore.maxDevices; i++) {
        store.addSimulated();
      }
      final dev = MindDevice.spp('AA:BB', 'x');
      await expectLater(store.connectBle(dev), throwsA(isA<StateError>()));
    });

    test('loadBonded descarta dispositivos sin nombre', () async {
      final messenger = TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_blue_plus/methods'),
        (call) async {
          switch (call.method) {
            case 'flutterHotRestart':
              return 0;
            case 'getBondedDevices':
              return {
                'devices': [
                  {'remote_id': 'AA:BB', 'platform_name': 'MindLink'},
                  {'remote_id': 'CC:DD', 'platform_name': ''},
                ]
              };
            default:
              return null;
          }
        },
      );
      final store = EegStore();
      final bonded = await store.loadBonded();
      expect(bonded.map((d) => d.name), ['MindLink']);
      messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_blue_plus/methods'), null);
    });
  });
}
