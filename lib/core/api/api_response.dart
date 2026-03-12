class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;
  final ApiPagination? pagination;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.pagination,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Object? json)? fromJsonT) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: (json['success'] == true && json['data'] != null && fromJsonT != null)
          ? fromJsonT(json['data'])
          : null,
      error: json['error'] != null ? ApiError.fromJson(json['error'] as Map<String, dynamic>) : null,
      pagination: json['pagination'] != null ? ApiPagination.fromJson(json['pagination'] as Map<String, dynamic>) : null,
    );
  }
}

class ApiError {
  final String code;
  final String message;
  final List<dynamic>? details;

  ApiError({required this.code, required this.message, this.details});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'An unknown error occurred.',
      details: json['details'] as List<dynamic>?,
    );
  }
}

class ApiPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  ApiPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory ApiPagination.fromJson(Map<String, dynamic> json) {
    return ApiPagination(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}
