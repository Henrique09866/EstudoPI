import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';

class AndroidStudyWidgetService {
  const AndroidStudyWidgetService._();

  static const _channel = MethodChannel('curujao/widgets');

  static Future<void> updateNextTask(Task? task) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': task?.title ?? 'Nenhuma tarefa pendente',
        'subtitle': task == null
            ? 'Toque para abrir seus estudos'
            : 'Próxima: ${_formatDateTime(task.dateTime)}',
      });
    } on PlatformException {
      // O restante do aplicativo funciona normalmente onde widgets não são
      // suportados, como desktop e testes.
    } on MissingPluginException {
      // O canal nativo só existe no Android.
    }
  }

  static String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} às ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}
