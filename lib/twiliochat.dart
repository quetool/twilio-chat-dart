import 'dart:async';
import 'package:flutter/services.dart';

class TwilioResponse {
  bool isError;
  String message;
}

class ChatChannel {
  ChatChannel(this.sid, this.uniqueName, this.friendlyName, this.members);

  String sid = "";
  String uniqueName = "";
  String friendlyName = "";
  List<String> members = List();

  static ChatChannel fromJson(dynamic json) {
    return ChatChannel(json['sid'], json['uniqueName'], json['friendlyName'], List<String>.from(json["members"]));
  }
}

class ChatMessage {
  ChatMessage(this.sid, this.channelSid, this.author, this.index, this.body, this.dateCreated);

  String sid = "";
  String channelSid = "";
  String author = "";
  int index = 0;
  String body = "";
  DateTime dateCreated;

  static ChatMessage fromJson(dynamic json) {
    return ChatMessage(json['sid'], json['channelSid'], json['author'], json['index'], json['body'],
        DateTime.parse(json['timestamp']));
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
typedef void ChannelUpdatedListener(String channelSid, ChannelUpdateReason reason);
typedef void ChannelDeletedListener(String channelSid);
typedef void ChannelOnMessageAddedListener(ChatMessage message);
typedef void InitializationErrorListener(ClientError error);

class Twiliochat {
  List<SynchronizationStatusListener> _syncStatusListeners;
  List<ChannelAddedListener> _channelAddedListeners;
  List<ChannelUpdatedListener> _channelUpdatedListeners;
  List<ChannelDeletedListener> _channelDeletedListeners;
  List<ChannelOnMessageAddedListener> _channelOnMessageAddedListener;
  List<InitializationErrorListener> _initializationErrorListener;
  String _accessToken;

  Twiliochat(this._accessToken) {
    this._syncStatusListeners = [];
    this._channelAddedListeners = [];
    this._channelUpdatedListeners = [];
    this._channelDeletedListeners = [];
    this._channelOnMessageAddedListener = [];
    this._initializationErrorListener = [];
  }

  static const MethodChannel _channel = const MethodChannel('twiliochat');

  init() {
    _channel.setMethodCallHandler(_handleMethod);
    _channel.invokeMethod('initWithAccessToken', <String, dynamic>{"token": _accessToken});
  }

  Future<bool> sendMessageInChannel(ChatChannel channel, String message) async {
    var result =
        await _channel.invokeMethod('sendMessageInChannel', <String, dynamic>{"sid": channel.sid, "message": message});
    return result;
  }

  void addInitializationErrorListener(InitializationErrorListener listener) {
    this._initializationErrorListener.add(listener);
  }

  void addSyncStatusListener(SynchronizationStatusListener listener) {
    this._syncStatusListeners.add(listener);
  }

  void addChannelOnMessageAddedListeners(ChannelOnMessageAddedListener listener) {
    this._channelOnMessageAddedListener.add(listener);
  }

  void addChannelAddedListener(ChannelAddedListener listener) {
    this._channelAddedListeners.add(listener);
  }

  void addChannelUpdatedListener(ChannelUpdatedListener listener) {
    this._channelUpdatedListeners.add(listener);
  }

  void addChannelDeletedListener(ChannelDeletedListener listener) {
    this._channelDeletedListeners.add(listener);
  }

  Future<List<ChatChannel>> getChannels() async {
    final List<dynamic> success = await _channel.invokeMethod('getChannels');
    return success.map(ChatChannel.fromJson).toList();
  }

  Future<List<ChatMessage>> getChannelMessages(ChatChannel channel, int lastIndex) async {
    final List<dynamic> success =
        await _channel.invokeMethod('getChannelMessages', <String, dynamic>{"sid": channel.sid, "index": lastIndex});
    // print(success[0]);
    // print(success.map(ChatMessage.fromJson).toList());
    return success.map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage> getChannelLastMessage(ChatChannel channel) async {
    final dynamic success = await _channel.invokeMethod('getChannelLastMessage', <String, dynamic>{"sid": channel.sid});
    if (success == null) {
      return null;
    }
    return ChatMessage.fromJson(success);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    print("_handleMethod " + call.method);

    switch (call.method) {
      case "onClientInitializationError":
        print("onClientInitializationError " + call.arguments.toString());
        this._initializationErrorListener.forEach((l) {
          l(ClientError.fromJson(call.arguments));
        });
        break;
      case "onClientSynchronization":
        print("onClientSynchronization");
        this._syncStatusListeners.forEach((l) {
          l(SynchronizationStatus.values[call.arguments]);
        });
        break;
      case "onChannelSynchronizationChange":
        print("onChannelSynchronizationChange");
        print(call.arguments);
        break;
      case "onChannelUpdated":
        this._channelUpdatedListeners.forEach((l) {
          l(call.arguments["sid"], ChannelUpdateReason.values[call.arguments["reason"]]);
        });
        break;
      case "onChannelAdded":
        print("onChannelAdded");
        this._channelAddedListeners.forEach((l) {
          l(ChatChannel.fromJson(call.arguments));
        });
        break;
      case "onChannelDeleted":
        this._channelDeletedListeners.forEach((l) {
          l(call.arguments["sid"]);
        });
        break;
      case "channelOnMessageAdded":
        print("channelOnMessageAdded");
        this._channelOnMessageAddedListener.forEach((l) {
          l(ChatMessage.fromJson(call.arguments));
        });
        break;
    }
  }
}
