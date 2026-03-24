import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  
  // Retrofit passes null data safely if T is nullable, but we allow nullable data
  final T? data;
  
  final ApiError? error;
  final ApiPagination? pagination;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.pagination,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return _$ApiResponseFromJson(json, fromJsonT);
  }

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}

@JsonSerializable()
class ApiError {
  final String code;
  final String message;
  final dynamic details;

  const ApiError({
    required this.code,
    required this.message,
    this.details,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);
  Map<String, dynamic> toJson() => _$ApiErrorToJson(this);
}

@JsonSerializable()
class ApiPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const ApiPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory ApiPagination.fromJson(Map<String, dynamic> json) => _$ApiPaginationFromJson(json);
  Map<String, dynamic> toJson() => _$ApiPaginationToJson(this);
}
