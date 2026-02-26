import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Navigation helper to optimize screen transitions and performance
class NavigationHelper {
  static const Duration _transitionDuration = Duration(milliseconds: 200);
  
  /// Optimized navigation with reduced transition duration
  static Future<T?> navigateToPage<T>(Widget page, {
    bool fullscreenDialog = false,
  }) async {
    return Get.to<T>(
      () => page,
      transition: Transition.cupertino,
      duration: _transitionDuration,
      fullscreenDialog: fullscreenDialog,
    );
  }
  
  /// Navigate and replace current screen
  static Future<T?> navigateAndReplace<T>(Widget page) async {
    return Get.off<T>(
      () => page,
      transition: Transition.cupertino,
      duration: _transitionDuration,
    );
  }
  
  /// Navigate and clear all previous routes
  static Future<T?> navigateAndClearAll<T>(Widget page) async {
    return Get.offAll<T>(
      () => page,
      transition: Transition.cupertino,
      duration: _transitionDuration,
    );
  }
  
  /// Preload a screen in background to reduce transition delay
  static void preloadScreen(Widget Function() screenBuilder) {
    // Preload the screen widget tree
    Future.microtask(() {
      try {
        screenBuilder();
      } catch (e) {
        print('Error preloading screen: $e');
      }
    });
  }
  
  /// Optimized back navigation
  static void goBack<T>([T? result]) {
    Get.back<T>(result: result);
  }
  
  /// Check if we can go back
  static bool canGoBack() {
    return Navigator.of(Get.context!).canPop();
  }
  
  /// Custom page route with optimized transitions
  static PageRoute<T> createOptimizedRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }
  
  /// Batch navigation operations to reduce multiple rebuilds
  static void batchNavigations(List<VoidCallback> operations) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final operation in operations) {
        operation();
      }
    });
  }
}

/// Widget wrapper to optimize expensive screens
class OptimizedScreen extends StatefulWidget {
  final Widget child;
  final bool preloadOnInit;
  final VoidCallback? onPreload;
  
  const OptimizedScreen({
    super.key,
    required this.child,
    this.preloadOnInit = false,
    this.onPreload,
  });

  @override
  State<OptimizedScreen> createState() => _OptimizedScreenState();
}

class _OptimizedScreenState extends State<OptimizedScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => false; // Don't keep alive by default
  
  @override
  void initState() {
    super.initState();
    
    if (widget.preloadOnInit && widget.onPreload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPreload!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Mixin for screens that need performance optimization
mixin PerformanceOptimizedScreen<T extends StatefulWidget> on State<T> {
  bool _isScreenActive = true;
  
  @override
  void initState() {
    super.initState();
    _optimizeScreenPerformance();
  }
  
  @override
  void dispose() {
    _isScreenActive = false;
    super.dispose();
  }
  
  void _optimizeScreenPerformance() {
    // Defer heavy operations to next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isScreenActive) {
        onScreenReady();
      }
    });
  }
  
  /// Override this method to perform heavy operations after screen is ready
  void onScreenReady() {}
  
  /// Safe setState that checks if screen is still active
  void safeSetState(VoidCallback fn) {
    if (_isScreenActive && mounted) {
      setState(fn);
    }
  }
  
  /// Debounced setState for high-frequency updates
  void debouncedSetState(VoidCallback fn, {Duration delay = const Duration(milliseconds: 100)}) {
    Future.delayed(delay, () {
      safeSetState(fn);
    });
  }
} 