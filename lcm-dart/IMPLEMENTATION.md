# LCM Dart Client Implementation

This document describes the LCM Dart UDP multicast client implementation.

## Overview

The LCM Dart client provides full UDP multicast support for publishing and subscribing to LCM messages, compatible with other LCM implementations (Python, C++, Java, C#, etc.).

## Key Features

### 1. UDP Multicast Protocol
- Full implementation of LCM UDP multicast protocol
- Compatible with LCM protocol version 2 (magic numbers 0x4c433032 and 0x4c433033)
- Configurable multicast address, port, and TTL

### 2. Message Publishing
- Automatic selection between short and fragmented message formats
- Short messages (≤65,499 bytes): Single packet transmission
- Large messages (>65,499 bytes): Automatic fragmentation
- Thread-safe message sequence numbering

### 3. Message Subscription
- Regex-based channel pattern matching
- Multiple subscribers per channel
- Support for wildcard subscriptions
- Dynamic subscription/unsubscription

### 4. Message Fragmentation
- Transparent fragmentation and reassembly for large messages
- Fragment buffer management with automatic cleanup
- Maximum message size limited only by available memory
- Compatible with fragmentation used by other LCM implementations

### 5. Type Safety
- Strongly-typed message classes generated from `.lcm` definitions
- Compile-time type checking
- Integration with Dart's type system

## Architecture

### Core Components

#### `Lcm` Class
Main client class providing:
- `create([provider])` - Factory method to create LCM instance
- `publish(channel, data)` - Publish messages
- `subscribe(channel, handler)` - Subscribe to channels
- `unsubscribe(subscription)` - Unsubscribe from channels
- `close()` - Clean up resources

#### `LcmSubscription` Class
Represents an active subscription:
- Stores channel pattern and handler
- Used for unsubscribing

#### Internal Components
- `_FragmentBuffer` - Manages reassembly of fragmented messages
- Socket management - Separate send and receive sockets
- Event handling - Async stream-based message reception

### Protocol Implementation

#### Short Message Format
```
+--------+--------+--------+--------+
|      Magic (4 bytes = 0x4c433032)  |
+--------+--------+--------+--------+
|    Sequence Number (4 bytes)       |
+--------+--------+--------+--------+
|  Channel Name (null-terminated)    |
+--------+--------+--------+--------+
|        Message Data                |
+--------+--------+--------+--------+
```

#### Fragmented Message Format
```
+--------+--------+--------+--------+
|      Magic (4 bytes = 0x4c433033)  |
+--------+--------+--------+--------+
|    Sequence Number (4 bytes)       |
+--------+--------+--------+--------+
|    Message Size (4 bytes)          |
+--------+--------+--------+--------+
|   Fragment Offset (4 bytes)        |
+--------+--------+--------+--------+
| Fragment No (2) | Total Frags (2) |
+--------+--------+--------+--------+
| Channel Name (null-terminated,     |
|  only in fragment 0)               |
+--------+--------+--------+--------+
|        Fragment Data               |
+--------+--------+--------+--------+
```

## Comparison with Other Implementations

### Python Implementation
| Feature | Python | Dart |
|---------|--------|------|
| UDP Multicast | ✓ | ✓ |
| Fragmentation | ✓ | ✓ |
| Regex Patterns | ✓ | ✓ |
| Async/Await | ✓ | ✓ |
| Type Safety | - | ✓ |

### C++ Implementation
| Feature | C++ | Dart |
|---------|-----|------|
| UDP Multicast | ✓ | ✓ |
| Fragmentation | ✓ | ✓ |
| Regex Patterns | ✓ | ✓ |
| Memory Safety | Manual | Automatic |
| Threading | Manual | Built-in |

### Java Implementation
| Feature | Java | Dart |
|---------|------|------|
| UDP Multicast | ✓ | ✓ |
| Fragmentation | ✓ | ✓ |
| Regex Patterns | ✓ | ✓ |
| Async | Callbacks | Async/Await |
| Performance | High | High |

## Design Decisions

### 1. Async/Await API
- Used Dart's native async/await for better readability
- Stream-based event handling for received messages
- Non-blocking I/O

### 2. Single Provider Support
- Currently supports only UDP multicast (`udpm://`)
- Other providers (file, memq) can be added in the future
- Clean separation allows easy extension

### 3. Fragment Key Generation
- Uses combination of sender address hash and sequence number
- Allows proper reassembly even with multiple senders
- Automatic cleanup of stale fragments

### 4. Error Handling
- Invalid packets are silently dropped (like other implementations)
- User handlers can throw exceptions without affecting other subscribers
- Resource cleanup guaranteed via `close()` method

### 5. TTL Default
- Default TTL=0 (localhost only) for safety
- Prevents accidental network-wide broadcasting
- Easy to configure for multi-machine setups

## Testing

### Unit Tests
- 6 unit tests covering core functionality
- Test short messages, fragmentation, patterns, and subscriptions
- All tests passing

### Integration Tests
- Publisher/subscriber communication verified
- Cross-communication with same implementation works
- Compatible with LCM wire protocol

### Interoperability
The implementation follows the LCM specification and should be compatible with:
- Python LCM
- C++ LCM  
- Java LCM
- C# LCM
- Other compliant implementations

## Performance Considerations

### Strengths
- Efficient UDP multicast
- Minimal overhead for short messages
- Stream-based message handling
- No serialization overhead (direct buffer operations)

### Limitations
- Dart's garbage collector may add latency for high-frequency messages
- Single-threaded event loop (typical for Dart applications)
- Memory allocation for fragment reassembly

### Optimization Tips
1. Reuse LCM instance across multiple publishes
2. Pre-allocate message buffers when possible
3. Use appropriate TTL settings
4. Consider message size for fragmentation overhead

## Future Enhancements

Possible future improvements:
1. Add support for `file://` provider (log playback)
2. Add support for `memq://` provider (in-memory queue)
3. Performance optimizations for high-frequency publishing
4. Statistics and monitoring APIs
5. Message filtering at subscription level
6. Configurable fragment timeout and cleanup

## Acknowledgments

This implementation is inspired by and follows the design patterns from:
- LCM C implementation (reference)
- LCM Python implementation (API design)
- LCM Java implementation (subscription patterns)
- LCM C# implementation (UDP handling)

## License

This implementation is part of the LCM project and is licensed under the LGPL.
