import 'package:dio/dio.dart';

/// Maps Dio / network failures to short Russian user-facing messages.
String apiErrorMessage(Object error, {String fallback = 'Что-то пошло не так. Попробуйте ещё раз.'}) {
  if (error is! DioException) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) return text.substring(11);
    return fallback;
  }

  final data = error.response?.data;
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return _localizeBackendMessage(message.trim());
    }
    if (message is List && message.isNotEmpty) {
      return message.map((e) => _localizeBackendMessage(e.toString())).join('\n');
    }
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Сервер не отвечает. Проверьте интернет и попробуйте снова.';
    case DioExceptionType.connectionError:
      return 'Нет связи с сервером. Проверьте интернет.';
    case DioExceptionType.cancel:
      return 'Запрос отменён.';
    case DioExceptionType.badResponse:
      final code = error.response?.statusCode;
      if (code == 401) return 'Сессия истекла. Войдите снова.';
      if (code == 403) return 'Недостаточно прав для этого действия.';
      if (code == 404) return 'Данные не найдены.';
      if (code == 409) return 'Это действие уже выполнено.';
      if (code == 429) return 'Слишком много запросов. Подождите минуту.';
      if (code == 503) return 'Сервис временно недоступен. Попробуйте позже.';
      if (code != null && code >= 500) return 'Ошибка сервера. Попробуйте позже.';
      return fallback;
    default:
      return fallback;
  }
}

String _localizeBackendMessage(String message) {
  const map = <String, String>{
    'You have already applied to this event': 'Вы уже подали заявку на это событие',
    'You cannot apply to your own event': 'Нельзя подать заявку на своё событие',
    'This event is no longer accepting applications': 'Событие больше не принимает заявки',
    'You have already made an offer on this request': 'Вы уже откликнулись на этот запрос',
    'This offer has already been processed': 'Этот отклик уже обработан',
    'This application has already been processed': 'Эта заявка уже обработана',
    'Only the host can view applications for this event': 'Только организатор видит заявки',
    'Event is already cancelled': 'Событие уже отменено',
    'You have already reviewed this user for this event': 'Вы уже оставили отзыв по этому событию',
  };
  return map[message] ?? message;
}
