library vimeoplayer;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'quality_links.dart';
import 'dart:math';
import 'dart:isolate';
import 'package:provider/provider.dart';
import 'package:booktouxstream/provider/auth.dart';
import 'package:booktouxstream/screens/misc/timerLogout.dart';
import 'dart:async';

//Класс видео плеера во весь экран
class FullscreenPlayer extends StatefulWidget {
  final String id;
  final bool? autoPlay;
  final bool? looping;
  final VideoPlayerController? controller;
  final String? userId;
  final position;
  final deviceId;
  final Future<void>? initFuture;
  final String? qualityValue;

  FullscreenPlayer({
    required this.id,
    this.autoPlay,
    this.looping,
    this.controller,
    this.position,
    this.deviceId,
    this.initFuture,
    this.userId,
    this.qualityValue,
    Key? key,
  }) : super(key: key);

  @override
  _FullscreenPlayerState createState() => _FullscreenPlayerState(
      id, autoPlay, looping, controller, position, initFuture, qualityValue);
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  String _id;
  bool? autoPlay = false;
  bool? looping = false;
  bool _overlay = true;
  bool fullScreen = true;
  bool? showId    = true;
  double? top;
  double? left;
  late Timer timer;


  VideoPlayerController? controller;
  VideoPlayerController? _controller;

  int? position;

  Future<void>? initFuture;
  var qualityValue;

  _FullscreenPlayerState(this._id, this.autoPlay, this.looping, this.controller,
      this.position, this.initFuture, this.qualityValue);

  // Quality Class
  late QualityLinks _quality;
  late Map _qualityValues;
  late Timer overLaytimer;

  //Переменная перемотки
  bool _seek = true;

  //Переменные видео
  double? videoHeight;
  double? videoWidth;
  late double videoMargin=0;

  //Переменные под зоны дабл-тапа
  double doubleTapRMarginFS  = 36;
  double? doubleTapRWidthFS  = 700;
  double doubleTapRHeightFS  = 300;
  double doubleTapLMarginFS  = 10;
  double? doubleTapLWidthFS  = 700;
  double? doubleTapLHeightFS = 400;

  Isolate? _isolateOne;
  Isolate? _isolateTwo;

  ReceivePort? _receivePortOne;
  ReceivePort? _receivePortTwo;


void _startIsolate() async{
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

    _receivePortOne!.listen((data){
      if(data == 1){
        overlayOff();
      }
    },onDone: (){
      print("done");
    });

    _receivePortTwo!.listen((data){
      if(data == 2){
        showAndCheck();
      }
    },onDone: (){
      print("done");
    });

  }
 static void _isolateOneFunction(SendPort sendPort) async {
    Timer.periodic(Duration(seconds: 5), (timer) { 
      sendPort.send(1);
    });
  }
 static void _isolateTwoFunction(SendPort sendPort) async {
    Timer.periodic(Duration(seconds: 30), (timer) { 
      sendPort.send(2);
    });
  }


