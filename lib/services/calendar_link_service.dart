import 'package:url_launcher/url_launcher.dart';

class CalendarLinkService {
  static Uri buildGoogleCalendarUrl({
    required String title,
    String? description,
    String? location,
    DateTime? start,
    DateTime? end,
  }) {
    final startAt = start ?? DateTime.now().add(const Duration(hours: 1));
    final endAt = end ?? startAt.add(const Duration(hours: 1));

    String format(DateTime dateTime) {
      final utc = dateTime.toUtc();
      return '${utc.year.toString().padLeft(4, '0')}'
          '${utc.month.toString().padLeft(2, '0')}'
          '${utc.day.toString().padLeft(2, '0')}T'
          '${utc.hour.toString().padLeft(2, '0')}'
          '${utc.minute.toString().padLeft(2, '0')}'
          '${utc.second.toString().padLeft(2, '0')}Z';
    }

    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${format(startAt)}/${format(endAt)}',
    };

    if (description != null && description.isNotEmpty) {
      params['details'] = description;
    }
    if (location != null && location.isNotEmpty) {
      params['location'] = location;
    }

    return Uri.https('calendar.google.com', '/calendar/render', params);
  }

  static Future<bool> openGoogleCalendar({
    required String title,
    String? description,
    String? location,
    DateTime? start,
    DateTime? end,
  }) async {
    final uri = buildGoogleCalendarUrl(
      title: title,
      description: description,
      location: location,
      start: start,
      end: end,
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}