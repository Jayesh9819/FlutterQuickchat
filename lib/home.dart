import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart' as webview_flutter_android;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'network_service.dart';

class PreviewWebpage extends StatefulWidget {
  const PreviewWebpage({super.key});

  @override
  State<PreviewWebpage> createState() => _PreviewWebpageState();
}

class _PreviewWebpageState extends State<PreviewWebpage> {
  late final WebViewController _controller;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String _userId = '';
  String _fcmToken = '';
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  final NetworkService _networkService = NetworkService();
  static const String channelId = 'high_importance_channel';
  static const String channelName = 'High Importance Notifications';
  static const String channelDescription = 'This channel is used for important notifications.';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    initFilePicker();
    _setupFirebase();
    _initializeNotifications();
    _loadUserId();
    _getAndStoreFCMToken();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {},
        onPageStarted: (String url) {},
        onPageFinished: (String url) {},
        onWebResourceError: (WebResourceError error) {},
        onNavigationRequest: (NavigationRequest request) async {
          if (request.url.contains('.jpeg') || request.url.contains('.pdf') || request.url.contains('.mp4') || request.url.contains('.gif')  || request.url.contains('.jpg') || request.url.contains('.png')) {
            // Handle file download
            await _launchURL(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          print('Received message from JS: ${message.message}');
          if (message.message == 'uploadImage') {
            // You can handle other commands here if needed
          } else {
            print('User ID received from JS: ${message.message}');
            setState(() {
              _userId = message.message;
            });
            if (_fcmToken.isNotEmpty) {
              _networkService.storeToken(_userId, _fcmToken);
            }
          }
        },
      )
      ..loadRequest(Uri.parse("https://quickchat.biz"));
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  initFilePicker() async {
    if (Platform.isAndroid) {
      final androidController = (_controller.platform as webview_flutter_android.AndroidWebViewController);
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  Future<List<String>> _androidFilePicker(webview_flutter_android.FileSelectorParams params) async {
    if (params.acceptTypes.any((type) => type == 'image/*')) {
      final picker = image_picker.ImagePicker();
      final photo = await picker.pickImage(source: image_picker.ImageSource.camera);

      if (photo == null) {
        return [];
      }
      return [Uri.file(photo.path).toString()];
    } else if (params.acceptTypes.any((type) => type == 'video/*')) {
      final picker = image_picker.ImagePicker();
      final vidFile = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 10));
      if (vidFile == null) {
        return [];
      }
      return [Uri.file(vidFile.path).toString()];
    } else {
      try {
        if (params.mode == webview_flutter_android.FileSelectorMode.openMultiple) {
          final attachments = await FilePicker.platform.pickFiles(allowMultiple: true);
          if (attachments == null) return [];

          return attachments.files.where((element) => element.path != null).map((e) => File(e.path!).uri.toString()).toList();
        } else {
          final attachment = await FilePicker.platform.pickFiles();
          if (attachment == null) return [];
          File file = File(attachment.files.single.path!);
          return [file.uri.toString()];
        }
      } catch (e) {
        return [];
      }
    }
  }

  void _setupFirebase() {
    print("Setting up Firebase...");
    _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    ).then((value) {
      print("Firebase messaging permission status: $value");
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");
    print("Message received: ${message.notification?.title} - ${message.notification?.body}");
  }

  void _initializeNotifications() {
    print("Initializing notifications...");
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
    print("Notifications initialized.");
  }

  Future<void> _createChannel() async {
    print("Creating notification channel...");
    var androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('s'),
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    print("Notification channel created.");
  }

  void _getAndStoreFCMToken() async {
    print("Getting FCM token...");
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
    } else {
      print("Failed to get FCM token.");
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}