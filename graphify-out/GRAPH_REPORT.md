# Graph Report - overmind_flutter  (2026-08-21)

## Corpus Check
- 33 files · ~66,281 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 430 nodes · 504 edges · 24 communities (22 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `416d0662`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- battle_game.dart
- home_screen.dart
- eeg_data.dart
- theme.dart
- game_screen.dart
- neurosky_ble.dart
- data_analyzer_screen.dart
- my_application.cc
- mind_source.dart
- eeg_store.dart
- thinkgear_parser.dart
- thinkgear_parser_test.dart
- .application
- Overmind (Flutter)
- gen_icon.py
- gen_sachiel.py
- PositionComponent
- MainActivity
- MindSource
- LaunchImage.imageset/README.md

## God Nodes (most connected - your core abstractions)
1. `EegStore` - 12 edges
2. `Overmind (Flutter)` - 9 edges
3. `_MyApplication` - 6 edges
4. `EegData` - 5 edges
5. `BattleGame` - 4 edges
6. `_DataAnalyzerScreenState` - 4 edges
7. `_GameScreenState` - 4 edges
8. `_HomeScreenState` - 4 edges
9. `my_application_local_command_line()` - 4 edges
10. `setup()` - 4 edges

## Surprising Connections (you probably didn't know these)
- `initState` --references--> `EegStore`  [EXTRACTED]
  lib/src/screens/data_analyzer_screen.dart → lib/src/state/eeg_store.dart
- `initState` --references--> `EegStore`  [EXTRACTED]
  lib/src/screens/game_screen.dart → lib/src/state/eeg_store.dart
- `build` --references--> `EegStore`  [EXTRACTED]
  lib/src/screens/home_screen.dart → lib/src/state/eeg_store.dart
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/main.cc → linux/my_application.cc

## Import Cycles
- None detected.

## Communities (24 total, 2 thin omitted)

### Community 0 - "battle_game.dart"
Cohesion: 0.02
Nodes (89): AudioPlayer?, dart:ui, Image, _applyHit, applyHome, attention, _audioOk, ballImage (+81 more)

### Community 1 - "home_screen.dart"
Cohesion: 0.07
Nodes (31): data_analyzer_screen.dart, game_screen.dart, IconData, levels_mind_screen.dart, OvermindApp, _LegendDot, _GameOverOverlay, accent (+23 more)

### Community 2 - "eeg_data.dart"
Cohesion: 0.06
Nodes (30): double get, int get, address, applyCapture, attention, bands, delta, halpha (+22 more)

### Community 3 - "theme.dart"
Cohesion: 0.07
Nodes (27): build, main, store, main, setPreferredOrientations, store, bg, bgLighter (+19 more)

### Community 4 - "game_screen.dart"
Cohesion: 0.09
Nodes (28): FlameGame, ../game/battle_game.dart, BattleGame, DataAnalyzerScreen, _DataAnalyzerScreenState, initState, build, createState (+20 more)

### Community 5 - "neurosky_ble.dart"
Cohesion: 0.08
Nodes (25): BluetoothDevice, ../eeg/thinkgear_parser.dart, connect, _controller, _dataFound, device, disconnect, dispose (+17 more)

### Community 6 - "data_analyzer_screen.dart"
Cohesion: 0.09
Nodes (24): Color, dart:async, ../eeg/eeg_data.dart, _attention, build, color, createState, dispose (+16 more)

### Community 7 - "my_application.cc"
Cohesion: 0.10
Nodes (20): FlPluginRegistry, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins(), main() (+12 more)

### Community 8 - "mind_source.dart"
Cohesion: 0.08
Nodes (23): dart:math, EegData get, int?, _attention, connect, _controller, disconnect, dispose (+15 more)

### Community 9 - "eeg_store.dart"
Cohesion: 0.09
Nodes (21): ../ble/mind_source.dart, ../ble/neurosky_ble.dart, bool get, ChangeNotifier, EegData, addSimulated, _bleAvailable, connectBle (+13 more)

### Community 10 - "thinkgear_parser.dart"
Cohesion: 0.10
Nodes (20): addBytes, attention, _b3, _buf, _decodePayload, _len, meditation, _out (+12 more)

### Community 11 - "thinkgear_parser_test.dart"
Cohesion: 0.11
Nodes (16): @immutable, dart:typed_data, MindWaveCapture, package:flutter_test/flutter_test.dart, package:overmind/src/eeg/eeg_data.dart, package:overmind/src/eeg/thinkgear_parser.dart, package:overmind/src/state/eeg_store.dart, buildPacket (+8 more)

### Community 12 - ".application"
Cohesion: 0.15
Nodes (10): Any, Bool, Flutter, FlutterAppDelegate, AppDelegate, RunnerTests, UIApplication, UIKit (+2 more)

### Community 13 - "Overmind (Flutter)"
Cohesion: 0.20
Nodes (9): Cómo ejecutar, Estructura, Mapeo del proyecto original, Notas de ingeniería, Overmind (Flutter), Permisos, Qué es, Stack (+1 more)

### Community 14 - "gen_icon.py"
Cohesion: 0.32
Nodes (4): core_orb(), hbar(), radial_glow(), within_roundrect()

### Community 15 - "gen_sachiel.py"
Cohesion: 0.43
Nodes (4): _capsule(), _ell(), setup(), _tri()

### Community 16 - "PositionComponent"
Cohesion: 0.40
Nodes (5): Fighter, Fireball, Hud, VsBanner, PositionComponent

### Community 18 - "MindSource"
Cohesion: 0.67
Nodes (3): MindSource, SimulatedMindSource, NeuroSkyBle

## Knowledge Gaps
- **252 isolated node(s):** `XCTest`, `store`, `main`, `setPreferredOrientations`, `build` (+247 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `EegStore` connect `game_screen.dart` to `battle_game.dart`, `home_screen.dart`, `data_analyzer_screen.dart`, `eeg_store.dart`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Why does `MindWaveCapture` connect `thinkgear_parser_test.dart` to `thinkgear_parser.dart`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Why does `EegData` connect `eeg_store.dart` to `home_screen.dart`, `eeg_data.dart`, `neurosky_ble.dart`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **What connects `XCTest`, `store`, `main` to the rest of the system?**
  _252 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `battle_game.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.022222222222222223 - nodes in this community are weakly interconnected._
- **Should `home_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.06854838709677419 - nodes in this community are weakly interconnected._
- **Should `eeg_data.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._