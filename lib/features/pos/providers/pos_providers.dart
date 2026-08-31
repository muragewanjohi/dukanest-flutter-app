import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/pos_cart.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../data/pos_totals.dart';

final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepository(ref.watch(apiClientProvider)),
);

/// Catalogue + store settings snapshot. Kept alive (not autoDispose) so moving
/// between the register / cart / tender screens doesn't refetch; pull-to-refresh
/// and the app-bar refresh action invalidate it explicitly.
final posBootstrapProvider = FutureProvider<PosBootstrap>((ref) {
  return ref.watch(posRepositoryProvider).bootstrap();
});

final posCartProvider =
    StateNotifierProvider<PosCartNotifier, PosCart>((ref) => PosCartNotifier());

/// Live totals for the current cart, using the cached tax config.
final posTotalsProvider = Provider<PosTotals>((ref) {
  final cart = ref.watch(posCartProvider);
  final settings =
      ref.watch(posBootstrapProvider).valueOrNull?.settings ?? PosSettings.empty;
  if (cart.isEmpty) return PosTotals.zero;
  return PosTotals.compute(
    lines: cart.lines,
    orderDiscount: cart.orderDiscount,
    tax: settings.tax,
  );
});

class PosCartNotifier extends StateNotifier<PosCart> {
  PosCartNotifier() : super(const PosCart());

  void clear() => state = const PosCart();

  /// Add a product/variant. If an identical line (same product + variant, no
  /// discount) already exists, bump its quantity instead of adding a row.
  void addItem(PosCatalogProduct product, {PosCatalogVariant? variant, int quantity = 1}) {
    final idx = state.lines.indexWhere((l) =>
        l.product.id == product.id &&
        l.variant?.id == variant?.id &&
        l.discountAmount == 0);
    if (idx >= 0) {
      final existing = state.lines[idx];
      _replaceAt(idx, existing.copyWith(quantity: existing.quantity + quantity));
      return;
    }
    state = state.copyWith(lines: [
      ...state.lines,
      PosCartLine(
        lineKey: posUuidV4(),
        product: product,
        variant: variant,
        quantity: quantity,
      ),
    ]);
  }

  void setQuantity(String lineKey, int quantity) {
    if (quantity <= 0) {
      removeLine(lineKey);
      return;
    }
    final idx = state.lines.indexWhere((l) => l.lineKey == lineKey);
    if (idx < 0) return;
    _replaceAt(idx, state.lines[idx].copyWith(quantity: quantity));
  }

  void setLineDiscount(String lineKey, double amount) {
    final idx = state.lines.indexWhere((l) => l.lineKey == lineKey);
    if (idx < 0) return;
    _replaceAt(
      idx,
      state.lines[idx].copyWith(discountAmount: amount < 0 ? 0 : amount),
    );
  }

  void removeLine(String lineKey) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.lineKey != lineKey).toList(),
    );
  }

  void setOrderDiscount(double amount) =>
      state = state.copyWith(orderDiscount: amount < 0 ? 0 : amount);

  void setCustomer({String? name, String? phone}) => state = state.copyWith(
        customerName: name ?? state.customerName,
        customerPhone: phone ?? state.customerPhone,
      );

  void setNotes(String notes) => state = state.copyWith(notes: notes);

  void _replaceAt(int idx, PosCartLine line) {
    final next = [...state.lines];
    next[idx] = line;
    state = state.copyWith(lines: next);
  }
}

/// Payment method chosen on the tender screen.
/// - `cash` / `other`: recorded as paid immediately (`other` = already paid,
///   e.g. straight to the owner's own M-Pesa till).
/// - `mpesa`: Tumizi customer STK push — the sale is `pending` until confirmed.
enum PosPaymentMethod { cash, mpesa, other }

extension PosPaymentMethodX on PosPaymentMethod {
  String get apiValue => switch (this) {
        PosPaymentMethod.cash => 'cash',
        PosPaymentMethod.mpesa => 'mpesa',
        PosPaymentMethod.other => 'other',
      };

  String get label => switch (this) {
        PosPaymentMethod.cash => 'Cash',
        PosPaymentMethod.mpesa => 'M-Pesa (STK)',
        PosPaymentMethod.other => 'Already paid / other',
      };
}

/// Everything the receipt screen needs, passed via GoRouter `extra` after a
/// successful sale.
@immutable
class PosCompletedSale {
  const PosCompletedSale({
    required this.result,
    required this.settings,
    required this.lines,
    required this.method,
    required this.customerName,
    required this.customerPhone,
  });

  final PosSaleResult result;
  final PosSettings settings;
  final List<PosCartLine> lines;
  final PosPaymentMethod method;
  final String customerName;
  final String customerPhone;
}
