import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

enum WeSafeToastType {
  success,
  warning,
  critical,
}

class WeSafeToastData {
  final String id;
  final String message;
  final String? title;
  final WeSafeToastType type;
  final Duration duration;
  final String? status;

  WeSafeToastData({
    required this.id,
    required this.message,
    this.title,
    this.type = WeSafeToastType.success,
    this.duration = const Duration(seconds: 4),
    this.status,
  });
}

class WeSafeToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Displays a WeSafe Premium Toast Alert
  static void show({
    required String message,
    String? title,
    WeSafeToastType type = WeSafeToastType.success,
    Duration duration = const Duration(seconds: 4),
    String? status,
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState != null) {
      WeSafeToastManager().show(
        WeSafeToastData(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          message: message,
          title: title,
          type: type,
          duration: duration,
          status: status,
        ),
        overlayState,
      );
    } else {
      debugPrint("WeSafeToast: OverlayState not available, output: $message");
    }
  }

  /// Convenience method for Success state
  static void showSuccess({
    required String message,
    String? title = "Emergency Alert Activated",
    Duration duration = const Duration(seconds: 5),
    String? status = "SENT",
  }) {
    show(
      message: message,
      title: title,
      type: WeSafeToastType.success,
      duration: duration,
      status: status,
    );
  }

  /// Convenience method for Warning state
  static void showWarning({
    required String message,
    String? title = "System Warning",
    Duration duration = const Duration(seconds: 4),
    String? status,
  }) {
    show(
      message: message,
      title: title,
      type: WeSafeToastType.warning,
      duration: duration,
      status: status,
    );
  }

  /// Convenience method for Critical state
  static void showCritical({
    required String message,
    String? title = "Emergency Triggered",
    Duration duration = const Duration(seconds: 5),
    String? status = "LIVE",
  }) {
    show(
      message: message,
      title: title,
      type: WeSafeToastType.critical,
      duration: duration,
      status: status,
    );
  }
}

class WeSafeToastManager {
  static final WeSafeToastManager _instance = WeSafeToastManager._internal();
  factory WeSafeToastManager() => _instance;
  WeSafeToastManager._internal();

  final List<WeSafeToastData> _toasts = [];
  OverlayEntry? _overlayEntry;

  void show(WeSafeToastData toast, OverlayState overlayState) {
    _toasts.add(toast);
    _ensureOverlayInserted(overlayState);
    _overlayEntry?.markNeedsBuild();
  }

  void remove(WeSafeToastData toast) {
    _toasts.remove(toast);
    if (_toasts.isEmpty) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _ensureOverlayInserted(OverlayState overlayState) {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          final mediaQuery = MediaQuery.maybeOf(context);
          final topPadding = mediaQuery?.padding.top ?? 24.0;
          return Positioned(
            top: topPadding + 16,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _toasts.map((toast) {
                  return WeSafeToastCard(
                    key: ValueKey(toast.id),
                    toast: toast,
                    onDismissed: () => remove(toast),
                  );
                }).toList(),
              ),
            ),
          );
        },
      );
      overlayState.insert(_overlayEntry!);
    }
  }
}

class WeSafeToastCard extends StatefulWidget {
  final WeSafeToastData toast;
  final VoidCallback onDismissed;

  const WeSafeToastCard({
    required Key key,
    required this.toast,
    required this.onDismissed,
  }) : super(key: key);

  @override
  _WeSafeToastCardState createState() => _WeSafeToastCardState();
}

class _WeSafeToastCardState extends State<WeSafeToastCard> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  AnimationController? _pulseController;
  Animation<double>? _glowAnimation;

  bool _isDismissing = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack, // Soft bounce
    ));

    _entranceController.forward();

    if (widget.toast.type == WeSafeToastType.critical) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..repeat(reverse: true);

      _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }

    _dismissTimer = Timer(widget.toast.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
    });
    _entranceController.reverse().then((_) {
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entranceController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildCardContent(),
      ),
    );

    return Dismissible(
      key: widget.key!,
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        _dismissTimer?.cancel();
        widget.onDismissed();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: card,
      ),
    );
  }

  Widget _buildCardContent() {
    final theme = widget.toast;
    List<Color> gradientColors;
    Color textColor;
    Color subtitleColor;
    Color borderGlowColor;
    IconData iconData;
    Color iconBgColor;
    Color iconColor;

    switch (theme.type) {
      case WeSafeToastType.success:
        gradientColors = [const Color(0xFF8B4F67), const Color(0xFFAE4BB0)];
        textColor = Colors.white;
        subtitleColor = Colors.white.withOpacity(0.85);
        borderGlowColor = const Color(0xFFAE4BB0);
        iconData = Icons.verified_user_rounded;
        iconBgColor = Colors.white.withOpacity(0.18);
        iconColor = Colors.white;
        break;
      case WeSafeToastType.warning:
        gradientColors = [const Color(0xFFAE4BB0), const Color(0xFFD4B8D0)];
        textColor = const Color(0xFF2B2230);
        subtitleColor = const Color(0xFF2B2230).withOpacity(0.8);
        borderGlowColor = Colors.transparent;
        iconData = Icons.warning_amber_rounded;
        iconBgColor = const Color(0xFF2B2230).withOpacity(0.1);
        iconColor = const Color(0xFF2B2230);
        break;
      case WeSafeToastType.critical:
        gradientColors = [const Color(0xFF3A004D), const Color(0xFF8B4F67)];
        textColor = Colors.white;
        subtitleColor = Colors.white.withOpacity(0.85);
        borderGlowColor = const Color(0xFFEF4444);
        iconData = Icons.gpp_maybe_rounded;
        iconBgColor = const Color(0xFFEF4444).withOpacity(0.2);
        iconColor = const Color(0xFFEF4444);
        break;
    }

    Widget cardBody = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withOpacity(0.85)).toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: theme.type == WeSafeToastType.critical
                  ? const Color(0xFFEF4444).withOpacity(0.4)
                  : Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBgColor,
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      theme.title ?? (theme.type == WeSafeToastType.success ? 'Success' : theme.type == WeSafeToastType.warning ? 'Warning' : 'Emergency'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.message,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (theme.status != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    theme.status!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (theme.type == WeSafeToastType.critical && _glowAnimation != null) {
      return AnimatedBuilder(
        animation: _glowAnimation!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: borderGlowColor.withOpacity(0.4 * (1.0 - (_glowAnimation!.value / 32.0))),
                  blurRadius: _glowAnimation!.value,
                  spreadRadius: _glowAnimation!.value / 4,
                ),
              ],
            ),
            child: child,
          );
        },
        child: cardBody,
      );
    } else if (theme.type == WeSafeToastType.success) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: borderGlowColor.withOpacity(0.25),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: cardBody,
      );
    } else {
      return cardBody;
    }
  }
}
