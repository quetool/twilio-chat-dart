import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:twiliochat/twiliochat.dart';

void main() => runApp(MyApp());
// String tokenURL = "https://aqua-dog-3932.twil.io/chat-token" + "?device=asdasdq32ed12wqqwds" + "&identity=" + "FACUNDO";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Twiliochat chatClient;
  List<ChatChannel> _channels = List();
  Map<String, ChatMessage> _lastMessages = Map();
  bool isSyncing;

  @override
  void initState() {
    super.initState();
    this.isSyncing = false;
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    var response = await http.get("https://aqua-dog-3932.twil.io/chat-token?device=234567&identity=FACUNDO");
    Map valueMap = json.decode(response.body);
    chatClient = Twiliochat(valueMap["token"]); // Esto debería ir en un singleton!
    chatClient.addSyncStatusListener((SynchronizationStatus status) {
      print("chatClient status " + status.toString());
      switch (status) {
        case SynchronizationStatus.started:
          this.isSyncing = true;
          break;
        case SynchronizationStatus.channelsCompleted:
          break;
        case SynchronizationStatus.completed:
          this.isSyncing = false;
          break;
        default:
          this.isSyncing = false;
          break;
      }
      setState(() {});
      chatClient.getChannels().then((List<ChatChannel> channels) {
        setState(() {
          _channels = channels;
        });
        if (status == SynchronizationStatus.completed) {
          for (var channel in _channels) {
            chatClient.getChannelLastMessage(channel).then((msg) {
              _lastMessages[channel.sid] = msg;
              setState(() {});
            });
          }
        }
      });
    });
    chatClient.init();

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            child: ListView.builder(
              itemBuilder: (_, i) {
                return Column(
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      // color: Colors.red,
                      child: InkWell(
                        onTap: () {
                          chatClient.getChannelMessages(_channels[i], 0).then((messages) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConversationScreen(
                                  messages: messages,
                                ),
                              ),
                            );
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(
                                    "channelSid: ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(_channels[i].sid),
                                ],
                              ),
                              Row(
                                children: <Widget>[
                                  Text(
                                    "lastMessage: ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(_lastMessages[_channels[i].sid]?.body ?? ""),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 12.0,
                      color: Colors.black26,
                    ),
                  ],
                );
              },
              itemCount: _channels.length,
            ),
          ),
          (this.isSyncing)
              ? Container(
                  color: Colors.black12,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Container(width: 0.0, height: 0.0)
        ],
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    Key key,
    @required this.messages,
  });
  final List<ChatMessage> messages;

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<ChatMessage> messages;

  @override
  void initState() {
    super.initState();
    this.messages = widget.messages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Conversation"),
      ),
      body: Container(
        child: ListView.builder(
          itemBuilder: (BuildContext context, int index) {
            return Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  // color: Colors.red,
                  child: Container(
                    margin: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              "Author: ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(this.messages[index].author ?? ""),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            Text(
                              "Body: ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(this.messages[index].body ?? ""),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              "Date: ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(this.messages[index].dateCreated.toIso8601String()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 12.0,
                  color: Colors.black26,
                ),
              ],
            );
          },
          itemCount: this.messages.length,
        ),
      ),
    );
  }
}
