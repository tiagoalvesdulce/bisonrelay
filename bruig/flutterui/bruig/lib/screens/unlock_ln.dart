import 'package:bruig/components/recent_log.dart';
import 'package:bruig/components/snackbars.dart';
import 'package:bruig/components/buttons.dart';
import 'package:bruig/config.dart';
import 'package:bruig/main.dart';
import 'package:bruig/models/log.dart';
import 'package:flutter/material.dart';
import 'package:golib_plugin/golib_plugin.dart';
import 'package:path/path.dart' as path;

class UnlockLNApp extends StatefulWidget {
  Config cfg;
  final String initialRoute;
  UnlockLNApp(this.cfg, this.initialRoute, {Key? key}) : super(key: key);

  void setCfg(Config c) {
    cfg = c;
  }

  @override
  State<UnlockLNApp> createState() => _UnlockLNAppState();
}

class _UnlockLNAppState extends State<UnlockLNApp> {
  Config get cfg => widget.cfg;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Connect to Bison Relay",
      initialRoute: widget.initialRoute,
      routes: {
        "/": (context) => _LNUnlockPage(widget.cfg, widget.setCfg),
        "/sync": (context) => _LNChainSyncPage(widget.cfg)
      },
      builder: (BuildContext context, Widget? child) => Scaffold(
        body: child,
      ),
    );
  }
}

class _LNUnlockPage extends StatefulWidget {
  final Config cfg;
  final Function(Config) setCfg;
  const _LNUnlockPage(this.cfg, this.setCfg, {Key? key}) : super(key: key);

  @override
  State<_LNUnlockPage> createState() => __LNUnlockPageState();
}

class __LNUnlockPageState extends State<_LNUnlockPage> {
  bool loading = false;
  final TextEditingController passCtrl = TextEditingController();

  Future<void> unlock() async {
    setState(() {
      loading = true;
    });
    try {
      var cfg = widget.cfg;
      var rpcHost = await Golib.lnRunDcrlnd(
          cfg.internalWalletDir, cfg.network, passCtrl.text);
      var tlsCert = path.join(cfg.internalWalletDir, "tls.cert");
      var macaroonPath = path.join(cfg.internalWalletDir, "data", "chain",
          "decred", cfg.network, "admin.macaroon");
      widget.setCfg(Config.newWithRPCHost(cfg, rpcHost, tlsCert, macaroonPath));
      Navigator.of(context).pushNamed("/sync");
    } catch (exception) {
      showErrorSnackbar(context, "Unable to unlock wallet: $exception");
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var backgroundColor = const Color(0xFF19172C);
    var cardColor = const Color(0xFF05031A);
    var textColor = const Color(0xFF8E8D98);
    var secondaryTextColor = const Color(0xFFE4E3E6);
    var darkTextColor = const Color(0xFF5A5968);
    return Container(
        color: backgroundColor,
        child: Stack(children: [
          Container(
              decoration: const BoxDecoration(
                  image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage("assets/images/loading-bg.png")))),
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                  cardColor,
                  const Color(0xFF07051C),
                  backgroundColor.withOpacity(0.34),
                ],
                    stops: const [
                  0,
                  0.17,
                  1
                ])),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              const SizedBox(height: 258),
              Text("Connect to Bison Relay",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w200)),
              const SizedBox(height: 34),
              Column(children: [
                SizedBox(
                    width: 377,
                    child: Text("Password",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            color: darkTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w300))),
                const SizedBox(height: 5),
                Center(
                    child: SizedBox(
                        width: 377,
                        child: TextField(
                            cursorColor: secondaryTextColor,
                            decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Password",
                                hintStyle:
                                    TextStyle(fontSize: 21, color: textColor),
                                filled: true,
                                fillColor: cardColor),
                            style: TextStyle(
                                color: secondaryTextColor, fontSize: 21),
                            controller: passCtrl,
                            obscureText: true))),
                const SizedBox(height: 34),
                Center(
                    child: SizedBox(
                        width: 283,
                        child: Row(children: [
                          const SizedBox(width: 35),
                          LoadingScreenButton(
                            onPressed: !loading ? unlock : null,
                            text: "Unlock Wallet",
                          ),
                          const SizedBox(width: 10),
                          loading
                              ? SizedBox(
                                  height: 25,
                                  width: 25,
                                  child: CircularProgressIndicator(
                                      value: null,
                                      backgroundColor: backgroundColor,
                                      color: textColor,
                                      strokeWidth: 2),
                                )
                              : const SizedBox(width: 25),
                        ])))
              ]),

