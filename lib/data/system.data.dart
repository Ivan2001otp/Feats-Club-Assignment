import 'package:intl/intl.dart';

class SystemData {
  static String _formateDateTime() {
    final dt = DateTime.now();
    final formatter = DateFormat.Hms();
    return formatter.format(dt);
  }

  static String getFormattedTime() {
    return DateTime.now().toIso8601String();
  }

  static String getSystemTimeProviderinMillis() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
