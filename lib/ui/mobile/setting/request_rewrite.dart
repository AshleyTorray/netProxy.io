import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';

class MobileRequestRewrite extends StatefulWidget {
  final ProxyServer proxyServer;

  const MobileRequestRewrite({super.key, required this.proxyServer});

  @override
  State<MobileRequestRewrite> createState() => _MobileRequestRewriteState();
}

class _MobileRequestRewriteState extends State<MobileRequestRewrite> {
  late RequestRuleList requestRuleList;
  late ValueNotifier<bool> enableNotifier;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    requestRuleList = RequestRuleList(widget.proxyServer.requestRewrites);
    enableNotifier = ValueNotifier(widget.proxyServer.requestRewrites.enabled);
  }

  @override
  void dispose() {
    if (changed || enableNotifier.value != widget.proxyServer.requestRewrites.enabled) {
      widget.proxyServer.requestRewrites.enabled = enableNotifier.value;
      widget.proxyServer.flushRequestRewriteConfig();
    }

    enableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Request a rewrite")),
        body: Container(
            padding: const EdgeInsets.all(10),
            child: ListView(
              children: [
                SizedBox(
                    child: ValueListenableBuilder(
                        valueListenable: enableNotifier,
                        builder: (_, bool v, __) {
                          return SwitchListTile(
                              contentPadding: const EdgeInsets.only(left: 2),
                              title: const Text('Whether to enable request rewriting'),
                              value: enableNotifier.value,
                              onChanged: (value) {
                                enableNotifier.value = value;
                              });
                        })),
                const SizedBox(height: 10),
                Row(children: [
                  FilledButton.icon(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        add();
                      },
                      label: const Text("add")),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                      onPressed: () {
                        var selectedIndex = requestRuleList.currentSelectedIndex();
                        add(selectedIndex);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("edit")),
                  TextButton.icon(
                      icon: const Icon(Icons.remove),
                      label: const Text("delete"),
                      onPressed: () {
                        var removeSelected = requestRuleList.removeSelected();
                        if (removeSelected.isEmpty) {
                          return;
                        }

                        changed = true;
                        setState(() {
                          widget.proxyServer.requestRewrites.removeIndex(removeSelected);
                          requestRuleList.changeState();
                        });
                      })
                ]),
                const SizedBox(height: 10),
                requestRuleList,
              ],
            )));
  }

  void add([int currentIndex = -1]) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return RuleAddDialog(
              requestRewrites: widget.proxyServer.requestRewrites,
              currentIndex: currentIndex,
              onChange: () {
                changed = true;
                requestRuleList.changeState();
              });
        });
  }
}

///请求重写规则添加对话框
class RuleAddDialog extends StatelessWidget {
  final RequestRewrites requestRewrites;
  final int currentIndex;
  final Function onChange;

  const RuleAddDialog({super.key, required this.currentIndex, required this.onChange, required this.requestRewrites});

  @override
  Widget build(BuildContext context) {
    GlobalKey formKey = GlobalKey<FormState>();
    RequestRewriteRule? rule;
    if (currentIndex >= 0) {
      rule = requestRewrites.rules[currentIndex];
    }

    ValueNotifier<bool> enableNotifier = ValueNotifier(rule == null || rule.enabled);
    String? url = rule?.url;
    String? requestBody = rule?.requestBody;
    String? responseBody = rule?.responseBody;

    return AlertDialog(
        title: const Text("Add request rewrite rules", style: TextStyle(fontSize: 16)),
        scrollable: true,
        content: Form(
            key: formKey,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ValueListenableBuilder(
                      valueListenable: enableNotifier,
                      builder: (_, bool enable, __) {
                        return SwitchListTile(
                            contentPadding: const EdgeInsets.only(left: 0),
                            title: const Text('Whether to enable', textAlign: TextAlign.start),
                            value: enable,
                            onChanged: (value) {
                              enableNotifier.value = value;
                            });
                      }),
                  TextFormField(
                      decoration: const InputDecoration(labelText: 'URL', hintText: '/api/v1/*'),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'URL cannot be empty';
                        }
                        return null;
                      },
                      initialValue: url,
                      onSaved: (val) => url = val),
                  TextFormField(
                      initialValue: requestBody,
                      decoration: const InputDecoration(labelText: 'Replace the request body with:'),
                      onSaved: (val) => requestBody = val),
                  TextFormField(
                      initialValue: responseBody,
                      minLines: 3,
                      maxLines: 15,
                      decoration: const InputDecoration(labelText: 'The response body is replaced with:', hintText: '{"code":"200","data":{}}'),
                      onSaved: (val) => responseBody = val)
                ])),
        actions: [
          FilledButton(
              child: const Text("save"),
              onPressed: () {
                if ((formKey.currentState as FormState).validate()) {
                  (formKey.currentState as FormState).save();

                  if (currentIndex >= 0) {
                    requestRewrites.rules[currentIndex] = RequestRewriteRule(enableNotifier.value, url!,
                        requestBody: requestBody, responseBody: responseBody);
                  } else {
                    requestRewrites.addRule(RequestRewriteRule(enableNotifier.value, url!,
                        requestBody: requestBody, responseBody: responseBody));
                  }

                  enableNotifier.dispose();
                  onChange.call();
                  Navigator.of(context).pop();
                }
              }),
          ElevatedButton(
              child: const Text("close"),
              onPressed: () {
                Navigator.of(context).pop();
              })
        ]);
  }
}

class RequestRuleList extends StatefulWidget {
  final RequestRewrites requestRewrites;

  RequestRuleList(this.requestRewrites) : super(key: GlobalKey<_RequestRuleListState>());

  @override
  State<RequestRuleList> createState() => _RequestRuleListState();

  List<int> removeSelected() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    List<int> list = [];
    state?.selected.forEach((key, value) {
      if (value == true) {
        list.add(key);
      }
    });
    state?.selected.clear();
    return list;
  }

  int currentSelectedIndex() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    return state?.currentSelectedIndex ?? -1;
  }

  changeState() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    state?.changeState();
  }
}

class _RequestRuleListState extends State<RequestRuleList> {
  final Map<int, bool> selected = {};
  int currentSelectedIndex = -1;

  changeState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMaxHeight: 100,
              border: TableBorder.symmetric(outside: BorderSide(width: 1, color: Theme.of(context).highlightColor)),
              columns: const <DataColumn>[
                DataColumn(label: Text('enable')),
                DataColumn(label: Text('URL')),
                DataColumn(label: Text('Request body')),
                DataColumn(label: Text('response body')),
              ],
              rows: List.generate(
                  widget.requestRewrites.rules.length,
                  (index) => DataRow(
                          cells: [
                            DataCell(Text(widget.requestRewrites.rules[index].enabled ? "yes" : "no")),
                            DataCell(ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 60),
                                child: Text(widget.requestRewrites.rules[index].url))),
                            DataCell(SelectableText.rich(
                                TextSpan(text: widget.requestRewrites.rules[index].requestBody),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              padding: const EdgeInsetsDirectional.all(10),
                              child: SelectableText.rich(
                                  TextSpan(text: widget.requestRewrites.rules[index].responseBody),
                                  style: const TextStyle(fontSize: 12)),
                            ))
                          ],
                          selected: selected[index] == true,
                          onSelectChanged: (value) {
                            setState(() {
                              selected[index] = value!;
                              currentSelectedIndex = index;
                            });
                          })),
            )));
  }
}
