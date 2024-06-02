import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:messagerie/main.dart';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:tflite_v2/tflite_v2.dart';

/// CameraApp is the Main Application.
class CameraApp extends StatefulWidget {
  /// Default Constructor
  const CameraApp({
    super.key,
    required this.currentUserId,
    required this.contactId,
    required this.client,
  });
  final String currentUserId;
  final String contactId;
  final StompClient client;
  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraImage? cameraImage;
  late CameraController controller;
  String output = '';
  CameraDescription cameraId = cameras[1];
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    loadModel();
    controller = CameraController(cameraId, ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        controller.startImageStream(
            (imageStream) => {cameraImage = imageStream, runModel()});
      });
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _sendMessage(String messageContent) {
    if (messageContent.isNotEmpty) {
      final messageJson = {
        'content': messageContent,
        'senderId': widget.currentUserId,
        'recipientId': widget.contactId,
        'timestamp': DateTime.now().toString().substring(11, 16),
      };
      widget.client.send(
        destination: '/app/chatt',
        body: json.encode(messageJson),
      );
      setState(() {
        messages.add(messageJson);
      });
    }
  }

  runModel() async {
    if (cameraImage != null) {
      var pred = await Tflite.runModelOnFrame(
          bytesList: cameraImage!.planes.map((e) => e.bytes).toList(),
          imageHeight: 48,
          imageWidth: 48,
          imageMean: 127.5,
          imageStd: 127.5,
          rotation: 0,
          numResults: 1,
          threshold: .1,
          asynch: true);

      setState(() {
        print("**************************************************************");
        print(pred);

        output = pred!.first['label'];
        //TODO
        Timer.periodic(Duration(seconds: 2), (timer) {
          processOutput(output);
        });
      });
    }
  }

  String aux = '';
  void processOutput(String detectedEmotion) {
    if (detectedEmotion != 'Neutral') {
      output = detectedEmotion;
      if (aux != output) {
        sendEmotionMessage(output);
        aux = output;
      }
    }
  }

  loadModel() async {
    String? res = await Tflite.loadModel(
        model: "assets/model_unquant.tflite",
        labels: "assets/labels.txt",
        numThreads: 1, // defaults to 1
        isAsset: true,
        useGpuDelegate:
            false // defaults to false, set to true to use GPU delegate
        );

    print('RESULTSSSSSSSS - $res');
  }

  void sendEmotionMessage(String variable) {
    _sendMessage(variable);
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        maintainBottomViewPadding: true,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,

          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          // alignment: AlignmentDirectional.bottomCenter,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              width: MediaQuery.of(context).size.width,
              child: Container(
                clipBehavior: Clip.hardEdge,
                margin: const EdgeInsets.all(20).copyWith(bottom: 0, top: 0),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(15)),
                child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: controller.buildPreview()),
              ),
            ),
            // const SizedBox(height: ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    shape: const StadiumBorder(),
                    avatar: const Icon(Icons.emoji_emotions_rounded),
                    label: Text(
                      // output is the variable that hold different emotions
                      output,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
