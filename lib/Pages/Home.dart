import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/Components/ChannelJoinModal.dart';
import '/Components/HomeDrawer.dart';
import '/Components/HomeTab.dart';
import '/Components/Notification.dart';
import '/MVP/Presenters/AccountPresenter.dart';
import '/MVP/Presenters/NotificationPresenter.dart';
import '/StreamOverlay/StreamOverlayBloc.dart';
import '/StreamOverlay/StreamOverlayState.dart';
import '/Views/Chat.dart';
import 'package:flutter_chatsen_irc/Twitch.dart' as twitch;
import 'package:hive/hive.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Our [HomePage]. This will contain access to everything: from Settings via a drawer, access to the different chat channels to everything else related to our application.
class HomePage extends StatefulWidget {
  const HomePage({
    Key key,
    // @required this.client,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> implements twitch.Listener {
  twitch.Client client;
  TextEditingController textEditingController;

  Future<void> loadChannelHistory() async {
    var channels = await Hive.openBox('Channels');
    await client.joinChannels(List<String>.from(channels.values));
    setState(() {});
  }

  @override
  void initState() {
    client = twitch.Client();

    AccountPresenter.findCurrentAccount().then(
      (account) async {
        print(account.login);
        await client.swapCredentials(
          twitch.Credentials(
            clientId: account.clientId,
            id: account.id,
            login: account.login,
            token: account.token,
          ),
        );
      },
    );

    loadChannelHistory();

    textEditingController = TextEditingController();
    client.listeners.add(this);
    super.initState();
  }

  @override
  void dispose() {
    textEditingController?.dispose();
    client.listeners.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: client.channels.length,
        child: BlocBuilder<StreamOverlayBloc, StreamOverlayState>(
          builder: (context, state) {
            var horizontal = MediaQuery.of(context).size.aspectRatio > 1.0;
            // var videoPlayer = Container(color: Theme.of(context).primaryColor);
            var videoPlayer = state is StreamOverlayOpened
                ? WebView(
                    initialUrl: 'https://player.twitch.tv/?channel=${state.channelName}&enableExtensions=true&muted=false&parent=pornhub.com',
                    javascriptMode: JavascriptMode.unrestricted,
                    allowsInlineMediaPlayback: true,
                  )
                : null;

            var scaffold = Scaffold(
              extendBody: true,
              extendBodyBehindAppBar: true,
              drawer: Builder(
                builder: (context) {
                  var currentChannel = client.channels.isNotEmpty ? client.channels[DefaultTabController.of(context).index] : null;
                  return HomeDrawer(
                    client: client,
                    channel: currentChannel,
                  );
                },
              ),
              bottomNavigationBar: Builder(
                builder: (context) => SafeArea(
                  child: Container(
                    height: 32.0,
                    child: Material(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) => InkWell(
                              child: Container(
                                child: Icon(Icons.menu),
                                height: 32.0,
                                width: 32.0,
                              ),
                              onTap: () async => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: TabBar(
                                labelPadding: EdgeInsets.only(left: 8.0),
                                isScrollable: true,
                                tabs: client.channels
                                    .map(
                                      (channel) => HomeTab(
                                        client: client,
                                        channel: channel,
                                        refresh: () => setState(() {}),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          Tooltip(
                            message: 'Add/Join a channel',
                            child: InkWell(
                              child: Container(
                                child: Icon(Icons.add),
                                height: 32.0,
                                width: 32.0,
                              ),
                              onTap: () async {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => SafeArea(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                      child: ChannelJoinModal(
                                        client: client,
                                        refresh: () => setState(() {}),
                                      ),
                                    ),
                                  ),
                                  // backgroundColor: Colors.transparent,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              body: Builder(
                builder: (context) => TabBarView(
                  children: [
                    for (var channel in client.channels)
                      ChatView(
                        client: client,
                        channel: channel,
                      ),
                  ],
                ),
              ),
            );

            return state is StreamOverlayClosed
                ? scaffold
                : (horizontal
                    ? Row(
                        children: [
                          Expanded(
                            child: SafeArea(child: videoPlayer),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(0.0),
                            child: SizedBox(
                              width: 340.0,
                              child: scaffold,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          SafeArea(
                            child: AspectRatio(
                              aspectRatio: 16.0 / 9.0,
                              child: videoPlayer,
                            ),
                          ),
                          Expanded(
                            child: scaffold,
                          ),
                        ],
                      ));
          },
        ),
      );

  @override
  void onChannelStateChange(twitch.Channel channel, twitch.ChannelState state) {}

  @override
  void onConnectionStateChange(twitch.Connection connection, twitch.ConnectionState state) {}

  @override
  void onMessage(twitch.Channel channel, twitch.Message message) {
    if (NotificationPresenter.cache.mentionNotification && message.mention) {
      NotificationWrapper.of(context).sendNotification(
        payload: message.body,
        title: message.user.login,
        subtitle: message.body,
      );
    }
  }

  @override
  void onHistoryLoaded(twitch.Channel channel) {}

  @override
  void onWhisper(twitch.Channel channel, twitch.Message message) {
    if (NotificationPresenter.cache.whisperNotification && message.user.id != channel.receiver.credentials.id) {
      NotificationWrapper.of(context).sendNotification(
        payload: message.body,
        title: message.user.login,
        subtitle: message.body,
      );
    }
  }
}