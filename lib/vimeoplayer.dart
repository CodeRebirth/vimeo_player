library vimeoplayer;

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:booktouxstream/provider/auth.dart';
import 'package:booktouxstream/provider/watchlist.dart';
import 'package:booktouxstream/screens/misc/timerLogout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:subtitle_wrapper_package/subtitle_wrapper_package.dart';
import 'package:video_player/video_player.dart';

import 'src/fullscreen_player.dart';
import 'src/quality_links.dart';

//Класс видео плеера
class VimeoPlayer extends StatefulWidget {
  final String id;
  final bool? autoPlay;
  final bool? looping;
  final int? position;
  final String? mediaId;
  final String? userId;
  final deviceId;
  final String subtitleUrl;
  final bool? pipMode;
  final bool? trailerMode;
  final Function? getTime;
  final String vimeoToken;

  VimeoPlayer({
    Key? key,
    required this.id,
    this.autoPlay,
    this.looping,
    this.position,
    this.mediaId,
    this.userId,
    required this.subtitleUrl,
    this.pipMode,
    this.trailerMode,
    this.getTime,
    required this.vimeoToken,
    this.deviceId,
  }) : super(key: key);

  @override
  _VimeoPlayerState createState() => _VimeoPlayerState(id, autoPlay, looping, position);
}

class _VimeoPlayerState extends State<VimeoPlayer> {
  String _id;
  bool? autoPlay = false;
  bool? looping = false;
  int? position;
  bool _overlay = false;
  var _currentQuality;

  bool? showId = true;
  double? top;
  double? left;
  late Timer timer;
  late Timer overLaytimer;
  bool subShow = true;
  SubtitleController? subtitleController;

  _VimeoPlayerState(this._id, this.autoPlay, this.looping, this.position);

  Isolate? _isolateOne;
  Isolate? _isolateTwo;

  ReceivePort? _receivePortOne;
  ReceivePort? _receivePortTwo;

  void _startIsolate() async {
    _receivePortOne = ReceivePort();
    _receivePortTwo = ReceivePort();
    _isolateOne = await Isolate.spawn(
      _isolateOneFunction,
      _receivePortOne!.sendPort,
    );
    _isolateTwo = await Isolate.spawn(
      _isolateTwoFunction,
      _receivePortTwo!.sendPort,
    );

    _receivePortOne!.listen((data) {
      if (data == 1) {
        overlayOff();
      }
    }, onDone: () {});

    _receivePortTwo!.listen((data) {
      if (data == 2) {
        showAndCheck();
      }
    }, onDone: () {});
  }

  static void _isolateOneFunction(SendPort sendPort) async {
    Timer.periodic(Duration(seconds: 5), (timer) {
      sendPort.send(1);
    });
  }

  static void _isolateTwoFunction(SendPort sendPort) async {
    Timer.periodic(Duration(seconds: 15), (timer) {
      sendPort.send(2);
    });
  }

  void showAndCheck() async {
    // Provider.of<Auth>(context, listen: false)
    //     .checkActive(widget.deviceId)
    //     .then((value) {
    //   if (value == 1) {
    //     Navigator.of(context).pushReplacement(
    //         MaterialPageRoute(builder: (ctx) => TimerLogout()));
    //   }
    // });
    top = double.parse(Random().nextInt(200).toString());
    left = double.parse(Random().nextInt(200).toString());
    if (mounted) {
      setState(() {
        showId = !showId!;
      });
    }
  }

  void overlayOff() async {
    setState(() {
      _overlay = false;
    });
  }

  void _stop() {
    if (_isolateOne != null) {
      _receivePortOne!.close();
      _isolateOne!.kill(priority: Isolate.immediate);
      _isolateOne = null;
    }
    if (_isolateTwo != null) {
      _receivePortTwo!.close();
      _isolateTwo!.kill(priority: Isolate.immediate);
      _isolateTwo = null;
    }
  }

  //Custom controller
  VideoPlayerController? _controller;
  Future<void>? initFuture;

  //Quality Class
  late QualityLinks _quality;
  late Map _qualityValues;
  var _qualityValue;

  //Переменная перемотки
  bool _seek = false;

  //Переменные видео
  double? videoHeight;
  double? videoWidth;
  late double videoMargin;

  //Переменные под зоны дабл-тапа
  double doubleTapRMargin = 36;
  double doubleTapRWidth = 400;
  double doubleTapRHeight = 160;
  double doubleTapLMargin = 10;
  double doubleTapLWidth = 400;
  double doubleTapLHeight = 160;

