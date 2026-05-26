import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/webrtc_service.dart';

class CallPage extends StatefulWidget {
  final String? callId;
  const CallPage({super.key, this.callId});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final _webrtc = WebRTCService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    await _webrtc.openUserMedia(_localRenderer, _remoteRenderer);
    
    // ВОТ СЮДА СТАВИМ СЛУШАТЕЛЬ СОСТОЯНИЯ ПОДКЛЮЧЕНИЯ

    
    setState(() {
      _isMicMuted = _webrtc.isMicMuted;
      _isVideoOff = _webrtc.isVideoOff;
    });

    if (widget.callId == null) {
      // Мы инициатор
      String id = await _webrtc.createCall("room_123");
      print("ID звонка: $id");
    } else {
      // Мы отвечаем
      await _webrtc.joinCall(widget.callId!);
    }
    
    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _toggleMic() async {
    await _webrtc.toggleMic();
    setState(() {
      _isMicMuted = _webrtc.isMicMuted;
    });
  }

  Future<void> _toggleCamera() async {
    await _webrtc.toggleCamera();
    setState(() {
      _isVideoOff = _webrtc.isVideoOff;
    });
  }

  Future<void> _hangUp() async {
    await _webrtc.leaveCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
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
        backgroundColor: Colors.black,
        body: _isInitializing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      "Подключение к звонку...",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  // Удаленное видео (собеседник)
                  Positioned.fill(
                    child: RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                  
                  // Затемнение, если видео выключено
                  if (_webrtc.remoteStream == null || _webrtc.remoteStream?.getVideoTracks().isEmpty == true)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              "Видео собеседника выключено",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Локальное видео (я) - маленькое в углу
                  Positioned(
                    top: 60,
                    right: 20,
                    width: 120,
                    height: 160,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                          if (_isVideoOff)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Icon(Icons.videocam_off, color: Colors.white54, size: 30),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Таймер звонка
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "В звонке",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  
                  // Панель кнопок управления
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Кнопка микрофона
                          _ControlButton(
                            icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                            label: _isMicMuted ? "Мик. выкл" : "Мик. вкл",
                            color: _isMicMuted ? Colors.red : Colors.white,
                            onPressed: _toggleMic,
                          ),
                          
                          // Кнопка завершения звонка
                          _ControlButton(
                            icon: Icons.call_end,
                            label: "Завершить",
                            color: Colors.red,
                            size: 60,
                            iconSize: 32,
                            onPressed: _hangUp,
                          ),
                          
                          // Кнопка камеры
                          _ControlButton(
                            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                            label: _isVideoOff ? "Камера выкл" : "Камера вкл",
                            color: _isVideoOff ? Colors.red : Colors.white,
                            onPressed: _toggleCamera,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Информация о статусе
                  Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        _webrtc.isMicMuted ? "Микрофон выключен" : "",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Виджет кнопки управления звонком
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  const _ControlButton({
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}