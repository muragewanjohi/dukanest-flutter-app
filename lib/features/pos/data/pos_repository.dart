import '../../../core/api/api_client.dart';
import 'pos_models.dart';

/// Thin wrapper over [ApiClient] for the POS feature. Unwraps the mobile
/// success envelope (`{ success, data }`) — for these routes `ApiResponse.data`
/// is already the inner payload, but we tolerate a double-nested `data` too.
class PosRepository {
  PosRepository(this._api);

  final ApiClient _api;

  Future<PosBootstrap> bootstrap({String? since}) async {
    final r = await _api.getPosBootstrap(since: since);
    if (!r.success || r.data == null) {
      throw StateError(r.error?.message ?? 'Could not load the POS catalogue.');
    }
    return PosBootstrap.fromData(_inner(r.data));
  }

  Future<PosSaleResult> submitSale(Map<String, dynamic> body) async {
    final r = await _api.postPosSale(body);
    if (!r.success || r.data == null) {
      throw StateError(r.error?.message ?? 'The sale could not be recorded.');
    }
    final inner = _inner(r.data);
    final sale = inner['sale'] is Map
        ? Map<String, dynamic>.from(inner['sale'] as Map)
        : inner;
    return PosSaleResult.fromJson(sale);
  }

  /// Poll Tumizi for an M-Pesa POS order. Returns the current `payment_status`
  /// (`pending` | `paid` | `failed` | ...). Reuses the dashboard order sync
  /// endpoint — a POS order is a normal `tumizi` order.
  Future<String> pollMpesaStatus(String orderId) async {
    final r = await _api.syncTumiziOrderPayment(orderId);
    if (!r.success || r.data == null) {
      throw StateError(r.error?.message ?? 'Could not check the payment.');
    }
    final inner = _inner(r.data);
    final status = inner['paymentStatus'] ?? inner['payment_status'];
    return status is String && status.isNotEmpty ? status : 'pending';
  }

  Map<String, dynamic> _inner(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final nested = map['data'];
    return nested is Map ? Map<String, dynamic>.from(nested) : map;
  }
}
