export 'launcher_stub.dart'
    if (dart.library.html) 'launcher_web.dart'
    if (dart.library.io) 'launcher_mobile.dart';
