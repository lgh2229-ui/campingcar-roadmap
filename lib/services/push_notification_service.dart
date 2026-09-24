import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  final _local = FlutterLocalNotificationsPlugin();
  SupabaseClient? _client;
  StreamSubscription<String>? _tokenSub;

  Future<void> initialize(SupabaseClient? client) async {
    _client = client;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      const channel = AndroidNotificationChannel('campingcar_alerts','캠핑카족 알림',description:'장소 승인, 신고, 의견 및 서비스 알림',importance:Importance.high);
      await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
      await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);
      await _registerToken();
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial);
      await _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen((m) async {
        final n=m.notification; if(n==null)return;
        await _local.show(m.hashCode,n.title,n.body,const NotificationDetails(android:AndroidNotificationDetails('campingcar_alerts','캠핑카족 알림',channelDescription:'장소 승인, 신고, 의견 및 서비스 알림',importance:Importance.high,priority:Priority.high)));
      });
    } catch (e) { debugPrint('Push init failed: $e'); }
  }

  void _handleTap(RemoteMessage message) {
    debugPrint('Push opened: kind=${message.data['kind']} reference_id=${message.data['reference_id']}');
  }

  Future<void> syncForSignedInUser() => _registerToken();

  Future<void> _registerToken() async {
    final token=await FirebaseMessaging.instance.getToken();
    if(token!=null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final c=_client; final uid=c?.auth.currentUser?.id;
    if(c==null||uid==null)return;
    try {
      await c.from('push_tokens').upsert({'user_id':uid,'token':token,'platform':'android','enabled':true,'updated_at':DateTime.now().toUtc().toIso8601String()},onConflict:'token');
    } catch(e){debugPrint('Push token save failed: $e');}
  }

  Future<void> disableCurrentToken() async {
    final c=_client; if(c==null)return;
    try { final t=await FirebaseMessaging.instance.getToken(); if(t!=null) await c.from('push_tokens').update({'enabled':false}).eq('token',t); } catch(_){}
  }
}
