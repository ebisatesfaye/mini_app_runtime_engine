library;


import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  String currentAppId = "default_miniapp";

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
          if (params != null && params["appId"] != null) {
            currentAppId = params["appId"];
          }
          result = {
            "instanceId": DateTime.now().millisecondsSinceEpoch.toString(),
            "capabilities": ["camera", "storage", "auth", "ui", "device", "location", "file_picker", "scanner", "payments"],
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${currentAppId}_${params["key"]}', params["value"]);
          result = true;
          break;

        case "storage.getItem":
          final prefs = await SharedPreferences.getInstance();
          result = prefs.getString('${currentAppId}_${params["key"]}');
          if (result == null) throw Exception("Item not found");
          break;
          
        case "storage.removeItem":
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('${currentAppId}_${params["key"]}');
          result = true;
          break;
          
        case "storage.clear":
          final prefs = await SharedPreferences.getInstance();
          final keys = prefs.getKeys().where((k) => k.startsWith('${currentAppId}_'));
          for (var k in keys) {
            await prefs.remove(k);
          }
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
          result = await _realCamera(context);
          break;

        case "device.location.getCurrentPosition":
          result = await _realLocation(context);
          break;

        case "device.location.watchPosition":
          _showToast("Started GPS Tracking (Simulated)", context);
          result = {"watchId": "watch_${Random().nextInt(1000)}"};
          break;

        case "device.location.clearWatch":
          _showToast("Stopped GPS Tracking (Simulated)", context);
          result = true;
          break;

        case "device.scanner.scan":
          result = await _realScanner(context);
          break;

        case "device.file.pick":
          result = await _realFilePicker(context);
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
        Permission? flutterPerm;
        final scope = p.toString();
        
        if (scope.contains("camera")) flutterPerm = Permission.camera;
        if (scope.contains("location")) flutterPerm = Permission.location;
        if (scope.contains("file") || scope.contains("storage")) flutterPerm = Permission.storage;
        if (scope.contains("bluetooth")) flutterPerm = Permission.bluetooth;
        if (scope.contains("microphone") || scope.contains("audio")) flutterPerm = Permission.microphone;
        if (scope.contains("contacts")) flutterPerm = Permission.contacts;
        if (scope.contains("calendar")) flutterPerm = Permission.calendar;
        if (scope.contains("sensors")) flutterPerm = Permission.sensors;

        if (flutterPerm != null) {
          final status = await flutterPerm.request();
          granted[scope] = status.isGranted ? "granted" : "denied";
        } else {
          bool allow = await _askUserPermission(scope, context);
          granted[scope] = allow ? "granted" : "denied";
        }
      }
    }
    return granted;
  }

  Future<bool> _askUserPermission(String scope, BuildContext context) async {
    if (!context.mounted) return false;
    
    String readableScope = scope;
    if (scope == "auth.token") readableScope = "Login Token";
    if (scope == "auth.profile") readableScope = "User Profile";
    if (scope == "payments.request") readableScope = "Make Payments";

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Permission Request", style: TextStyle(color: Colors.white)),
        content: Text("The Mini-App is requesting permission to access your $readableScope. Do you want to allow this?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Deny", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Allow"),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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

  Future<Map<String, dynamic>> _realCamera(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      return {"url": photo.path, "name": photo.name};
    }
    throw Exception("Camera cancelled");
  }

  Future<Map<String, dynamic>> _realScanner(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (result != null) {
      return result as Map<String, dynamic>;
    }
    throw Exception("Scanner cancelled");
  }

  Future<Map<String, dynamic>> _realFilePicker(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      return {"name": file.name, "size": file.size, "type": file.extension != null ? "application/${file.extension}" : "unknown", "path": file.path};
    }
    throw Exception("File picker cancelled");
  }

  Future<Map<String, dynamic>> _realLocation(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services are disabled.");
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception("Location permissions are denied.");
    }
    if (permission == LocationPermission.deniedForever) throw Exception("Location permissions are permanently denied.");

    Position position = await Geolocator.getCurrentPosition();
    return {"lat": position.latitude, "lng": position.longitude, "accuracy": position.accuracy};
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

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR/Barcode')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final barcode = barcodes.first;
            Navigator.pop(context, {"text": barcode.rawValue ?? "", "format": barcode.format.name});
          }
        },
      ),
    );
  }
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
