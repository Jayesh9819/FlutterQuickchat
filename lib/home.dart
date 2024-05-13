import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'network_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WebViewController controller;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String _userId = '';
  String _fcmToken = '';
  final NetworkService _networkService = NetworkService();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'High Importance Notifications';
  static const String channelDescription = 'This channel is used for important notifications.';

  @override
  void initState() {
    super.initState();
    _setupFirebase();
    _initializeNotifications();
    _loadUserId();
    _getAndStoreFCMToken();
  }

  void _setupFirebase() {
    _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,

    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");
    print("Message received: ${message.notification?.title} - ${message.notification?.body}");

  }


  void _initializeNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (String? payload) async {
        if (payload != null) {
          print('notification payload: $payload');
        }
      },
    );


  }

  Future<void> _createChannel() async {
    var androidChannel = AndroidNotificationChannel(
      channelId,  // Channel ID
      channelName,  // Channel name
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('s'),  // Ensure this is correctly referred
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _showTestNotification() async {
    var androidDetails = AndroidNotificationDetails(
      channelId,  // Channel ID
      channelName,  // Channel name
      importance: Importance.max,  // The importance level of the notification
      priority: Priority.high,  // The priority of the notification
      playSound: true,
      sound: RawResourceAndroidNotificationSound('s'),

    );

    var notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,  // Notification ID
      "Test Title",  // Notification title
      "Test Body",  // Notification body
      notificationDetails,  // Notification details
    );
  }



  void _getAndStoreFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      setState(() {
        _fcmToken = token;
      });
      print("FCM Token: $_fcmToken");
      if (_userId.isNotEmpty) {
        _networkService.storeToken(_userId, _fcmToken);
        _createChannel();

      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebView(
        javascriptMode: JavascriptMode.unrestricted,
        initialUrl: 'https://quickchat.biz',
        onWebViewCreated: (WebViewController webViewController) {
          controller = webViewController;
        },
        javascriptChannels: <JavascriptChannel>{
          _alertJavascriptChannel(context),
        },
      ),
    );
  }

  JavascriptChannel _alertJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'Flutter',
      onMessageReceived: (JavascriptMessage message) {
        print('User ID received from JS: ${message.message}');
        setState(() {
          _userId = message.message;
        });
        if (_fcmToken.isNotEmpty) {
          _networkService.storeToken(_userId, _fcmToken);
        }
        _storeUserId(_userId);
      },
    );
  }

  Future<void> _storeUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id') ?? '';
    });
  }
}
