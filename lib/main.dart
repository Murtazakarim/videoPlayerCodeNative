import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_ffmpeg/media_information.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Manager Demo',
      home: Material(
        child: Center(
          child: Builder(
            builder: (context) {
              return RaisedButton(
                onPressed: () async {
                  final permitted = await PhotoManager.requestPermission();
                  if (!permitted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => Gallery()),
                  );
                },
                child: Text('Open Gallery'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class Gallery extends StatefulWidget {
  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  List<AssetEntity> assets = [];

  @override
  void initState() {
    _fetchAssets();
    super.initState();
  }

  _fetchAssets() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
    );
    final recentAlbum = albums.first;

    // Now that we got the album, fetch all the assets it contains
    final recentAssets = await recentAlbum.getAssetListRange(
      start: 0, // start at index 0
      end: 1000000, // end at a very big index (to get all the assets)
    );

    // Update the state and notify UI
    setState(() => assets = recentAssets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery'),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemCount: assets.length,
        itemBuilder: (_, index) {
          return AssetThumbnail(asset: assets[index]);
        },
      ),
    );
  }
}

class AssetThumbnail extends StatelessWidget {
  const AssetThumbnail({
    Key key,
    @required this.asset,
  }) : super(key: key);

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: asset.thumbData,
      builder: (_, snapshot) {
        final bytes = snapshot.data;

        if (bytes == null) return CircularProgressIndicator();
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) {
                  if (asset.type == AssetType.image) {
                    return ImageScreen(imageFile: asset.file);
                  } else {
                    return VideoScreen(videoFile: asset.file);
                  }
                },
              ),
            );
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
              // Display a Play icon if the asset is a video
              if (asset.type == AssetType.video)
                Center(
                  child: Container(
                    color: Colors.blue,
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ImageScreen extends StatelessWidget {
  const ImageScreen({
    Key key,
    @required this.imageFile,
  }) : super(key: key);

  final Future<File> imageFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: FutureBuilder<File>(
        future: imageFile,
        builder: (_, snapshot) {
          final file = snapshot.data;
          if (file == null) return Container();
          return Image.file(file);
        },
      ),
    );
  }
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({
    Key key,
    @required this.videoFile,
  }) : super(key: key);

  final Future<File> videoFile;

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController _controller;
  bool initialized = false;

  @override
  void initState() {
    _initVideo();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _initVideo() async {
    final video = await widget.videoFile;
    // FlutterFFprobe flutterFFprobe;
    // FlutterFFmpeg _flutterFFmpeg;
    // MediaInformation mediaInformation =
    //     await flutterFFprobe.getMediaInformation(video.path);
    // Map<dynamic, dynamic> mp = mediaInformation.getMediaProperties();
    // double timeInterval = double.parse(mp["duration"]);
    // int loop = timeInterval ~/ 30;
    // String commandToExecute =
    //     "-y -i ${video.path} -ss 00:00:${30} -t 30 ${video.path}";
    // await _flutterFFmpeg
    //     .execute(commandToExecute)
    //     .then((value) => print("FFmpeg return with $value"));
    _controller = VideoPlayerController.file(video)
      ..setLooping(true)
      ..initialize().then((_) => setState(() => initialized = true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: initialized
          ? Scaffold(
              body: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            )
          // If the video is not yet initialized, display a spinner
          : Center(child: CircularProgressIndicator()),
    );
  }
}
