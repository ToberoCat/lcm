# Dart Tutorial

This tutorial covers how to use LCM with Dart, including code generation and basic usage patterns.

## Introduction

LCM provides a Dart code generator that creates type-safe classes from `.lcm` message definitions. The Dart package includes:

1. A code generator (`lcm-gen --dart`)
2. Runtime support library (`lcm_dart`)
3. Integration with Dart's `build_runner` for automatic code generation

## Installation

### Installing LCM

First, ensure you have LCM installed with `lcm-gen`:

```bash
# On Ubuntu/Debian
sudo apt-get install liblcm-dev

# Or build from source
git clone https://github.com/lcm-proj/lcm
cd lcm
mkdir build && cd build
cmake ..
make
sudo make install
```

Verify installation:
```bash
lcm-gen --version
```

### Setting up a Dart Project

Create a new Dart project or use an existing one:

```bash
dart create my_lcm_project
cd my_lcm_project
```

Add `lcm_dart` to your `pubspec.yaml`:

```yaml
dependencies:
  lcm_dart: ^1.5.1

dev_dependencies:
  build_runner: ^2.4.0
```

Install dependencies:
```bash
dart pub get
```

## Defining Message Types

Create your LCM message definitions in the `lib/` directory. LCM uses a simple syntax for defining structured data types:

### Example 1: Simple Message

Create `lib/my_point_t.lcm`:

```lcm
package my_messages;

struct my_point_t
{
    double x;
    double y;
    double z;
}
```

### Example 2: Complex Message

Create `lib/pose_t.lcm`:

```lcm
package my_messages;

struct pose_t
{
    int64_t timestamp;
    double position[3];
    double orientation[4];
}
```

### Example 3: Variable-Length Arrays

Create `lib/sensor_data_t.lcm`:

```lcm
package my_messages;

struct sensor_data_t
{
    int64_t timestamp;
    int32_t num_readings;
    double readings[num_readings];
    string sensor_name;
}
```

### Example 4: Nested Messages

Create `lib/robot_state_t.lcm`:

```lcm
package my_messages;

struct robot_state_t
{
    int64_t timestamp;
    my_point_t position;
    my_point_t velocity;
}
```

## Generating Dart Code

### Using build_runner (Recommended)

The easiest way to generate code is using `build_runner`:

```bash
# Generate code once
dart run build_runner build

# Or watch for changes and regenerate automatically
dart run build_runner watch
```

This will find all `.lcm` files in your `lib/` directory and generate corresponding `.dart` files.

### Manual Generation

You can also generate code manually using `lcm-gen`:

```bash
lcm-gen --dart --dart-path=lib lib/my_point_t.lcm
```

This creates `lib/my_messages/my_point_t.dart`.

## Using Generated Code

### Basic Usage

```dart
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/my_point_t.dart';

void main() {
  // Create a message
  final point = my_point_t(
    x: 1.5,
    y: 2.5,
    z: 3.5,
  );

  // Encode the message
  final buffer = LcmBuffer(1024);
  point.encode(buffer);
  final bytes = buffer.uint8List.sublist(0, buffer.position);

  // Decode the message
  final decodeBuffer = LcmBuffer.fromUint8List(bytes);
  final decoded = my_point_t.decode(decodeBuffer);

  print('Point: (${decoded.x}, ${decoded.y}, ${decoded.z})');
}
```

### Working with Arrays

```dart
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/pose_t.dart';

void main() {
  final pose = pose_t(
    timestamp: DateTime.now().millisecondsSinceEpoch,
    position: [1.0, 2.0, 3.0],
    orientation: [1.0, 0.0, 0.0, 0.0], // quaternion
  );

  // Access array elements
  print('X position: ${pose.position[0]}');
  print('Y position: ${pose.position[1]}');
  print('Z position: ${pose.position[2]}');
}
```

### Variable-Length Arrays

