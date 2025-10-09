import 'dart:typed_data';
import 'package:lcm_dart/lcm_dart.dart';
import 'lib/my_messages/point_t.dart';

/// Example subscriber that receives point_t messages on the "POINTS" channel
void main() async {
  // Create LCM instance
  final lcm = await Lcm.create();
  print('LCM subscriber started, listening for messages on "POINTS" channel...');

  // Subscribe to the POINTS channel
  lcm.subscribe('POINTS', (String channel, Uint8List data) {
    try {
      // Decode the message
      final buffer = LcmBuffer.fromUint8List(data);
      final point = point_t.decode(buffer);

      print('Received on channel "$channel": (${point.x}, ${point.y}, ${point.z})');
    } catch (e) {
      print('Error decoding message: $e');
    }
  });

  // Keep the program running
  print('Press Ctrl+C to stop...');
  
  // Note: In a real application, you would want to handle shutdown gracefully
  // For example, using ProcessSignal.sigint.watch() to call lcm.close()
}
