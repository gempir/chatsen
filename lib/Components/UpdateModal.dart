import 'dart:convert';
import 'dart:io';

import 'package:dart_downloader/DownloadManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_material_next/WidgetBlur.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:version/version.dart';

class GithubRelease {
  final String repositoryPath;
  Version version;

  String get downloads => 'https://github.com/$repositoryPath/releases/download/$version';

  GithubRelease({
    @required this.repositoryPath,
    String versionName,
  }) {
    version = Version.parse(versionName);
  }
}

class GithubReleaseProvider {
  final String repositoryPath;

  const GithubReleaseProvider(this.repositoryPath);

  Future<List<GithubRelease>> getReleases() async {
    var response = await http.get(Uri.parse('https://api.github.com/repos/$repositoryPath/tags'));
    var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
    var result = <GithubRelease>[];

    for (var tagData in jsonResponse) {
      try {
        result.add(
          GithubRelease(
            repositoryPath: repositoryPath,
            versionName: tagData['name'],
          ),
        );
      } catch (e) {
        print(e);
      }
    }

    return result;
  }
}

class UpdateModal extends StatelessWidget {
  final Version currentVersion;
  final GithubRelease latestRelease;

  static Future<bool> hasUpdate() async {
    var releases = await GithubReleaseProvider('chatsen/chatsen').getReleases();
    releases.sort((a1, a2) => a1.version.compareTo(a2.version));
    var packageInfo = await PackageInfo.fromPlatform();
    var currentReleaseVersion = Version.parse('${packageInfo.version}+${packageInfo.buildNumber}');
    var lastRelease = releases.last;
    return currentReleaseVersion < lastRelease.version;
  }

  static void searchForUpdate(BuildContext context) async {
    var releases = await GithubReleaseProvider('chatsen/chatsen').getReleases();
    releases.sort((a1, a2) => a1.version.compareTo(a2.version));

    var packageInfo = await PackageInfo.fromPlatform();
    var currentReleaseVersion = Version.parse('${packageInfo.version}+${packageInfo.buildNumber}');
    var lastRelease = releases.last;

    if (currentReleaseVersion < lastRelease.version) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: UpdateModal(
              currentVersion: currentReleaseVersion,
              latestRelease: lastRelease,
            ),
          ),
        ),
      );
    }
  }

  const UpdateModal({
    Key key,
    @required this.currentVersion,
    @required this.latestRelease,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadManager, DownloadManagerState>(
        builder: (context, state) => WidgetBlur(
          child: Material(
            color: Theme.of(context).canvasColor.withAlpha(196),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 1.0, color: Theme.of(context).dividerColor),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(width: 32.0, height: 2.0, color: Theme.of(context).dividerColor),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var download in state.downloads)
                        BlocBuilder<Download, DownloadState>(
                          buildWhen: (state1, state2) => true,
                          bloc: download,
                          builder: (context, state) => InkWell(
                            onTap: () async {
                              if (state is DownloadCompleted) {
                                var savePath = (await getApplicationDocumentsDirectory()).path;
                                var fileName = state.url.split('/').last;
                                await File('$savePath/$fileName').writeAsBytes(state.bytes, flush: true);
                                await OpenFile.open('$savePath/$fileName');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${state is DownloadCompleted ? 'Downloaded' : 'Downloading'} update ${latestRelease.version}'),
                                    SizedBox(height: 8.0),
                                    if (state is DownloadContentState)
                                      LinearProgressIndicator(
                                        value: state.curBytes / state.maxBytes,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (state.downloads.isEmpty) ...[
                        Text('Local version: $currentVersion'),
                        Text('Upstream version: ${latestRelease.version}'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => BlocProvider.of<DownloadManager>(context).add(DownloadManagerAdd(url: '${latestRelease.downloads}/${Platform.isAndroid ? 'Android.apk' : 'iOS.ipa'}')),
                              label: Text('Update now'),
                              icon: Icon(Icons.system_update),
                            ),
                            SizedBox(width: 8.0),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(height: 1.0, color: Theme.of(context).dividerColor),
              ],
            ),
          ),
        ),
      );
}