## 0.1.0

- Initial release
- `Mobileanalytics.init()` — SDK initialization with app key
- `Mobileanalytics.track()` — custom event tracking
- `Mobileanalytics.screen()` — screen view tracking
- `Mobileanalytics.identify()` — user identification
- Offline event queue with sqflite persistence
- Batch sending with GZip compression
- Exponential backoff retry with rate limit support
- Auto-capture: app lifecycle events and session management
- Privacy hashing: daily/monthly SHA256 salted hashes
- Device context collection (non-PII)
