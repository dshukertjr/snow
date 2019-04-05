import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snow的なやつ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<CameraDescription> cameras;
  CameraController controller;
  bool _isScanBusy = false;
  Rect box;
  double modifyer;
  Offset _noseBase;

  @override
  void initState() {
    getCameras();
    super.initState();
  }

  Future<void> getCameras() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[1], ResolutionPreset.low);
    await controller.initialize();
    if (!mounted) {
      return;
    }
    await controller.startImageStream((CameraImage availableImage) {
      if (!_isScanBusy) _scanFace(availableImage);
    });
    setState(() {});
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraint) {
            return Stack(
              children: <Widget>[
                CameraPreview(controller),
                Positioned(
                  top: box == null ? 0 : (box.top * modifyer),
                  right: box == null ? 0 : (box.left * modifyer),
                  child: _noseBase == null
                      ? Container()
                      : Container(
                          width: box.size.width * modifyer,
                          height: box.size.height * modifyer,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.red,
                              width: 5,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  // top: box == null ? 0 : (box.top * modifyer),
                  // right: box == null ? 0 : (box.left * modifyer),
                  right: _noseBase == null ? 0 : (_noseBase.dx * modifyer - 5),
                  top: _noseBase == null ? 0 : (_noseBase.dy * modifyer - 5),
                  child: _noseBase == null
                      ? Container()
                      : Container(
                          // width: box.size.width * modifyer,
                          // height: box.size.height * modifyer,
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.red,
                              width: 5,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  void _scanFace(CameraImage availableImage) async {
    _isScanBusy = true;

    modifyer = MediaQuery.of(context).size.width /
        availableImage.height; //since the image is rotated, the height is a

    final FirebaseVisionImageMetadata metadata = FirebaseVisionImageMetadata(
        rawFormat: availableImage.format.raw,
        // size: controller.value.previewSize,
        size: Size(
            availableImage.width.toDouble(), availableImage.height.toDouble()),
        rotation: ImageRotation.rotation270,
        planeData: availableImage.planes
            .map(
              (currentPlane) => FirebaseVisionImagePlaneMetadata(
                    bytesPerRow: currentPlane.bytesPerRow,
                    height: currentPlane.height,
                    width: currentPlane.width,
                  ),
            )
            .toList());

    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromBytes(availableImage.planes[0].bytes, metadata);
    final FaceDetector faceDetector =
        FirebaseVision.instance.faceDetector(FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: true,
      mode: FaceDetectorMode.accurate,
      minFaceSize: 0.2,
    ));
    final List<Face> faces = await faceDetector.processImage(visionImage);
    if (faces.length > 0) {
      final face = faces[0];
      box = face.boundingBox;
      FaceLandmark noseBase = face.getLandmark(FaceLandmarkType.noseBase);
      _noseBase = noseBase == null ? null : noseBase.position;
      // FaceLandmark bottomMouth =  face.getLandmark(FaceLandmarkType.bottomMouth);
    } else {
      box = null;
      _noseBase = null;
    }
    setState(() {});

    _isScanBusy = false;
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          _cameraPreviewWidget(),
        ],
      ),
    );
  }
}