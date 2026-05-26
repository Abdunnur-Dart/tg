import 'package:chat/services/config_service.dart';
import 'package:chat/services/fcm_v1_service.dart';
import 'package:chat/viewmodels/utils/legal_texts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support_admin_list_page.dart';
import 'support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/app_config_viewmodel.dart';
import '../widgets/profile_card.dart';
import '../widgets/document_viewer.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

void _revokeConsent(BuildContext context) async {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("ОТОЗВАТЬ СОГЛАСИЕ?", style: TextStyle(color: Colors.orangeAccent)),
      content: const Text(
        "Вы снова увидите экран согласия при следующем запуске. Ваши данные не будут удалены.",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text("ОТМЕНА", style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent.withOpacity(0.2),
            foregroundColor: Colors.orangeAccent,
          ),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('user_consent_v1');
            Navigator.pop(c);
            
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
          child: const Text("ОТОЗВАТЬ"),
        ),
      ],
    ),
  );
}

  void _openTermsOfUse(BuildContext context) async {
  const String url = "https://anvistanb17-afk.github.io/Terms-of-Use-/";
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DocumentViewer(
        title: "Пользовательское соглашение",
        url: url,
        fallbackText: LegalTexts.termsOfUse,
      ),
    ),
  );
}

  void _openPrivacyPolicy(BuildContext context) async {
    const String url = "https://anvistanb17-afk.github.io/politika/";
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewer(
          title: "Политика конфиденциальности",
          url: url,
          fallbackText: LegalTexts.privacyPolicy,
        ),
      ),
    );
  }



















void _testNotification(BuildContext context, AppConfigViewModel conf) async {
  final fcm = FCMV1Service();
  
  // Показываем индикатор
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Отправка тестового уведомления...")),
  );
  
  final result = await fcm.sendMessageNotification(
    targetUserId: conf.userId,
    senderName: "Telegraph Test",
    messageText: "🎉 Это тестовое уведомление! Если вы его видите - всё работает!",
    chatId: "test",
    chatTitle: "Тест",
  );
  
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ? "✅ Уведомление отправлено!" : "❌ Ошибка отправки. Проверьте логи."),
        backgroundColor: result ? Colors.green : Colors.red,
      ),
    );
  }
}






















void _confirmClearCache(BuildContext context, AppConfigViewModel conf) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("ОЧИСТИТЬ КЭШ?", style: TextStyle(color: Colors.orangeAccent)),
      content: const Text(
        "Это удалит локальные настройки и сбросит PIN-код. Данные будут загружены заново с сервера.",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text("ОТМЕНА", style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent.withOpacity(0.2),
            foregroundColor: Colors.orangeAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            Navigator.pop(c);
              await conf.clearLocalCache();
            
            if (context.mounted) {
              // Возвращаемся на экран авторизации/загрузки
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
          child: const Text("ОЧИСТИТЬ"),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final conf = Provider.of<AppConfigViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Параметры", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      

      // body идет СРАЗУ после AppBar и содержит ТОЛЬКО один ListView
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
const SizedBox(height: 10),

// --- СЕКЦИЯ СВЯЗИ ---
//        
          // Твоя новая карточка профиля
          ProfileCard(conf: conf), 

          const SizedBox(height: 10),

          // --- СЕКЦИЯ БЕЗОПАСНОСТИ ---










          const SizedBox(height: 25),

          // --- СЕКЦИЯ ИНТЕРФЕЙСА ---
          _buildHeader("ИНТЕРФЕЙС"),
          
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(CupertinoIcons.photo, color: Colors.white70),
            title: const Text("Фон чатов", style: TextStyle(color: Colors.white)),
            trailing: DropdownButton<int>(
              value: conf.bgIndex,
              dropdownColor: Colors.grey[900],
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white24),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Тёмно-серый", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 1, child: Text("Индиго", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 2, child: Text("Фиолетовый", style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) => conf.setBgIndex(val ?? 0),
            ),
          ),

          const SizedBox(height: 15),
          _buildSliderLabel("Размер текста", conf.fontSize.toInt().toString()),
          Slider(
            value: conf.fontSize,
            min: 12,
            max: 24,
            activeColor: conf.accentColor,
            inactiveColor: Colors.white10,
            onChanged: (v) => conf.setFontSize(v),
          ),

          _buildSliderLabel("Скругление сообщений", conf.bubbleRadius.toInt().toString()),
          Slider(
            value: conf.bubbleRadius,
            min: 0,
            max: 30,
            activeColor: conf.accentColor,
            inactiveColor: Colors.white10,
            onChanged: (v) => conf.setBubbleRadius(v),
          ),
          
          _buildTile(
            icon: CupertinoIcons.paintbrush,
            title: "Акцентный цвет",
            trailing: CircleAvatar(radius: 10, backgroundColor: conf.accentColor),
            onTap: () => _showColorPicker(context, conf),
          ),
          const SizedBox(height: 40),

 _buildHeader("СВЯЗЬ"),
          _buildTile(
            icon: Icons.support_agent,
            title: "Связаться с поддержкой",
            subtitle: "Задать вопрос разработчику",
            onTap: () {
              final user = FirebaseAuth.instance.currentUser;
              // Если почта совпадает с твоей — открываем список тикетов (Админку)
              if (user != null && user.email == "anvistanb17@gmail.com") {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const SupportAdminListPage())
                );
              } else {
                // Все остальные пользователи попадают в обычный чат
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const SupportPage())
                );
              }
            },
          ),
            const SizedBox(height: 40),

          _buildHeader("ДОКУМЕНТЫ"),

_buildTile(
  icon: Icons.privacy_tip_outlined,
  title: "Пользовательское соглашение",
            subtitle: "На что вы соглашаетесь при использовании приложения",
  trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
            onTap: () => _openTermsOfUse(context),
),