  @override
  void initState() {
    //Create class

    subtitleController = SubtitleController(
      subtitleUrl: widget.subtitleUrl,
      subtitleType: SubtitleType.srt,
    );

    _quality = QualityLinks(_id);
    //Инициализация контроллеров видео при получении данных из Vimeo
    _quality.getQualitiesSync(widget.vimeoToken).then((value) {
      _qualityValues = value;
      _qualityValue = value[value.lastKey()];
      _controller = VideoPlayerController.network(_qualityValue);
      _controller!.setLooping(looping == null ? false : true);
      initFuture = _controller!.initialize().then((value) {
        if (autoPlay!) _controller!.play();
        if (widget.getTime != null) {
          _controller!.addListener(() {
            if (_controller!.value.isPlaying) {
              widget.getTime!(_controller!.value.position.inSeconds, _controller!.value.size.height, _controller!.value.size.width);
            }
          });
        }

        if (position != null) _controller!.seekTo(Duration(seconds: position!));
        if (!widget.pipMode! || widget.trailerMode == false) {
          Navigator.push(
              context,
              PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (BuildContext context, _, __) => FullscreenPlayer(
                      id: _id,
                      userId: widget.userId,
                      autoPlay: true,
                      deviceId: widget.deviceId,
                      controller: _controller,
                      position: _controller!.value.position.inSeconds,
                      initFuture: initFuture,
                      subtitleUrl: widget.subtitleUrl,
                      vimeoToken: widget.vimeoToken,
                      qualityValue: _qualityValue),
                  transitionsBuilder: (___, Animation<double> animation, ____, Widget child) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  })).then((value) => position);
        }
      });

      //Обновление состояние приложения и перерисовка
      if (mounted) {
        setState(() {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
        });
      }
    });

    //На странице видео преимущество за портретной ориентацией
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);

    super.initState();
    _startIsolate();
  }

  //Отрисовываем элементы плеера
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          int? lastPlay = _controller!.value.position.inSeconds;

          Provider.of<WatchList>(context, listen: false).watchlistSave(widget.mediaId, lastPlay.toString());

          return true;
        },
        child: Center(
            child: Stack(
          // alignment: AlignmentDirectional.center,
          children: <Widget>[
            GestureDetector(
              child: FutureBuilder(
                  future: initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      //Управление шириной и высотой видео
                      double delta = MediaQuery.of(context).size.width - MediaQuery.of(context).size.height * _controller!.value.aspectRatio;

                      //Рассчет ширины и высоты видео плеера относительно сторон
                      // и ориентации устройства
                      if (MediaQuery.of(context).orientation == Orientation.portrait || delta < 0) {
                        videoHeight = MediaQuery.of(context).size.width / _controller!.value.aspectRatio;
                        videoWidth = MediaQuery.of(context).size.width;
                        videoMargin = 0;
                      } else {
                        videoHeight = MediaQuery.of(context).size.height;
                        videoWidth = videoHeight! * _controller!.value.aspectRatio;
                        videoMargin = (MediaQuery.of(context).size.width - videoWidth!) / 2;
                      }

                      //Начинаем с того же места, где и остановились при смене качества
                      if (_seek && _controller!.value.duration.inSeconds > 2) {
                        _controller!.seekTo(Duration(seconds: position!));
                        _seek = false;
                      }

                      //Отрисовка элементов плеера
                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                              height: videoHeight,
                              width: videoWidth,
                              margin: EdgeInsets.only(left: videoMargin),
                              child: SubtitleWrapper(
                                videoPlayerController: _controller!,
                                subtitleController: subtitleController!,
                                subtitleStyle: SubtitleStyle(
                                  textColor: Colors.white,
                                  hasBorder: true,
                                ),
                                videoChild: VideoPlayer(_controller!),
                              )),
                          if (showId!)
                            Positioned(
                              top: top,
                              left: left,
                              child: Row(children: <Widget>[
                                Image.asset(
                                  "assets/icons/1.png",
                                  height: 35,
                                  width: 35,
                                ),
                                Text("${widget.userId}", style: TextStyle(fontSize: 13, color: Colors.grey.withOpacity(0.5))),
                              ]),
                            ),
                          _videoOverlay(),
                        ],
                      );
                    } else {
                      return Center(
                        heightFactor: 6,
                        child: CircularProgressIndicator(),
                      );
                    }
                  }),
              onTap: () {
                //Редактируем размер области дабл тапа при показе оверлея.
                // Сделано для открытия кнопок "Во весь экран" и "Качество"
                setState(() {
                  _overlay = !_overlay;
                  if (_overlay) {
                    doubleTapRHeight = videoHeight! - 36;
                    doubleTapLHeight = videoHeight! - 10;
                    doubleTapRMargin = 36;
                    doubleTapLMargin = 10;
                  } else if (!_overlay) {
                    doubleTapRHeight = videoHeight! + 36;
                    doubleTapLHeight = videoHeight! + 16;
                    doubleTapRMargin = 0;
                    doubleTapLMargin = 0;
                  }
                });
              },
            ),
            GestureDetector(
                //======= Перемотка назад =======//
                child: Container(
                  width: doubleTapLWidth / 2 - 30,
                  height: doubleTapLHeight - 46,
                  margin: EdgeInsets.fromLTRB(0, 10, doubleTapLWidth / 2 + 30, doubleTapLMargin + 20),
                  decoration: BoxDecoration(
                      //color: Colors.red,
                      ),
                ),

                // Изменение размера блоков дабл тапа. Нужно для открытия кнопок
                // "Во весь экран" и "Качество" при включенном overlay
                onTap: () {
                  setState(() {
                    _overlay = !_overlay;
                    if (_overlay) {
                      doubleTapRHeight = videoHeight! - 36;
                      doubleTapLHeight = videoHeight! - 10;
                      doubleTapRMargin = 36;
                      doubleTapLMargin = 10;
                    } else if (!_overlay) {
                      doubleTapRHeight = videoHeight! + 36;
                      doubleTapLHeight = videoHeight! + 16;
                      doubleTapRMargin = 0;
                      doubleTapLMargin = 0;
                    }
                  });
                },
                onDoubleTap: () {
                  setState(() {
                    _controller!.seekTo(Duration(seconds: _controller!.value.position.inSeconds - 10));
                  });
                }),
            GestureDetector(
                child: Container(
                  //======= Перемотка вперед =======//
                  width: doubleTapRWidth / 2 - 45,
                  height: doubleTapRHeight - 60,
                  margin: EdgeInsets.fromLTRB(doubleTapRWidth / 2 + 45, doubleTapRMargin, 0, doubleTapRMargin + 20),
                  decoration: BoxDecoration(
                      //color: Colors.red,
                      ),
                ),
                // Изменение размера блоков дабл тапа. Нужно для открытия кнопок
                // "Во весь экран" и "Качество" при включенном overlay
                onTap: () {
                  setState(() {
                    _overlay = !_overlay;
                    if (_overlay) {
                      doubleTapRHeight = videoHeight! - 36;
                      doubleTapLHeight = videoHeight! - 10;
                      doubleTapRMargin = 36;
                      doubleTapLMargin = 10;
                    } else if (!_overlay) {
                      doubleTapRHeight = videoHeight! + 36;
                      doubleTapLHeight = videoHeight! + 16;
                      doubleTapRMargin = 0;
                      doubleTapLMargin = 0;
                    }
                  });
                },
                onDoubleTap: () {
                  setState(() {
                    _controller!.seekTo(Duration(seconds: _controller!.value.position.inSeconds + 10));
                  });
                }),
          ],
        )));
  }

  //================================ Quality ================================//
  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          //Формирования списка качества
          final children = <Widget>[];
          _qualityValues.forEach((elem, value) {
            return children.add(new ListTile(
                selected: _currentQuality.toString() == value.toString(),
                selectedTileColor: Colors.black,
                trailing: _currentQuality.toString() == value.toString()
                    ? Icon(
                        Icons.check,
                        color: Colors.green,
                      )
                    : null,
                title: new Text(" ${elem.toString()} fps"),
                onTap: () => {
                      //Обновление состояние приложения и перерисовка
                      Navigator.pop(context),
                      setState(() {
                        _controller!.pause();
                        _currentQuality = value;
                        _qualityValue = value;
                        _controller = VideoPlayerController.network(_qualityValue);
                        _controller!.setLooping(true);
                        _seek = true;
                        initFuture = _controller!.initialize();
                        _controller!.play();
                      }),
                    }));
          });
          //Вывод элементов качество списком
          return Container(
            child: Wrap(
              children: children,
            ),
          );
        });
  }

  //================================ OVERLAY ================================//
  Widget _videoOverlay() {
    return _overlay
        ? Stack(
            alignment: widget.trailerMode! ? Alignment.center : AlignmentDirectional.topStart,
            children: <Widget>[
              GestureDetector(
                child: Center(
                  child: Container(
                    width: videoWidth,
                    height: videoHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [const Color(0x662F2C47), const Color(0x662F2C47)],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: IconButton(
                    padding: EdgeInsets.only(top: videoHeight! / 2 - 30, bottom: videoHeight! / 2 - 30),
                    icon: _controller!.value.isPlaying ? Icon(Icons.pause, size: 60.0) : Icon(Icons.play_arrow, size: 60.0),
                    onPressed: () {
                      setState(() {
                        _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                      });
                    }),
              ),
              Container(
                margin: EdgeInsets.only(top: videoHeight! - 70, left: videoWidth! + videoMargin - 50),
                child: IconButton(
                    alignment: AlignmentDirectional.center,
                    icon: Icon(Icons.fullscreen, size: 30.0),
                    onPressed: () async {
                      setState(() {
                        _controller!.pause();
                      });
                      //Создание новой страницы с плеером во весь экран,
                      // предача данных в плеер и возвращение позиции при
                      // возвращении обратно. Пока что мы не вернулись из
                      // фуллскрина - программа в ожидании
                      position = await Navigator.push(
                          context,
                          PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (BuildContext context, _, __) => FullscreenPlayer(
                                  id: _id,
                                  userId: widget.userId,
                                  autoPlay: true,
                                  deviceId: widget.deviceId,
                                  controller: _controller!,
                                  subtitleUrl: widget.subtitleUrl,
                                  position: _controller!.value.position.inSeconds,
                                  vimeoToken: widget.vimeoToken,
                                  initFuture: initFuture,
                                  qualityValue: _qualityValue),
                              transitionsBuilder: (___, Animation<double> animation, ____, Widget child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(scale: animation, child: child),
                                );
                              }));
                      setState(() {
                        _controller!.play();
                        _seek = true;
                      });
                    }),
              ),
              if (widget.trailerMode == false)
                Container(
                  margin: EdgeInsets.only(left: videoWidth! + videoMargin - 90),
                  child: IconButton(
                      icon: subShow ? Icon(Icons.subtitles, size: 26.0) : Icon(Icons.subtitles_off),
                      onPressed: () {
                        if (subShow) {
                          subtitleController!.updateSubtitleUrl(url: "https://booktoux.com/public/assets/upload/blank.srt");
                          setState(() {
                            subShow = false;
                          });
                        } else {
                          setState(() {
                            subtitleController!.updateSubtitleUrl(url: widget.subtitleUrl);
                            subShow = true;
                          });
                        }
                      }),
                ),
              if (widget.trailerMode == false)
                Container(
                  margin: EdgeInsets.only(left: videoWidth! + videoMargin - 48),
                  child: IconButton(
                      icon: Icon(Icons.settings, size: 26.0),
                      onPressed: () {
                        position = _controller!.value.position.inSeconds;
                        _seek = true;
                        _settingModalBottomSheet(context);
                        setState(() {});
                      }),
                ),
              Container(
                //===== Ползунок =====//
                margin: EdgeInsets.only(top: videoHeight! - 26, left: videoMargin), //CHECK IT
                child: _videoOverlaySlider(),
              )
            ],
          )
        : Center(
            child: Container(
              height: 5,
              width: videoWidth,
              margin: EdgeInsets.only(top: videoHeight! - 5),
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Color(0xFF22A3D2),
                  backgroundColor: Color(0x5515162B),
                  bufferedColor: Color(0x5583D8F7),
                ),
                padding: EdgeInsets.only(top: 2),
              ),
            ),
          );
  }

  //=================== ПОЛЗУНОК ===================//
  Widget _videoOverlaySlider() {
    return ValueListenableBuilder(
      valueListenable: _controller!,
      builder: (context, VideoPlayerValue value, child) {
        if (!value.hasError && value.isInitialized) {
          return Row(
            children: <Widget>[
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(value.position.inMinutes.toString() + ':' + (value.position.inSeconds - value.position.inMinutes * 60).toString(), style: TextStyle(fontSize: 10)),
              ),
              Container(
                height: 20,
                width: videoWidth! - 92,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Color(0xFF22A3D2),
                    backgroundColor: Color(0x5515162B),
                    bufferedColor: Color(0x5583D8F7),
                  ),
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                ),
              ),
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(value.duration.inMinutes.toString() + ':' + (value.duration.inSeconds - value.duration.inMinutes * 60).toString(), style: TextStyle(fontSize: 10)),
              ),
            ],
          );
        } else {
          return Container();
        }
      },
    );
  }

  @override
  void dispose() {
    _stop();
    _controller!.dispose();
    super.dispose();
  }
}
