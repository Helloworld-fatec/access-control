import 'package:flutter/widgets.dart';

import 'session_controller.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    required SessionController session,
    required super.child,
    super.key,
  }) : super(notifier: session);
  static SessionController of(BuildContext c) {
    final s = c.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(s != null);
    return s!.notifier!;
  }
}
