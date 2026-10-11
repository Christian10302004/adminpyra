import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model representing a single object detected by Roboflow
class RoboflowPrediction {
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  RoboflowPrediction({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory RoboflowPrediction.fromMap(Map<String, dynamic> map) {
    return RoboflowPrediction(
      className: map['class']?.toString() ?? map['label']?.toString() ?? 'Unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';
}

/// Response payload returned by Roboflow inference API
class RoboflowResponse {
  final List<RoboflowPrediction> predictions;
  final double time;
  final int imageWidth;
  final int imageHeight;
  final Map<String, dynamic> raw;

  RoboflowResponse({
    required this.predictions,
    required this.time,
    required this.imageWidth,
    required this.imageHeight,
    required this.raw,
  });

  factory RoboflowResponse.fromMap(Map<String, dynamic> map) {
    final predictionsList = (map['predictions'] as List<dynamic>?)
            ?.map((e) => RoboflowPrediction.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final imageMap = map['image'] as Map<String, dynamic>?;

    return RoboflowResponse(
      predictions: predictionsList,
      time: (map['time'] as num?)?.toDouble() ?? 0.0,
      imageWidth: (imageMap?['width'] as num?)?.toInt() ?? 0,
      imageHeight: (imageMap?['height'] as num?)?.toInt() ?? 0,
      raw: map,
    );
  }
}

/// Roboflow API Integration Service for Computer Vision / Object Detection
class RoboflowService {
  String apiKey;
  String modelId;
  String version;

  RoboflowService({
    this.apiKey = 'raFpQPwkCGYNWepqcp7o',
    this.modelId = 'pyracheck-fire-safety-detection-owr2k',
    this.version = '2',
  });

  /// Runs Roboflow computer vision object detection on raw image bytes.
  /// Works across Android, iOS, and Web platforms.
  Future<RoboflowResponse?> detectFromBytes(
    Uint8List bytes, {
    double confidenceThreshold = 0.25,
  }) async {
    try {
      final String base64Image = base64Encode(bytes);
      final Uri uri = Uri.parse(
        'https://detect.roboflow.com/$modelId/$version?api_key=$apiKey&confidence=${(confidenceThreshold * 100).toInt()}',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: base64Image,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return RoboflowResponse.fromMap(data);
      } else {
        debugPrint('Roboflow API Error [${response.statusCode}]: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Roboflow Exception: $e');
      return null;
    }
  }

  /// Runs Roboflow object detection on an image URL.
  Future<RoboflowResponse?> detectFromUrl(
    String imageUrl, {
    double confidenceThreshold = 0.25,
  }) async {
    try {
      final Uri uri = Uri.parse(
        'https://detect.roboflow.com/$modelId/$version?api_key=$apiKey&image=${Uri.encodeComponent(imageUrl)}&confidence=${(confidenceThreshold * 100).toInt()}',
      );

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return RoboflowResponse.fromMap(data);
      } else {
        debugPrint('Roboflow API Error [${response.statusCode}]: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Roboflow Exception: $e');
      return null;
    }
  }
}
