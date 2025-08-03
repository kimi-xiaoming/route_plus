import 'dart:math';
import 'package:flutter/cupertino.dart';

class PositionedPopupRoute<T> extends PopupRoute<T> {
  PositionedPopupRoute({
    super.settings,
    super.requestFocus,
    super.filter,
    super.traversalEdgeBehavior,
    super.directionalTraversalEdgeBehavior,
    required this.builder,
    required this.targetAlignment,
    required this.localContext,
    this.localAlignment,
    this.localOffset,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  final BuildContext localContext;
  final Alignment? localAlignment;
  final Offset? localOffset;
  final Alignment targetAlignment;

  @override
  Duration get transitionDuration => Duration(milliseconds: 250);

  final WidgetBuilder builder;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final RenderObject? renderObject = navigator!.context.findRenderObject();
    final localBox = localContext.findRenderObject() as RenderBox;
    final Offset offset = localBox.localToGlobal(
      localOffset ?? localAlignment!.alongSize(localBox.size),
      ancestor: renderObject,
    );

    final TweenSequence<double> scaleTween = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 0.7),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 0.3),
    ]);

    final CurvedAnimation tweenCurve = CurvedAnimation(parent: animation, curve: Curves.linear);
    final double scale = tweenCurve.drive(scaleTween).value;

    return PositionedAlign(
      offset: offset,
      alignment: targetAlignment,
      child: Opacity(
        opacity: min(1.0, scale),
        child: Transform.scale(alignment: targetAlignment, scale: scale, child: child),
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }
}

class PositionedAlign extends CustomSingleChildLayout {
  PositionedAlign({
    super.key,
    required Alignment alignment,
    required Offset offset,
    required super.child,
  }) : super(delegate: PositionedAlignDelegate(targetAlignment: alignment, targetOffset: offset));
}

class PositionedAlignDelegate extends SingleChildLayoutDelegate {
  final Alignment targetAlignment;
  final Offset targetOffset;

  PositionedAlignDelegate({super.relayout, required this.targetAlignment, required this.targetOffset});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    Alignment targetAlignment = this.targetAlignment;
    Offset targetOffset = targetAlignment.alongSize(childSize);
    Offset result = this.targetOffset - targetOffset;

    final Rectangle rect = Rectangle(result.dx, result.dy, childSize.width, childSize.height);

    if (rect.topLeft.x < 0) {
      targetAlignment = Alignment(targetAlignment.x - 1.0, targetAlignment.y);
    }
    if (rect.topLeft.y < 0) {
      targetAlignment = Alignment(targetAlignment.x, targetAlignment.y - 2.0);
    }

    if (rect.bottomRight.x > size.width) {
      targetAlignment = Alignment(targetAlignment.x + 1.0, targetAlignment.y);
    }
    if (rect.bottomRight.y > size.height) {
      targetAlignment = Alignment(targetAlignment.x, targetAlignment.y + 2.0);
    }

    targetOffset = targetAlignment.alongSize(childSize);
    return this.targetOffset - targetOffset;
  }

  @override
  bool shouldRelayout(covariant PositionedAlignDelegate oldDelegate) {
    return oldDelegate.targetAlignment != targetAlignment || oldDelegate.targetOffset != targetOffset;
  }
}
