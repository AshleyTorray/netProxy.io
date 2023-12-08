import 'package:flutter/material.dart';
import 'package:network_proxy/main.dart';


class ThemeSetting extends StatelessWidget {
  final bool dense;

  const ThemeSetting({Key? key, this.dense = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
        tooltip: themeNotifier.value.name,
        surfaceTintColor: Theme.of(context).colorScheme.onPrimary,
        offset: const Offset(150, 0),
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.cached), dense: true, title: Text("Follow the system")),
                onTap: () {
                  themeNotifier.value = ThemeMode.system;
                }),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.nightlight_outlined), dense: true, title: Text("Dark")),
                onTap: () {
                  themeNotifier.value = ThemeMode.dark;
                }),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.sunny), dense: true, title: Text("light color")),
                onTap: () {
                  themeNotifier.value = ThemeMode.light;
                }),
          ];
        },
        child: ListTile(
          title: const Text("theme"),
          trailing: const Icon(Icons.arrow_right),
          dense: dense,
        ));
  }
}
