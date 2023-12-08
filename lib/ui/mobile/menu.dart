import 'dart:io';

import 'package:easy_permission/easy_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/theme.dart';
import 'package:network_proxy/ui/mobile/connect_remote.dart';
import 'package:network_proxy/ui/mobile/setting/filter.dart';
import 'package:network_proxy/ui/mobile/setting/request_rewrite.dart';
import 'package:network_proxy/ui/mobile/setting/ssl.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:url_launcher/url_launcher.dart';

///左侧抽屉
class DrawerWidget extends StatelessWidget {
  final ProxyServer proxyServer;

  const DrawerWidget({Key? key, required this.proxyServer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
          child: const Text('option'),
        ),
        PortWidget(proxyServer: proxyServer),
        ListTile(
            title: const Text("HTTPS packet capture"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () => navigator(context, MobileSslWidget(proxyServer: proxyServer))),
        const ThemeSetting(),
        ListTile(
            title: const Text("Domain name whitelist"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () =>
                navigator(context, MobileFilterWidget(proxyServer: proxyServer, hostList: HostFilter.whitelist))),
        ListTile(
            title: const Text("Domain name blacklist"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () =>
                navigator(context, MobileFilterWidget(proxyServer: proxyServer, hostList: HostFilter.blacklist))),
        ListTile(
            title: const Text("Request a rewrite"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () => navigator(context, MobileRequestRewrite(proxyServer: proxyServer))),
        ListTile(
            title: const Text("Github"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              launchUrl(Uri.parse("https://github.com/wanghongenpin/network_proxy_flutter"),
                  mode: LaunchMode.externalApplication);
            }),
        ListTile(
            title: const Text("download link"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              launchUrl(Uri.parse("https://gitee.com/wanghongenpin/network-proxy-flutter/releases"),
                  mode: LaunchMode.externalApplication);
            })
      ],
    ));
  }

  ///跳转页面
  navigator(BuildContext context, Widget widget) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (BuildContext context) {
        return widget;
      }),
    );
  }
}

/// +号菜单
class MoreEnum extends StatelessWidget {
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> desktop;

  const MoreEnum({super.key, required this.proxyServer, required this.desktop});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      tooltip: "Scan code to connect",
      offset: const Offset(0, 30),
      child: const SizedBox(height: 38, width: 38, child: Icon(Icons.add_circle_outline, size: 26)),
      itemBuilder: (BuildContext context) {
        return <PopupMenuItem>[
          PopupMenuItem(
              padding: const EdgeInsets.only(left: 0),
              child: ListTile(
                  dense: true,
                  title: const Text("HTTPS packet capture"),
                  leading: Icon(Icons.https, color: proxyServer.enableSsl ? null : Colors.red),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (BuildContext context) {
                        return MobileSslWidget(proxyServer: proxyServer);
                      }),
                    );
                  })),
          PopupMenuItem(
              padding: const EdgeInsets.only(left: 0),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.qr_code_scanner_outlined),
                title: const Text("Connect terminal"),
                onTap: () {
                  connectRemote(context);
                },
              )),
          PopupMenuItem(
              padding: const EdgeInsets.only(left: 0),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.phone_iphone),
                title: const Text("My QR code"),
                onTap: () async {
                  var ip = await localIp();
                  if (context.mounted) {
                    connectQrCode(context, ip, proxyServer.port);
                  }
                },
              )),
        ];
      },
    );
  }

  ///扫码连接
  connectRemote(BuildContext context) async {
    String scanRes;
    if (Platform.isAndroid) {
      await EasyPermission.requestPermissions([PermissionType.CAMERA]);
      scanRes = await scanner.scan() ?? "-1";
    } else {
      scanRes = await FlutterBarcodeScanner.scanBarcode("#ff6666", "cancel", true, ScanMode.QR);
    }

    if (scanRes == "-1") return;
    if (scanRes.startsWith("http")) {
      launchUrl(Uri.parse(scanRes), mode: LaunchMode.externalApplication);
      return;
    }

    if (scanRes.startsWith("proxypin://connect")) {
      Uri uri = Uri.parse(scanRes);
      var host = uri.queryParameters['host'];
      var port = uri.queryParameters['port'];

      try {
        var response = await HttpClients.get("http://$host:$port/ping").timeout(const Duration(seconds: 1));
        if (response.bodyAsString == "pong") {
          desktop.value = RemoteModel(
              connect: true,
              host: host,
              port: int.parse(port!),
              os: response.headers.get("os"),
              hostname: response.headers.get("hostname"));

          if (context.mounted && Navigator.canPop(context)) {
            FlutterToastr.show("connection succeeded", context);
            Navigator.pop(context);
          }
        }
      } catch (e) {
        print(e);
        if (context.mounted) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return const AlertDialog(content: Text("Connection failed, please check if you are on the same LAN"));
              });
        }
      }
      return;
    }
    if (context.mounted) {
      FlutterToastr.show("Unrecognized QR code", context);
    }
  }

  ///连接二维码
  connectQrCode(BuildContext context, String host, int port) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.only(top: 5),
            actionsPadding: const EdgeInsets.only(bottom: 5),
            title: const Text("Remote connection, forwarding requests to other terminals", style: TextStyle(fontSize: 16)),
            content: SizedBox(
                height: 240,
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      backgroundColor: Colors.white,
                      data: "proxypin://connect?host=$host&port=${proxyServer.port}",
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 20),
                    const Text("Please use your mobile phone to scan the QR code"),
                  ],
                )),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("cancel")),
            ],
          );
        });
  }
}