  void showAndCheck() async { 
  Provider.of<Auth>(context,listen:false).checkActive(widget.deviceId).then((value){
    if(value == 1){
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(ctx)=>TimerLogout()));
    }
  });
  top  =  double.parse(Random().nextInt(400).toString());
  left =  double.parse(Random().nextInt(400).toString());
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

  void _stop(){
    if(_isolateOne != null){
      _receivePortOne!.close();
      _isolateOne!.kill(priority: Isolate.immediate);
      _isolateOne = null;
    }
    if(_isolateTwo != null){
      _receivePortTwo!.close();
      _isolateTwo!.kill(priority: Isolate.immediate);
      _isolateTwo = null;
    }
  }


  @override
  void initState() {
    //Инициализация контроллеров видео при получении данных из Vimeo
  
    _controller = controller;
    if (autoPlay!) _controller!.play();

    // Подгрузка списка качеств видео
    _quality = QualityLinks(_id); //Create class
    _quality.getQualitiesSync().then((value) {
      _qualityValues = value;
    });

    setState(() {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIOverlays([]);
    });

    super.initState();
    _startIsolate();
  }

  //Ослеживаем пользовательского нажатие назад и переводим
  // на экран с плеером не в режиме фуллскрин, возвращаем ориентацию
  Future<bool> _onWillPop() {
    setState(() {
      _controller!.pause();
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIOverlays(
          [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    });
    Navigator.pop(context, _controller!.value.position.inSeconds);
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
          child: Stack(
          alignment: AlignmentDirectional.center,
          children: <Widget>[
            GestureDetector(
              child: FutureBuilder(
                  future: initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      //Управление шириной и высотой видео
                      double delta = MediaQuery.of(context).size.width -
                          MediaQuery.of(context).size.height *
                              _controller!.value.aspectRatio;
                      if (MediaQuery.of(context).orientation ==
                              Orientation.portrait ||
                          delta < 0) {
                        videoHeight = MediaQuery.of(context).size.width /
                            _controller!.value.aspectRatio;
                        videoWidth = MediaQuery.of(context).size.width;
                        videoMargin = 0;
                      } else {
                        videoHeight = MediaQuery.of(context).size.height;
                        videoWidth = MediaQuery.of(context).size.width;
                        
                        
                      }
                      //Переменные дабл тапа, зависимые от размеров видео
                      doubleTapRWidthFS = videoWidth;
                      doubleTapRHeightFS = videoHeight! - 36;
                      doubleTapLWidthFS = videoWidth;
                      doubleTapLHeightFS = videoHeight;

                      //Сразу при входе в режим фуллскрин перематываем
                      // на нужное место
                      if (_seek && fullScreen) {
                        _controller!.seekTo(Duration(seconds: position!));
                        _seek = false;
                      }

                      //Переходи на нужное место при смене качества
                      if (_seek && _controller!.value.duration.inSeconds > 2) {
                        _controller!.seekTo(Duration(seconds: position!));
                        _seek = false;
                      }
                      

                      //Отрисовка элементов плеера
                      return Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child:Container(
                            height: videoHeight,
                            width: videoWidth,
                            alignment: Alignment.center,
                            child: Center(child:VideoPlayer(_controller!)),
                          )),
                          if(showId!)
                          Positioned(
                          top: top,
                          left: left,
                          child:Row(
                          children: <Widget>[
                            Image.asset("assets/booktouxlogo.png",height: 15,width: 15,),
                            Text("${widget.userId}",style:TextStyle(fontSize:9,color:Colors.grey.withOpacity(0.5))),
                          ]
                          ),
                          ),
                          _videoOverlay(),
                        ],
                      );
                    } else {
                      return Center(
                          heightFactor: 6,
                          child: CircularProgressIndicator());
                    }
                  }),
              //Редактируем размер области дабл тапа при показе оверлея.
              // Сделано для открытия кнопок "Во весь экран" и "Качество"
              onTap: () {
                setState(() {
                  _overlay = !_overlay;
                  if (_overlay) {
                    doubleTapRHeightFS = videoHeight! - 36;
                    doubleTapLHeightFS = videoHeight! - 10;
                    doubleTapRMarginFS = 36;
                    doubleTapLMarginFS = 10;
                  } else if (!_overlay) {
                    doubleTapRHeightFS = videoHeight! + 36;
                    doubleTapLHeightFS = videoHeight;
                    doubleTapRMarginFS = 0;
                    doubleTapLMarginFS = 0;
                  }
                });
              },
            ),
            GestureDetector(
                child: Container(
                  width: doubleTapLWidthFS! / 2 - 30,
                  height: doubleTapLHeightFS! - 44,
                  margin:
                      EdgeInsets.fromLTRB(0, 0, doubleTapLWidthFS! / 2 + 30, 40),
                  decoration: BoxDecoration(
                    //color: Colors.red,
                  ),
                ),
                //Редактируем размер области дабл тапа при показе оверлея.
                // Сделано для открытия кнопок "Во весь экран" и "Качество"
                onTap: () {
                  setState(() {
                    _overlay = !_overlay;
                    if (_overlay) {
                      doubleTapRHeightFS = videoHeight! - 36;
                      doubleTapLHeightFS = videoHeight! - 10;
                      doubleTapRMarginFS = 36;
                      doubleTapLMarginFS = 10;
                    } else if (!_overlay) {
                      doubleTapRHeightFS = videoHeight! + 36;
                      doubleTapLHeightFS = videoHeight;
                      doubleTapRMarginFS = 0;
                      doubleTapLMarginFS = 0;
                    }
                  });
                },
                onDoubleTap: () {
                  setState(() {
                    _controller!.seekTo(Duration(
                        seconds: _controller!.value.position.inSeconds - 10));
                  });
                }),
            GestureDetector(
                child: Container(
                  width: doubleTapRWidthFS! / 2 - 45,
                  height: doubleTapRHeightFS - 80,
                  margin: EdgeInsets.fromLTRB(doubleTapRWidthFS! / 2 + 45, 0, 0,
                      doubleTapLMarginFS + 20),
                  decoration: BoxDecoration(
                    //color: Colors.red,
                  ),
                ),
                //Редактируем размер области дабл тапа при показе оверлея.
                // Сделано для открытия кнопок "Во весь экран" и "Качество"
                onTap: () {
                  setState(() {
                    _overlay = !_overlay;
                    if (_overlay) {
                      doubleTapRHeightFS = videoHeight! - 36;
                      doubleTapLHeightFS = videoHeight! - 10;
                      doubleTapRMarginFS = 36;
                      doubleTapLMarginFS = 10;
                    } else if (!_overlay) {
                      doubleTapRHeightFS = videoHeight! + 36;
                      doubleTapLHeightFS = videoHeight;
                      doubleTapRMarginFS = 0;
                      doubleTapLMarginFS = 0;
                    }
                  });
                },
                onDoubleTap: () {
                  setState(() {
                    _controller!.seekTo(Duration(
                        seconds: _controller!.value.position.inSeconds + 10));
                  });
                }),
          ],
        ))));
  }

  //================================ Quality ================================//
  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          final children = <Widget>[];
          _qualityValues.forEach((elem, value) => (children.add(new ListTile(
              selected: qualityValue.toString() == value.toString(),
               selectedTileColor: Colors.black,
               trailing: qualityValue.toString() == value.toString() ? Icon(Icons.check, color: Colors.green,) : null,
              title: new Text(" ${elem.toString()} fps"),
              onTap: () => {
                    //Обновление состояние приложения и перерисовка
                    Navigator.pop(context),
                    setState(() {
                      _controller!.pause();
                      qualityValue = value;
                      _controller = VideoPlayerController.network(value);
                      _controller!.setLooping(true);
                      _seek = true;
                      initFuture = _controller!.initialize();
                      _controller!.play();
                    }),
                  }))));

          return Container(
            height: videoHeight,
            child: ListView(
              children: children,
            ),
          );
        });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  //================================ OVERLAY ================================//
  Widget _videoOverlay() {
    return _overlay
        ? Stack(
            children: <Widget>[
              GestureDetector(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                   
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          const Color(0x662F2C47),
                          const Color(0x662F2C47)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: IconButton(
                    padding: EdgeInsets.only(
                      top: videoHeight! / 2 - 50,
                      bottom: videoHeight! / 2 - 30,
                    ),
                    icon: _controller!.value.isPlaying
                        ? Icon(Icons.pause, size: 60.0)
                        : Icon(Icons.play_arrow, size: 60.0),
                    onPressed: () {
                      setState(() {
                        _controller!.value.isPlaying
                            ? _controller!.pause()
                            : _controller!.play();
                      });
                    }),
              ),
              Container(
                margin: EdgeInsets.only(
                    top: videoHeight! + videoMargin - 55, left: videoWidth! + videoMargin - 50),
                child: IconButton(
                    alignment: AlignmentDirectional.center,
                    icon: Icon(Icons.fullscreen, size: 30.0),
                    onPressed: () {
                      setState(() {
                        _controller!.pause();
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitDown,
                          DeviceOrientation.portraitUp
                        ]);
                        SystemChrome.setEnabledSystemUIOverlays(
                            [SystemUiOverlay.top, SystemUiOverlay.bottom]);
                      });
                      Navigator.pop(
                          context, _controller!.value.position.inSeconds);
                    }),
              ),
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
                margin: EdgeInsets.only(
                    top: videoHeight! - 25, left: videoMargin), //CHECK IT
                child: _videoOverlaySlider(),
              )
            ],
          )
        : Center();
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
                child: Text(value.position.inMinutes.toString() +
                    ':' +
                    (value.position.inSeconds - value.position.inMinutes * 60)
                        .toString(),style:TextStyle(fontSize:10)),
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
                child: Text(value.duration.inMinutes.toString() +
                    ':' +
                    (value.duration.inSeconds - value.duration.inMinutes * 60)
                        .toString(),style:TextStyle(fontSize:10)),
              ),
            ],
          );
        } else {
          return Container();
        }
      },
    );
  }
}
