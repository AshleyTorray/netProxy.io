import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/network/util/host_filter.dart';

class RemoteModel {
  final bool connect;
  final String? host;
  final int? port;
  final String? os;
  final String? hostname;

  RemoteModel({
    required this.connect,
    this.host,
    this.port,
    this.os,
    this.hostname,
  });
}

class ConnectRemote extends StatefulWidget {
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> desktop;

  const ConnectRemote({super.key, required this.desktop, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return ConnectRemoteState();
  }
}

class ConnectRemoteState extends State<ConnectRemote> {
  bool syncConfig = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote connected', style: TextStyle(fontSize: 16))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('connected:${widget.desktop.value.hostname}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            OutlinedButton(
                child: const Text('Disconnect'),
                onPressed: () {
                  widget.desktop.value = RemoteModel(connect: false);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 10),
            OutlinedButton(
              child: const Text('Sync configuration'),
              onPressed: () {
                pullConfig();
              },
            ),
          ],
        ),
      ),
    );
  }

  //拉取桌面配置
  pullConfig() {
    var desktopModel = widget.desktop.value;
    HttpClients.get('http://${desktopModel.host}:${desktopModel.port}/config').then((response) {
      if (response.status.isSuccessful()) {
        var config = jsonDecode(response.bodyAsString);
        syncConfig = true;
        showDialog(
            context: context,
            builder: (context) {
              return ConfigSyncWidget(proxyServer: widget.proxyServer, config: config);
            });
      }
    }).onError((error, stackTrace) {
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pull configuration, please check network connection')));
    });
  }
}

class ConfigSyncWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final Map<String, dynamic> config;

  const ConfigSyncWidget({super.key, required this.proxyServer, required this.config});

  @override
  State<StatefulWidget> createState() {
    return ConfigSyncState();
  }
}

class ConfigSyncState extends State<ConfigSyncWidget> {
  bool syncWhiteList = true;
  bool syncBlackList = true;
  bool syncRewrite = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync configuration', style: TextStyle(fontSize: 16)),
      content: SizedBox(
          height: 230,
          child: Column(
            children: [
              SwitchListTile(
                  subtitle: const Text("Sync whitelist filtering"),
                  value: syncWhiteList,
                  onChanged: (val) {
                    setState(() {
                      syncWhiteList = val;
                    });
                  }),
              SwitchListTile(
                  subtitle: const Text("Sync blacklist filtering"),
                  value: syncBlackList,
                  onChanged: (val) {
                    setState(() {
                      syncBlackList = val;
                    });
                  }),
              SwitchListTile(
                  subtitle: const Text("Synchronous request rewrite"),
                  value: syncRewrite,
                  onChanged: (val) {
                    setState(() {
                      syncRewrite = val;
                    });
                  }),
            ],
          )),
      actions: [
        TextButton(
            child: const Text('cancel'),
            onPressed: () {
              Navigator.pop(context);
            }),
        TextButton(
            child: const Text('Start syncing'),
            onPressed: () {
              if (syncWhiteList) {
                HostFilter.whitelist.load(widget.config['whitelist']);
              }
              if (syncBlackList) {
                HostFilter.blacklist.load(widget.config['blacklist']);
              }
              if (syncRewrite) {
                widget.proxyServer.requestRewrites.load(widget.config['requestRewrites']);
                widget.proxyServer.flushRequestRewriteConfig();
              }
              widget.proxyServer.flushConfig();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synchronization successful')));
            }),
      ],
    );
  }
}
