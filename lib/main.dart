import 'dart:convert';
import 'dart:io';

import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/component/split_view.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/domain.dart';
import 'package:network_proxy/ui/desktop/left/request_editor.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';

void main(List<String> args) async {
  if (Platforms.isMobile()) {
    runApp(const FluentApp(MobileHomePage()));
    return;
  }

  //Muti window
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args[2].isEmpty ? const {} : jsonDecode(args[2]) as Map<String, dynamic>;
    runApp(FluentApp(multiWindow(windowId, argument)));
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  //windowSize options
  WindowOptions windowOptions = WindowOptions(
      minimumSize: const Size(980, 600),
      size: Platform.isMacOS ? const Size(1200, 750) : const Size(1080, 650),
      center: true,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const FluentApp(DesktopHomePage()));
}

///multi window
Widget multiWindow(int windowId, Map<dynamic, dynamic> argument) {
  if (argument['name'] == 'RequestEditor') {
    return RequestEditor(
        windowController: WindowController.fromWindowId(windowId),
        request: HttpRequest.fromJson(argument['request']),
        proxyPort: argument['proxyPort']);
  }

  if (argument['name'] == 'HttpBodyWidget') {
    return HttpBodyWidget(
        windowController: WindowController.fromWindowId(windowId),
        httpMessage: HttpMessage.fromJson(argument['httpMessage']),
        inNewWindow: true);
  }

  return const SizedBox();
}

/// valueNotifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class FluentApp extends StatelessWidget {
  final Widget home;

  const FluentApp(
    this.home, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var lightTheme = ThemeData.light(useMaterial3: true);
    var darkTheme = ThemeData.dark(useMaterial3: !Platforms.isDesktop());
    if (Platform.isWindows) {
      lightTheme = lightTheme.useSystemChineseFont(Brightness.light);
      darkTheme = darkTheme.useSystemChineseFont(Brightness.dark);
    }

    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'ProxyPin',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: currentMode,
            home: home,
          );
        });
  }
}

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePagePageState();
}

class _DesktopHomePagePageState extends State<DesktopHomePage> implements EventListener {
  final domainStateKey = GlobalKey<DomainWidgetState>();

  late ProxyServer proxyServer;
  late NetworkTabController panel;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    domainStateKey.currentState!.addResponse(channel, response);
  }

  @override
  void initState() {
    super.initState();
    proxyServer = ProxyServer(listener: this);
    panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 18), proxyServer: proxyServer);

    proxyServer.initializedListener(() {
      if (!proxyServer.guide) {
        return;
      }
      //first booting
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
                actions: [
                  TextButton(
                      onPressed: () {
                        proxyServer.guide = false;
                        proxyServer.flushConfig();
                        Navigator.pop(context);
                      },
                      child: const Text('closure'))
                ],
                title: const Text('hint', style: TextStyle(fontSize: 18)),
                content: const Text('It prompts that HTTPS packet capture will not be enabled by default. Please install the certificate before enabling HTTPS packet capture.\n'
                    'Click on the HTTPS packet capture (lock icon), choose to install the root certificate, and follow the prompts.'));
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final domainWidget = DomainWidget(key: domainStateKey, proxyServer: proxyServer, panel: panel);

    return Scaffold(
        appBar: Tab(
          child: Toolbar(proxyServer, domainStateKey),
        ),
        body: VerticalSplitView(ratio: 0.3, minRatio: 0.15, maxRatio: 0.9, left: domainWidget, right: panel));
  }
}
