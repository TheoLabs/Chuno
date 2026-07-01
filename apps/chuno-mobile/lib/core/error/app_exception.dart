import 'package:dio/dio.dart';

/// 앱 전역 에러 타입. dio/네트워크 예외를 UI/도메인이 다루기 쉬운 형태로 변환한 것.
sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;
  const AppException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => '$runtimeType($statusCode): $message';

  /// dio 예외를 앱 예외로 변환한다.
  factory AppException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(cause: e);
      case DioExceptionType.connectionError:
        return NetworkFailure(cause: e);
      case DioExceptionType.cancel:
        return CanceledFailure(cause: e);
      case DioExceptionType.badCertificate:
        return NetworkFailure(message: '보안 인증서 오류가 발생했어요.', cause: e);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final status = e.response?.statusCode;
        final serverMsg = _extractMessage(e.response?.data);
        if (status == 401 || status == 403) {
          return UnauthorizedFailure(
            message: serverMsg ?? '인증이 필요해요. 다시 로그인해 주세요.',
            statusCode: status,
            cause: e,
          );
        }
        if (status != null && status >= 500) {
          return ServerFailure(
            message: serverMsg ?? '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
            statusCode: status,
            cause: e,
          );
        }
        if (status != null && status >= 400) {
          return RequestFailure(
            message: serverMsg ?? '요청을 처리할 수 없어요.',
            statusCode: status,
            cause: e,
          );
        }
        return UnknownFailure(cause: e);
    }
  }

  static String? _extractMessage(Object? data) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['detail'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return null;
  }
}

class NetworkFailure extends AppException {
  const NetworkFailure({String? message, super.cause})
      : super(message ?? '네트워크 연결을 확인해 주세요.');
}

class TimeoutFailure extends AppException {
  const TimeoutFailure({String? message, super.cause})
      : super(message ?? '응답이 지연되고 있어요. 다시 시도해 주세요.');
}

class CanceledFailure extends AppException {
  const CanceledFailure({String? message, super.cause})
      : super(message ?? '요청이 취소되었어요.');
}

class UnauthorizedFailure extends AppException {
  const UnauthorizedFailure({required String message, super.statusCode, super.cause})
      : super(message);
}

class RequestFailure extends AppException {
  const RequestFailure({required String message, super.statusCode, super.cause})
      : super(message);
}

class ServerFailure extends AppException {
  const ServerFailure({required String message, super.statusCode, super.cause})
      : super(message);
}

class UnknownFailure extends AppException {
  const UnknownFailure({String? message, super.cause})
      : super(message ?? '알 수 없는 오류가 발생했어요.');
}