```dart
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/sensor_data_t.dart';

void main() {
  final data = sensor_data_t(
    timestamp: DateTime.now().millisecondsSinceEpoch,
    num_readings: 5,
    readings: [1.1, 2.2, 3.3, 4.4, 5.5],
    sensor_name: 'IMU',
  );

  // Encode and decode
  final buffer = LcmBuffer(1024);
  data.encode(buffer);
  
  final bytes = buffer.uint8List.sublist(0, buffer.position);
  final decoded = sensor_data_t.decode(
    LcmBuffer.fromUint8List(bytes)
  );

  print('Sensor: ${decoded.sensor_name}');
  print('Readings: ${decoded.readings}');
}
```

### Nested Messages

```dart
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/robot_state_t.dart';
import 'my_messages/my_point_t.dart';

void main() {
  final state = robot_state_t(
    timestamp: DateTime.now().millisecondsSinceEpoch,
    position: my_point_t(x: 1.0, y: 2.0, z: 0.0),
    velocity: my_point_t(x: 0.5, y: 0.0, z: 0.0),
  );

  print('Robot position: (${state.position.x}, ${state.position.y})');
  print('Robot velocity: (${state.velocity.x}, ${state.velocity.y})');
}
```

## Type System

LCM types map to Dart types as follows:

| LCM Type | Dart Type | Notes |
|----------|-----------|-------|
| `int8_t` | `int` | 8-bit signed integer |
| `int16_t` | `int` | 16-bit signed integer |
| `int32_t` | `int` | 32-bit signed integer |
| `int64_t` | `int` | 64-bit signed integer |
| `byte` | `int` | Unsigned 8-bit integer |
| `float` | `double` | 32-bit floating point |
| `double` | `double` | 64-bit floating point |
| `string` | `String` | UTF-8 encoded string |
| `boolean` | `bool` | Boolean value |
| Custom structs | Generated class | User-defined types |
| `type[N]` | `List<type>` | Fixed-size array |
| `type[var]` | `List<type>` | Variable-size array |

## Constants

LCM supports constants in message definitions:

```lcm
package my_messages;

struct config_t
{
    const int32_t MAX_SIZE = 100;
    const double PI = 3.14159;
    
    int32_t size;
    double scale;
}
```

These are generated as static constants in Dart:

```dart
print('Max size: ${config_t.MAX_SIZE}');
print('PI: ${config_t.PI}');
```

## Best Practices

### 1. Use Packages

Always define a package for your messages:

```lcm
package my_app.messages;

struct my_message_t { ... }
```

This prevents naming conflicts and organizes generated code.

### 2. Timestamp Convention

Use `int64_t` for timestamps (milliseconds since epoch):

```lcm
struct my_message_t
{
    int64_t timestamp;
    // ... other fields
}
```

### 3. Version Your Messages

When updating message definitions, consider using a version field:

```lcm
struct my_message_t
{
    int32_t version;  // increment when changing format
    // ... other fields
}
```

### 4. Buffer Sizing

Allocate enough buffer space for encoding. A safe approach is to estimate:

```dart
// For fixed-size messages
final buffer = LcmBuffer(1024);

// For messages with variable-length arrays
final estimatedSize = 8 + // fingerprint
                      myMessage.data.length * 8 + 
                      100; // safety margin
final buffer = LcmBuffer(estimatedSize);
```

### 5. Error Handling

Always handle potential errors:

```dart
try {
  final decoded = my_message_t.decode(buffer);
  // Process message
} catch (e) {
  print('Failed to decode message: $e');
}
```

## Integration with LCM Networking

The LCM Dart package includes a full UDP multicast client for publishing and subscribing to messages over the network.

### Publishing Messages

To publish messages over LCM:

```dart
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/my_point_t.dart';

void main() async {
  // Create LCM instance (uses default multicast address)
  final lcm = await Lcm.create();

  // Create and encode a message
  final point = my_point_t(x: 1.0, y: 2.0, z: 3.0);
  final buffer = LcmBuffer(1024);
  point.encode(buffer);
  final bytes = buffer.uint8List.sublist(0, buffer.position);

  // Publish to channel
  lcm.publish('MY_POINTS', bytes);

  // Clean up when done
  lcm.close();
}
```

