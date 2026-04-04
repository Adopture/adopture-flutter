# Adopture SDK Example App

A demo Flutter app showcasing the Adopture analytics SDK.

## Screens

- **Home** — SDK state dashboard (session ID, queue length, tracking status) with action buttons for track, flush, reset, and disable/enable
- **Profile** — User identification and logout flow
- **Settings** — Opt-out/opt-in toggles and SDK debug info
- **Shop** — E-commerce event tracking (product views, add to cart, checkout)
- **Revenue** — Revenue tracking methods: purchase, renewal, trial, cancellation, refund
- **Stress Test** — Burst events (10/50/200), offline simulation, opt-out cycle, large properties

## Running

```bash
cd example
flutter run
```

The app uses a test app key and sends events to `api.adopture.com`. Replace the app key in `lib/main.dart` with your own key from the Adopture dashboard.
