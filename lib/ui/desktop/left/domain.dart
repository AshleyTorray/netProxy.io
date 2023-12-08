import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/component/transition.dart';
import 'package:network_proxy/ui/desktop/left/path.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/search.dart';

///Domain name on the left
class DomainWidget extends StatefulWidget {
  final NetworkTabController panel;
  final ProxyServer proxyServer;

  const DomainWidget({super.key, required this.panel, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return DomainWidgetState();
  }
}

class DomainWidgetState extends State<DomainWidget> {
  LinkedHashMap<HostAndPort, HeaderBody> containerMap = LinkedHashMap<HostAndPort, HeaderBody>();

  //Search text
  String? searchText;
  bool changing = false; //is there a refresh task?

  changeState() {
    if (!changing) {
      changing = true;
      Future.delayed(const Duration(milliseconds: 1500), () {
        setState(() {
          changing = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = containerMap.values;
    //Filter based on search text
    if (searchText?.trim().isNotEmpty == true) {
      list = searchFilter(searchText!);
    }

    return Scaffold(
        body: SingleChildScrollView(child: Column(children: list.toList())),
        bottomNavigationBar: Search(onSearch: (val) {
          if (val == searchText) {
            return;
          }
          setState(() {
            searchText = val.toLowerCase();
          });
        }));
  }

  ///Search filter
  List<HeaderBody> searchFilter(String text) {
    var result = <HeaderBody>[];
    containerMap.forEach((key, headerBody) {
      var body = headerBody.filter(text);
      if (body.isNotEmpty) {
        result.add(headerBody.copy(body: body, selected: true));
      }
    });
    return result;
  }

  ///add request
  add(Channel channel, HttpRequest request) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    //Classified by domain name
    HeaderBody? headerBody = containerMap[hostAndPort];
    var listURI = PathRow(request, widget.panel, proxyServer: widget.proxyServer);
    if (headerBody != null) {
      headerBody.addBody(channel.id, listURI);

      //Search status, refresh data
      if (searchText?.isNotEmpty == true) {
        changeState();
      }
      return;
    }

    headerBody = HeaderBody(hostAndPort, proxyServer: widget.proxyServer, onRemove: () => remove(hostAndPort));
    headerBody.addBody(channel.id, listURI);
    setState(() {
      containerMap[hostAndPort] = headerBody!;
    });
  }

  remove(HostAndPort hostAndPort) {
    setState(() {
      containerMap.remove(hostAndPort);
    });
  }

  ///add response
  addResponse(Channel channel, HttpResponse response) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    HeaderBody? headerBody = containerMap[hostAndPort];
    headerBody?.getBody(channel.id)?.add(response);
  }

  ///clear
  clean() {
    widget.panel.change(null, null);
    setState(() {
      containerMap.clear();
    });
  }
}

///Title and content layout The title is the domain name and the content is requested under the domain name
class HeaderBody extends StatefulWidget {
  //Mapping of request IDs and requests
  final Map<String, PathRow> channelIdPathMap = HashMap<String, PathRow>();

  final HostAndPort header;
  final ProxyServer proxyServer;

  //request list
  final Queue<PathRow> _body = Queue();

  //check or not
  final bool selected;

  //移除回调
  final Function()? onRemove;

  HeaderBody(this.header, {this.selected = false, this.onRemove, required this.proxyServer})
      : super(key: GlobalKey<_HeaderBodyState>());

  ///添加请求
  void addBody(String key, PathRow widget) {
    _body.addFirst(widget);
    channelIdPathMap[key] = widget;
    var state = super.key as GlobalKey<_HeaderBodyState>;
    state.currentState?.changeState();
  }

  PathRow? getBody(String key) {
    return channelIdPathMap[key];
  }

  ///根据文本过滤
  Iterable<PathRow> filter(String text) {
    return _body.where((element) => element.request.requestUrl.toLowerCase().contains(text));
  }

  ///复制
  HeaderBody copy({Iterable<PathRow>? body, bool? selected}) {
    var headerBody =
        HeaderBody(header, selected: selected ?? this.selected, onRemove: onRemove, proxyServer: proxyServer);
    if (body != null) {
      headerBody._body.addAll(body);
    }
    return headerBody;
  }

  @override
  State<StatefulWidget> createState() {
    return _HeaderBodyState();
  }
}

class _HeaderBodyState extends State<HeaderBody> {
  final GlobalKey<ColorTransitionState> transitionState = GlobalKey<ColorTransitionState>();

  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  changeState() {
    setState(() {});
    transitionState.currentState?.show();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _hostWidget(widget.header.domain),
      Offstage(offstage: !selected, child: Column(children: widget._body.toList()))
    ]);
  }

  Widget _hostWidget(String title) {
    var host = GestureDetector(
        onSecondaryLongPressDown: menu,
        child: ListTile(
            minLeadingWidth: 25,
            leading: Icon(selected ? Icons.arrow_drop_down : Icons.arrow_right, size: 16),
            dense: true,
            horizontalTitleGap: 0,
            visualDensity: const VisualDensity(vertical: -3.6),
            title: Text(title,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            onTap: () {
              setState(() {
                selected = !selected;
              });
            }));

    return ColorTransition(
        key: transitionState,
        duration: const Duration(milliseconds: 1800),
        begin: Theme.of(context).focusColor,
        startAnimation: false,
        child: host);
  }

  //域名右键菜单
  menu(LongPressDownDetails details) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: <PopupMenuEntry>[
        PopupMenuItem(
            height: 38,
            child: const Text("Add Blacklist", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.blacklist.add(widget.header.host);
              widget.proxyServer.flushConfig();
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("Add Whitelist", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.whitelist.add(widget.header.host);
              widget.proxyServer.flushConfig();
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("Delete whitelist", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.whitelist.remove(widget.header.host);
              widget.proxyServer.flushConfig();
            }),
        PopupMenuItem(height: 38, child: const Text("delete", style: TextStyle(fontSize: 14)), onTap: () => _delete()),
      ],
    );
  }

  _delete() {
    widget.channelIdPathMap.clear();
    widget._body.clear();
    widget.onRemove?.call();
  }
}
