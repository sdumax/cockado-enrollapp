import 'package:flutter/material.dart';

abstract class PlatformUtils {
  /// Returns true if the device is a tablet (shortest side >= 600dp).
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }
}
