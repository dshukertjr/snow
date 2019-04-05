import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flare_flutter/flare_actor.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snow的なやつ',
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
  bool isScanningBusy = false;
  Rect faceBox;
  Offset noseBase;
  double imageViewportRatio;

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
      // print(isScanningBusy);
      if (!isScanningBusy) {
        print("scanning is not busy");
        scanFace(availableImage);
      }
    });
    setState(() {});
  }

  Widget cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Text("カメラの使用を許可してください"),
      );
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        children: <Widget>[
          CameraPreview(controller),
          faceBox == null
              ? Container()
              : Positioned(
                  right: faceBox.left * imageViewportRatio,
                  top: faceBox.top * imageViewportRatio,
                  child: SizedBox(
                    child: FlareActor("assets/ear.flr"),
                    width: faceBox.width * imageViewportRatio,
                    height: faceBox.height * imageViewportRatio / 2.5,
                  ),
                ),
          noseBase == null
              ? Container()
              : Positioned(
                  right: noseBase.dx * imageViewportRatio - faceBox.width * imageViewportRatio / 2 / 2,
                  top: noseBase.dy * imageViewportRatio - faceBox.height * imageViewportRatio / 2 / 2,
                  child: SizedBox(
                    child: FlareActor("assets/nose.flr"),
                    width: faceBox.width * imageViewportRatio / 2,
                    height: faceBox.height * imageViewportRatio / 2,
                  ),
                ),
        ],
      ),
    );
  }

  void scanFace(CameraImage availableImage) async {
    isScanningBusy = true;
    imageViewportRatio =
        MediaQuery.of(context).size.width / availableImage.height;
    final FirebaseVisionImageMetadata metadata = FirebaseVisionImageMetadata(
      rawFormat: availableImage.format.raw,
      planeData: availableImage.planes
          .map(
            (currentPlane) => FirebaseVisionImagePlaneMetadata(
                  bytesPerRow: currentPlane.bytesPerRow,
                  height: currentPlane.height,
                  width: currentPlane.width,
                ),
          )
          .toList(),
      size: Size(
          availableImage.width.toDouble(), availableImage.height.toDouble()),
      rotation: ImageRotation.rotation270,
    );

    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromBytes(availableImage.planes[0].bytes, metadata);
    final FaceDetector faceDetector =
        FirebaseVision.instance.faceDetector(FaceDetectorOptions(
      enableLandmarks: true,
    ));

    final List<Face> faces = await faceDetector.processImage(visionImage);
    print(faces.length);
    if (faces.length > 0) {
      final face = faces[0];
      faceBox = face.boundingBox;
      if (face.getLandmark(FaceLandmarkType.noseBase) != null)
        noseBase = face.getLandmark(FaceLandmarkType.noseBase).position;
        else noseBase = null;
    } else {
      faceBox = null;
      noseBase = null;
    }
    print(noseBase);
    isScanningBusy = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: cameraPreviewWidget(),
    );
  }
}
