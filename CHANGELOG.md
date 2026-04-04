## 0.1.0

- Initial release
- `Adopture.init()` — SDK initialization with app key
- `Adopture.track()` — custom event tracking
- `Adopture.screen()` — screen view tracking
- `Adopture.identify()` — user identification
- `Adopture.observeGoRouter()` — automatic screen tracking for go_router (incl. StatefulShellRoute)
- `Adopture.navigationObserver()` — NavigatorObserver for standard navigation / modals
- Offline event queue with sqflite persistence
- Batch sending with retry and backoff
- Auto-capture: app lifecycle events and session management
- Privacy hashing: daily/monthly SHA256 salted hashes
- Device context collection (non-PII)
