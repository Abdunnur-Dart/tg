import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class WebRTCService {
  final _db = FirebaseFirestore.instance;
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  
  bool isMicMuted = false;
  bool isVideoOff = false;
  String? _currentCallId;
  StreamSubscription? _callSubscription;
  StreamSubscription? _remoteCandidatesSubscription;

Map<String, dynamic> configuration = {
  'iceServers': [
    // STUN серверы для обнаружения вашего IP
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
    
    // TURN сервер Open Relay Project (основной)
    {
      'urls': [
        'turn:openrelay.metered.ca:80',
        'turn:openrelay.metered.ca:443',
        'turn:openrelay.metered.ca:5349',
      ],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ],
  'iceTransportPolicy': 'all',
  'iceCandidatePoolSize': 5,
};
  // --- УПРАВЛЕНИЕ МИКРОФОНОМ ---
  Future<void> toggleMic() async {
    if (localStream == null) return;
    
    isMicMuted = !isMicMuted;
    final audioTracks = localStream!.getAudioTracks();
    for (var track in audioTracks) {
      track.enabled = !isMicMuted;
    }
  }





  // --- УПРАВЛЕНИЕ КАМЕРОЙ ---
  Future<void> toggleCamera() async {
    if (localStream == null) return;
    
    isVideoOff = !isVideoOff;
    final videoTracks = localStream!.getVideoTracks();
    for (var track in videoTracks) {
      track.enabled = !isVideoOff;
    }
  }



// Аудиозвонок (без видео)
Future<void> openUserMediaAudio(RTCVideoRenderer? remoteRenderer) async {
  final Map<String, dynamic> mediaConstraints = {
    'audio': true,
    'video': false,  // Только аудио
  };

  localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  
  // Если remoteRenderer передан, всё равно показываем картинку "Аудиозвонок"
  if (remoteRenderer != null) {
    // Можно показать заглушку вместо видео
  }

  _peerConnection = await createPeerConnection(configuration);
  
  localStream!.getTracks().forEach((track) {
    _peerConnection!.addTrack(track, localStream!);
  });

  // Для аудио onTrack будет содержать только аудиодорожки
  _peerConnection!.onTrack = (event) {
    remoteStream = event.streams[0];
    // Для аудио рендерить нечего, но можно показать аватар
    if (remoteRenderer != null) {
      // Создаём чёрный/серый экран с текстом
      _showAudioPlaceholder(remoteRenderer);
    }
  };
}

void _showAudioPlaceholder(RTCVideoRenderer renderer) async {
  // Создаём чёрное изображение как заглушку
  // Или просто не используем видео-рендерер
}



  // --- ИНИЦИАЛИЗАЦИЯ МЕДИА ---
Future<void> openUserMedia(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo) async {
  final Map<String, dynamic> mediaConstraints = {
    'audio': true,
    'video': {'facingMode': 'user'}
  };

  localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  localVideo.srcObject = localStream;

  // ⬇️ ВОТ ЭТУ КОНФИГУРАЦИЮ ЗАМЕНИТЕ ⬇️
  Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:5349',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'iceTransportPolicy': 'all',
    'iceCandidatePoolSize': 5,
  };

  _peerConnection = await createPeerConnection(configuration);
  
  localStream!.getTracks().forEach((track) {
    _peerConnection!.addTrack(track, localStream!);
  });

  _peerConnection!.onTrack = (event) {
    remoteStream = event.streams[0];
    remoteVideo.srcObject = remoteStream;
  };
}

  // --- СОЗДАНИЕ ЗВОНКА (Инициатор) ---
  Future<String> createCall(String roomId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Пользователь не авторизован");
    
    DocumentReference callDoc = _db.collection('calls').doc();
    _currentCallId = callDoc.id;
    
    // Собираем свои ICE-кандидаты
    var callerCandidatesCollection = callDoc.collection('callerCandidates');
    _peerConnection!.onIceCandidate = (candidate) {
      callerCandidatesCollection.add(candidate.toMap());
        };

    // Создаем оффер
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    Map<String, dynamic> roomWithOffer = {
      'offer': offer.toMap(),
      'participants': [currentUser.uid],
      'callerId': currentUser.uid,
      'status': 'ringing', // Звонок активен
      'createdAt': FieldValue.serverTimestamp(),
    };
    await callDoc.set(roomWithOffer);
    
    // Слушаем ответ от собеседника
    _listenToAnswer(callDoc);
    
    // Слушаем статус звонка
    _listenToCallStatus();
    
    return callDoc.id;
  }

  // --- СЛУШАЕМ ОТВЕТ (для инициатора) ---
  void _listenToAnswer(DocumentReference callDoc) {
    callDoc.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      
      // Проверяем, не завершен ли звонок
      if (data['status'] == 'ended') {
        debugPrint("🔴 Звонок завершен собеседником");
        dispose();
        return;
      }
      
      // Если появился ответ — применяем его
      if (data['answer'] != null && _peerConnection != null) {
      }
    });
  }

  // --- ПРИСОЕДИНЕНИЕ К ЗВОНКУ (Отвечающий) ---
  Future<void> joinCall(String callId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Пользователь не авторизован");
    
    _currentCallId = callId;
    var callDoc = _db.collection('calls').doc(callId);
    
    // Добавляем себя в участники
    await callDoc.update({
      'participants': FieldValue.arrayUnion([currentUser.uid])
    });
    
    // Получаем оффер
    var callData = (await callDoc.get()).data() as Map<String, dynamic>;
    
    // Проверяем статус звонка
    if (callData['status'] == 'ended') {
      debugPrint("🔴 Звонок уже завершен");
      return;
    }
    
    var offer = callData['offer'];
    
    // Применяем оффер
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    
    // Подписываемся на ICE-кандидаты звонящего
    _subscribeToRemoteCandidates(callDoc, 'callerCandidates');

    // Создаем ответ
    var answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    // Отправляем ответ
    await callDoc.update({
      'answer': answer.toMap(),
      'status': 'active', // Звонок активен
    });
    
    // Отправляем свои ICE-кандидаты
    var calleeCandidatesCollection = callDoc.collection('calleeCandidates');
    _peerConnection!.onIceCandidate = (candidate) {
      calleeCandidatesCollection.add(candidate.toMap());
        };
    
    _listenToCallStatus();
    debugPrint("✅ Присоединились к звонку");
  }

  // --- ПОДПИСКА НА ICE-КАНДИДАТЫ СОБЕСЕДНИКА ---
  void _subscribeToRemoteCandidates(DocumentReference callDoc, String collectionName) {
    _remoteCandidatesSubscription?.cancel();
    _remoteCandidatesSubscription = callDoc
        .collection(collectionName)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          await _peerConnection?.addCandidate(candidate);
        }
      }
    });
  }

  // --- ОТСЛЕЖИВАНИЕ СТАТУСА ЗВОНКА ---
  void _listenToCallStatus() {
    if (_currentCallId == null) return;
    
    _callSubscription?.cancel();
    _callSubscription = _db.collection('calls')
        .doc(_currentCallId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        debugPrint("🔴 Звонок удален");
        dispose();
        return;
      }
      
      final data = snapshot.data() as Map<String, dynamic>;
      
      // Проверяем статус
      if (data['status'] == 'ended') {
        debugPrint("🔴 Звонок завершен");
        dispose();
        return;
      }
      
      final participants = List<String>.from(data['participants'] ?? []);
      
      // Если остался один участник — завершаем
      if (participants.length < 2 && data['status'] == 'active') {
        debugPrint("⚠️ Остался один участник, завершаем звонок");
        _endCall();
      }
    });
  }

  // --- ЗАВЕРШЕНИЕ ЗВОНКА ---
  Future<void> _endCall() async {
    if (_currentCallId != null) {
      await _db.collection('calls').doc(_currentCallId).update({
        'status': 'ended',
      });
    }
    dispose();
  }

  // --- ВЫХОД ИЗ ЗВОНКА ---
  Future<void> leaveCall() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (_currentCallId != null && currentUser != null) {
      // Удаляем себя из участников
      await _db.collection('calls').doc(_currentCallId).update({
        'participants': FieldValue.arrayRemove([currentUser.uid])
      });
      
      // Проверяем, остался ли кто-то
      final doc = await _db.collection('calls').doc(_currentCallId).get();
      
      if (doc.exists) {
        final participants = List<String>.from(doc.data()?['participants'] ?? []);
        
        if (participants.isEmpty) {
          // Если никого не осталось — удаляем звонок
          await _db.collection('calls').doc(_currentCallId).delete();
          debugPrint("✅ Звонок полностью завершён и удалён");
        } else {
          // Иначе помечаем как завершенный
          await _db.collection('calls').doc(_currentCallId).update({
            'status': 'ended',
          });
          debugPrint("🔴 Звонок завершен, собеседник получит уведомление");
        }
      }
    }
    
    dispose();
  }

  void dispose() {
    _callSubscription?.cancel();
    _remoteCandidatesSubscription?.cancel();
    localStream?.dispose();
    remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _currentCallId = null;
    debugPrint("🧹 Ресурсы очищены");
  }
}