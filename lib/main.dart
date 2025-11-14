import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart'; 
// Permission requests for Android 13+ are handled natively in MainActivity.kt
 
Future<void> _messageHandler(RemoteMessage message) async { 
  print('background message ${message.notification!.body}'); 
} 

// Animated / themed dialog for quotes. Uses a background image if available
// and provides a different entrance animation depending on `animationType`.
class QuoteDialog extends StatefulWidget {
  final String title;
  final String quote;
  final IconData icon;
  final Color color;
  final String backgroundAsset;
  final String animationType; // 'regular', 'important', 'motivational', 'wisdom'

  const QuoteDialog({
    Key? key,
    required this.title,
    required this.quote,
    required this.icon,
    required this.color,
    required this.backgroundAsset,
    required this.animationType,
  }) : super(key: key);

  @override
  _QuoteDialogState createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<QuoteDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: 450));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Map the animationType (which doubles as quote type) to a font family
  // declared in `pubspec.yaml`. Return null to let Flutter fall back to the
  // default system font if the font isn't available.
  String? _fontFamilyForType(String type) {
    switch (type) {
      case 'important':
        return 'ImportantQuotes';
      case 'motivational':
        return 'MotivationalQuotes';
      case 'wisdom':
        return 'WisdomQuotes';
      case 'regular':
      default:
        return 'RegularQuotes';
    }
  }

  Widget _buildAnimatedChild(Widget child) {
    // Provide different entrance animations per type.
    switch (widget.animationType) {
      case 'important':
        // Pulse + shake
        return AnimatedBuilder(
          animation: _ctrl,
          child: child,
          builder: (context, c) {
            final shake = math.sin(_ctrl.value * math.pi * 8) * 8.0; // horizontal shake px
            final scale = 0.9 + 0.18 * _anim.value; // pulse-in
            return Transform.translate(
              offset: Offset(shake, 0),
              child: Transform.scale(scale: scale, child: c),
            );
          },
        );

      case 'motivational':
        // Slide from bottom (keeps confetti overlay handled elsewhere)
        return SlideTransition(position: Tween<Offset>(begin: Offset(0, 0.22), end: Offset.zero).animate(_anim), child: child);

      case 'wisdom':
        // Slow rotate + scale for a thoughtful reveal
        return AnimatedBuilder(
          animation: _ctrl,
          child: child,
          builder: (context, c) {
            final rot = (1 - _anim.value) * -0.04; // rotate into place
            final scale = 0.96 + 0.06 * _anim.value;
            final dy = (1 - _anim.value) * -8.0; // slight upward float
            return Transform.translate(
              offset: Offset(0, dy),
              child: Transform.rotate(
                angle: rot,
                child: Transform.scale(scale: scale, child: c),
              ),
            );
          },
        );

      case 'regular':
      default:
        // Gentle fade + slide from top
        return FadeTransition(
          opacity: _anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, -0.06), end: Offset.zero).animate(_anim),
            child: child,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Background image area
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.backgroundAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) {
                          // Fallback colored banner
                          return Container(color: widget.color.withOpacity(0.12));
                        },
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.18),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 12,
                        child: Row(children: [Icon(widget.icon, color: Colors.white, size: 28), SizedBox(width: 8), Text(widget.title, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Use the custom font family for the current quote `type`.
                      // If the font file is not present the platform will fall back.
                      SelectableText(
                        widget.quote,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          fontFamily: _fontFamilyForType(widget.animationType),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text('Copy'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.quote));
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quote copied')));
                            },
                          ),
                          SizedBox(width: 8),
                          TextButton(
                            child: Text('Close'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );

    // If motivational, overlay a lightweight confetti animation
    Widget result = _buildAnimatedChild(content);
    if (widget.animationType == 'motivational') {
      result = Stack(
        alignment: Alignment.center,
        children: [
          result,
          // ConfettiOverlay is non-interactive and auto-disposes after playing
          Positioned.fill(child: IgnorePointer(child: ConfettiOverlay())),
        ],
      );
    }

    return result;
  }
}

// Lightweight confetti overlay: draws simple particles for a short burst.
class ConfettiOverlay extends StatefulWidget {
  final int particleCount;
  final Duration duration;
  const ConfettiOverlay({Key? key, this.particleCount = 24, this.duration = const Duration(milliseconds: 1200)}) : super(key: key);

