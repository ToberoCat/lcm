# LCM Dart Examples

This directory contains examples demonstrating how to use the LCM Dart client for publishing and subscribing to messages.

## Examples

### 1. Basic Encoding/Decoding (`main.dart`)

Demonstrates basic message encoding and decoding without networking:

```bash
dart run main.dart
```

This example:
- Creates a `point_t` message
- Encodes it to bytes
- Decodes it back
- Verifies correctness

### 2. Publisher (`publisher.dart`)

Publishes `point_t` messages on the "POINTS" channel every second:

```bash
dart run publisher.dart
```

This example demonstrates:
- Creating an LCM client
- Publishing messages periodically
- Message encoding

### 3. Subscriber (`subscriber.dart`)

Subscribes to the "POINTS" channel and prints received messages:

```bash
dart run subscriber.dart
```

This example demonstrates:
- Creating an LCM client
- Subscribing to a channel
- Message decoding
- Handling received messages

### 4. Pattern Subscriber (`pattern_subscriber.dart`)

Demonstrates regex-based channel subscription:

```bash
dart run pattern_subscriber.dart
```

This example shows:
- Pattern-based subscriptions (e.g., `SENSOR_.*`)
- Multiple subscriptions with different patterns
- Wildcard subscriptions

## Running Publisher and Subscriber Together

To see the pub/sub system in action:

1. In one terminal, start the subscriber:
   ```bash
   dart run subscriber.dart
   ```

2. In another terminal, start the publisher:
   ```bash
   dart run publisher.dart
   ```

You should see the subscriber receiving and printing the messages sent by the publisher.

## Network Configuration

By default, all examples use localhost-only multicast (TTL=0). This is the safest setting for development and testing.

To communicate across machines on the same network, modify the code to use TTL=1:

```dart
final lcm = await Lcm.create('udpm://239.255.76.67:7667?ttl=1');
```

**Warning:** Use TTL>1 only if you understand the implications for your network.

## Message Definitions

The examples use the `point_t` message defined in `lib/my_messages/point_t.lcm`:

```lcm
package my_messages;

struct point_t
{
    double x;
    double y;
    double z;
}
```

The corresponding Dart code is generated in `lib/my_messages/point_t.dart`.

## Interoperability

These examples are compatible with LCM implementations in other languages (Python, C++, Java, etc.) as long as they:

1. Use the same multicast address and port
2. Use compatible message definitions
3. Have matching TTL settings for network reach

## Troubleshooting

### Messages not being received

1. Check that both publisher and subscriber are using the same channel name
2. Verify the multicast address and port match
3. Ensure your firewall allows UDP multicast traffic
4. Try increasing the TTL if communicating across machines

### Permission errors

On some systems, binding to multicast addresses may require elevated privileges. Try running with `sudo` if you encounter permission errors.

## Further Reading

- [LCM Documentation](https://lcm-proj.github.io/)
- [Dart Tutorial](../../docs/content/tutorial-dart.md)
- [LCM Dart README](../README.md)
