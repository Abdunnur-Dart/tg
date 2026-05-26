import 'package:flutter/material.dart';

class RuStoreOfferPage extends StatelessWidget {
  const RuStoreOfferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Публичная оферта", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: "1. ОСНОВНЫЕ ПОЛОЖЕНИЯ",
              content: """

1.2. Правообладатель:
-Индивидуальный предприниматель (ваше ФИО)
- Email для связи: anvistanb17@gmail.com

1.3. Приложение предоставляется пользователю на условиях простой (неисключительной) лицензии.
Права на интеллектуальную собственность принадлежат Правообладателю.
Пользователь НЕ имеет права копировать, модифицировать или дизассемблировать Приложение.
              """,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: "2. УСЛОВИЯ ИСПОЛЬЗОВАНИЯ",
              content: """
2.1. Использование Приложения возможно только после:
- Подтверждения возраста (18+)
- Принятия условий Оферты
- Согласия с Политикой конфиденциальности

2.2. Приложение предоставляется БЕСПЛАТНО. Платные функции ОТСУТСТВУЮТ.

2.3. Правообладатель оставляет за собой право:
- Изменять функционал Приложения
- Проводить технические работы с предварительным уведомлением
- Блокировать аккаунты при нарушении условий
              """,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: "3. ОТВЕТСТВЕННОСТЬ СТОРОН",
              content: """
3.1. Приложение предоставляется "КАК ЕСТЬ" (AS IS).

3.2. Правообладатель НЕ НЕСЕТ ответственности за:
- Содержание сообщений пользователей
- Перерывы в работе, связанные с провайдерами связи
- Убытки, возникшие из-за форс-мажорных обстоятельств

3.3. Ответственность Правообладателя ограничена 1 000 (одной тысячей) рублей.
              """,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: "4. ПОЛИТИКА ВОЗВРАТА СРЕДСТВ",
              content: """
4.1. Приложение распространяется БЕСПЛАТНО.

4.2. Внутриприкладные покупки (in-app purchases) ОТСУТСТВУЮТ.

4.3. Пользователь не может быть лишен денежных средств при использовании Приложения.

4.4. Возврат средств не требуется ввиду отсутствия платных услуг.
              """,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: "5. КОНТАКТЫ ДЛЯ ЮРИДИЧЕСКИХ ОБРАЩЕНИЙ",
              content: """
Для направления официальных обращений:

Email: anvistanb17@gmail.com
Срок рассмотрения обращений: 30 (тридцать) календарных дней.

              """,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: "6. РЕКВИЗИТЫ",
              content: """
              """,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    "Используя приложение, вы подтверждаете, что:",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "✅ Ознакомлены с условиями Оферты\n"
                    "✅ Принимаете их в полном объеме\n"
                    "✅ Подтверждаете, что вам есть 18 лет",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Сохраняем согласие с офертой
                        // и возвращаемся назад
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Я ПРИНИМАЮ УСЛОВИЯ",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}