_buildTile(
  icon: Icons.privacy_tip_outlined,
  title: "Политика конфиденциальности",
  subtitle: "Как мы защищаем ваши данные",
  trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
            onTap: () => _openPrivacyPolicy(context),
),
const SizedBox(height: 40),

          _buildHeader("БЕЗОПАСНОСТЬ"),
          _buildTile(
            icon: CupertinoIcons.lock_shield,
            title: "PIN-код",
            subtitle: conf.pinCode == null ? "Не установлен" : "Активен",
            onTap: () => _showPinDialog(context, conf),
          ),
          _buildTile(
            icon: CupertinoIcons.arrow_right_square,
            title: "Выйти из профиля",
            onTap: () => _confirmLogout(context, conf),
          ),
          const SizedBox(height: 40),

          _buildHeader("ОПАСНАЯ ЗОНА!"),
_buildTile(
            icon: CupertinoIcons.trash,
            title: "Удалить аккаунт",
            titleColor: Colors.redAccent,
            onTap: () => _confirmDeleteAccount(context, conf),
          ),
          _buildTile(
  icon: Icons.privacy_tip_outlined,
  title: "Отозвать согласие и сбросить настройки",
  // subtitle: "",
  onTap: () => _revokeConsent(context),
),
 const SizedBox(height: 40),

_buildHeader("РАЗРАБОТКА"),
_buildTile(
  icon: Icons.cleaning_services_rounded,
  title: "Очистить кэш",
  subtitle: "Сброс локальных данных для отладки",
  titleColor: Colors.orangeAccent,
            onTap: () => _confirmClearCache(context, conf),
),


_buildTile(
  icon: Icons.notifications_active,
  title: "Тест уведомления",
  subtitle: "Отправить себе тестовое push",
  onTap: () => _testNotification(context, conf),
),



_buildTile(
  icon: Icons.info_outline,
  title: "О приложении",
  subtitle: "Версия ${ConfigService.appVersion}",
  onTap: () => _showAppInfoDialog(context),
),

          const Center(
            child: Text(
              "",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }


  // --- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ---

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSliderLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color titleColor = Colors.white,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        // Полупрозрачный фон (эффект стекла)
        color: Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(16),
        // Тонкая стильная граница
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        // Внутренние отступы, чтобы текст не прилипал к краям карточки
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: titleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: titleColor.withOpacity(0.9), size: 20),
        ),
        title: Text(
          title, 
          style: TextStyle(
            color: titleColor, 
            fontSize: 15, 
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null 
            ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)) 
            : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
        onTap: onTap,
      ),
    );
  }

  // --- ДИАЛОГИ ---

  void _showPinDialog(BuildContext context, AppConfigViewModel conf) {
    final ctrl = TextEditingController(text: conf.pinCode);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("УСТАНОВИТЬ PIN", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "...."),
        ),
        actions: [
         // Кнопка отмены — просто текст, чтобы не отвлекать
  TextButton(
    onPressed: () => Navigator.pop(c),
            child: const Text("ОТМЕНА", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
  ),
  
  // Кнопка действия — закругленная и с фоном
  ElevatedButton(
    style: ElevatedButton.styleFrom(
              backgroundColor: conf.accentColor,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
    ),
    onPressed: () {
              // TODO: Реализовать сохранение PIN
              Navigator.pop(c);
    },
    child: const Text("СОХРАНИТЬ"),
  ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, AppConfigViewModel conf) {
    final colors = [Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.redAccent, Colors.purpleAccent];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (c) => Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: colors.map((color) => GestureDetector(
            onTap: () {
              conf.setAccentColor(color);
              Navigator.pop(c);
            },
            child: CircleAvatar(backgroundColor: color),
          )).toList(),
        ),
      ),
    );
  }

void _confirmLogout(BuildContext context, AppConfigViewModel conf) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("ВЫЙТИ?", style: TextStyle(color: Colors.white)),
      content: const Text("Вы уверены, что хотите выйти?", style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c), 
          child: const Text("НЕТ", style: TextStyle(color: Colors.white38))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent.withOpacity(0.2),
            foregroundColor: Colors.orangeAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            // Сначала закрываем диалог
            Navigator.pop(c);
            
            // Выполняем выход
            await conf.logout();
            
            // МГНОВЕННЫЙ ПЕРЕХОД на экран авторизации
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
          child: const Text("ВЫЙТИ"),
        ),
      ],
    ),
  );
}

void _confirmDeleteAccount(BuildContext context, AppConfigViewModel conf) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("УДАЛИТЬ АККАУНТ?", style: TextStyle(color: Colors.redAccent)),
      content: const Text(
        "ВСЕ данные будут стерты навсегда:\n"
        "• Все сообщения\n"
        "• История звонков\n"
        "• Списки блокировки\n"
        "• Жалобы\n"
        "• Профиль\n\n"
        "Это действие НЕЛЬЗЯ отменить!",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c), 
          child: const Text("ОТМЕНА", style: TextStyle(color: Colors.white38))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withOpacity(0.2),
            foregroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            Navigator.pop(c); // Закрываем диалог
            
            // Показываем индикатор загрузки
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (c) => AlertDialog(
                backgroundColor: Colors.grey[900],
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 16),
                    Text("Удаление аккаунта...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            );
            
            try {
              await conf.deleteAccount();
              if (context.mounted) {
                Navigator.of(context).pop(); // Закрываем индикатор
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.of(context).pop(); // Закрываем индикатор
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Ошибка: $e"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          },
          child: const Text("УДАЛИТЬ НАВСЕГДА"),
        ),
      ],
    ),
  );
}

  void _showAppInfoDialog(BuildContext context) {}
}