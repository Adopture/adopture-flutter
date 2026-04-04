# Adopture Flutter SDK

Privacy-first mobile analytics SDK for Flutter. Simple event tracking with offline support, automatic session management, and privacy-preserving user identification.

## Features

- **3-line setup** — init, track, done
- **Offline-first** — events queued on disk, sent when online
- **Privacy by design** — only hashed IDs, raw device ID never leaves the device
- **Automatic sessions** — lifecycle events and session rotation
- **Batched sending** — with retry and backoff
- **GoRouter support** — automatic screen tracking including StatefulShellRoute branches
- **Lightweight** — minimal dependencies, no native code

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  adopture: ^0.1.0
```

## Usage

```dart
import 'package:adopture/adopture.dart';

// Initialize once in main()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Adopture.init(appKey: 'ak_your_app_key_here_000000');

  runApp(MyApp());
}

// Track events anywhere
Adopture.track('button_clicked', {'screen': 'home'});

// Track screen views
Adopture.screen('HomeScreen');

// Identify users (optional)
Adopture.identify('user_123');
```

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

## Configuration

```dart
await Adopture.init(
  appKey: 'ak_your_app_key_here_000000',
  endpoint: 'https://api.adopture.com',    // Custom endpoint
  debug: false,                             // Log events to console
  autoCapture: true,                        // Lifecycle events + sessions
  flushInterval: Duration(seconds: 30),     // Batch send interval
  flushAt: 20,                              // Send when N events queued
  maxQueueSize: 1000,                       // Max events stored on disk
);
```

## Privacy

The SDK never sends raw device identifiers. Instead, it generates rotating SHA256 hashes:

- **Daily hash** — rotates daily, used for DAU counting
- **Monthly hash** — rotates monthly, used for MAU and retention
- No IP addresses stored server-side (used only for GeoIP, then discarded)

## License

MIT
