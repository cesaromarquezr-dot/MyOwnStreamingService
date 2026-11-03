import 'package:flutter_test/flutter_test.dart';

import 'package:my_own_streaming_service/app_core.dart';

void main() {
  test('quiet demo preview seeding does not notify listeners', () {
    final controller = AppController.instance;
    var notifications = 0;
    void listener() => notifications++;

    controller.addListener(listener);
    controller.ensureDemoPreviewMedia(notify: false);
    controller.removeListener(listener);

    expect(notifications, 0);
  });
}
