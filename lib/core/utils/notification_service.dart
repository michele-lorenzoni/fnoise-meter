import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> showSimpleNotification(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id', // 1. ID del canale
      'your_channel_name', // 2. Nome del canale
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    var iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Hello!',
      'This is a simple notification.',
      platformChannelSpecifics,
    );
  }