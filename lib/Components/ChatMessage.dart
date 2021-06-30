import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatsen/Badges/ChatsenBadges.dart';
import 'package:chatsen/Badges/ChatterinoBadges.dart';
import 'package:chatsen/Badges/FFZAPBadges.dart';
import 'package:chatsen/Badges/FFZBadges.dart';
import 'package:chatsen/Badges/SevenTVBadges.dart';
import 'package:chatsen/Components/WidgetTooltip.dart';
import 'package:chatsen/Settings/Settings.dart';
import 'package:chatsen/Settings/SettingsState.dart';
import 'package:chatsen_resources/user.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chatsen_irc/Twitch.dart' as twitch;
import 'package:octo_image/octo_image.dart';
import '/Pages/Search.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'dart:async';

/// [ChatMessage] is a Widget that takes a [twitch.Message] and renders into something readable and interactable.
class ChatMessage extends StatelessWidget {
  final String? prefixText;
  final twitch.Message message;
  final Color? backgroundColor;

  const ChatMessage({
    Key? key,
    this.prefixText,
    required this.message,
    this.backgroundColor,
  }) : super(key: key);

  Color getUserColor(BuildContext context, Color color) {
    switch (Theme.of(context).brightness) {
      case Brightness.dark:
        final hsl = HSLColor.fromColor(Color(color.value == 0xFF000000 ? 0xFF010101 : color.value));
        return hsl.withLightness(hsl.lightness.clamp(0.6, 1.0)).toColor();
      case Brightness.light:
        final hsl = HSLColor.fromColor(Color(color.value == 0xFF000000 ? 0xFF010101 : color.value));
        return hsl.withLightness(hsl.lightness.clamp(0.0, 0.4)).toColor();
    }
  }

  Future<ui.Image> imageFromUrl(String url) {
    var completer = Completer<ui.Image>();
    NetworkImage(url).resolve(ImageConfiguration()).addListener(ImageStreamListener((image, synchronousCall) {
      completer.complete(image.image);
    }));
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    var color = getUserColor(context, Color(int.tryParse(message.user!.color ?? '777777', radix: 16) ?? 0x777777).withAlpha(255));
    var spans = <InlineSpan>[];

    for (var token in message.tokens) {
      switch (token.type) {
        case twitch.MessageTokenType.Text:
          spans.add(
            TextSpan(
              text: '${token.data} ',
              style: TextStyle(color: message.action ? color : null),
            ),
          );
          break;
        case twitch.MessageTokenType.Link:
          spans.add(
            TextSpan(
              children: [
                TextSpan(
                  text: '${token.data}',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () async => launch(token.data),
                ),
                TextSpan(text: ' '),
              ],
            ),
          );
          break;
        case twitch.MessageTokenType.Image:
          if (!(BlocProvider.of<Settings>(context).state as SettingsLoaded).messageImagePreview) {
            spans.add(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${token.data}',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () async => launch(token.data),
                  ),
                  TextSpan(text: ' '),
                ],
              ),
            );
            break;
          }

