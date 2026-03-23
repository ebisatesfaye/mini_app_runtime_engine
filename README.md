# Mini-App Runtime Engine (Flutter)

This package contains the official `MiniAppContainer` widget. It provides a secure sandbox and a robust native bridge for loading 3rd-party Mini-Apps built with the `miniapp-sdk`.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  miniapp_runtime_engine:
    path: ../miniapp_runtime_engine
```

## Usage

Simply drop the `MiniAppContainer` into any Flutter screen and provide the path to your packaged Mini-App's `index.html`.

```dart
import 'package:flutter/material.dart';
import 'package:miniapp_runtime_engine/miniapp_runtime_engine.dart';

class MyHostScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mini-App Example")),
      body: MiniAppContainer(
        initialFile: "assets/miniapp/index.html",
        onMessage: (msg) {
          print("Message from Mini-App: $msg");
        },
      ),
    );
  }
}
```

## Features Supported out-of-the-box
The `MiniAppContainer` intercepts all bridge methods via `InAppWebView` and handles:
- **Device Sensors**: Camera (`_mockCamera`), Scanner (`_mockScanner`), Location, File Pickers.
- **Payments**: Shows a processing payment bottom sheet and returns mock transaction data.
- **System Modals**: Displays toasts and beautiful AlertDialogs natively in Flutter.
- **Storage/Auth/Permissions**: Handles mock persistence and scoped permission requests seamlessly.
