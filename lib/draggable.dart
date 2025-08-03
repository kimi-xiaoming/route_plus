import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

mixin class FractionalDragDelegate {
  FutureOr<void> handleDragStart(DragStartDetails details, Alignment alignment) {}

  FutureOr<void> handleDragUpdate(Offset offset) {}

  FutureOr<void> handleDragEnd(double dxVelocityRatio, double dyVelocityRatio) {}

  FutureOr<void> handleDragCancel() {}
}

class FractionalGestureDetector extends StatefulWidget {
  const FractionalGestureDetector({
    super.key,
    required this.horizontalEnabled,
    required this.verticalEnabled,
    required this.controller,
    required this.child,
  });

  final bool horizontalEnabled;
  final bool verticalEnabled;
  final FractionalDragDelegate controller;
  final Widget child;

  @override
  State<FractionalGestureDetector> createState() => _FractionalGestureDetectorState();
}

class _FractionalGestureDetectorState extends State<FractionalGestureDetector> {
  Offset lastPosition = Offset(0.0, 0.0);

  late HorizontalDragGestureRecognizer horizontalRecognizer;

  void _handleDragStart(DragStartDetails details) {
    lastPosition = details.localPosition;
    widget.controller.handleDragStart(details, FractionalOffset.fromOffsetAndSize(lastPosition, context.size!));
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final Size size = context.size!;

    final Offset offset = Offset(
      (details.localPosition.dx - lastPosition.dx) / size.width,
      (details.localPosition.dy - lastPosition.dy) / size.height,
    );

    lastPosition = details.localPosition;
    widget.controller.handleDragUpdate(offset);
  }

  void _handleDragEnd(DragEndDetails details) {
    widget.controller.handleDragEnd(
      details.velocity.pixelsPerSecond.dx / context.size!.width,
      details.velocity.pixelsPerSecond.dy / context.size!.height,
    );
  }

  void _handleDragCancel() {
    widget.controller.handleDragCancel();
  }

  void onPointerDown(PointerDownEvent event){
    horizontalRecognizer.addPointer(event);
  }

  @override
  void initState() {
    horizontalRecognizer = HorizontalDragGestureRecognizer()
    ..onlyAcceptDragOnThreshold = true
    ..onStart = _handleDragStart
    ..onUpdate = _handleDragUpdate
    ..onEnd = _handleDragEnd
    ..onCancel = _handleDragCancel;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
