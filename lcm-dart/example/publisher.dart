import 'dart:async';
import 'package:lcm_dart/lcm_dart.dart';
import 'lib/my_messages/point_t.dart';

/// Example publisher that sends point_t messages on the "POINTS" channel
void main() async {
  // Create LCM instance
  final lcm = await Lcm.create();
  print('LCM publisher started');

  var counter = 0;
  
  // Publish messages every second
  Timer.periodic(Duration(seconds: 1), (timer) {
    try {
      // Create a point message
      final point = point_t(
        x: counter * 1.0,
        y: counter * 2.0,
        z: counter * 3.0,
      );

      print('Publishing point ${counter}: (${point.x}, ${point.y}, ${point.z})');

      // Encode the message
      final buffer = LcmBuffer(1024);
      point.encode(buffer);
      final bytes = buffer.uint8List.sublist(0, buffer.position);

      // Publish to LCM
      lcm.publish('POINTS', bytes);
      
      counter++;
    } catch (e) {
      print('Error publishing: $e');
      timer.cancel();
      lcm.close();
    }
  });

  // Handle shutdown
  print('Press Ctrl+C to stop...');
}
