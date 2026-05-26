import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/app_config_viewmodel.dart';
import '../widgets/custom_buttons.dart';


class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();







  
  
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _nick = TextEditingController();
  bool isLogin = true;
  bool _isLoading = false; // Индикатор загрузки


// По умолчанию пароль скрыт

























// Метод для сброса пароля
  Future<void> _handleResetPassword() async {
    final email = _email.text.trim();
    
    if (email.isEmpty) {
      _showError("Сначала введите email в поле выше");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final conf = Provider.of<AppConfigViewModel>(context, listen: false);
      await conf.resetPassword(email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Инструкция по смене пароля отправлена на почту (проверьте СПАМ)"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError("Ошибка: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }






  Future<void> _submit() async {
    // Валидация
    if (_email.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      _showError("Заполните почту и пароль");
      return;
    }
    if (!isLogin && _nick.text.trim().isEmpty) {
      _showError("Введите никнейм");
      return;
    }

    setState(() => _isLoading = true);
    final conf = Provider.of<AppConfigViewModel>(context, listen: false);

    try {
      await conf.authAction(
        _email.text.trim(),
        _pass.text.trim(),
        _nick.text.trim(),
        isLogin,
      );
      // Если вход успешен, main.dart сам переключит экран благодаря Consumer
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // void _showError(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
  //   );
  // }












@override
  Widget build(BuildContext context) {
    final conf = Provider.of<AppConfigViewModel>(context); // conf доступен здесь
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Используем backgrounds из вьюмодели
          gradient: LinearGradient(colors: conf.backgrounds[conf.bgIndex]),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(30),
              color: Colors.black45,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    Text(
                      isLogin ? "ВХОД" : "РЕГИСТРАЦИЯ",
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (!isLogin)
                      TextField(
                        controller: _nick,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Никнейм", labelStyle: TextStyle(color: Colors.white60)),
                      ),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.white60)),
                    ),
                    PasswordInput(
                      controller: _pass,
                      accentColor: conf.accentColor,
                    ),
                    if (isLogin)
                      TextButton(
                        onPressed: () => _handleResetPassword(),
                        child: const Text("Забыли пароль?", style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ),
                    const SizedBox(height: 30),
                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      // Основная кнопка входа[cite: 15]
                      StylishButton(
                        text: isLogin ? "ВОЙТИ" : "СОЗДАТЬ АККАУНТ",
                        isLoading: _isLoading,
                        color: conf.accentColor,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 15),
                      // КНОПКА GOOGLE ТЕПЕРЬ ЗДЕСЬ
                      
                    ],
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? "Нет аккаунта? Регистрация" : "Уже есть аккаунт? Войти",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }











//   @override
//   Widget build(BuildContext context) {
//     final conf = Provider.of<AppConfigViewModel>(context);
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(colors: conf.backgrounds[conf.bgIndex]),
//         ),
//         child: Center(
//           child: SingleChildScrollView(
//             child: Card(
//               margin: const EdgeInsets.all(30),
//               color: Colors.black45,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//               child: Padding(
//                 padding: const EdgeInsets.all(25),
//                 child: Column(
//                   children: [
//                     Text(
//                       isLogin ? "ВХОД" : "РЕГИСТРАЦИЯ",
//                       style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 20),
//                     if (!isLogin)
//                       TextField(
//                         controller: _nick,
//                         style: const TextStyle(color: Colors.white),
//                         decoration: const InputDecoration(labelText: "Никнейм", labelStyle: TextStyle(color: Colors.white60)),
//                       ),
//                     TextField(
//                       controller: _email,
//                       keyboardType: TextInputType.emailAddress,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.white60)),
//                     ),
// // Вместо старого TextField пароля вставь это:
// PasswordInput(
//   controller: _pass,
//   accentColor: conf.accentColor,
// ),


// // Внутри Column, после TextField с паролем:
// if (isLogin)
//   Padding(
//     padding: const EdgeInsets.all(5.0),
//     child: Center(
//       child: TextButton(
//         onPressed: () => _handleResetPassword(),
//         child: const Text(
//           "Забыли пароль?",
//           style: TextStyle(color: Colors.white54, fontSize: 13),
//         ),
//       ),
//     ),
// ),


                    
//                     const SizedBox(height: 30),
//                     _isLoading
//                         ? const CircularProgressIndicator(color: Colors.white)
//                         : // Вместо ElevatedButton(...)
// StylishButton(
//   text: isLogin ? "ВОЙТИ" : "СОЗДАТЬ АККАУНТ",
//   isLoading: _isLoading,
//   color: conf.accentColor, // будет использовать твой выбранный цвет
//   onPressed: _submit,
// ),
//                     TextButton(
//                       onPressed: () => setState(() => isLogin = !isLogin),
//                       child: Text(
//                         isLogin ? "Нет аккаунта? Регистрация" : "Уже есть аккаунт? Войти",
//                         style: const TextStyle(color: Colors.white70),
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }





void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



}
class PasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final Color accentColor;

  const PasswordInput({
    super.key, 
    required this.controller, 
    required this.accentColor
  });

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    // Используем Stack или Row вместо suffixIcon, чтобы избежать бага Flutter Web
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Пароль",
                labelStyle: TextStyle(color: Colors.white60),
                border: InputBorder.none, // Убираем стандартную линию
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          GestureDetector( // Используем GestureDetector вместо IconButton
            onTap: () {
              setState(() {
                _obscure = !_obscure;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}