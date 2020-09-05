package co.quetool.twiliochat;

import android.app.Activity;
import android.util.Log;

import com.twilio.chat.CallbackListener;
import com.twilio.chat.Channel;
import com.twilio.chat.ChannelListener;
import com.twilio.chat.Channels;
import com.twilio.chat.ChatClient;
import com.twilio.chat.ChatClientListener;
import com.twilio.chat.ErrorInfo;
import com.twilio.chat.Member;
import com.twilio.chat.Message;
import com.twilio.chat.Messages;
import com.twilio.chat.User;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * TwiliochatPlugin
 */
public class TwiliochatPlugin implements MethodCallHandler {
    private final Activity activity;

    private ChatClient mChatClient;
    private static Map<String, Channel> mChannels = new HashMap<>();
    private static MethodChannel methodChannel;

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        methodChannel = new MethodChannel(registrar.messenger(), "twiliochat");
        methodChannel.setMethodCallHandler(new TwiliochatPlugin(registrar.activity()));
    }

    private TwiliochatPlugin(Activity activity) {
        this.activity = activity;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {

        if (call.method.equals("initWithAccessToken")) {

            String token = call.argument("token");
            InitWithAccessToken(token, result);
        }

        if (call.method.equals("getChannels")) {
            GetChannels(result);
        }

        if (call.method.equals("sendMessageInChannel")) {
            SendMessageInChannel(call.argument("sid").toString(), call.argument("message").toString(), result);
        }


        if (call.method.equals("getChannelMessages")) {
            Log.d("TESTING", call.argument("index").toString());
            GetChannelMessages(call.argument("sid").toString(), Long.valueOf(call.argument("index").toString()), result);
        }

        if (call.method.equals("getChannelLastMessage")) {
            GetChannelLastMessage(call.argument("sid").toString(), result);
        }
    }

    private void SendMessageInChannel(String channelSid, String message, final Result result) {
        if (mChannels.get(channelSid) != null) {
            Message.Options options = Message.options().withBody(message);
            mChannels.get(channelSid).getMessages().sendMessage(options, new CallbackListener<Message>() {
                @Override
                public void onSuccess(Message message) {
                    result.success(true);
                }

                @Override
                public void onError(ErrorInfo errorInfo) {
                    super.onError(errorInfo);
                    result.error(String.valueOf(errorInfo.getCode()), errorInfo.getMessage(), errorInfo);
                }
            });
        }

    }

    private void GetChannelLastMessage(String channelSid, final Result result) {
        if (mChannels.get(channelSid) != null) {
            Messages channelMessages = mChannels.get(channelSid).getMessages();
            if (channelMessages != null) {
                channelMessages.getLastMessages(1, new CallbackListener<List<Message>>() {
                    @Override
                    public void onSuccess(List<Message> messages) {
                        if (messages.size() > 0) {
                            Map<String, Object> obj = new HashMap<>();
                            obj.put("sid", messages.get(0).getSid());
                            obj.put("body", messages.get(0).getMessageBody());
                            obj.put("timestamp", messages.get(0).getDateCreated());
                            obj.put("author", messages.get(0).getAuthor());
                            obj.put("index", messages.get(0).getMessageIndex());
                            result.success(obj);
                        } else {
                            result.success(null);
                        }
                    }
                });
            }
        }
    }

    private void GetChannelMessages(String channelSid, long lastIndex, final Result result) {
        Log.d("TESTTT", String.valueOf(lastIndex));
        if (mChannels.get(channelSid) != null) {
            mChannels.get(channelSid).getMessages().getMessagesAfter(lastIndex, 300, new CallbackListener<List<Message>>() {
                @Override
                public void onSuccess(List<Message> messages) {
                    final List<Map<String, Object>> msgs = new ArrayList<>();

                    for (Message msg :
                            messages) {
                        Map<String, Object> obj = new HashMap<>();
                        obj.put("sid", msg.getSid());
                        obj.put("body", msg.getMessageBody());
                        obj.put("timestamp", msg.getDateCreated());
                        obj.put("author", msg.getAuthor());
                        obj.put("index", msg.getMessageIndex());
                        obj.put("channelSid", msg.getChannelSid());
                        msgs.add(obj);
                    }
                    result.success(msgs);
                }

                @Override
                public void onError(ErrorInfo errorInfo) {
                    result.error(String.valueOf(errorInfo.getCode()), errorInfo.getMessage(), errorInfo);
                }
            });

        }
    }

    private void GetChannels(final Result result) {
        List<Channel> chans = mChatClient.getChannels().getSubscribedChannelsSortedBy(Channels.SortCriterion.LAST_MESSAGE, Channels.SortOrder.DESCENDING);
        final List<Map<String, Object>> array = new ArrayList<>();
        Log.e("Twilio Chat", "CHANNELS");

        for (int i = 0; i < chans.size(); i++) {
            if (mChannels.get(chans.get(i).getSid()) != null) {
                mChannels.get(chans.get(i).getSid()).removeAllListeners();
            }
            mChannels.put(chans.get(i).getSid(), chans.get(i));
            mChannels.get(chans.get(i).getSid()).addListener(new ChannelListener() {
                @Override
                public void onMessageAdded(Message message) {
                    Map<String, Object> obj = new HashMap<>();
                    obj.put("sid", message.getSid());
                    obj.put("channelSid", message.getChannelSid());
                    obj.put("body", message.getMessageBody());
                    obj.put("timestamp", message.getDateCreated());
                    obj.put("author", message.getAuthor());
                    obj.put("index", message.getMessageIndex());
                    methodChannel.invokeMethod("channelOnMessageAdded", obj);
                }

                @Override
                public void onMessageUpdated(Message message, Message.UpdateReason updateReason) {

                }

                @Override
                public void onMessageDeleted(Message message) {

                }

                @Override
                public void onMemberAdded(Member member) {

                }

                @Override
                public void onMemberUpdated(Member member, Member.UpdateReason updateReason) {

                }

                @Override
                public void onMemberDeleted(Member member) {

                }

                @Override
                public void onTypingStarted(Channel channel, Member member) {
                    Log.e("TYPING", channel.getSid());
                }

                @Override
                public void onTypingEnded(Channel channel, Member member) {
                    Log.e("TYPING ENDED", channel.getSid());
                }

                @Override
                public void onSynchronizationChanged(Channel channel) {

                }
            });


            Map<String, Object> json = new HashMap<>();
            json.put("sid", chans.get(i).getSid());
            json.put("uniqueName", chans.get(i).getUniqueName());
            json.put("friendlyName", chans.get(i).getFriendlyName());
            List<String> membersList = new ArrayList<>();

            if (chans.get(i).getMembers() != null) {

                for (Member m :
                        chans.get(i).getMembers().getMembersList()) {
                    membersList.add(m.getIdentity());

                }
            }

            json.put("members", membersList);
            array.add(json);
        }

        result.success(array);
    }

    private void InitWithAccessToken(String token, final Result result) {


        ChatClient.Properties.Builder builder = new ChatClient.Properties.Builder();
        ChatClient.Properties props = builder.createProperties();

        ChatClient.create(activity, token, props, new CallbackListener<ChatClient>() {
            @Override
            public void onSuccess(ChatClient chatClient) {
                Log.d("TwilioChat", "Success creating Twilio Chat Client");
                mChatClient = chatClient;

                mChatClient.setListener(new ChatClientListener() {
                    @Override
                    public void onChannelJoined(Channel channel) {

                    }

                    @Override
                    public void onChannelInvited(Channel channel) {

                    }

                    @Override
                    public void onChannelAdded(Channel channel) {
                        Map<String, Object> obj = new HashMap<>();
                        obj.put("sid", channel.getSid());
                        obj.put("uniqueName", channel.getUniqueName());
                        obj.put("friendlyName", channel.getFriendlyName());
                        List<String> membersList = new ArrayList<>();

                        if (channel.getMembers() != null) {

                            for (Member m : channel.getMembers().getMembersList()) {
                                membersList.add(m.getIdentity());

                            }
                        }
                        obj.put("members", membersList);
                        mChannels.put(channel.getSid(), channel);
                        methodChannel.invokeMethod("onChannelAdded", obj);
                    }

                    @Override
                    public void onChannelUpdated(Channel channel, Channel.UpdateReason updateReason) {
                        Map<String, Object> obj = new HashMap<>();
                        obj.put("sid", channel.getSid());
                        obj.put("reason", updateReason.getValue());
                        mChannels.put(channel.getSid(), channel);
                        methodChannel.invokeMethod("onChannelUpdated", obj);
                    }

                    @Override
                    public void onChannelDeleted(Channel channel) {
                        Map<String, Object> obj = new HashMap<>();
                        obj.put("sid", channel.getSid());
                        mChannels.put(channel.getSid(), channel);
                        methodChannel.invokeMethod("onChannelDeleted", obj);
                    }

                    @Override
                    public void onChannelSynchronizationChange(Channel channel) {
                        Log.e("ASASDASD", "CHANNEL SYNC!!!");
//                        methodChannel.invokeMethod("onChannelSynchronizationChange", channel);
                    }

                    @Override
                    public void onError(ErrorInfo errorInfo) {
                        Log.e("ERROR", "ERORORORRO" + errorInfo.getMessage());
                    }

                    @Override
                    public void onUserUpdated(User user, User.UpdateReason updateReason) {

                    }

                    @Override
                    public void onUserSubscribed(User user) {

                    }

                    @Override
                    public void onUserUnsubscribed(User user) {

                    }

                    @Override
                    public void onClientSynchronization(ChatClient.SynchronizationStatus synchronizationStatus) {
                        Log.e("ASASDASD", "CLIENT SYNC!!!");
                        methodChannel.invokeMethod("onClientSynchronization", synchronizationStatus.getValue());

                    }

                    @Override
                    public void onNewMessageNotification(String s, String s1, long l) {
                    }

                    @Override
                    public void onAddedToChannelNotification(String s) {

                    }

                    @Override
                    public void onInvitedToChannelNotification(String s) {

                    }

                    @Override
                    public void onRemovedFromChannelNotification(String s) {

                    }

                    @Override
                    public void onNotificationSubscribed() {

                    }

                    @Override
                    public void onNotificationFailed(ErrorInfo errorInfo) {

                    }

                    @Override
                    public void onConnectionStateChange(ChatClient.ConnectionState connectionState) {

                    }

                    @Override
                    public void onTokenExpired() {

                    }

                    @Override
                    public void onTokenAboutToExpire() {

                    }
                });


                result.success(true);
            }

            @Override
            public void onError(ErrorInfo errorInfo) {
                // result.error("error", errorInfo.getMessage(), errorInfo);
                Map<String, String> obj = new HashMap<>();
                obj.put("errorMessage", errorInfo.getMessage());
                obj.put("errorCode", String.valueOf(errorInfo.getCode()));
                methodChannel.invokeMethod("onClientInitializationError", obj);
            }
        });

    }


}
