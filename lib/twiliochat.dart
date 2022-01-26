import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TwilioResponse {
  bool? isError;
  String? message;
}

class ChatChannel {
  ChatChannel(this.sid, this.uniqueName, this.friendlyName, this.members);

  String sid = "";
  String uniqueName = "";
  String friendlyName = "";
  List<String> members = [];

  static ChatChannel fromJson(dynamic json) {
    return ChatChannel(json['sid'], json['uniqueName'], json['friendlyName'],
        List<String>.from(json["members"]));
  }
}

class ChatMessage {
  ChatMessage(this.sid, this.channelSid, this.author, this.index, this.body,
      this.dateCreated);

  String sid = "";
  String channelSid = "";
  String author = "";
  int index = 0;
  String body = "";
  DateTime dateCreated;

  static ChatMessage fromJson(dynamic json) {
    return ChatMessage(json['sid'], json['channelSid'], json['author'],
        json['index'], json['body'], DateTime.parse(json['timestamp']));
  }
}

class ClientError {
  String errorMessage;
  String errorCode;

  ClientError(this.errorMessage, this.errorCode);

  static ClientError fromJson(dynamic json) {
    return ClientError(json['errorMessage'], json['errorCode']);
  }
}

enum SynchronizationStatus { started, channelsCompleted, completed, failed }
enum ChannelUpdateReason {
  status,
  lastConsumedMessageIndex,
  uniqueName,
  friendlyName,
  attributes,
  lastMessage,
  notificationLevel
}

typedef void SynchronizationStatusListener(SynchronizationStatus status);
typedef void ChannelAddedListener(ChatChannel channel);
typedef void ChannelUpdatedListener(
    String channelSid, ChannelUpdateReason reason);
typedef void ChannelDeletedListener(String channelSid);
typedef void ChannelOnMessageAddedListener(ChatMessage message);
typedef void InitializationErrorListener(ClientError error);

class Twiliochat {
  List<SynchronizationStatusListener>? _syncStatusListeners;
  List<ChannelAddedListener>? _channelAddedListeners;
  List<ChannelUpdatedListener>? _channelUpdatedListeners;
  List<ChannelDeletedListener>? _channelDeletedListeners;
  List<ChannelOnMessageAddedListener>? _channelOnMessageAddedListener;
  List<InitializationErrorListener>? _initializationErrorListener;
  String? _accessToken;

  Twiliochat(String accessToken) {
    _accessToken = accessToken;
    _syncStatusListeners = [];
    _channelAddedListeners = [];
    _channelUpdatedListeners = [];
    _channelDeletedListeners = [];
    _channelOnMessageAddedListener = [];
    _initializationErrorListener = [];
  }

  static const MethodChannel _channel = MethodChannel('twiliochat');

  init() {
    _channel.setMethodCallHandler(_handleMethod);
    _channel.invokeMethod(
        'initWithAccessToken', <String, dynamic>{"token": _accessToken});
  }

  Future<bool> sendMessageInChannel(ChatChannel channel, String message) async {
    var result = await _channel.invokeMethod('sendMessageInChannel',
        <String, dynamic>{"sid": channel.sid, "message": message});
    return result;
  }

  void addInitializationErrorListener(InitializationErrorListener listener) {
    if (_initializationErrorListener == null) return;
    _initializationErrorListener!.add(listener);
  }

  void addSyncStatusListener(SynchronizationStatusListener listener) {
    if (_syncStatusListeners == null) return;
    _syncStatusListeners!.add(listener);
  }

  void addChannelOnMessageAddedListeners(
      ChannelOnMessageAddedListener listener) {
    if (_channelOnMessageAddedListener == null) return;
    _channelOnMessageAddedListener!.add(listener);
  }

  void addChannelAddedListener(ChannelAddedListener listener) {
    if (_channelAddedListeners == null) return;
    _channelAddedListeners!.add(listener);
  }

  void addChannelUpdatedListener(ChannelUpdatedListener listener) {
    if (_channelUpdatedListeners == null) return;
    _channelUpdatedListeners!.add(listener);
  }

  void addChannelDeletedListener(ChannelDeletedListener listener) {
    if (_channelDeletedListeners == null) return;
    _channelDeletedListeners!.add(listener);
  }

  Future<List<ChatChannel>> getChannels() async {
    final List<dynamic> channels = await _channel.invokeMethod('getChannels');
    debugPrint('${channels.length.toString()} channels');
    return channels.map(ChatChannel.fromJson).toList();
  }

  Future<List<ChatMessage>> getChannelMessages(
    ChatChannel channel,
    int lastIndex,
  ) async {
    final List<dynamic> messages = await _channel.invokeMethod(
      'getChannelMessages',
      <String, dynamic>{
        "sid": channel.sid,
        "index": lastIndex,
      },
    );
    debugPrint(
        '${messages.length.toString()} messages in channel ${channel.sid}');
    return messages.map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage?> getChannelLastMessage(ChatChannel channel) async {
    final success = await _channel.invokeMethod(
      'getChannelLastMessage',
      <String, dynamic>{"sid": channel.sid},
    );
    if (success == null) {
      return null;
    }
    return ChatMessage.fromJson(success);
  }

  Future<void> createChannel(String friendlyName) async {
    await _channel.invokeMethod(
      'createChannel',
      <String, dynamic>{"friendlyName": friendlyName},
    );
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    debugPrint("_handleMethod " + call.method);

    switch (call.method) {
      case "onClientInitializationError":
        debugPrint("onClientInitializationError " + call.arguments.toString());
        for (var listener in _initializationErrorListener!) {
          listener(ClientError.fromJson(call.arguments));
        }
        break;
      case "onClientSynchronization":
        debugPrint("onClientSynchronization");
        for (var listener in _syncStatusListeners!) {
          listener(SynchronizationStatus.values[call.arguments]);
        }
        break;
      case "onChannelSynchronizationChange":
        debugPrint("onChannelSynchronizationChange");
        debugPrint(call.arguments);
        break;
      case "onChannelUpdated":
        for (var listener in _channelUpdatedListeners!) {
          listener(call.arguments["sid"],
              ChannelUpdateReason.values[call.arguments["reason"]]);
        }
        break;
      case "onChannelAdded":
        debugPrint("onChannelAdded");
        for (var listener in _channelAddedListeners!) {
          listener(ChatChannel.fromJson(call.arguments));
        }
        break;
      case "onChannelDeleted":
        for (var listener in _channelDeletedListeners!) {
          listener(call.arguments["sid"]);
        }
        break;
      case "channelOnMessageAdded":
        debugPrint("channelOnMessageAdded");
        for (var listener in _channelOnMessageAddedListener!) {
          listener(ChatMessage.fromJson(call.arguments));
        }
        break;
    }
  }
}
