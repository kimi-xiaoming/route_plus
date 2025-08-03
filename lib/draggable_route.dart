import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'draggable.dart';

class ResizableRouteTarget extends StatefulWidget {
  const ResizableRouteTarget({super.key, required this.tag, required this.builder});

  final Object tag;

  final Widget Function(BuildContext context, double progress) builder;

  static _ResizableRouteTargetState? _maybeOf(BuildContext context, Object tag) {
    _ResizableRouteTargetState? res;
    void visitor(Element element) {
      if (element.widget is ResizableRouteTarget) {
        final ResizableRouteTarget target = element.widget as ResizableRouteTarget;
        if (target.tag == tag) {
          res = (element as StatefulElement).state as _ResizableRouteTargetState;
          return;
        }
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return res;
  }

  @override
  State<ResizableRouteTarget> createState() => _ResizableRouteTargetState();
}

class _ResizableRouteTargetState extends State<ResizableRouteTarget> {
  double _progress = 0.0;

  set progress(double value) {
    if (_progress != value) {
      setState(() {
        _progress = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _progress);
  }
}

class DraggableResizedRoute<T> extends PageRoute<T> {
  DraggableResizedRoute({
    super.settings,
    super.requestFocus,
    super.traversalEdgeBehavior,
    super.directionalTraversalEdgeBehavior,
    super.fullscreenDialog,
    super.allowSnapshotting,
    required this.tag,
    required this.context,
    required this.builder,
  });

  static ResizingRouteScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ResizingRouteScope>();
  }

  final Object tag;
  final BuildContext context;
  final Widget Function(BuildContext context) builder;

  late final _FractionalController _fractionalController;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ResizingRouteScope(animation: animation, child: builder(context));
  }

  @override
  void install() {
    super.install();
    _fractionalController = _FractionalController(
      route: this,
      routeController: controller!,
      tag: tag,
      context: context,
    );
  }

  @override
  TickerFuture didPush() {
    _fractionalController.handlePush();
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    _fractionalController.handlePop();
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _DraggableSheet(route: this, controller: _fractionalController, child: child);
  }
}

class _FractionalController extends ChangeNotifier with FractionalDragDelegate {
  _FractionalController({
    required this.route,
    required this.routeController,
    required this.tag,
    required this.context,
  }) {
    routeController.addListener(handleAnimationUpdate);
  }

  final Object tag;
  final BuildContext context;
  final ModalRoute route;
  final AnimationController routeController;

  Offset _offset = Offset.zero;
  Alignment _dragAlignment = Alignment.center;
  double dragEndProgress = 1.0;
  _ResizableRouteTargetState? target;

  late CurvedAnimation alignmentCurve = CurvedAnimation(
    curve: Curves.fastEaseInToSlowEaseOut.flipped,
    parent: routeController,
  );

  void handlePush() {
    updateTarget();
  }

  void handlePop() {
    updateTarget();
  }

  void handleAnimationUpdate() {
    target?.progress = routeController.value;
  }

  void updateTarget() {
    final _ResizableRouteTargetState? previous = target;
    target = ResizableRouteTarget._maybeOf(context, tag);
    if (previous != null && target != previous) {
      previous.progress = 0.0;
    }
  }

  @override
  FutureOr<void> handleDragStart(DragStartDetails details, Alignment alignment) {
    updateTarget();
    route.navigator?.didStartUserGesture();
    _dragAlignment = alignment;
    _offset = Offset.zero;
    notifyListeners();
  }

  @override
  FutureOr<void> handleDragUpdate(Offset offset) {
    _offset = _offset + offset;
    double progress = 1.0 - min(0.3, max(_offset.dx.abs(), _offset.dy.abs()));
    routeController.value = progress;
    notifyListeners();
  }

  @override
  FutureOr<void> handleDragEnd(double dxVelocityRatio, double dyVelocityRatio) async {
    dragEndProgress = routeController.value;
    if (routeController.value < 0.80) {
      if (route.isCurrent) {
        route.navigator?.pop();
      }
    } else {
      await routeController.forward();
    }
    route.navigator?.didStopUserGesture();
    notifyListeners();
  }

  Alignment getAlignment(Alignment targetAlignment) {
    double progress = routeController.value;
    if ((route.navigator?.userGestureInProgress ?? true) || dragEndProgress == 1.0) {
      return AlignmentTween(begin: targetAlignment, end: _dragAlignment).transform(progress);
    }

    final TweenSequence<Alignment> sequence = TweenSequence([
      TweenSequenceItem(
        tween: AlignmentTween(begin: targetAlignment, end: _dragAlignment),
        weight: dragEndProgress,
      ),
      TweenSequenceItem(
        tween: AlignmentTween(begin: _dragAlignment, end: Alignment.center),
        weight: 1 - dragEndProgress,
      ),
    ]);

    return sequence.transform(routeController.value);
  }

  Offset get offSet {
    if ((route.navigator?.userGestureInProgress ?? true) || dragEndProgress == 1.0) {
      return _offset;
    }

    final TweenSequence<Offset> sequence = TweenSequence([
      TweenSequenceItem(
        tween: OffsetTween(begin: Offset.zero, end: _offset),
        weight: dragEndProgress,
      ),
      TweenSequenceItem(
        tween: OffsetTween(begin: _offset, end: Offset.zero),
        weight: 1 - dragEndProgress,
      ),
    ]);

    return sequence.transform(routeController.value);
  }
}

class OffsetTween extends Tween<Offset> {
  OffsetTween({super.begin, super.end});

  @override
  Offset lerp(double t) => Offset.lerp(begin, end, t)!;
}

class _DraggableSheet extends StatefulWidget {
  const _DraggableSheet({required this.controller, required this.route, required this.child});

  final _FractionalController controller;
  final Widget child;
  final ModalRoute route;

  @override
  State<_DraggableSheet> createState() => _DraggableRouteTransition();
}

class _DraggableRouteTransition extends State<_DraggableSheet> with TickerProviderStateMixin {
  Alignment getAlignment(Size parentSize, Size childSize, Offset offset) {
    final Offset other = (parentSize - childSize) as Offset;
    final double centerX = other.dx / 2.0;
    final double centerY = other.dy / 2.0;
    return Alignment(
      centerX == 0.0 ? -1 : (offset.dx - centerX) / centerX,
      centerY == 0.0 ? -1 : (offset.dy - centerY) / centerY,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget transition = LayoutBuilder(
      builder: (context, constrains) {
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, child) {
            RenderBox? targetRenderBox =
                widget.controller.target?.context.findRenderObject() as RenderBox?;
            RenderObject navigatorRenderBox = widget.route.navigator!.context.findRenderObject()!;

            Size beginSize = targetRenderBox?.size ?? Size.zero;
            Size endSize = constrains.biggest;

            final CurvedAnimation sizedCurved = CurvedAnimation(
              parent: widget.route.animation!,
              curve: Curves.linear,
            );
            final SizeTween sizeTween = SizeTween(begin: beginSize, end: endSize);
            final Animation<Size?> sizeAnimation = sizedCurved.drive(sizeTween);
            Offset? tagetOffset = targetRenderBox?.localToGlobal(
              Offset.zero,
              ancestor: navigatorRenderBox,
            );

            Alignment targetAlignment =
                tagetOffset == null
                    ? Alignment.center
                    : getAlignment(constrains.biggest, beginSize, tagetOffset);

            return FractionalTranslation(
              translation: widget.controller.offSet,
              child: Align(
                alignment: widget.controller.getAlignment(targetAlignment),
                child: SizedBox.fromSize(size: sizeAnimation.value, child: widget.child),
              ),
            );
          },
        );
      },
    );

    return FractionalGestureDetector(
      controller: widget.controller,
      horizontalEnabled: true,
      verticalEnabled: false,
      child: transition,
    );
  }
}

class ResizingRouteScope extends InheritedWidget {
  const ResizingRouteScope({super.key, required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(covariant ResizingRouteScope oldWidget) {
    return oldWidget.animation != animation;
  }
}
