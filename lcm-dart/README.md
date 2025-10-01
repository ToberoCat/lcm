# LCM Dart

Dart bindings and code generator for LCM (Lightweight Communications and Marshalling).

## Features

- Automatic Dart code generation from `.lcm` message definitions using `build_runner`
- Type-safe message encoding and decoding
- Support for all LCM primitive types and arrays
- Integration with Dart's build system

## Installation

1. First, ensure you have LCM installed with `lcm-gen` in your PATH:
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

2. Add `lcm_dart` to your `pubspec.yaml`:
   ```yaml
   dependencies:
     lcm_dart: ^1.5.1
   
   dev_dependencies:
     build_runner: ^2.4.0
   ```

3. Run `dart pub get` to install dependencies.

## Usage

### 1. Create LCM Message Definitions

Create your `.lcm` files in the `lib/` directory of your Dart project:

```lcm
// lib/messages/example_t.lcm
package my_messages;

struct example_t
{
    int64_t  timestamp;
    double   position[3];
    string   name;
}
```

### 2. Generate Dart Code

Run build_runner to generate Dart code from your `.lcm` files:

```bash
dart run build_runner build
```

Or for continuous generation during development:

```bash
dart run build_runner watch
```

This will generate a `.dart` file for each `.lcm` file in your project.

### 3. Use Generated Classes

```dart
import 'package:lcm_dart/lcm_dart.dart';
import 'messages/example_t.dart';

void main() {
  // Create a message
  final msg = example_t(
    timestamp: DateTime.now().millisecondsSinceEpoch,
    position: [1.0, 2.0, 3.0],
    name: 'test',
  );

  // Encode the message
  final buffer = LcmBuffer(1024);
  msg.encode(buffer);
  final bytes = buffer.uint8List.sublist(0, buffer.position);

  // Decode the message
  final decodeBuffer = LcmBuffer.fromUint8List(bytes);
  final decoded = example_t.decode(decodeBuffer);

  print('Timestamp: ${decoded.timestamp}');
  print('Position: ${decoded.position}');
  print('Name: ${decoded.name}');
}
```

## LCM Type System

The Dart generator supports all LCM types:

| LCM Type | Dart Type |
|----------|-----------|
| `int8_t` | `int` |
| `int16_t` | `int` |
| `int32_t` | `int` |
| `int64_t` | `int` |
| `byte` | `int` |
| `float` | `double` |
| `double` | `double` |
| `string` | `String` |
| `boolean` | `bool` |
| Custom structs | Generated classes |

Arrays are represented as `List<T>` in Dart.

## Manual Code Generation

If you prefer not to use build_runner, you can generate code manually:

```bash
lcm-gen --dart --dart-path=lib/generated my_message.lcm
```

## Requirements

- Dart SDK 3.0.0 or later
- LCM with `lcm-gen` installed and in PATH

## License

This package is part of the LCM project and is licensed under the LGPL.

## Links

- [LCM Project](https://lcm-proj.github.io/)
- [LCM GitHub](https://github.com/lcm-proj/lcm)
