## 0.1.0

Initial release of the Adopture Flutter SDK.

### Event Tracking
- `Adopture.init()` -- SDK initialization with app key
- `Adopture.track()` -- custom event tracking
- `Adopture.screen()` -- screen view tracking
- `Adopture.identify()` / `Adopture.logout()` -- user identification

### Navigation
- `Adopture.observeGoRouter()` -- automatic screen tracking for go_router (incl. StatefulShellRoute)
- `Adopture.navigationObserver()` -- NavigatorObserver for standard navigation and modals

### Revenue
- `trackPurchase()`, `trackOneTimePurchase()`, `trackRenewal()` -- purchase tracking
- `trackTrialStarted()`, `trackTrialConverted()` -- trial lifecycle
- `trackCancellation()`, `trackRefund()` -- cancellation and refunds
- `trackRevenue()` -- custom revenue events with full control

### Super Properties
- `registerSuperProperties()` / `registerSuperPropertiesOnce()` -- global event properties
- `unregisterSuperProperty()` / `clearSuperProperties()` -- property management

### Privacy & Infrastructure
- Privacy hashing: daily/monthly/quarterly SHA256 salted hashes
- Offline event queue with SQLite persistence
- Batch sending with exponential backoff and retry
- Auto-capture: `app_installed`, `app_updated`, `app_opened`, `app_backgrounded`, `session_start`
- Opt-out/opt-in: `disable()` / `enable()`
- Device context collection (non-PII only)
