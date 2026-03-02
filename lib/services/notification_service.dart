import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize Firebase Messaging and request notification permissions
  static Future<void> initialize() async {
    try {
      // Request notification permissions for iOS
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
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

      // Listen to background messages
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  /// Save FCM token to Firestore user document
  static Future<void> _saveUserToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving user token: $e');
    }
  }

  /// Handle background messages
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    debugPrint('Background message received: ${message.notification?.title}');
  }

  /// Send emergency notification to a list of phone numbers
  /// In production, this would call a Cloud Function that uses Twilio/AWS SNS
  static Future<void> sendEmergencyNotification({
    required List<String> phoneNumbers,
    required String userName,
    required String userLocation,
  }) async {
    try {
      // Call a Firebase Cloud Function that handles SMS and push notifications
      await _firestore.collection('notifications').add({
        'type': 'emergency',
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
