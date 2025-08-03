import 'package:flutter/material.dart';

import '../draggable.dart';

const Duration _kDroppedSheetDragAnimationDuration = Duration(milliseconds: 300);
const double _kMinFlingVelocity = 2.0;

enum DrawerPosition {
  left,
  right;

  bool get isLeft => this == DrawerPosition.left;
}

class SlideDrawer<T> extends PageRoute<T> {
  SlideDrawer({
    super.traversalEdgeBehavior,
    super.directionalTraversalEdgeBehavior,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible = true,
    required this.builder,
    this.widthFactor = 0.80,
    this.drawerPosition = DrawerPosition.left,
    this.barrierColor = Colors.black12,
  });

  final double widthFactor;
  final DrawerPosition drawerPosition;
  final WidgetBuilder builder;
  late final _DrawerVerticalGestureController _gestureController = _DrawerVerticalGestureController(
    route: this,
    routeController: controller!,
  );

  @override
  final Color? barrierColor;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  bool canTransitionTo(TransitionRoute nextRoute) => false;

  CurvedAnimation getCurvedAnimation(Animation<double> parent) {
    final bool linearTransition = popGestureInProgress;
    return CurvedAnimation(
      curve: linearTransition ? Curves.linear : Curves.fastEaseInToSlowEaseOut,
      reverseCurve: linearTransition ? Curves.linear : Curves.fastEaseInToSlowEaseOut.flipped,
      parent: parent,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FractionalGestureDetector(
      controller: _gestureController,
      horizontalEnabled: true,
      verticalEnabled: false,
      child: FractionallySizedBox(
        alignment: drawerPosition.isLeft ? Alignment.centerLeft : Alignment.centerRight,
        widthFactor: widthFactor,
        child: builder(context),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animatable<Offset> offSetTween = Tween<Offset>(
      begin: Offset(drawerPosition.isLeft ? -widthFactor : widthFactor, 0.0),
      end: const Offset(0.0, 0.0),
    );

    final Animation<Offset> position = getCurvedAnimation(animation).drive(offSetTween);
    return FractionalTranslation(translation: position.value, child: child);
  }

  @override
  late DelegatedTransitionBuilder? delegatedTransition = (
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final Animatable<Offset> offSetTween = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: Offset(drawerPosition.isLeft ? widthFactor : -widthFactor, 0.0),
    );
    final Animation<Offset> position = getCurvedAnimation(secondaryAnimation).drive(offSetTween);
    return FractionalTranslation(translation: position.value, child: child);
  };
}

class _DrawerVerticalGestureController with FractionalDragDelegate {
  _DrawerVerticalGestureController({required this.routeController, required this.route});

  final AnimationController routeController;
  final SlideDrawer route;

  @override
  void handleDragStart(DragStartDetails details, Alignment alignment) {
    route.navigator?.didStartUserGesture();
  }

  @override
  void handleDragUpdate(Offset offset) {
    routeController.value += offset.dx * (route.drawerPosition.isLeft ? 1 : -1);
  }

  @override
  void handleDragCancel() {
    return handleDragEnd(0.0, 0.0);
  }

  @override
  void handleDragEnd(double dxVelocityRatio, double dyVelocityRatio) async {
    if(!route.navigator!.userGestureInProgress){
      return;
    }

    const Curve animationCurve = Curves.easeOut;
    final bool animateForward;
    if (!route.isCurrent) {
      animateForward = route.isActive;
    } else if (dxVelocityRatio.abs() >= _kMinFlingVelocity) {
      animateForward = route.drawerPosition.isLeft ? dxVelocityRatio >= 0 : dxVelocityRatio <= 0;
    } else {
      animateForward = routeController.value > 0.52;
    }

    if (animateForward) {
      await routeController.animateTo(
        1.0,
        duration: _kDroppedSheetDragAnimationDuration,
        curve: animationCurve,
      );
    } else {
      if (route.isCurrent && route.canPop) {
        route.navigator?.pop();
      } else {
        route.navigator?.removeRoute(route);
      }

      if (routeController.isAnimating) {
        await routeController.animateBack(
          0.0,
          duration: _kDroppedSheetDragAnimationDuration,
          curve: animationCurve,
        );
      }
    }
    route.navigator?.didStopUserGesture();
  }
}
