// ignore_for_file: non_constant_identifier_names

import 'package:flutter/src/widgets/_window_linux.dart';

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'linux.g.dart';

/// Provides additional delegate methods for [WindowControllerLinux].
///
/// The delegate can be added to window controller using
/// [WindowControllerLinuxExtension.addDelegate] method.
abstract mixin class WindowDelegateLinux {
  /// Called right before the window is closed. This is the best place to add
  /// any platform specific cleanup code.
  void windowWillClose() {}

  /// Called when window state changes, e.g. when it is minimized,
  /// maximized, or enters fullscreen.
  void windowStateDidChange() {}
}

extension WindowControllerLinuxExtension on WindowControllerLinux {
  /// Register a Linux specific delegate to this window controller.
  void addDelegate(WindowDelegateLinux delegate) {
    _WindowControllerLinuxPrivate.forController(this).addDelegate(delegate);
  }

  /// Unregister a previously registered delegate.
  void removeDelegate(WindowDelegateLinux delegate) {
    _WindowControllerLinuxPrivate.forController(this).removeDelegate(delegate);
  }

  /// Returns current window state specific to Linux platform.
  WindowStateLinux getWindowState() {
    final state = cw_window_get_state(windowHandle);
    return WindowStateLinux._(state);
  }

  void windowToWrlLayer(WrlLayerWindowLayer layer, WrlLayerScreenEdge anchor) {
    _gtkLayerInitForWindow(windowHandle);
    wrlLayerSetLayer(layer);
    wrlLayerSetAnchor(anchor);
  }

  void wrlLayerSetLayer(WrlLayerWindowLayer layer) {
    _gtkLayerSetLayer(windowHandle, switch(layer) {
      .background => GTK_LAYER_SHELL_LAYER_BACKGROUND,
      .bottom => GTK_LAYER_SHELL_LAYER_BOTTOM,
      .top => GTK_LAYER_SHELL_LAYER_TOP,
      .overlay => GTK_LAYER_SHELL_LAYER_OVERLAY,
    });
  }

  void wrlLayerSetAnchor(WrlLayerScreenEdge anchor) {
    bool anchorTop = anchor.contains(const WrlLayerScreenEdge.top());
    bool anchorRight = anchor.contains(const WrlLayerScreenEdge.right());
    bool anchorBottom = anchor.contains(const WrlLayerScreenEdge.bottom());
    bool anchorLeft = anchor.contains(const WrlLayerScreenEdge.left());

    _gtkLayerSetAnchor(windowHandle, GTK_LAYER_SHELL_EDGE_TOP, anchorTop);
    _gtkLayerSetAnchor(windowHandle, GTK_LAYER_SHELL_EDGE_RIGHT, anchorRight);
    _gtkLayerSetAnchor(windowHandle, GTK_LAYER_SHELL_EDGE_LEFT, anchorLeft);
    _gtkLayerSetAnchor(windowHandle, GTK_LAYER_SHELL_EDGE_BOTTOM, anchorBottom);
  }

  void wrlLayerSetLayerMargin({
    int left = 0,
    int top = 0,
    int right = 0,
    int bottom = 0,
  }) {
    _gtkLayerSetMargin(windowHandle, GTK_LAYER_SHELL_EDGE_TOP, top);
    _gtkLayerSetMargin(windowHandle, GTK_LAYER_SHELL_EDGE_RIGHT, right);
    _gtkLayerSetMargin(windowHandle, GTK_LAYER_SHELL_EDGE_LEFT, left);
    _gtkLayerSetMargin(windowHandle, GTK_LAYER_SHELL_EDGE_BOTTOM, bottom);
  }

  void wrlLayerSetKeyboardMode(WrlLayerKeyboardMode mode) {
    _gtkLayerSetKeyboardMode(windowHandle, switch(mode) {
      WrlLayerKeyboardMode.none => GTK_LAYER_SHELL_KEYBOARD_MODE_NONE,
      WrlLayerKeyboardMode.exclusive => GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE,
      WrlLayerKeyboardMode.onDemand => GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND,
    });
  }

  String getXdgToken() {
    final tokenNative = cw_wrl_get_xdg_token();
    final response = tokenNative.cast<Utf8>().toDartString();
    malloc.free(tokenNative);
    return response;
  }
}

/// Linux specific window state.
class WindowStateLinux {
  final bool withdrawn;
  final bool iconified;
  final bool maximized;
  final bool sticky;
  final bool fullscreen;
  final bool above;
  final bool below;
  final bool focused;
  final bool topTiled;
  final bool topResizable;
  final bool rightTiled;
  final bool rightResizable;
  final bool bottomTiled;
  final bool bottomResizable;
  final bool leftTiled;
  final bool leftResizable;

  WindowStateLinux._(int state)
    : withdrawn = (state & CW_WINDOW_STATE_WITHDRAWN) != 0,
      iconified = (state & CW_WINDOW_STATE_ICONIFIED) != 0,
      maximized = (state & CW_WINDOW_STATE_MAXIMIZED) != 0,
      sticky = (state & CW_WINDOW_STATE_STICKY) != 0,
      fullscreen = (state & CW_WINDOW_STATE_FULLSCREEN) != 0,
      above = (state & CW_WINDOW_STATE_ABOVE) != 0,
      below = (state & CW_WINDOW_STATE_BELOW) != 0,
      focused = (state & CW_WINDOW_STATE_FOCUSED) != 0,
      topTiled = (state & CW_WINDOW_STATE_TOP_TILED) != 0,
      topResizable = (state & CW_WINDOW_STATE_TOP_RESIZABLE) != 0,
      rightTiled = (state & CW_WINDOW_STATE_RIGHT_TILED) != 0,
      rightResizable = (state & CW_WINDOW_STATE_RIGHT_RESIZABLE) != 0,
      bottomTiled = (state & CW_WINDOW_STATE_BOTTOM_TILED) != 0,
      bottomResizable = (state & CW_WINDOW_STATE_BOTTOM_RESIZABLE) != 0,
      leftTiled = (state & CW_WINDOW_STATE_LEFT_TILED) != 0,
      leftResizable = (state & CW_WINDOW_STATE_LEFT_RESIZABLE) != 0;
}

