import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:safepath_campus/features/companion/companion_page.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _companionRequestSubscription;
  static final Set<String> _shownCompanionRequestIds = <String>{};
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize Firebase Messaging and request notification permissions
  static Future<void> initialize({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    try {
      _navigatorKey = navigatorKey;

      // Request notification permissions for iOS
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Get and print FCM token
      final token = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');

      // Save token to user profile (for sending notifications later)
      if (_auth.currentUser != null) {
        await _saveUserToken(token ?? '');
      }

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.notification?.title}');
        // Handle foreground notification display
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _openFromPayload(message.data['payload']?.toString());
      });

      // Listen to background messages
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      _auth.authStateChanges().listen((user) {
        if (user == null) {
          _companionRequestSubscription?.cancel();
          _companionRequestSubscription = null;
          _shownCompanionRequestIds.clear();
          return;
        }
        _startCompanionRequestListener(user.uid);
      });

      if (_auth.currentUser != null) {
        _startCompanionRequestListener(_auth.currentUser!.uid);
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  /// Save FCM token to Firestore user document
  static Future<void> _saveUserToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('Users').doc(userId).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user token: $e');
    }
  }

  /// Handle background messages
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    debugPrint('Background message received: ${message.notification?.title}');
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    _openFromPayload(response.payload);
  }

  static void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (!payload.startsWith('companion:')) return;

    final nav = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    if (nav == null || context == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => const CompanionPage(),
      ),
    );
  }

  static Future<void> _startCompanionRequestListener(String myUid) async {
    await _companionRequestSubscription?.cancel();
    _companionRequestSubscription = _firestore
        .collection('companion_requests')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        final hostUid = (data['hostUid'] ?? '').toString();
        if (hostUid == myUid) continue;
        final roomCode = (data['roomCode'] ?? change.doc.id).toString().toUpperCase();
        final requestId = change.doc.id;
        if (_shownCompanionRequestIds.contains(requestId)) continue;
        _shownCompanionRequestIds.add(requestId);
        _showCompanionRequestLocalNotification(roomCode: roomCode, id: requestId.hashCode);
      }
    });
  }

  static Future<void> _showCompanionRequestLocalNotification({
    required String roomCode,
    required int id,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'companion_requests',
      'Companion Requests',
      channelDescription: 'Virtual walk-home request alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iOSDetails = DarwinNotificationDetails();
    await _localNotifications.show(
      id,
      'Companion request',
      'A student requested a virtual walk-home. Tap to join.',
      const NotificationDetails(android: androidDetails, iOS: iOSDetails),
      payload: 'companion:$roomCode',
    );
  }

  /// Send emergency notification to a list of phone numbers
  /// In production, this would call a Cloud Function that uses Twilio/AWS SNS
  static Future<void> sendEmergencyNotification({
    required List<String> phoneNumbers,
    required String userName,
    required String userLocation,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      // Call a Firebase Cloud Function that handles SMS and push notifications
      await _firestore.collection('notifications').add({
        'type': 'emergency',
        'senderId': userId,
        'recipientPhones': phoneNumbers,
        'senderName': userName,
        'userLocation': userLocation,
        'timestamp': FieldValue.serverTimestamp(),
        'message': '$userName sent an emergency alert. Location: $userLocation',
        'status': 'pending',
      });

      debugPrint('Emergency notification queued for: $phoneNumbers');
    } catch (e) {
      debugPrint('Error sending emergency notification: $e');
    }
  }

  /// Send push notification to specific user
  static Future<void> sendPushNotification({
    required String title,
    required String body,
    required String recipientUserId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'push',
        'title': title,
        'body': body,
        'recipientUserId': recipientUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  /// Subscribe to emergency notifications for specific phone number
  static Future<void> subscribeToEmergencyUpdates(String phoneNumber) async {
    try {
      await _firebaseMessaging.subscribeToTopic('emergency_$phoneNumber');
      debugPrint('Subscribed to emergency updates for: $phoneNumber');
    } catch (e) {
      debugPrint('Error subscribing to emergency updates: $e');
    }
  }

  /// Unsubscribe from emergency notifications
  static Future<void> unsubscribeFromEmergencyUpdates(String phoneNumber) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('emergency_$phoneNumber');
      debugPrint('Unsubscribed from emergency updates for: $phoneNumber');
    } catch (e) {
      debugPrint('Error unsubscribing from emergency updates: $e');
    }
  }
}
