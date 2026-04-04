## 0.1.0

- Initial release
- `Adopture.init()` — SDK initialization with app key
- `Adopture.track()` — custom event tracking
- `Adopture.screen()` — screen view tracking
- `Adopture.identify()` / `Adopture.logout()` — user identification
- `Adopture.observeGoRouter()` — automatic screen tracking for go_router (incl. StatefulShellRoute)
- `Adopture.navigationObserver()` — NavigatorObserver for standard navigation / modals
- Revenue tracking: `trackPurchase()`, `trackOneTimePurchase()`, `trackRenewal()`, `trackTrialStarted()`, `trackTrialConverted()`, `trackCancellation()`, `trackRefund()`, `trackRevenue()`
- Super properties: `registerSuperProperties()`, `registerSuperPropertiesOnce()`, `unregisterSuperProperty()`, `clearSuperProperties()`
- Opt-out/opt-in: `disable()` / `enable()`
- Offline event queue with SQLite persistence
- Batch sending with exponential backoff and retry
- Auto-capture: app lifecycle events (`app_installed`, `app_updated`, `app_opened`, `app_backgrounded`) and session management
- Privacy hashing: daily/monthly/quarterly SHA256 salted hashes
- Device context collection (non-PII only)
