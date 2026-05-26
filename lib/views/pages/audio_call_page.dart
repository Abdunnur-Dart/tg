import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/webrtc_service.dart';

class AudioCallPage extends StatefulWidget {
  final String? callId;
  final String contactName;
  
  const AudioCallPage({super.key, this.callId, required this.contactName});

  @override
  State<AudioCallPage> createState() => _AudioCallPageState();
}

class _AudioCallPageState extends State<AudioCallPage> {
  final _webrtc = WebRTCService();
  final _remoteRenderer = RTCVideoRenderer(); // Всё равно нужен для структуры
  bool _isMicMuted = false;
  bool _isInitializing = true;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioCall();
  }

  Future<void> _initAudioCall() async {
    await _remoteRenderer.initialize();
    
    // Используем аудио-режим
    await _webrtc.openUserMediaAudio(_remoteRenderer);
    
    if (widget.callId == null) {
      // Инициатор звонка
      String id = await _webrtc.createCall("room_123");
      print("ID аудиозвонка: $id");
    } else {
      // Отвечающий
      await _webrtc.joinCall(widget.callId!);
    }
    
    setState(() {
      _isInitializing = false;
    });
    
    // Запускаем таймер
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration += const Duration(seconds: 1);
      });
    });
  }

  Future<void> _toggleMic() async {
    await _webrtc.toggleMic();
    setState(() {
      _isMicMuted = _webrtc.isMicMuted;
    });
  }

  Future<void> _hangUp() async {
    _callTimer?.cancel();
    await _webrtc.leaveCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _remoteRenderer.dispose();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _hangUp();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: _isInitializing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text("Подключение...", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Аватар или иконка
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.headset,
                        size: 60,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Имя собеседника
                    Text(
                      widget.contactName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Статус звонка
                    Text(
                      _webrtc.isMicMuted ? "Микрофон выключен" : "В разговоре",
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    
                    // Таймер
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 32,
                        fontFamily: 'monospace',
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Кнопки управления
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Кнопка микрофона
                          _AudioControlButton(
                            icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                            label: _isMicMuted ? "Включить" : "Выключить",
                            color: _isMicMuted ? Colors.red : Colors.white70,
                            onPressed: _toggleMic,
                          ),
                          
                          // Кнопка завершения
                          _AudioControlButton(
                            icon: Icons.call_end,
                            label: "Завершить",
                            color: Colors.red,
                            size: 70,
                            iconSize: 36,
                            onPressed: _hangUp,
                          ),
                          
                          // Пустая заглушка для симметрии
                          const SizedBox(width: 60),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AudioControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  const _AudioControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.8),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: iconSize),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}