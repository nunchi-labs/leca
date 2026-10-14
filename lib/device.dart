import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Phones carry GPS and do the deliveries. Computers manage the shop.
bool lecaOnPhone(BuildContext context) {
  if (kIsWeb) {
    return MediaQuery.sizeOf(context).shortestSide < 700;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
  }
}
