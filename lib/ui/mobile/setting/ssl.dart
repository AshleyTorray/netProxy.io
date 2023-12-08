import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/crts.dart';
import 'package:url_launcher/url_launcher.dart';

class MobileSslWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final Function(bool val)? onEnableChange;

  const MobileSslWidget({super.key, required this.proxyServer, this.onEnableChange});

  @override
  State<MobileSslWidget> createState() => _MobileSslState();
}

class _MobileSslState extends State<MobileSslWidget> {
  bool changed = false;

  @override
  void dispose() {
    if (changed) {
      widget.proxyServer.flushConfig();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("HTTPS proxy"),
          centerTitle: true,
        ),
        body: ListView(children: [
          SwitchListTile(
              hoverColor: Colors.transparent,
              title: const Text("Enable HTTPS proxy", style: TextStyle(fontSize: 16)),
              value: widget.proxyServer.enableSsl,
              onChanged: (val) {
                widget.proxyServer.enableSsl = val;
                if (widget.onEnableChange != null) widget.onEnableChange!(val);
                changed = true;
                CertificateManager.cleanCache();
                setState(() {});
              }),
          ExpansionTile(
              title: const Text("Install root certificate"),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.only(left: 20),
              expandedAlignment: Alignment.topLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              shape: const Border(),
              children: [
                TextButton(onPressed: () => _downloadCert(), child: const Text("1. Click to download the root certificate")),
                ...(Platform.isIOS ? ios() : android()),
                const SizedBox(height: 20)
              ])
        ]));
  }

  List<Widget> ios() {
    return [
      TextButton(onPressed: () {}, child: const Text("2. Install root certificate -> trust certificate")),
      TextButton(onPressed: () {}, child: const Text("2.1 Install the root certificate Settings > Downloaded description file > Install")),
      Padding(
          padding: const EdgeInsets.only(left: 15),
          child:
              Image.network("https://foruda.gitee.com/images/1689346516243774963/c56bc546_1073801.png", height: 400)),
      TextButton(onPressed: () {}, child: const Text("2.2 Trust the root certificate Settings > General > About This Mac -> Certificate Trust Settings")),
      Padding(
          padding: const EdgeInsets.only(left: 15),
          child:
              Image.network("https://foruda.gitee.com/images/1689346614916658100/fd9b9e41_1073801.png", height: 270)),
    ];
  }

  List<Widget> android() {
    return [
      TextButton(onPressed: () {}, child: const Text("2. Open Settings -> Security -> Encryption & Credentials -> Install Certificate -> CA Certificate")),
      ClipRRect(
          child: Align(
              alignment: Alignment.topCenter,
              heightFactor: .7,
              child: Image.network(
                "https://foruda.gitee.com/images/1689352695624941051/74e3bed6_1073801.png",
                height: 680,
              )))
    ];
  }

  void _downloadCert() async {
    if (!widget.proxyServer.isRunning) {
      showDialog(
          context: context,
          builder: (context) {
            return const Text("Please start packet capture first");
          });
      return;
    }
    launchUrl(Uri.parse("http://127.0.0.1:${widget.proxyServer.port}/ssl"), mode: LaunchMode.externalApplication);
    CertificateManager.cleanCache();
  }
}
