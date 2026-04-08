<p align="center">
  <a href="https://adopture.com">
    <img src="https://adopture.com/logo.svg" alt="Adopture" width="120" />
  </a>
</p>

<h3 align="center">Privacy-first mobile analytics for Flutter</h3>

<p align="center">
  <a href="https://pub.dev/packages/adopture"><img src="https://img.shields.io/pub/v/adopture.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/adopture/score"><img src="https://img.shields.io/pub/points/adopture" alt="pub points"></a>
  <a href="https://pub.dev/packages/adopture"><img src="https://img.shields.io/pub/popularity/adopture" alt="popularity"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
</p>

<p align="center">
  Simple event tracking with offline support, automatic session management, and privacy-preserving user identification. No raw device IDs ever leave the device.
</p>

---

## Features

- **3-line setup** -- init, track, done
- **Offline-first** -- events queued on disk (SQLite), sent when online
- **Privacy by design** -- only hashed IDs leave the device, no raw identifiers
- **Revenue tracking** -- purchases, subscriptions, trials, refunds
- **Automatic sessions** -- lifecycle events and 30-min timeout rotation
- **Batched sending** -- with exponential backoff and retry
- **GoRouter support** -- automatic screen tracking including StatefulShellRoute branches
- **Super properties** -- persistent properties attached to every event
- **Lightweight** -- no native code, pure Dart

## Installation

```yaml
dependencies:
  adopture: ^0.1.0
```

Then run:

```sh
flutter pub get
```

## Quick Start

```dart
import 'package:adopture/adopture.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Adopture.init(appKey: 'ak_your_app_key_here_000000');
  runApp(MyApp());
}
```

Track events anywhere in your app:

```dart
// Custom events
Adopture.track('button_clicked', {'screen': 'home'});

// Screen views
Adopture.screen('HomeScreen');

// User identification (optional)
await Adopture.identify('user_123');
```

## Configuration

```dart
await Adopture.init(
  appKey: 'ak_your_app_key_here_000000',
  debug: false,                             // Log events to console
  autoCapture: true,                        // Lifecycle events + sessions
  flushInterval: Duration(seconds: 30),     // Batch send interval
  flushAt: 20,                              // Send when N events queued
  maxQueueSize: 1000,                       // Max events stored on disk
  hashUserIds: true,                        // SHA256 hash user IDs (default)
);
```

Set `hashUserIds: false` if you need raw user IDs on the server, e.g. for matching with RevenueCat subscription data.

## Event Tracking

### Custom Events

```dart
Adopture.track('purchase_completed', {
  'product': 'Premium Plan',
  'price': '9.99',
});
```

### Screen Views

```dart
Adopture.screen('SettingsScreen', {'tab': 'notifications'});
```

### User Identification

```dart
// Associate a user ID with all subsequent events
await Adopture.identify('firebase_uid_123');

// Clear identity on logout
await Adopture.logout();
```

## Revenue Tracking

Track purchases and subscription lifecycle events directly from your app. Revenue events are stored separately and power revenue analytics (MRR, trial conversion, etc.).

### Purchases

```dart
// Initial subscription purchase
Adopture.trackPurchase(
  productId: 'com.app.premium_monthly',
  price: 9.99,
  currency: 'USD',
  transactionId: 'txn_abc123',
);

// One-time (non-recurring) purchase
Adopture.trackOneTimePurchase(
  productId: 'com.app.lifetime',
  price: 49.99,
  currency: 'USD',
);
```

### Subscription Lifecycle

```dart
// Renewal
Adopture.trackRenewal(
  productId: 'com.app.premium_monthly',
  price: 9.99,
  currency: 'USD',
);

// Trial started
Adopture.trackTrialStarted(
  productId: 'com.app.premium_monthly',
  expirationAt: '2026-04-12T00:00:00Z',
);

// Trial converted to paid
Adopture.trackTrialConverted(
  productId: 'com.app.premium_monthly',
  price: 9.99,
  currency: 'USD',
);

// Cancellation
Adopture.trackCancellation(productId: 'com.app.premium_monthly');

// Refund
Adopture.trackRefund(
  productId: 'com.app.premium_monthly',
  price: 9.99,
  currency: 'USD',
);
```

### Custom Revenue Events

For full control, use `trackRevenue` directly:

```dart
Adopture.trackRevenue(RevenueData(
  eventType: RevenueEventType.nonRenewingPurchase,
  productId: 'com.app.coin_pack_500',
  price: 4.99,
  currency: 'EUR',
  quantity: 2,
  store: Store.appStore,
));
```

The store is auto-detected from the platform (iOS/macOS -> App Store, Android -> Play Store) if not specified.

> **Tip:** If you use RevenueCat, revenue tracking is handled automatically via the webhook integration -- no SDK calls needed.

## GoRouter Integration

For apps using `go_router` with `StatefulShellRoute`, the standard `NavigatorObserver` misses branch switches. The SDK provides a dedicated observer:

```dart
final router = GoRouter(
  observers: [Adopture.navigationObserver()],
  routes: [...],
);

// Observe all route changes including shell branch switches
Adopture.observeGoRouter(router);
```

## Super Properties

Register properties that are automatically attached to every event:

```dart
// Set properties (overwrites existing keys)
await Adopture.registerSuperProperties({'plan': 'premium', 'theme': 'dark'});

// Set only if not already registered
await Adopture.registerSuperPropertiesOnce({'first_open': '2026-04-05'});

// Remove a single property
await Adopture.unregisterSuperProperty('theme');

// Clear all super properties
await Adopture.clearSuperProperties();
```

## Opt-Out / Opt-In

```dart
// Disable tracking (clears queue, stops sending)
await Adopture.disable();

// Re-enable tracking
Adopture.enable();
```

## Lifecycle

```dart
// Flush all queued events immediately
await Adopture.flush();

// Reset all state (user, session, queue)
await Adopture.reset();

// Shut down the SDK (flushes remaining events)
await Adopture.shutdown();
```

## Auto-Captured Events

When `autoCapture: true` (default), the SDK automatically tracks:

| Event | Trigger |
|-------|---------|
| `app_installed` | First launch |
| `app_updated` | App version changed |
| `app_opened` | App resumed from background |
| `app_backgrounded` | App went to background |
| `session_start` | New session after 30-min timeout |

## Privacy

The SDK never sends raw device identifiers. Instead, it generates rotating SHA256 hashes:

| Hash | Rotation | Use |
|------|----------|-----|
| Daily | Every day | DAU counting |
| Monthly | Every month | MAU and retention |
| Retention | Every quarter | Cross-month cohort analysis |

- No IP addresses stored server-side (used only for GeoIP lookup, then discarded)
- User IDs are SHA256-hashed by default before leaving the device
- All data transmitted over HTTPS

## Platform Support

| Platform | Supported |
|----------|-----------|
| Android  | Yes       |
| iOS      | Yes       |
| macOS    | Yes       |

## Learn More

- [Adopture Dashboard](https://app.adopture.com) -- view your analytics
- [Documentation](https://adopture.com/docs) -- full API reference
- [GitHub](https://github.com/Adopture/adopture-flutter) -- source code and issues

## License

MIT -- see [LICENSE](LICENSE) for details.
