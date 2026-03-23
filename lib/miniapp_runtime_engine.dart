library;

// import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MiniAppContainer extends StatefulWidget {
  final String initialFile;
  final Function(String message)? onMessage;

  const MiniAppContainer({
    super.key,
    required this.initialFile,
    this.onMessage,
  });

  @override
  State<MiniAppContainer> createState() => _MiniAppContainerState();
}

class _MiniAppContainerState extends State<MiniAppContainer> {
  InAppWebViewController? controller;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: widget.initialFile,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        isInspectable: true,
      ),
      onWebViewCreated: (ctrl) {
        controller = ctrl;
        ctrl.addJavaScriptHandler(
          handlerName: "MiniAppBridge",
          callback: (args) async {
            final message = args[0];
            debugPrint("🔥 Received from MiniApp: $message");
            if (widget.onMessage != null) {
              widget.onMessage!(message.toString());
            }
            return await handleRequest(message, context);
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> handleRequest(Map message, BuildContext context) async {
    final method = message["method"];
    final params = message["params"];

    try {
      dynamic result;

      switch (method) {
        case "core.init":
          result = {
            "instanceId": DateTime.now().millisecondsSinceEpoch.toString(),
            "capabilities": ["camera", "storage", "auth", "ui", "device", "payments"],
          };
          break;

        case "permissions.request":
          result = await _requestPermissions(params, context);
          break;

        case "auth.getProfile":
          _showToast("Authenticating User...", context);
          await Future.delayed(const Duration(seconds: 1));
          result = {"id": "usr_9982", "displayName": "John Doe", "email": "john@example.com"};
          break;

        case "auth.getToken":
          result = {"token": "mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}"};
          break;

        case "storage.setItem":
          result = true;
          break;

        case "storage.getItem":
          result = '{"item":"Pizza","price":20}';
          break;
          
        case "storage.removeItem":
          result = true;
          break;

        case "ui.toast":
          _showToast(params["message"] ?? "Toast Triggered", context);
          result = true;
          break;

        case "ui.modal":
          result = await _showModal(params, context);
          break;

        case "device.notify":
          _showToast("Notification: ${params?["message"] ?? params?["title"]}", context);
          result = true;
          break;

        case "device.camera.open":
        case "device.camera.capture":
          result = await _mockCamera(context);
          break;

        case "device.location.getCurrentPosition":
          result = await _mockLocation(context);
          break;

        case "device.location.watchPosition":
          _showToast("Started GPS Tracking", context);
          result = {"watchId": "watch_${Random().nextInt(1000)}"};
          break;

        case "device.location.clearWatch":
          _showToast("Stopped GPS Tracking", context);
          result = true;
          break;

        case "device.scanner.scan":
          result = await _mockScanner(context);
          break;

        case "device.file.pick":
          result = await _mockFilePicker(context);
          break;
          
        case "device.clipboard.read":
          ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
          if (!context.mounted) return {"ok": false, "error": "unmounted"};
          _showToast("Read from Clipboard", context);
          result = {"text": data?.text ?? ""};
          break;
          
        case "device.clipboard.write":
          await Clipboard.setData(ClipboardData(text: params?["text"] ?? ""));
          if (!context.mounted) return {"ok": false, "error": "unmounted"};
          _showToast("Copied to Clipboard!", context);
          result = true;
          break;

        case "payments.requestPayment":
          result = await _requestPayment(params, context);
          break;

        default:
          throw Exception("Unknown method: $method");
      }

      return {"ok": true, "result": result};
    } catch (e) {
      return {"ok": false, "error": e.toString()};
    }
  }

  Future<Map<String, String>> _requestPermissions(dynamic params, BuildContext context) async {
    Map<String, String> granted = {};
    dynamic requestedPerms;
    
    if (params is Map && params.containsKey("scopes")) {
      requestedPerms = params["scopes"];
    } else {
      requestedPerms = params;
    }

    if (requestedPerms is List) {
      for (var p in requestedPerms) {
        granted[p.toString()] = "granted";
      }
    }
    return granted;
  }

  void _showToast(String message, BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<Map<String, dynamic>> _showModal(dynamic params, BuildContext context) async {
    String title = params?["title"] ?? "Confirm";
    String message = params?["message"] ?? "Are you sure?";

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    return {"confirmed": confirmed ?? false};
  }

  Future<Map<String, dynamic>> _mockCamera(BuildContext context) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            const Material(
              color: Colors.transparent,
              child: Text("Opening Camera...", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
    if (context.mounted) Navigator.pop(context);
    
    return {"url": "https://dummyimage.com/600x400/4a90e2/ffffff&text=Mock+Camera+Photo"};
  }

  Future<Map<String, dynamic>> _mockScanner(BuildContext context) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 16),
            const Material(
              color: Colors.transparent,
              child: Text("Scanning QR Code...", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.greenAccent),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1200));
    if (context.mounted) Navigator.pop(context);
    
    return {"text": "mock_scanned_data_xyz987", "format": "QR_CODE"};
  }

  Future<Map<String, dynamic>> _mockFilePicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select a file", style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              title: const Text("document.pdf", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blueAccent),
              title: const Text("photo.jpg", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx),
            )
          ],
        ),
      ),
    );
    return {"name": "document.pdf", "size": 102400, "type": "application/pdf"};
  }

  Future<Map<String, dynamic>> _mockLocation(BuildContext context) async {
    _showToast("Fetching exact GPS coordinates...", context);
    await Future.delayed(const Duration(seconds: 1));
    return {"lat": 9.03, "lng": 38.74, "accuracy": 15.0};
  }

  Future<Map<String, dynamic>> _requestPayment(dynamic params, BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            const Text("Processing Payment", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Amount: ${(params["amountMinor"] / 100).toStringAsFixed(2)} ${params["currency"]}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 32),
            const LinearProgressIndicator(color: Color(0xFF10B981), backgroundColor: Color(0xFF0F172A)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.pop(context);

    return {"status": "success", "transactionId": "txn_${Random().nextInt(999999)}"};
  }
}
