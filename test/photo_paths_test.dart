import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_laundry_tracker/services/image_store.dart';
import 'package:smart_laundry_tracker/state/wardrobe_state.dart';

class _Docs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String path;
  _Docs(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  test('photos survive iOS moving the app folder on an update', () async {
    final root = Directory.systemTemp.createTempSync('fmf');
    addTearDown(() => root.deleteSync(recursive: true));
    // This install's folder, with the photo saved by the last one.
    final docs = Directory('${root.path}/NEW-APP-ID/Documents')..createSync(recursive: true);
    PathProviderPlatform.instance = _Docs(docs.path);
    final photo = File('${docs.path}/garments/g_1.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final stray = File('${docs.path}/garments/g_unused.jpg')..writeAsBytesSync([4]);

    // What the last install saved: the photo's path in its old folder.
    const old = '/var/mobile/Containers/Data/Application/OLD-APP-ID/Documents/garments/g_1.png';
    SharedPreferences.setMockInitialValues({
      'welcome_done_v1': true,
      'saved_garments_v1': jsonEncode([
        {'id': 'g1', 'name': 'Tee', 'category': 'tops', 'status': 'dirtyHamper', 'imageUrl': old, 'wearCount': 4},
      ]),
    });
    final state = WardrobeState(load: false);
    await state.loadFromStorage();

    final tee = state.garments.single;
    expect(tee.imageUrl, photo.path, reason: 'pointed at the photo in the new folder');
    expect((tee.status.name, tee.wearCount), ('dirtyHamper', 4), reason: 'nothing else changed');

    await ImageStore.deleteUnused({old});
    expect(photo.existsSync(), isTrue, reason: 'an old path never gets a photo deleted');
    expect(stray.existsSync(), isFalse, reason: 'unused photos are still cleaned up');
  });
}
