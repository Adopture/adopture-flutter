/// Revenue event types matching the backend revenue_events schema.
enum RevenueEventType {
  /// First purchase of a subscription or product.
  initialPurchase,

  /// Subscription billing cycle renewal.
  renewal,

  /// One-time (non-recurring) purchase.
  nonRenewingPurchase,

  /// Subscription canceled by user or system.
  cancellation,

  /// Payment reversed / refunded.
  refund,

  /// Free trial period started.
  trialStarted,

  /// User converted from trial to paid.
  trialConverted;

  /// Converts to the backend string representation.
  String toBackendString() => switch (this) {
        RevenueEventType.initialPurchase => 'INITIAL_PURCHASE',
        RevenueEventType.renewal => 'RENEWAL',
        RevenueEventType.nonRenewingPurchase => 'NON_RENEWING_PURCHASE',
        RevenueEventType.cancellation => 'CANCELLATION',
        RevenueEventType.refund => 'REFUND',
        RevenueEventType.trialStarted => 'TRIAL_STARTED',
        RevenueEventType.trialConverted => 'TRIAL_CONVERTED',
      };

  /// Parses a backend string into the enum value.
  static RevenueEventType fromBackendString(String value) => switch (value) {
        'INITIAL_PURCHASE' => RevenueEventType.initialPurchase,
        'RENEWAL' => RevenueEventType.renewal,
        'NON_RENEWING_PURCHASE' => RevenueEventType.nonRenewingPurchase,
        'CANCELLATION' => RevenueEventType.cancellation,
        'REFUND' => RevenueEventType.refund,
        'TRIAL_STARTED' => RevenueEventType.trialStarted,
        'TRIAL_CONVERTED' => RevenueEventType.trialConverted,
        _ => throw ArgumentError('Unknown RevenueEventType: $value'),
      };
}

/// Store where the purchase was made.
enum Store {
  /// Apple App Store.
  appStore,

  /// Google Play Store.
  playStore,

  /// Stripe payments.
  stripe,

  /// Any other payment provider.
  other;

  String toBackendString() => switch (this) {
        Store.appStore => 'APP_STORE',
        Store.playStore => 'PLAY_STORE',
        Store.stripe => 'STRIPE',
        Store.other => 'OTHER',
      };

  static Store fromBackendString(String value) => switch (value) {
        'APP_STORE' => Store.appStore,
        'PLAY_STORE' => Store.playStore,
        'STRIPE' => Store.stripe,
        'OTHER' => Store.other,
        _ => throw ArgumentError('Unknown Store: $value'),
      };
}

/// Revenue tracking data attached to a revenue event.
class RevenueData {
  /// The type of revenue event.
  final RevenueEventType eventType;

  /// Product identifier (e.g., App Store product ID, SKU).
  final String productId;

  /// Price in the specified [currency]. Must be >= 0.
  final double price;

  /// ISO 4217 currency code (e.g., "USD", "EUR"). Must be 3 uppercase letters.
  final String currency;

  /// Quantity of items purchased. Defaults to 1.
  final int quantity;

  /// Unique transaction ID for deduplication.
  final String? transactionId;

  /// Store where the purchase was made.
  /// Auto-detected from platform if not specified.
  final Store? store;

  /// Whether this is a trial period event.
  final bool isTrial;

  /// Whether this is a trial-to-paid conversion.
  final bool isTrialConversion;

  /// Subscription period type ("TRIAL", "INTRO", "NORMAL", or empty).
  final String periodType;

  /// Subscription expiration timestamp (ISO 8601 UTC).
  final String? expirationAt;

  const RevenueData({
    required this.eventType,
    required this.productId,
    required this.price,
    required this.currency,
    this.quantity = 1,
    this.transactionId,
    this.store,
    this.isTrial = false,
    this.isTrialConversion = false,
    this.periodType = '',
    this.expirationAt,
  });

  /// Validates the revenue data. Throws [ArgumentError] on invalid input.
  void validate() {
    if (productId.isEmpty || productId.length > 200) {
      throw ArgumentError(
        'productId must be between 1 and 200 characters.',
      );
    }
    if (price < 0) {
      throw ArgumentError('price must be >= 0.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError(
        'currency must be a 3-letter uppercase ISO 4217 code (e.g., "USD").',
      );
    }
    if (quantity < 1 || quantity > 1000) {
      throw ArgumentError('quantity must be between 1 and 1000.');
    }
  }

  Map<String, dynamic> toJson() => {
        'event_type': eventType.toBackendString(),
        'product_id': productId,
        'price': price,
        'currency': currency,
        'quantity': quantity,
        if (transactionId != null) 'transaction_id': transactionId,
        if (store != null) 'store': store!.toBackendString(),
        'is_trial': isTrial,
        'is_trial_conversion': isTrialConversion,
        'period_type': periodType,
        if (expirationAt != null) 'expiration_at': expirationAt,
      };

  factory RevenueData.fromJson(Map<String, dynamic> json) => RevenueData(
        eventType:
            RevenueEventType.fromBackendString(json['event_type'] as String),
        productId: json['product_id'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        transactionId: json['transaction_id'] as String?,
        store: json['store'] != null
            ? Store.fromBackendString(json['store'] as String)
            : null,
        isTrial: json['is_trial'] as bool? ?? false,
        isTrialConversion: json['is_trial_conversion'] as bool? ?? false,
        periodType: json['period_type'] as String? ?? '',
        expirationAt: json['expiration_at'] as String?,
      );
}
