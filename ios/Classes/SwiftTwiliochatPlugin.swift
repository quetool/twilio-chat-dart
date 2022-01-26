import Flutter
import UIKit
import TwilioChatClient

public class SwiftTwiliochatPlugin: NSObject, FlutterPlugin, TwilioChatClientDelegate {
    
    private var mChatClient: TwilioChatClient? = nil
    private var mChannels: [String: TCHChannel] = [String: TCHChannel]()
    private var methodChannel: FlutterMethodChannel? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "twiliochat", binaryMessenger: registrar.messenger())
        let instance = SwiftTwiliochatPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print(call.method)
        print(call.arguments ?? "No arguments")
        if call.method == "initWithAccessToken" {
            if let arguments: [String: Any] = call.arguments as? [String: Any] {
                if let token: String = arguments["token"] as? String {
                    self.initWithAccessToken(token, result: result)
                }
            }
        }
        
        if call.method=="getChannels" {
            self.getChannels(result)
        }
        
        if call.method == "sendMessageInChannel" {
            if let arguments: [String: Any] = call.arguments as? [String: Any] {
                if let sid: String = arguments["sid"] as? String {
                    if let message: String = arguments["message"] as? String {
                        self.sendMessageInChannel(sid, message: message, result: result)
                    }
                }
            }
        }
        
        if call.method == "getChannelMessages" {
            if let arguments: [String: Any] = call.arguments as? [String: Any] {
                if let sid: String = arguments["sid"] as? String {
                    if let lastIndex: UInt = arguments["index"] as? UInt {
                        self.getChannelMessages(sid, lastIndex: lastIndex, result: result)
                    }
                }
            }
        }
        
        if call.method == "getChannelLastMessage" {
            if let arguments: [String: Any] = call.arguments as? [String: Any] {
                if let sid: String = arguments["sid"] as? String {
                    self.getChannelLastMessage(sid, result: result)
                }
            }
        }
        
        if call.method == "createChannel" {
            if let arguments: [String: Any] = call.arguments as? [String: Any] {
                if let friendlyName: String = arguments["friendlyName"] as? String {
                    self.createChannel(friendlyName: friendlyName, channelType: TCHChannelType.public)
                }
            }
        }
        
    }
    
    private func initWithAccessToken(_ token: String, result: @escaping FlutterResult) {
        TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { (response, chatClient) in
            guard (response.isSuccessful()) else {
                if let error: TCHError = response.error {
                    //                    result(FlutterError(code: "error", message: error.localizedDescription, details: nil))
                    var object: [String: Any] = [String: String]()
                    object["errorMessage"] = error.localizedDescription
                    object["errorCode"] = String(error.code)
                    self.methodChannel?.invokeMethod("onClientInitializationError", arguments: object)
                } else {
                    //                    result(FlutterError(code: "00", message: "Error al iniciar con token", details: nil))
                    var object: [String: Any] = [String: String]()
                    object["errorMessage"] = "Error al iniciar con token"
                    object["errorCode"] = "00"
                    self.methodChannel?.invokeMethod("onClientInitializationError", arguments: object)
                }
                return
            }
            
            self.mChatClient = chatClient
            self.mChatClient?.delegate = self
        }
    }
    
    private func getChannels(_ result: FlutterResult) {
        
        if let channels: [TCHChannel] = self.mChatClient?.channelsList()?.subscribedChannelsSorted(by: TCHChannelSortingCriteria.lastMessage, order: TCHChannelSortingOrder.descending) {
            self.mChannels = [String: TCHChannel]()
            var array: [[String:Any]] = [[String:Any]]()
            print("CHANNELS")
            channels.forEach({ (channel) in
                if let channelSid: String = channel.sid {
                    self.mChannels[channelSid] = channel
                    var object: [String: Any] = [String: Any]()
                    object["sid"] = channelSid
                    object["uniqueName"] = channel.uniqueName
                    object["friendlyName"] = channel.friendlyName
                    var membersList: [String] = [String]()
                    if let members: TCHMembers = channel.members {
                        for m in members.membersList() {
                            membersList.append(m.identity ?? "");
                        }
                    }
                    object["members"] = membersList
                    array.append(object)
                }
            })
            result(array)
        }
        
    }
    
    private func sendMessageInChannel(_ channelSid: String, message: String, result: @escaping FlutterResult) {
        if let channel: TCHChannel = self.mChannels[channelSid] {
            let options: TCHMessageOptions = TCHMessageOptions().withBody(message)
            channel.messages?.sendMessage(with: options, completion: { (response, message) in
                if response.isSuccessful() {
                    result(true)
                } else {
                    if let error: TCHError = response.error {
                        result(FlutterError(code: String(error.code), message: error.localizedDescription, details: nil))
                    } else {
                        result(FlutterError(code: "00", message: "Error al enviar mensaje", details: nil))
                    }
                }
            })
        }
    }
    
    private func getChannelMessages(_ channelSid: String, lastIndex: UInt, result: @escaping FlutterResult) {
        if let channel: TCHChannel = self.mChannels[channelSid] {
            channel.messages?.getAfter(lastIndex, withCount: 300, completion: { (response, messages) in
                if response.isSuccessful() {
                    var array: [[String:Any]] = [[String:Any]]()
                    messages?.forEach({ (message) in
                        var object: [String: Any] = [String: Any]()
                        object["sid"] = message.sid
                        object["body"] = message.body
                        object["timestamp"] = message.dateCreatedAsDate?.timeIntervalSince1970 ?? 0
                        object["author"] = message.author
                        object["index"] = message.index
                        object["channelSid"] = channelSid
                        array.append(object)
                    })
                    result(array)
                } else {
                    if let error: TCHError = response.error {
                        result(FlutterError(code: String(error.code), message: error.localizedDescription, details: nil))
                    } else {
                        result(FlutterError(code: "00", message: "Error al obtener mensajes", details: nil))
                    }
                }
            })
        }
    }
    
    private func getChannelLastMessage(_ channelSid: String, result: @escaping FlutterResult) {
        if let channel: TCHChannel = self.mChannels[channelSid] {
            channel.messages?.getLastWithCount(1, completion: { (response, messages) in
                if response.isSuccessful() {
                    if (messages?.count ?? 0) > 0 {
                        var object: [String: Any] = [String: Any]()
                        object["sid"] = messages?.first?.sid ?? ""
                        object["body"] = messages?.first?.body ?? ""
                        object["timestamp"] = messages?.first?.dateCreatedAsDate?.timeIntervalSince1970 ?? 0
                        object["author"] = messages?.first?.author ?? ""
                        object["index"] = messages?.first?.index ?? ""
                        result(object)
                    } else {
                        result(nil)
                    }
                } else {
                    print("Error al obtener el último mensaje de " + (channel.friendlyName ?? "") + " " + (response.error?.description ?? ""))
                }
            })
        } else {
            print("NO CHANNEL")
        }
    }
    
    private func createChannel(friendlyName: String, channelType: TCHChannelType) {
        let options = [
            TCHChannelOptionFriendlyName: friendlyName,
            TCHChannelOptionType: channelType.rawValue
        ] as [String : Any]
        
        self.mChatClient?.channelsList()?.createChannel(options: options, completion: { channelResult, channel in
            if (channelResult.isSuccessful()) {
                print("Channel created.")
            } else {
                print("Channel NOT created.")
            }
        })
    }
    // MARK: Twilio Chat Delegate Functions for getChannels
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        var object: [String: Any] = [String: Any]()
        if let messageSid: String = message.sid {
            object["sid"] = messageSid
            object["channelSid"] = channel.sid ?? ""
            object["body"] = message.body ?? ""
            object["timestamp"] = message.dateCreatedAsDate?.timeIntervalSince1970 ?? 0
            object["author"] = message.author ?? ""
            object["index"] = message.index ?? ""
            self.methodChannel?.invokeMethod("channelOnMessageAdded", arguments: object)
        }
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, message: TCHMessage, updated: TCHMessageUpdate) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageDeleted message: TCHMessage) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, memberJoined member: TCHMember) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, member: TCHMember, updated: TCHMemberUpdate) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, memberLeft member: TCHMember) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, typingStartedOn channel: TCHChannel, member: TCHMember) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, typingEndedOn channel: TCHChannel, member: TCHMember) {
        
    }
    
    
    // MARK: Twilio Chat Delegate Functions for initWithAccessToken
    public func chatClient(_ client: TwilioChatClient, synchronizationStatusUpdated status: TCHClientSynchronizationStatus) {
        self.methodChannel?.invokeMethod("onClientSynchronization", arguments: status.rawValue)
    }
    
    public func chatClient(_ client: TwilioChatClient, channelAdded channel: TCHChannel) {
        var object: [String: Any] = [String: Any]()
        if let channelSid: String = channel.sid {
            object["sid"] = channelSid
            object["uniqueName"] = channel.uniqueName
            object["friendlyName"] = channel.friendlyName
            var membersList: [String] = [String]()
            if let members: TCHMembers = channel.members {
                for m in members.membersList() {
                    membersList.append(m.identity ?? "");
                }
            }
            object["members"] = membersList
            self.mChannels[channelSid] = channel
            self.methodChannel?.invokeMethod("onChannelAdded", arguments: object)
        }
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, updated: TCHChannelUpdate) {
        var object: [String: Any] = [String: Any]()
        if let channelSid: String = channel.sid {
            object["sid"] = channelSid
            object["reason"] = updated.rawValue
            self.mChannels[channelSid] = channel
            self.methodChannel?.invokeMethod("onChannelUpdated", arguments: object)
        }
    }
    
    public func chatClient(_ client: TwilioChatClient, channelDeleted channel: TCHChannel) {
        var object: [String: Any] = [String: Any]()
        if let channelSid: String = channel.sid {
            object["sid"] = channelSid
            self.mChannels[channelSid] = channel
            self.methodChannel?.invokeMethod("onChannelDeleted", arguments: object)
        }
    }
    
    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, synchronizationStatusUpdated status: TCHChannelSynchronizationStatus) {
        //        print("CHANNEL SYNC!!! " + (channel.friendlyName ?? "no name") + " " + "\(status.rawValue)")
        //        self.methodChannel?.invokeMethod("onChannelSynchronizationChange", arguments: channel)
    }
    
    public func chatClient(_ client: TwilioChatClient, errorReceived error: TCHError) {
        print("ERORORORRO " + error.localizedDescription)
    }
    
    public func chatClient(_ client: TwilioChatClient, user: TCHUser, updated: TCHUserUpdate) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, userSubscribed user: TCHUser) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, userUnsubscribed user: TCHUser) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, notificationNewMessageReceivedForChannelSid channelSid: String, messageIndex: UInt) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, notificationAddedToChannelWithSid channelSid: String) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, notificationInvitedToChannelWithSid channelSid: String) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, notificationRemovedFromChannelWithSid channelSid: String) {
        
    }
    
    public func chatClient(_ client: TwilioChatClient, connectionStateUpdated state: TCHClientConnectionState) {
        
    }
    
    public func chatClientTokenExpired(_ client: TwilioChatClient) {
        
    }
    
    public func chatClientTokenWillExpire(_ client: TwilioChatClient) {
        
    }
}
