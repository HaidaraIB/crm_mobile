import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ErrorLog {
  final DateTime timestamp;
  final String error;
  final String? stackTrace;
  final String? endpoint;
  final String? method;
  final Map<String, dynamic>? requestData;
  final int? statusCode;
  final String? responseBody;

  ErrorLog({
    required this.timestamp,
    required this.error,
    this.stackTrace,
    this.endpoint,
    this.method,
    this.requestData,
    this.statusCode,
    this.responseBody,
  });

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('ERROR LOG');
    buffer.writeln('=' * 80);
    buffer.writeln('Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp)}');
    buffer.writeln('');
    
    if (endpoint != null) {
      buffer.writeln('Endpoint: $method $endpoint');
      buffer.writeln('');
    }
    
    buffer.writeln('Error:');
    buffer.writeln(error);
    buffer.writeln('');
    
    if (stackTrace != null) {
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace);
      buffer.writeln('');
    }
    
    if (requestData != null && requestData!.isNotEmpty) {
      buffer.writeln('Request Data:');
      requestData!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln('');
    }
    
    if (statusCode != null) {
      buffer.writeln('Status Code: $statusCode');
      buffer.writeln('');
    }
    
    if (responseBody != null) {
      buffer.writeln('Response Body:');
      buffer.writeln(responseBody);
      buffer.writeln('');
    }
    
    buffer.writeln('=' * 80);
    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'stackTrace': stackTrace,
      'endpoint': endpoint,
      'method': method,
      'requestData': requestData,
      'statusCode': statusCode,
      'responseBody': responseBody,
    };
  }

  factory ErrorLog.fromJson(Map<String, dynamic> json) {
    return ErrorLog(
      timestamp: DateTime.parse(json['timestamp']),
      error: json['error'],
      stackTrace: json['stackTrace'],
      endpoint: json['endpoint'],
      method: json['method'],
      requestData: json['requestData'] != null 
          ? Map<String, dynamic>.from(json['requestData']) 
          : null,
      statusCode: json['statusCode'],
      responseBody: json['responseBody'],
    );
  }
}

class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._internal();
  factory ErrorLogger() => _instance;
  ErrorLogger._internal();

  final List<ErrorLog> _logs = [];
  static const int maxLogs = 100;

  void logError({
    required String error,
    String? stackTrace,
    String? endpoint,
    String? method,
    Map<String, dynamic>? requestData,
    int? statusCode,
    String? responseBody,
  }) {
    final log = ErrorLog(
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      endpoint: endpoint,
      method: method,
      requestData: requestData,
      statusCode: statusCode,
      responseBody: responseBody,
    );

    _logs.insert(0, log);
    
    // Keep only the last maxLogs
    if (_logs.length > maxLogs) {
      _logs.removeRange(maxLogs, _logs.length);
    }

    // Also print to console for debugging
    if (kDebugMode) {
      debugPrint(log.toFormattedString());
    }
  }

  List<ErrorLog> getLogs() {
    return List.unmodifiable(_logs);
  }

  void clearLogs() {
    _logs.clear();
  }

  String getAllLogsAsString() {
    if (_logs.isEmpty) {
      return 'No errors logged yet.';
    }

    final buffer = StringBuffer();
    buffer.writeln('ERROR LOGS - ${_logs.length} error(s)');
    buffer.writeln('=' * 80);
    buffer.writeln('');

    for (int i = 0; i < _logs.length; i++) {
      buffer.writeln('ERROR #${i + 1}');
      buffer.writeln('');
      buffer.writeln(_logs[i].toFormattedString());
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String getLatestErrorAsString() {
    if (_logs.isEmpty) {
      return 'No errors logged yet.';
    }
    return _logs.first.toFormattedString();
  }
}

