import 'dart:async';
import 'dart:typed_data';
import 'package:lcm_dart/lcm_dart.dart';
import 'lib/my_messages/point_t.dart';

/// Comprehensive example showing all LCM Dart client features
void main() async {
  print('=== LCM Dart Comprehensive Example ===\n');

  // 1. Create LCM instance
  print('1. Creating LCM instance...');
  final lcm = await Lcm.create();
  print('   ✓ LCM instance created (default settings)\n');

  // 2. Set up multiple subscriptions
  print('2. Setting up subscriptions...');
  
  var pointsReceived = 0;
  var sensorsReceived = 0;
  var allMessagesReceived = 0;

  // Subscribe to specific channel
  final pointsSub = lcm.subscribe('POINTS', (channel, data) {
    final buffer = LcmBuffer.fromUint8List(data);
    final point = point_t.decode(buffer);
    pointsReceived++;
    print('   [POINTS] Received: (${point.x}, ${point.y}, ${point.z})');
  });

  // Subscribe with pattern
  lcm.subscribe('SENSOR_.*', (channel, data) {
    sensorsReceived++;
    print('   [PATTERN] Sensor data on $channel: ${data.length} bytes');
  });

  // Subscribe to all channels (wildcard)
  lcm.subscribe('.*', (channel, data) {
    allMessagesReceived++;
  });

  print('   ✓ Three subscriptions created\n');

  // Give subscriptions time to register
  await Future.delayed(Duration(milliseconds: 100));

  // 3. Publish different types of messages
  print('3. Publishing messages...');

  // Publish to POINTS channel
  for (var i = 0; i < 3; i++) {
    final point = point_t(
      x: i * 1.0,
      y: i * 2.0,
      z: i * 3.0,
    );
    final buffer = LcmBuffer(1024);
    point.encode(buffer);
    lcm.publish('POINTS', buffer.uint8List.sublist(0, buffer.position));
    await Future.delayed(Duration(milliseconds: 50));
  }

  // Publish to sensor channels (matches pattern)
  for (var i = 1; i <= 2; i++) {
    final sensorData = Uint8List.fromList([i, i * 2, i * 3]);
    lcm.publish('SENSOR_$i', sensorData);
    await Future.delayed(Duration(milliseconds: 50));
  }

  // Publish to other channel (doesn't match pattern)
  lcm.publish('OTHER', Uint8List.fromList([42]));
  await Future.delayed(Duration(milliseconds: 50));

  print('   ✓ All messages published\n');

  // Wait for messages to be received
  await Future.delayed(Duration(milliseconds: 500));

  // 4. Test unsubscribe
  print('4. Testing unsubscribe...');
  lcm.unsubscribe(pointsSub);
  print('   ✓ Unsubscribed from POINTS\n');

  // Publish another POINTS message (should not be received)
  final testPoint = point_t(x: 99.0, y: 99.0, z: 99.0);
  final testBuffer = LcmBuffer(1024);
  testPoint.encode(testBuffer);
  lcm.publish('POINTS', testBuffer.uint8List.sublist(0, testBuffer.position));
  
  await Future.delayed(Duration(milliseconds: 200));

  // 5. Display statistics
  print('5. Statistics:');
  print('   - Points received: $pointsReceived (expected: 3)');
  print('   - Sensors received: $sensorsReceived (expected: 2)');
  print('   - All messages: $allMessagesReceived (expected: 7)');
  print('');

  // Verify results
  final success = pointsReceived == 3 && 
                  sensorsReceived == 2 && 
                  allMessagesReceived == 7;

  if (success) {
    print('✓ All tests passed!');
  } else {
    print('✗ Some tests failed');
  }

  // 6. Clean up
  print('\n6. Cleaning up...');
  lcm.close();
  print('   ✓ LCM instance closed\n');

  print('=== Example Complete ===');
}