          spans.add(
            TextSpan(
              children: [
                TextSpan(text: '\n'),
                WidgetSpan(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: InkWell(
                      onTap: () async => launch(token.data),
                      // child: Image.network('${token.data}'),
                      child: OctoImage(
                        image: CachedNetworkImageProvider(token.data),
                        filterQuality: FilterQuality.high,
                        // height: 96.0,
                        // errorBuilder: OctoError.icon(color: Colors.red),
                      ),
                    ),
                  ),
                ),
                TextSpan(text: '\n'),
              ],
            ),
          );
          break;
        case twitch.MessageTokenType.Video:
          break;
        case twitch.MessageTokenType.Emote:
          spans.add(
            WidgetSpan(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WidgetTooltip(
                    message: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            // child: Image.network(
                            //   (token.data as twitch.Emote).mipmap!.last!,
                            //   isAntiAlias: true,
                            //   filterQuality: FilterQuality.high,
                            //   height: 96.0,
                            //   fit: BoxFit.fitHeight,
                            // ),
                            child: OctoImage(
                              image: CachedNetworkImageProvider((token.data as twitch.Emote).mipmap!.last!),
                              filterQuality: FilterQuality.high,
                              height: 96.0,
                              errorBuilder: OctoError.icon(color: Colors.red),
                              fit: BoxFit.fitHeight,
                            ),
                          ),
                          Text((token.data as twitch.Emote).name!),
                          Text((token.data as twitch.Emote).provider!),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      // child: Image.network(
                      //   token.data.provider == 'Twitch' ? token.data.mipmap[1] : token.data.mipmap.last,
                      //   filterQuality: FilterQuality.high,
                      //   isAntiAlias: true,
                      //   scale: token.data.provider == 'Twitch' ? 2.0 : (token.data.mipmap.length == 1 ? 1.0 : 4.0),
                      // ),
                      // child: Image(
                      //   image: CachedNetworkImageProvider(
                      //     token.data.provider == 'Twitch' ? token.data.mipmap[1] : token.data.mipmap.last,
                      //     scale: token.data.provider == 'Twitch' ? 2.0 : (token.data.mipmap.length == 1 ? 1.0 : 4.0),
                      //   ),
                      //   filterQuality: FilterQuality.high,
                      //   isAntiAlias: true,
                      // ),
                      child: OctoImage(
                        image: CachedNetworkImageProvider(
                          token.data.provider == 'Twitch' ? token.data.mipmap[1] : token.data.mipmap.last,
                          scale: token.data.provider == 'Twitch' ? 2.0 : (token.data.mipmap.length == 1 ? 1.0 : 4.0),
                        ),
                        filterQuality: FilterQuality.high,
                        errorBuilder: OctoError.icon(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
        case twitch.MessageTokenType.EmoteStack:
          spans.add(
            WidgetSpan(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var emote in token.data)
                    WidgetTooltip(
                      message: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              // child: Image.network(
                              //   (token.data as List<twitch.Emote>).first.mipmap!.last!,
                              //   isAntiAlias: true,
                              //   filterQuality: FilterQuality.high,
                              //   height: 96.0,
                              //   fit: BoxFit.fitHeight,
                              // ),
                              child: OctoImage(
                                image: CachedNetworkImageProvider((token.data as List<twitch.Emote>).first.mipmap!.last!),
                                filterQuality: FilterQuality.high,
                                height: 96.0,
                                errorBuilder: OctoError.icon(color: Colors.red),
                                fit: BoxFit.fitHeight,
                              ),
                            ),
                            Text((token.data as List<twitch.Emote>).first.name!),
                            Text((token.data as List<twitch.Emote>).first.provider!),
                            for (var emote in (token.data as List<twitch.Emote>).sublist(1))
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      // child: Image.network(emote.mipmap!.first!),
                                      child: OctoImage(
                                        image: CachedNetworkImageProvider(emote.mipmap!.first!),
                                        filterQuality: FilterQuality.high,
                                        errorBuilder: OctoError.icon(color: Colors.red),
                                      ),
                                    ),
                                    Text(emote.name!),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        // child: Image.network(
                        //   emote.provider == 'Twitch' ? emote.mipmap[1] : emote.mipmap.last,
                        //   filterQuality: FilterQuality.high,
                        //   isAntiAlias: true,
                        //   scale: emote.provider == 'Twitch' ? 2.0 : 4.0,
                        // ),
                        child: OctoImage(
                          image: CachedNetworkImageProvider(
                            emote.provider == 'Twitch' ? emote.mipmap[1] : emote.mipmap.last,
                            scale: emote.provider == 'Twitch' ? 2.0 : 4.0,
                          ),
                          filterQuality: FilterQuality.high,
                          errorBuilder: OctoError.icon(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
          break;
        case twitch.MessageTokenType.User:
          break;
      }
    }

    return Container(
      color: message.mention ? Theme.of(context).colorScheme.primary.withAlpha(48) : backgroundColor,
      child: InkWell(
        onLongPress: () async => await Clipboard.setData(ClipboardData(text: message.body)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                    if (prefixText != null)
                      TextSpan(
                        text: '$prefixText ',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    if ((BlocProvider.of<Settings>(context).state as SettingsLoaded).messageTimestamp)
                      TextSpan(
                        text: '${message.dateTime!.hour.toString().padLeft(2, '0')}:${message.dateTime!.minute.toString().padLeft(2, '0')} ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    // if (first != null)
                    //   for (var badge in first.badges)
                    //     WidgetSpan(
                    //       child: Padding(
                    //         padding: const EdgeInsets.only(right: 4.0),
                    //         child: Image.network(
                    //           data!.badges.firstWhere((element) => element.name == badge.badgeName).image,
                    //           filterQuality: FilterQuality.high,
                    //           isAntiAlias: true,
                    //           // scale: 4.0,
                    //           height: 18.0,
                    //         ),
                    //       ),
                    //     ),
                    for (var badge in message.badges + BlocProvider.of<FFZBadges>(context).getBadgesForUser('${message.user?.login?.toLowerCase()}') + BlocProvider.of<FFZAPBadges>(context).getBadgesForUser('${message.user?.id}') + BlocProvider.of<ChatterinoBadges>(context).getBadgesForUser('${message.user?.id}') + BlocProvider.of<SevenTVBadges>(context).getBadgesForUser('${message.user?.id}') + BlocProvider.of<ChatsenBadges>(context).getBadgesForUser('${message.user?.id}'))
                      WidgetSpan(
                        child: WidgetTooltip(
                          message: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: ClipRRect(
                                    borderRadius: badge.color != null ? BorderRadius.circular(96.0 / 8.0) : BorderRadius.zero,
                                    child: Container(
                                      color: badge.color != null ? Color(int.tryParse(badge.color ?? '777777', radix: 16) ?? 0x777777).withAlpha(255) : null,
                                      // child: Image.network(
                                      //   badge.mipmap!.last!,
                                      //   isAntiAlias: true,
                                      //   filterQuality: FilterQuality.high,
                                      //   height: 96.0,
                                      //   fit: BoxFit.fitHeight,
                                      // ),
                                      child: OctoImage(
                                        image: CachedNetworkImageProvider(badge.mipmap!.last!),
                                        filterQuality: FilterQuality.high,
                                        height: 96.0,
                                        errorBuilder: OctoError.icon(color: Colors.red),
                                        fit: BoxFit.fitHeight,
                                      ),
                                    ),
                                  ),
                                ),
                                Text('${badge.title}'),
                                if (badge.title != badge.description && badge.description != null) Text('${badge.description}'),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: ClipRRect(
                              borderRadius: badge.color != null ? BorderRadius.circular(2.0) : BorderRadius.zero,
                              child: Container(
                                color: badge.color != null ? Color(int.tryParse(badge.color ?? '777777', radix: 16) ?? 0x777777).withAlpha(255) : null,
                                // child: Image.network(
                                //   badge.mipmap!.last!,
                                //   filterQuality: FilterQuality.high,
                                //   isAntiAlias: true,
                                //   scale: 4.0,
                                //   height: 18.0,
                                //   fit: BoxFit.fitHeight,
                                // ),
                                child: OctoImage(
                                  image: CachedNetworkImageProvider(badge.mipmap!.last!),
                                  filterQuality: FilterQuality.high,
                                  height: 18.0,
                                  errorBuilder: OctoError.icon(color: Colors.red),
                                  fit: BoxFit.fitHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    TextSpan(
                      text: '${message.user!.displayName}' + (message.user!.displayName!.toLowerCase() != message.user!.login!.toLowerCase() ? ' (${message.user!.login})' : '') + (message.action ? ' ' : ': '),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) => SearchPage(channel: message.channel, user: message.user),
                              ),
                            ),
                    ),
                  ] +
                  spans,
            ),
          ),
        ),
      ),
    );
  }
}
