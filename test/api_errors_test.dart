import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/utils/api_errors.dart';

void main() {
  test('reads backend message from map', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 400,
        data: {'message': 'Неверный код'},
      ),
      type: DioExceptionType.badResponse,
    );
    expect(apiErrorMessage(error), 'Неверный код');
  });

  test('maps connection errors', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(apiErrorMessage(error), contains('интернет'));
  });

  test('maps 503', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 503,
      ),
      type: DioExceptionType.badResponse,
    );
    expect(apiErrorMessage(error), contains('недоступен'));
  });
}