/*
                ],
                    stops: const [
                  0,
                  0.17,
                  1
                ])),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              const SizedBox(height: 258),
              Text("Connect to Bison Relay",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w200)),
              const SizedBox(height: 55),
              Row(children: [
                const SizedBox(width: 323),
                Expanded(
                    child: TextField(
                        decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle:
                                TextStyle(fontSize: 21, color: textColor),
                            filled: true,
                            fillColor: cardColor),
                        style: TextStyle(color: textColor, fontSize: 21),
                        controller: passCtrl,
                        obscureText: true)),
                        ])
              
                  Center(
                      child: SizedBox(
                          width: 283,
                          child: Row(children: [
                            const SizedBox(width: 35),
                            LoadingScreenButton(
                              loading: loading,
                              onPressed: unlock,
                              text: "Unlock Wallet",
                            ),
                            const SizedBox(width: 10),
                            loading
                                ? SizedBox(
                                    height: 25,
                                    width: 25,
                                    child: CircularProgressIndicator(
                                        value: null,
                                        backgroundColor: backgroundColor,
                                        color: textColor,
                                        strokeWidth: 2),
                                  )
                                : const SizedBox(width: 25),
                          ])))
                          */
            ]),
          )
        ]));
  }
}

class _LNChainSyncPage extends StatefulWidget {
  final Config cfg;
  const _LNChainSyncPage(this.cfg, {Key? key}) : super(key: key);

  @override
  State<_LNChainSyncPage> createState() => _LNChainSyncPageState();
}

class _LNChainSyncPageState extends State<_LNChainSyncPage> {
  int blockHeight = 0;
  String blockHash = "";
  DateTime blockTimestamp = DateTime.fromMicrosecondsSinceEpoch(0);
  double currentTimeStamp = DateTime.now().millisecondsSinceEpoch / 1000;
  bool synced = false;
  static const startBlockTimestamp = 1454907600;
  static const fiveMinBlock = 300;
  double progress = 0;

  void readSyncProgress() async {
    var stream = Golib.lnInitChainSyncProgress();
    try {
      await for (var update in stream) {
        setState(() {
          blockHeight = update.blockHeight;
          blockHash = update.blockHash;
          blockTimestamp =
              DateTime.fromMillisecondsSinceEpoch(update.blockTimestamp * 1000);
          synced = update.synced;
          progress = update.blockHeight /
              ((currentTimeStamp - startBlockTimestamp) / fiveMinBlock);
        });
        if (update.synced) {
          syncCompleted();
        }
      }
    } catch (exception) {
      showErrorSnackbar(
          context, "Unable to read chain sync updates: $exception");
    }
  }

  @override
  void initState() {
    super.initState();
    readSyncProgress();

    // TODO: check if already synced.
  }

  void syncCompleted() async {
    runMainApp(widget.cfg);
  }

  @override
  Widget build(BuildContext context) {
    var backgroundColor = const Color(0xFF19172C);
    var cardColor = const Color(0xFF05031A);
    var textColor = const Color(0xFF8E8D98);
    var secondaryTextColor = const Color(0xFFE4E3E6);
    return Container(
        color: backgroundColor,
        child: Stack(children: [
          Container(
              decoration: const BoxDecoration(
                  image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage("assets/images/loading-bg.png")))),
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                  cardColor,
                  const Color(0xFF07051C),
                  backgroundColor.withOpacity(0.34),
                ],
                    stops: const [
                  0,
                  0.17,
                  1
                ])),
          ),
          Container(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                const SizedBox(height: 89),
                Text("Setting up Bison Relay",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w200)),
                const SizedBox(height: 89),
                Text("Network Sync",
                    style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 21,
                        fontWeight: FontWeight.w300)),
                const SizedBox(height: 50),
                Center(
                    child: SizedBox(
                        width: 740,
                        child: Row(children: [
                          const SizedBox(width: 65),
                          Expanded(
                              child: ClipRRect(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(5)),
                                  child: LinearProgressIndicator(
                                      minHeight: 8,
                                      value: progress > 1 ? 1 : progress,
                                      color: cardColor,
                                      backgroundColor: cardColor,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          textColor)))),
                          const SizedBox(width: 20),
                          Text(
                              "${((progress > 1 ? 1 : progress) * 100).toStringAsFixed(2)}%",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300))
                        ]))),
                const SizedBox(height: 21),
                Center(
                  child: Container(
                      margin: const EdgeInsets.all(0),
                      width: 610,
                      height: 251,
                      padding: const EdgeInsets.all(10),
                      color: cardColor,
                      child: Column(children: [
                        Row(children: [
                          Text("Block Height: ",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300)),
                          Text("$blockHeight",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300)),
                          const SizedBox(width: 21),
                          Text("Block Hash: ",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300)),
                          Text("$blockHeight",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300)),
                          const SizedBox(width: 21),
                          Text("Block Time: ",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300)),
                          Text(blockTimestamp.toString(),
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300))
                        ]),
                        Expanded(
                            child: LogLines(globalLogModel,
                                maxLines: 15, optionalTextColor: textColor))
                      ])),
                )
              ]))
        ]));
  }
}

Future<void> runUnlockDcrlnd(Config cfg) async {
  runApp(UnlockLNApp(cfg, "/"));
}

Future<void> runChainSyncDcrlnd(Config cfg) async {
  runApp(UnlockLNApp(cfg, "/sync"));
}
