import 'package:lcm_dart/lcm_dart.dart';
import 'lib/my_messages/point_t.dart';

void main() {
  // Create a point message
  final point = PointT(
    x: 1.5,
    y: 2.5,
    z: 3.5,
  );

  print('Original point: (${point.x}, ${point.y}, ${point.z})');

  // Encode the message
  final buffer = LcmBuffer(1024);
  point.encode(buffer);
  final bytes = buffer.uint8List.sublist(0, buffer.position);
  
  print('Encoded ${buffer.position} bytes');

  // Decode the message
  final decodeBuffer = LcmBuffer.fromUint8List(bytes);
  final decoded = PointT.decode(decodeBuffer);

  print('Decoded point: (${decoded.x}, ${decoded.y}, ${decoded.z})');
  
  // Verify correctness
  assert(decoded.x == point.x);
  assert(decoded.y == point.y);
  assert(decoded.z == point.z);
  
  print('Success! Encoding and decoding works correctly.');
}
