import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobileanalytics/mobileanalytics.dart';

/// Change this to your actual app key and endpoint for real testing.
const _testAppKey = 'ak_test1234567890abcdefgh';
const _testEndpoint = 'http://localhost:3001';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Mobileanalytics.init(
    appKey: _testAppKey,
    endpoint: _testEndpoint,
    debug: true,
    autoCapture: true,
    flushInterval: const Duration(seconds: 10),
    flushAt: 5,
    maxQueueSize: 500,
  );

  Mobileanalytics.identify('test-user-001');

  runApp(const TestApp());
}

// ---------------------------------------------------------------------------
// App Root
// ---------------------------------------------------------------------------

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SDK Test App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home Screen — Dashboard with SDK state + navigation
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _refreshTimer;
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    Mobileanalytics.screen('HomeScreen');
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _log(String message) {
    setState(() {
      _eventLog.insert(0, '${_timestamp()} $message');
      if (_eventLog.length > 50) _eventLog.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SDK Test App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () => setState(() => _eventLog.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          // SDK State Card
          _SdkStateCard(),

          const Divider(height: 1),

          // Navigation to test screens
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NavChip(
                  label: 'Profile',
                  icon: Icons.person,
                  onTap: () => _navigateTo(context, const ProfileScreen()),
                ),
                _NavChip(
                  label: 'Settings',
                  icon: Icons.settings,
                  onTap: () => _navigateTo(context, const SettingsScreen()),
                ),
                _NavChip(
                  label: 'Shop',
                  icon: Icons.shopping_cart,
                  onTap: () => _navigateTo(context, const ShopScreen()),
                ),
                _NavChip(
                  label: 'Stress Test',
                  icon: Icons.speed,
                  onTap: () => _navigateTo(context, StressTestScreen(onLog: _log)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  label: 'Track Event',
                  icon: Icons.touch_app,
                  onPressed: () {
                    Mobileanalytics.track('button_clicked', {
                      'screen': 'home',
                      'variant': 'primary',
                    });
                    _log('track: button_clicked');
                  },
                ),
                _ActionButton(
                  label: 'Flush',
                  icon: Icons.send,
                  onPressed: () async {
                    await Mobileanalytics.flush();
                    _log('flush: manual');
                  },
                ),
                _ActionButton(
                  label: 'Reset',
                  icon: Icons.restart_alt,
                  color: Colors.orange,
                  onPressed: () async {
                    await Mobileanalytics.reset();
                    _log('reset: cleared queue + new session');
                  },
                ),
                _ActionButton(
                  label: Mobileanalytics.isEnabled ? 'Disable' : 'Enable',
                  icon: Mobileanalytics.isEnabled
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  color: Mobileanalytics.isEnabled
                      ? Colors.red
                      : Colors.green,
                  onPressed: () async {
                    if (Mobileanalytics.isEnabled) {
                      await Mobileanalytics.disable();
                      _log('tracking: DISABLED (opt-out)');
                    } else {
                      Mobileanalytics.enable();
                      _log('tracking: ENABLED');
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Event Log
          Expanded(
            child: _eventLog.isEmpty
                ? const Center(
                    child: Text(
                      'No events yet.\nTap buttons or navigate screens.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _eventLog.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _eventLog[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Mobileanalytics.screen('ProfileScreen');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 16),
          const Text(
            'Test User',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'test-user-001',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: () {
              Mobileanalytics.track('profile_edit_tapped');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tracked: profile_edit_tapped')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Change Avatar'),
            onTap: () {
              Mobileanalytics.track('avatar_change_tapped');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tracked: avatar_change_tapped')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Mobileanalytics.track('logout_tapped');
              Mobileanalytics.reset();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tracked: logout + reset')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    Mobileanalytics.screen('SettingsScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Tracks: setting_changed'),
            value: _notifications,
            onChanged: (v) {
              setState(() => _notifications = v);
              Mobileanalytics.track('setting_changed', {
                'setting': 'notifications',
                'value': v.toString(),
              });
            },
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Tracks: setting_changed'),
            value: _darkMode,
            onChanged: (v) {
              setState(() => _darkMode = v);
              Mobileanalytics.track('setting_changed', {
                'setting': 'dark_mode',
                'value': v.toString(),
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Opt-out of Analytics'),
            subtitle: const Text('Calls Mobileanalytics.disable()'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Mobileanalytics.disable();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Analytics disabled. Queue cleared.'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Opt back in'),
            subtitle: const Text('Calls Mobileanalytics.enable()'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Mobileanalytics.enable();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics re-enabled.')),
              );
            },
          ),
          const Divider(),
          const _SdkInfoTile(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shop Screen — simulates e-commerce events
// ---------------------------------------------------------------------------

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const _products = [
    ('Wireless Headphones', '79.99', 'electronics'),
    ('Running Shoes', '129.00', 'sports'),
    ('Coffee Beans 1kg', '24.50', 'food'),
    ('Flutter Book', '39.99', 'books'),
    ('USB-C Hub', '49.99', 'electronics'),
  ];

  @override
  Widget build(BuildContext context) {
    Mobileanalytics.screen('ShopScreen');

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _products.length,
        itemBuilder: (context, i) {
          final (name, price, category) = _products[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: Text(name),
              subtitle: Text('\$$price  ·  $category'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View product',
                    onPressed: () {
                      Mobileanalytics.track('product_viewed', {
                        'product': name,
                        'price': price,
                        'category': category,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tracked: product_viewed ($name)')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart),
                    tooltip: 'Add to cart',
                    onPressed: () {
                      Mobileanalytics.track('add_to_cart', {
                        'product': name,
                        'price': price,
                        'category': category,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tracked: add_to_cart ($name)')),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Mobileanalytics.track('checkout_started', {
            'item_count': '3',
            'total': '249.48',
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tracked: checkout_started')),
          );
        },
        icon: const Icon(Icons.payment),
        label: const Text('Checkout'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stress Test Screen — batch events, offline simulation, etc.
// ---------------------------------------------------------------------------

class StressTestScreen extends StatefulWidget {
  final void Function(String message)? onLog;

  const StressTestScreen({super.key, this.onLog});

  @override
  State<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends State<StressTestScreen> {
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Mobileanalytics.screen('StressTestScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stress Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SdkStateCard(),

          const SizedBox(height: 16),

          // Burst 10 events
          _TestCard(
            title: 'Burst: 10 Events',
            description: 'Send 10 track events rapidly to test batching.',
            icon: Icons.bolt,
            onRun: () => _burst(10),
          ),

          // Burst 50 events
          _TestCard(
            title: 'Burst: 50 Events',
            description: 'Send 50 events to test queue + flush threshold.',
            icon: Icons.flash_on,
            onRun: () => _burst(50),
          ),

          // Burst 200 events
          _TestCard(
            title: 'Burst: 200 Events',
            description: 'Send 200 events to test multi-batch sending (max 100/request).',
            icon: Icons.rocket_launch,
            onRun: () => _burst(200),
          ),

          // Flush manually
          _TestCard(
            title: 'Manual Flush',
            description: 'Force flush all queued events to the server now.',
            icon: Icons.send,
            onRun: () async {
              setState(() => _isSending = true);
              await Mobileanalytics.flush();
              setState(() => _isSending = false);
              _showResult('Flushed. Queue: ${Mobileanalytics.queueLength}');
            },
          ),

          // Disable → track → enable → flush
          _TestCard(
            title: 'Opt-out / Opt-in Cycle',
            description:
                'Disable tracking, try to track events (should be dropped), '
                're-enable, track again, verify only post-enable events are queued.',
            icon: Icons.privacy_tip,
            onRun: _testOptOutCycle,
          ),

          // Reset test
          _TestCard(
            title: 'Reset SDK State',
            description: 'Clears queue, user ID, starts new session. Verify session ID changes.',
            icon: Icons.restart_alt,
            onRun: () async {
              final oldSession = Mobileanalytics.sessionId;
              await Mobileanalytics.reset();
              final newSession = Mobileanalytics.sessionId;
              _showResult(
                'Session rotated\n'
                'Old: ${oldSession?.substring(0, 8)}...\n'
                'New: ${newSession?.substring(0, 8)}...\n'
                'Queue: ${Mobileanalytics.queueLength}',
              );
            },
          ),

          // Properties size test
          _TestCard(
            title: 'Large Properties',
            description: 'Track event with many properties (near 500-char limit per value).',
            icon: Icons.data_object,
            onRun: () {
              final props = <String, String>{};
              for (var i = 0; i < 10; i++) {
                props['key_$i'] = 'v' * 100; // 100 chars each
              }
              Mobileanalytics.track('large_props_event', props);
              _showResult(
                'Tracked large_props_event with ${props.length} properties.\n'
                'Queue: ${Mobileanalytics.queueLength}',
              );
            },
          ),

          // Rapid screen switches
          _TestCard(
            title: 'Rapid Screen Views',
            description: 'Fire 20 screen() calls to simulate fast navigation.',
            icon: Icons.swap_horiz,
            onRun: () {
              final screens = [
                'Home', 'Profile', 'Settings', 'Shop', 'Cart',
                'Checkout', 'OrderConfirm', 'Search', 'Filters', 'Detail',
                'Reviews', 'Wishlist', 'Notifications', 'Messages', 'Help',
                'About', 'Terms', 'Privacy', 'Account', 'Billing',
              ];
              for (final s in screens) {
                Mobileanalytics.screen(s);
              }
              _showResult(
                'Fired 20 screen views.\nQueue: ${Mobileanalytics.queueLength}',
              );
            },
          ),

          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _burst(int count) async {
    for (var i = 0; i < count; i++) {
      Mobileanalytics.track('stress_event', {
        'index': '$i',
        'total': '$count',
        'batch': '${DateTime.now().millisecondsSinceEpoch}',
      });
    }
    setState(() {});
    _showResult('Sent $count events. Queue: ${Mobileanalytics.queueLength}');
    widget.onLog?.call('burst: $count events');
  }

  Future<void> _testOptOutCycle() async {
    // 1. Disable
    await Mobileanalytics.disable();
    final queueAfterDisable = Mobileanalytics.queueLength;

    // 2. Try to track (should be silently dropped)
    Mobileanalytics.track('should_be_dropped', {'phase': 'disabled'});
    final queueAfterDropped = Mobileanalytics.queueLength;

    // 3. Re-enable
    Mobileanalytics.enable();

    // 4. Track for real
    Mobileanalytics.track('after_reenable', {'phase': 'enabled'});
    final queueAfterEnable = Mobileanalytics.queueLength;

    _showResult(
      'Opt-out cycle complete:\n'
      '  After disable: queue=$queueAfterDisable\n'
      '  After dropped track: queue=$queueAfterDropped (should be same)\n'
      '  After re-enable track: queue=$queueAfterEnable (should be +1)',
    );
  }

  void _showResult(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Result'),
        content: Text(message, style: const TextStyle(fontFamily: 'monospace')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _SdkStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctx = Mobileanalytics.deviceContext;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Mobileanalytics.isEnabled
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 12,
                  color: Mobileanalytics.isEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  Mobileanalytics.isEnabled ? 'TRACKING ON' : 'TRACKING OFF',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  'Queue: ${Mobileanalytics.queueLength}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow('Session', _truncate(Mobileanalytics.sessionId, 20)),
            _InfoRow('Endpoint', Mobileanalytics.endpoint ?? '-'),
            if (ctx != null) ...[
              _InfoRow('Device', '${ctx.os} ${ctx.osVersion} · ${ctx.deviceType}'),
              _InfoRow('App', 'v${ctx.appVersion} · ${ctx.locale}'),
              _InfoRow('Screen', '${ctx.screenWidth}x${ctx.screenHeight}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: color != null
          ? FilledButton.styleFrom(backgroundColor: color)
          : null,
    );
  }
}

class _TestCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onRun;

  const _TestCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: FilledButton(
          onPressed: onRun,
          child: const Text('Run'),
        ),
      ),
    );
  }
}

class _SdkInfoTile extends StatelessWidget {
  const _SdkInfoTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SDK Debug Info',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _InfoRow('Initialized', '${Mobileanalytics.isInitialized}'),
          _InfoRow('Enabled', '${Mobileanalytics.isEnabled}'),
          _InfoRow('Queue', '${Mobileanalytics.queueLength}'),
          _InfoRow('Session', _truncate(Mobileanalytics.sessionId, 20)),
          _InfoRow('Endpoint', Mobileanalytics.endpoint ?? '-'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _truncate(String? s, int maxLen) {
  if (s == null) return '-';
  return s.length > maxLen ? '${s.substring(0, maxLen)}...' : s;
}

String _timestamp() {
  final now = DateTime.now();
  return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
}

String _pad(int n) => n.toString().padLeft(2, '0');
