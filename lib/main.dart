import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
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

  @override
  void initState() {
    getCameras();
    super.initState();
  }

  Future<void> getCameras() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[1], ResolutionPreset.low);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
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
                // Positioned(
                //   top: 100,
                //   left: 0,
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: <Widget>[
                //       Text("left ${box == null ? 0 : box.left}"),
                //       Text("top ${box == null ? 0 : box.top}"),
                //       Text("box width ${box == null ? 0 : box.width}"),
                //       Text("box height ${box == null ? 0 : box.height}"),
                //       Text("${box == null ? 0 : (box.right + box.width)}"),
                //       Text("screen width ${constraint.maxWidth}"),
                //       Text(
                //           "screen height ${constraint.maxHeight}"),
                //       Text(
                //           "camera width ${controller.value.previewSize.width}"),
                //       Text("${modifyer == null ? 0 : modifyer}"),
                //     ],
                //   ),
                // ),
                Positioned(
                  top: box == null ? 0 : (box.top * modifyer),
                  right: box == null ? 0 : (box.left * modifyer),
                  child: box == null
                      ? Container()
                      : Container(
                          width: box.size.width * modifyer,
                          height: box.size.height * modifyer,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.red,
                              // color: Colors.transparent,
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

    // print("scanning!...");

    // print("width ${availableImage.width}");
    // print("height ${availableImage.height}");

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

    // var some = FirebaseVisionImage.fromFile(imageFile)
    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromBytes(availableImage.planes[0].bytes, metadata);
    final FaceDetector faceDetector =
        FirebaseVision.instance.faceDetector(FaceDetectorOptions(
      enableClassification: false,
      mode: FaceDetectorMode.accurate,
      minFaceSize: 0.2,
    ));
    final List<Face> faces = await faceDetector.processImage(visionImage);
    // print("scanning: ${faces.length}");
    // if (faces.length > 0) print("detected face!!!!!!!!!!! ${faces[0].boundingBox.size}");
    if (faces.length > 0) {
      final face = faces[0];
      box = face.boundingBox;
      modifyer = MediaQuery.of(context).size.width / availableImage.height;
    } else {
      box = null;
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
          Row(
            children: <Widget>[
              FlatButton(
                child: Text("start"),
                onPressed: () async {
                  await controller
                      .startImageStream((CameraImage availableImage) {
                    if (!_isScanBusy) _scanFace(availableImage);
                  });
                },
              ),
              FlatButton(
                child: Text("stop"),
                onPressed: () async => await controller.stopImageStream(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