### Subscribing to Messages

To receive messages from LCM:

```dart
import 'dart:typed_data';
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/my_point_t.dart';

void main() async {
  // Create LCM instance
  final lcm = await Lcm.create();

  // Subscribe to a channel
  lcm.subscribe('MY_POINTS', (String channel, Uint8List data) {
    // Decode the message
    final buffer = LcmBuffer.fromUint8List(data);
    final point = my_point_t.decode(buffer);
    
    print('Received point: (${point.x}, ${point.y}, ${point.z})');
  });

  // Program keeps running to receive messages
  // Call lcm.close() when shutting down
}
```

### Channel Patterns

LCM supports regex patterns for subscribing to multiple channels:

```dart
// Subscribe to all sensor channels
lcm.subscribe('SENSOR_.*', (channel, data) {
  print('Received sensor data on $channel');
});

// Subscribe to numbered channels
lcm.subscribe('ROBOT_[0-9]+_STATUS', (channel, data) {
  print('Robot status on $channel');
});

// Subscribe to all channels
lcm.subscribe('.*', (channel, data) {
  print('Received ${data.length} bytes on $channel');
});
```

### Custom Network Configuration

You can customize the multicast address, port, and TTL:

```dart
// Default configuration (localhost only, TTL=0)
final lcm1 = await Lcm.create();

// Specify custom settings
final lcm2 = await Lcm.create('udpm://239.255.76.67:7667?ttl=1');
```

**TTL Settings:**
- `ttl=0`: Packets never leave localhost (default, safest for development)
- `ttl=1`: Packets stay on local network, don't cross routers
- `ttl>1`: Use with caution - packets may cross network boundaries

### Unsubscribing

To stop receiving messages on a channel:

```dart
final subscription = lcm.subscribe('MY_CHANNEL', myHandler);

// Later...
lcm.unsubscribe(subscription);
```

### Complete Example: Publisher/Subscriber

**Publisher (`publisher.dart`):**
```dart
import 'dart:async';
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/sensor_data_t.dart';

void main() async {
  final lcm = await Lcm.create();
  var counter = 0;

  Timer.periodic(Duration(seconds: 1), (timer) {
    final msg = sensor_data_t(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      values: List.generate(10, (i) => i * 1.5),
    );

    final buffer = LcmBuffer(1024);
    msg.encode(buffer);
    lcm.publish('SENSOR_DATA', buffer.uint8List.sublist(0, buffer.position));

    print('Published message ${counter++}');
  });
}
```

**Subscriber (`subscriber.dart`):**
```dart
import 'dart:typed_data';
import 'package:lcm_dart/lcm_dart.dart';
import 'my_messages/sensor_data_t.dart';

void main() async {
  final lcm = await Lcm.create();

  lcm.subscribe('SENSOR_DATA', (channel, data) {
    final buffer = LcmBuffer.fromUint8List(data);
    final msg = sensor_data_t.decode(buffer);
    
    print('Received: timestamp=${msg.timestamp}, '
          'values.length=${msg.values.length}');
  });

  print('Listening for messages...');
}
```

### Large Messages and Fragmentation

LCM automatically handles fragmentation for messages larger than 65KB. The implementation:

- Messages ≤ 65,499 bytes: Sent as single packet
- Messages > 65,499 bytes: Automatically fragmented and reassembled
- Maximum message size: Limited by available memory

You don't need to handle fragmentation manually - it's transparent to your application.

## Troubleshooting

### lcm-gen not found

Ensure `lcm-gen` is in your PATH:

```bash
which lcm-gen
```

If not found, install LCM or add its bin directory to PATH.

### Generated files not found

Make sure to run `dart run build_runner build` after creating or modifying `.lcm` files.

### Type errors

Ensure the generated Dart code matches your LCM definitions. Regenerate if needed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Further Reading

- [LCM Type Specification](lcm-type-ref.md)
- [LCM Website](https://lcm-proj.github.io/)
- [LCM GitHub](https://github.com/lcm-proj/lcm)
