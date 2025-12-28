import 'package:intl/intl.dart';

class DateFormatter {
  static String formatRelativeTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date.toLocal());

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd/MM/yy').format(date.toLocal());
    }
  }

  static String formatMessageTime(DateTime date) {
    return DateFormat('hh:mm a').format(date.toLocal());
  }
}
