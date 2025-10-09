import 'dart:typed_data';
import 'package:lcm_dart/lcm_dart.dart';
import 'lib/my_messages/point_t.dart';

/// Example showing subscription with regex patterns
void main() async {
  // Create LCM instance
  final lcm = await Lcm.create();
  print('LCM pattern subscriber started...\n');

  // Subscribe to all channels starting with "SENSOR_"
  lcm.subscribe('SENSOR_.*', (String channel, Uint8List data) {
    print('Received sensor data on channel: $channel (${data.length} bytes)');
  });

  // Subscribe to specific point channels
  lcm.subscribe('POINT_[0-9]+', (String channel, Uint8List data) {
    try {
      final buffer = LcmBuffer.fromUint8List(data);
      final point = point_t.decode(buffer);
      print('Received point on $channel: (${point.x}, ${point.y}, ${point.z})');
    } catch (e) {
      print('Error decoding point: $e');
    }
  });

  // Subscribe to all channels (wildcard)
  lcm.subscribe('.*', (String channel, Uint8List data) {
    print('All channels: Got ${data.length} bytes on "$channel"');
  });

  print('Subscribed to patterns:');
  print('  - SENSOR_.*     (all sensor channels)');
  print('  - POINT_[0-9]+  (numbered point channels)');
  print('  - .*            (all channels)\n');
  
  print('Send some test messages from another process...');
  print('Press Ctrl+C to stop...');
}