  @override
  _ConfettiOverlayState createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _particles = List.generate(widget.particleCount, (i) {
      final angle = (rnd.nextDouble() * 2 - 1) * math.pi / 3; // spread
      final speed = 200 + rnd.nextDouble() * 200;
      final color = Colors.primaries[rnd.nextInt(Colors.primaries.length)].withOpacity(0.95);
      final size = 6.0 + rnd.nextDouble() * 8.0;
      return _Particle(angle: angle, speed: speed, color: color, size: size, xOffset: (rnd.nextDouble() - 0.5) * 80);
    });

    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(() {
        setState(() {});
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ConfettiPainter(particles: _particles, progress: _ctrl.value),
      size: Size.infinite,
    );
  }
}

class _Particle {
  final double angle; // radians
  final double speed; // px/sec
  final Color color;
  final double size;
  final double xOffset; // starting x offset relative to center
  _Particle({required this.angle, required this.speed, required this.color, required this.size, required this.xOffset});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1
  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.15);
    final t = progress;
    for (final p in particles) {
      final dx = p.xOffset + math.cos(p.angle) * p.speed * t;
      final dy = math.sin(p.angle).abs() * p.speed * t + 0.5 * 900 * t * t; // gravity feel
      final pos = center + Offset(dx, dy);
      final paint = Paint()..color = p.color.withOpacity((1 - t).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: pos, width: p.size, height: p.size * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress || old.particles != particles;
}

class SavedQuotesPage extends StatefulWidget {
  final List<String> quotes;
  final Future<void> Function(int) onDelete;

  const SavedQuotesPage({Key? key, required this.quotes, required this.onDelete}) : super(key: key);

  @override
  _SavedQuotesPageState createState() => _SavedQuotesPageState();
}

class _SavedQuotesPageState extends State<SavedQuotesPage> {
  late List<String> _localQuotes;

  @override
  void initState() {
    super.initState();
    _localQuotes = List.from(widget.quotes);
  }

  Future<void> _deleteAt(int index) async {
    await widget.onDelete(index);
    setState(() {
      _localQuotes.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed quote')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Saved Quotes')),
      body: _localQuotes.isEmpty
          ? Center(child: Text('No saved quotes'))
          : ListView.separated(
              itemCount: _localQuotes.length,
              separatorBuilder: (_, __) => Divider(height: 1),
              itemBuilder: (context, index) {
                final q = _localQuotes[index];
                return ListTile(
                  leading: Icon(Icons.format_quote),
                  title: SelectableText(q),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(Icons.copy),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: q));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied')));
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.share),
                      tooltip: 'Share',
                      onPressed: () {
                        Share.share(q);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      tooltip: 'Delete',
                      onPressed: () => _deleteAt(index),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
 
void main() async { 
  WidgetsFlutterBinding.ensureInitialized(); 
  await Firebase.initializeApp( 
    options: DefaultFirebaseOptions.currentPlatform, 
  ); 
  FirebaseMessaging.onBackgroundMessage(_messageHandler); 
  runApp(MessagingTutorial()); 
} 
 
class MessagingTutorial extends StatelessWidget { 
  @override 
  Widget build(BuildContext context) { 
    return MaterialApp( 
      debugShowCheckedModeBanner: false, 
      title: 'Firebase Messaging', 
      theme: ThemeData( 
        primarySwatch: Colors.blue, 
      ), 
      home: MyHomePage(title: 'Firebase Messaging'), 
    ); 
  } 
} 
 
class MyHomePage extends StatefulWidget { 
  MyHomePage({Key? key, this.title}) : super(key: key); 
 
  final String? title; 
 
  @override 
  _MyHomePageState createState() => _MyHomePageState(); 
} 
 
class _MyHomePageState extends State<MyHomePage> { 
  late FirebaseMessaging messaging; 
  String? notificationText; 
  bool _tokenDialogShown = false;
  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const String _channelRegular = 'quotes_regular';
  static const String _channelImportant = 'quotes_important';
  static const String _channelMotivational = 'quotes_motivational';
  static const String _channelWisdom = 'quotes_wisdom';
  @override 
  void initState() { 
    super.initState(); 
    messaging = FirebaseMessaging.instance; 
    _initLocalNotifications();
    _loadSavedQuotes();
    messaging.subscribeToTopic("messaging"); 
    // Obtain the FCM token and keep it in state so we can display/copy it.
    messaging.getToken().then((value) {
      print('FCM token: $value');
      setState(() {
        notificationText = value;
      });
      // Show a one-time dialog with the token so the developer can copy it easily.
      if (value != null && !_tokenDialogShown && mounted) {
        _tokenDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('FCM Token'),
              content: SelectableText(value),
              actions: [
                TextButton(
                  child: Text('Copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Token copied to clipboard')));
                  },
                ),
                TextButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        });
      }
    }); 
    // Handle incoming foreground messages and show themed UI based on type
    FirebaseMessaging.onMessage.listen((RemoteMessage event) {
      print('message received');
      print('notification body: ${event.notification?.body}');
      print('data: ${event.data}');
      _handleIncomingMessage(event);
    });

    // Notification permission for Android 13+ is requested natively in MainActivity

    // When the user taps a notification and the app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
      _handleIncomingMessage(message, openedFromBackground: true);
    });
  } 

  // Local persistence for received quotes
  List<String> _savedQuotes = [];

  Future<void> _loadSavedQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_quotes') ?? <String>[];
    setState(() {
      _savedQuotes = list;
    });
  }

  Future<void> _saveQuote(String quote) async {
    final prefs = await SharedPreferences.getInstance();
    // Simple de-dup and keep newest first
    _savedQuotes.remove(quote);
    _savedQuotes.insert(0, quote);
    await prefs.setStringList('saved_quotes', _savedQuotes);
    setState(() {});
  }

  Future<void> _removeSavedQuoteAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _savedQuotes.removeAt(index);
    await prefs.setStringList('saved_quotes', _savedQuotes);
    setState(() {});
  }

  Future<void> _initLocalNotifications() async {
    print('[DEBUG] _initLocalNotifications: start');
    // Android initialization
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
    print('[DEBUG] _initLocalNotifications: plugin initialized');

    // Create Android channels for different quote types. Each channel can have
    // its own sound. Sound files (e.g. important.mp3) must be placed under
    // android/app/src/main/res/raw/ without extension in the code below.
    final androidImpl = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    print('[DEBUG] _initLocalNotifications: resolved Android implementation = $androidImpl');

    // Helper to create a channel with optional custom sound name (raw resource)
    Future<void> createChannel(String id, String name, String description, {String? sound}) async {
      print('[DEBUG] createChannel: creating channel id=$id name=$name sound=$sound');
      try {
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          id,
          name,
          description: description,
          importance: Importance.max,
          sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
        );
        await androidImpl?.createNotificationChannel(channel);
        print('[DEBUG] createChannel: created channel $id');
      } catch (e, st) {
        print('[ERROR] createChannel: failed to create channel $id: $e\n$st');
      }
    }

    // Create channels. If you want custom sounds, add files to
    // android/app/src/main/res/raw/<sound>.mp3 and use the base name here.
    await createChannel(_channelRegular, 'Regular Quotes', 'Regular quote notifications', sound: null);
    await createChannel(_channelImportant, 'Important Quotes', 'Important quote notifications', sound: 'important');
    await createChannel(_channelMotivational, 'Motivational Quotes', 'Motivational quote notifications', sound: 'motivational');
    await createChannel(_channelWisdom, 'Wisdom Quotes', 'Wisdom quote notifications', sound: 'wisdom');
  }

  // Notification permission on Android 13+ is requested natively in MainActivity.kt

  Future<void> _showLocalNotification({required String channelId, required String channelName, required String title, required String body, String? sound, Color? color}) async {
    print('[DEBUG] _showLocalNotification: preparing notification channelId=$channelId title=$title sound=$sound');
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound != null,
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      color: color,
    );

    final details = NotificationDetails(android: androidDetails);
    try {
      await _localNotifications.show(0, title, body, details);
      print('[DEBUG] _showLocalNotification: shown notification title="$title" body="${body.length > 120 ? body.substring(0, 120) + '...' : body}"');
    } catch (e, st) {
      print('[ERROR] _showLocalNotification: failed to show notification: $e\n$st');
    }
  }

  void _handleIncomingMessage(RemoteMessage message, {bool openedFromBackground = false}) {
    print('[DEBUG] _handleIncomingMessage: messageId=${message.messageId} openedFromBackground=$openedFromBackground');
    print('[DEBUG] _handleIncomingMessage: data=${message.data} notification=${message.notification?.title}/${message.notification?.body}');
    // Prefer a data field named `quote` for the message text, otherwise use
    // the notification body. The `type` field controls visual styling.
    final String quote = message.data['quote'] ?? message.notification?.body ?? '""';
    final String type = (message.data['type'] ?? 'regular').toLowerCase();

    // Map types to icon and color
    IconData icon = Icons.message;
    Color color = Colors.grey.shade800;
    String title = 'Quote';

    switch (type) {
      case 'important':
        icon = Icons.warning;
        color = Colors.red.shade700;
        title = 'Important Quote';
        break;
      case 'motivational':
        icon = Icons.emoji_events; // trophy
        color = Colors.blue.shade700;
        title = 'Motivational Quote';
        break;
      case 'wisdom':
        icon = Icons.lightbulb;
        color = Colors.purple.shade700;
        title = 'Wisdom Quote';
        break;
      case 'regular':
      default:
        icon = Icons.message;
        color = Colors.grey.shade800;
        title = 'Quote';
    }

    if (!mounted) return;

    print('[DEBUG] _handleIncomingMessage: resolved type=$type title=$title');

    // Also show a platform notification with a channel-specific sound (Android).
    String channelId = _channelRegular;
    String channelName = 'Regular Quotes';
    String? soundName;
    switch (type) {
      case 'important':
        channelId = _channelImportant;
        channelName = 'Important Quotes';
        soundName = 'important';
        break;
      case 'motivational':
        channelId = _channelMotivational;
        channelName = 'Motivational Quotes';
        soundName = 'motivational';
        break;
      case 'wisdom':
        channelId = _channelWisdom;
        channelName = 'Wisdom Quotes';
        soundName = 'wisdom';
        break;
      case 'regular':
      default:
        channelId = _channelRegular;
        channelName = 'Regular Quotes';
        soundName = null;
    }

    // Fire a local notification (this will use the channel sound on Android)
    // Persist the quote locally for later viewing
    _saveQuote(quote);
    print('[DEBUG] _handleIncomingMessage: saved quote, scheduling local notification');

    _showLocalNotification(
      channelId: channelId,
      channelName: channelName,
      title: title,
      body: quote,
      sound: soundName,
      color: color,
    );

    print('[DEBUG] _handleIncomingMessage: scheduled local notification for channel=$channelId');

    // Show a themed, animated dialog that uses a background image if present.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Prefer JPG assets (e.g. assets/images/important.jpg). Falls back to
      // colored banner if not present.
      final bgAsset = 'assets/images/${type}.jpg';
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => QuoteDialog(
          title: title,
          quote: quote,
          icon: icon,
          color: color,
          backgroundAsset: bgAsset,
          animationType: type,
        ),
      );
    });
    print('[DEBUG] _handleIncomingMessage: requested showing QuoteDialog (type=$type)');
  }


 
  @override 
  Widget build(BuildContext context) { 
    return Scaffold( 
      appBar: AppBar( 
        title: Text(widget.title!), 
        actions: [
          IconButton(
            icon: Icon(Icons.bookmarks),
            tooltip: 'Saved quotes',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SavedQuotesPage(
                  quotes: _savedQuotes,
                  onDelete: _removeSavedQuoteAt,
                ),
              ));
            },
          )
        ],
      ), 
      body: Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Messaging Tutorial", style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            Text("FCM Token:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            SelectableText(notificationText ?? 'No token yet. Run on a supported platform (Android/iOS/web).'),
            SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: notificationText == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: notificationText!));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Token copied to clipboard')));
                        },
                  child: Text('Copy Token'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final t = await messaging.getToken();
                    setState(() => notificationText = t);
                    print('Refreshed token: $t');
                  },
                  child: Text('Refresh Token'),
                ),
              ],
            )
          ],
        ),
      )), 
    ); 
  } 
} 