//
// Implementation details.
//

class _WindowControllerLinuxPrivate {
  _WindowControllerLinuxPrivate._(this.controller) {
    final initRequest = ffi.Struct.create<cw_delegate_config_t>();
    initRequest.on_window_will_close = _windowWillClose.nativeFunction;
    initRequest.on_window_state_changed = _windowStateChanged.nativeFunction;
    cw_gtk_window_init_delegate(
      controller.windowHandle,
      initRequest,
    );
  }

  final WindowControllerLinux controller;

  late final _windowWillClose = ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
    _onWindowWillClose,
  );
  late final _windowStateChanged = ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
    _onWindowStateChanged,
  );

  void _onWindowWillClose() {
    for (final delegate in delegates) {
      delegate.windowWillClose();
    }
    _windowWillClose.close();
    _windowStateChanged.close();
  }

  void _onWindowStateChanged() {
    for (final delegate in delegates) {
      delegate.windowStateDidChange();
    }
  }

  static _WindowControllerLinuxPrivate forController(
    WindowControllerLinux controller,
  ) {
    var existing = _expando[controller];
    if (existing != null) {
      return existing;
    }
    final created = _WindowControllerLinuxPrivate._(
      controller,
    );
    _expando[controller] = created;
    return created;
  }

  void addDelegate(WindowDelegateLinux delegate) {
    if (!_delegates.contains(delegate)) {
      _delegates.add(delegate);
    }
  }

  void removeDelegate(WindowDelegateLinux delegate) {
    _delegates.remove(delegate);
  }

  List<WindowDelegateLinux> get delegates => List.of(_delegates);

  final List<WindowDelegateLinux> _delegates = [];

  static final _expando = Expando<_WindowControllerLinuxPrivate>(
    'WindowControllerLinux',
  );
}

enum WrlLayerKeyboardMode {
  none(0),
  exclusive(1),
  onDemand(2);

  /// Integer representation of the enum. This should match with the int value
  /// of the platform side enum.
  final int value;

  const WrlLayerKeyboardMode(this.value);
}

enum WrlLayerWindowLayer {
  background(1),
  bottom(2),
  top(3),
  overlay(4);

  /// This is the ID of the layer. This should match with the int representation
  /// of layers in the platform side enum.
  final int layerId;

  const WrlLayerWindowLayer(this.layerId);
}

/// Represent an edge in the screen.
/// This is mainly used for setting the anchor for layers.
class WrlLayerScreenEdge {
  /// This is an integer representation of the enum. This value must match with the
  /// int representation of the enum in the platform side.
  final int value;

  const WrlLayerScreenEdge._(this.value);

  const WrlLayerScreenEdge.top() : value = 1 << 0;
  const WrlLayerScreenEdge.right() : value = 1 << 1;
  const WrlLayerScreenEdge.bottom() : value = 1 << 2;
  const WrlLayerScreenEdge.left() : value = 1 << 3;

  WrlLayerScreenEdge operator |(WrlLayerScreenEdge other) {
    return WrlLayerScreenEdge._(value | other.value);
  }

  bool contains(WrlLayerScreenEdge other) {
    return value & other.value != 0;
  }
}

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeType>, ffi.Int)>(
  symbol: 'gtk_layer_set_keyboard_mode',
)
external void _gtkLayerSetKeyboardMode(ffi.Pointer<ffi.NativeType> window, int mode);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeType>, ffi.Int, ffi.Bool)>(
  symbol: 'gtk_layer_set_anchor',
)
external void _gtkLayerSetAnchor(ffi.Pointer<ffi.NativeType> window, int edge, bool anchorToEdge);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeType>, ffi.Int)>(
  symbol: 'gtk_layer_set_layer',
)
external void _gtkLayerSetLayer(ffi.Pointer<ffi.NativeType> window, int layer);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeType>)>(
  symbol: 'gtk_layer_init_for_window',
)
external void _gtkLayerInitForWindow(ffi.Pointer<ffi.NativeType> window);

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeType>, ffi.Int, ffi.Int)>(
  symbol: 'gtk_layer_set_margin',
)
external void _gtkLayerSetMargin(ffi.Pointer<ffi.NativeType> window, int edge, int margin);

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_EDGE_LEFT;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_EDGE_RIGHT;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_EDGE_TOP;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_EDGE_BOTTOM;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_EDGE_ENTRY_NUMBER;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_KEYBOARD_MODE_NONE;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_KEYBOARD_MODE_ENTRY_NUMBER;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_LAYER_BACKGROUND;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_LAYER_BOTTOM;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_LAYER_TOP;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_LAYER_OVERLAY;

@ffi.Native<ffi.Int>()
external final int GTK_LAYER_SHELL_LAYER_ENTRY_NUMBER;
