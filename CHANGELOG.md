## 0.1.3

- Fix duplicate screen tracking when both `observeGoRouter()` and `navigationObserver()` are active
- `NavigationObserver` now automatically skips all events when `GoRouterObserver` is active, preventing double-counting with different separators (e.g. `onboarding-v3/auth` vs `onboarding-v3-auth`)
- Deprecate `goRouterRouteNames` parameter on `navigationObserver()` — deduplication is now fully automatic

## 0.1.2

- Fix broken logo image in README — use text header instead

## 0.1.1

- Update all dependencies to latest versions
- `connectivity_plus` ^6.1.0 → ^7.1.0
- `device_info_plus` ^12.4.0, `package_info_plus` ^9.0.1
- `flutter_lints` ^5.0.0 → ^6.0.0
- Minor version bumps for all other packages

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
