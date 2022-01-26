import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:twiliochat/twiliochat.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Twiliochat? chatClient;
  List<ChatChannel> _channels = [];
  final Map<String, ChatMessage> _lastMessages = {};
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    isSyncing = false;
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    var response = await http.get(Uri.parse(
        'https://linen-stoat-3955.twil.io/chat-token?identity=quetool'));
    if (response.statusCode != 200) return;
    final valueMap = json.decode(response.body);
    chatClient = Twiliochat(valueMap["token"]);
    chatClient!.addSyncStatusListener((SynchronizationStatus status) {
      debugPrint("chatClient status " + status.toString());
      switch (status) {
        case SynchronizationStatus.started:
          isSyncing = true;
          break;
        case SynchronizationStatus.channelsCompleted:
          break;
        case SynchronizationStatus.completed:
          isSyncing = false;
          break;
        default:
          isSyncing = false;
          break;
      }
      setState(() {});
      chatClient!.getChannels().then((List<ChatChannel> channels) {
        setState(() {
          _channels = channels;
        });
        if (status == SynchronizationStatus.completed) {
          for (var channel in _channels) {
            chatClient!.getChannelLastMessage(channel).then((msg) {
              if (msg != null) {
                _lastMessages[channel.sid] = msg;
                setState(() {});
              }
            });
          }
        }
      }).catchError((error) {
        debugPrint('getChannels error $error');
      });
    });
    chatClient!.init();

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
          ListView.builder(
            itemBuilder: (_, i) {
              return Column(
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      onTap: () {
                        chatClient!
                            .getChannelMessages(_channels[i], 0)
                            .then((messages) {
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
                                const Text(
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
                                const Text(
                                  "lastMessage: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(_lastMessages[_channels[i].sid]?.body ??
                                    ""),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 12.0,
                    color: Colors.black26,
                  ),
                ],
              );
            },
            itemCount: _channels.length,
          ),
          (isSyncing)
              ? Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : const SizedBox(width: 0.0, height: 0.0)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          chatClient!.createChannel('test channel');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    Key? key,
    required this.messages,
  }) : super(key: key);
  final List<ChatMessage> messages;

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    messages = widget.messages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversation"),
      ),
      body: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          return Column(
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                // color: Colors.red,
                child: Container(
                  margin: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            "Author: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(messages[index].author),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          const Text(
                            "Body: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(messages[index].body),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          const Text(
                            "Date: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(messages[index].dateCreated.toIso8601String()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(
                height: 1,
                indent: 12.0,
                color: Colors.black26,
              ),
            ],
          );
        },
        itemCount: messages.length,
      ),
    );
  }
}
