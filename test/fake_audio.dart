// Fakes del plugin audioplayers para tests de unidad sin plataforma.
//
// El plugin abre canales Method/Event por reproductor con ids aleatorios, así
// que en vez de mockear canales se sustituyen las interfaces del platform
// interface por implementaciones no-op.
import 'dart:async';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';

class FakeAudioplayersPlatform implements AudioplayersPlatformInterface {
  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      const Stream<AudioEvent>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeGlobalAudioplayersPlatform
    implements GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      const Stream<GlobalAudioEvent>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Instala los fakes; llamar al inicio de `main()` en cada test de widget.
void installFakeAudio() {
  AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance =
      FakeGlobalAudioplayersPlatform();
}
