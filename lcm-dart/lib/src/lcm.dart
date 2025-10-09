import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'lcm_buffer.dart';

/// LCM protocol constants
const int _lcmMagicShort = 0x4c433032; // ASCII "LC02"
const int _lcmMagicLong = 0x4c433033; // ASCII "LC03"
const int _lcmShortMessageMaxSize = 65499;
const int _lcmFragmentMaxPayload = 65487;
const int _maxChannelNameLength = 63;

/// Default LCM multicast address and port
const String _defaultNetwork = '239.255.76.67';
const int _defaultPort = 7667;
const int _defaultTtl = 0;

/// Callback type for message handlers
typedef LcmMessageHandler = void Function(String channel, Uint8List data);

/// Subscription object that can be used to unsubscribe
class LcmSubscription {
  final RegExp _pattern;
  final LcmMessageHandler _handler;

  LcmSubscription._(this._pattern, this._handler);
}

/// Main LCM client class for publishing and subscribing to messages
/// over UDP multicast.
class Lcm {
  RawDatagramSocket? _sendSocket;
  RawDatagramSocket? _recvSocket;
  InternetAddress? _multicastAddress;
  int _port = _defaultPort;
  int _ttl = _defaultTtl;
  int _messageSequenceNumber = 0;
  bool _closed = false;

  final List<LcmSubscription> _subscriptions = [];
  final Map<int, _FragmentBuffer> _fragmentBuffers = {};
  StreamSubscription<RawSocketEvent>? _recvSubscription;

  /// Create a new LCM instance with the given provider URL.
  ///
  /// The URL format is: `udpm://[network[:port]]?ttl=[ttl]`
  ///
  /// If no URL is provided, defaults to `udpm://239.255.76.67:7667?ttl=0`
  ///
  /// Examples:
  /// - `udpm://239.255.76.67:7667` - Standard LCM multicast
  /// - `udpm://239.255.76.67:7667?ttl=1` - LCM with TTL 1
  ///
  /// Note: TTL=0 means packets never leave localhost.
  /// TTL=1 means packets stay on local network.
  static Future<Lcm> create([String? provider]) async {
    final lcm = Lcm._();
    await lcm._initialize(provider);
    return lcm;
  }

  Lcm._();

  Future<void> _initialize(String? provider) async {
    _parseProvider(provider);

    // Create send socket
    _sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _sendSocket!.multicastHops = _ttl;
    _sendSocket!.broadcastEnabled = true;

    // Create receive socket
    _recvSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _recvSocket!.multicastHops = _ttl;
    _recvSocket!.readEventsEnabled = true;

    // Join multicast group
    _multicastAddress = InternetAddress(_defaultNetwork);
    _recvSocket!.joinMulticast(_multicastAddress!);

    // Set up receive handler
    _recvSubscription = _recvSocket!.listen(_handleSocketEvent);
  }

  void _parseProvider(String? provider) {
    if (provider == null || provider.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(provider);
    if (uri == null || uri.scheme != 'udpm') {
      throw ArgumentError('Invalid LCM provider URL. Expected format: udpm://[address[:port]]?ttl=[ttl]');
    }

    if (uri.host.isNotEmpty) {
      // Parse network address and port from host
      final hostParts = uri.host.split(':');
      _defaultNetwork; // Keep default if not specified
      if (hostParts.isNotEmpty && hostParts[0].isNotEmpty) {
        // Use provided network address
      }
      if (uri.hasPort) {
        _port = uri.port;
      }
    }

    // Parse query parameters
    final ttlStr = uri.queryParameters['ttl'];
    if (ttlStr != null) {
      _ttl = int.tryParse(ttlStr) ?? _defaultTtl;
      if (_ttl == 0) {
        stderr.writeln('LCM: TTL set to zero, traffic will not leave localhost.');
      } else if (_ttl > 1) {
        stderr.writeln('LCM: TTL set to > 1... That\'s almost never correct!');
      }
    }
  }

  /// Publish a message on the given channel.
  ///
  /// [channel] - The channel name (max 63 characters)
  /// [data] - The message data to publish
  ///
  /// Returns the number of bytes sent, or throws an exception on error.
  int publish(String channel, Uint8List data) {
    if (_closed) {
      throw StateError('LCM instance has been closed');
    }

    if (channel.length > _maxChannelNameLength) {
      throw ArgumentError('Channel name too long: ${channel.length} > $_maxChannelNameLength');
    }

    final channelBytes = channel.codeUnits;
    final payloadSize = channelBytes.length + 1 + data.length;

    if (payloadSize <= _lcmShortMessageMaxSize) {
      return _publishShort(channel, channelBytes, data);
    } else {
      return _publishFragmented(channel, channelBytes, data);
    }
  }

  int _publishShort(String channel, List<int> channelBytes, Uint8List data) {
    // Create header
    final headerSize = 8; // magic (4) + seqno (4)
    final packetSize = headerSize + channelBytes.length + 1 + data.length;
    final packet = Uint8List(packetSize);
    final buffer = LcmBuffer.fromUint8List(packet);

    // Write header
    buffer.putUint32(_lcmMagicShort);
    buffer.putUint32(_messageSequenceNumber++);

    // Write channel name (null-terminated)
    buffer.putUint8List(channelBytes);
    buffer.putUint8(0);

    // Write data
    buffer.putUint8List(data);

    // Send packet
    final bytesSent = _sendSocket!.send(packet, _multicastAddress!, _port);
    return bytesSent;
  }

  int _publishFragmented(String channel, List<int> channelBytes, Uint8List data) {
    final fragmentSize = _lcmFragmentMaxPayload;
    final payloadSize = channelBytes.length + 1 + data.length;
    final numFragments = (payloadSize / fragmentSize).ceil();

    if (numFragments > 65535) {
      throw ArgumentError('Message too large to fragment');
    }

    final seqno = _messageSequenceNumber++;
    var fragmentOffset = 0;
    var dataOffset = 0;

    // Send first fragment (includes channel name)
    final firstFragmentDataSize = fragmentSize - (channelBytes.length + 1);
    _sendFragment(
      seqno,
      data.length,
      0,
      0,
      numFragments,
      channel,
      channelBytes,
      data.sublist(0, firstFragmentDataSize),
    );
    dataOffset += firstFragmentDataSize;
    fragmentOffset += firstFragmentDataSize;

    // Send remaining fragments
    for (var fragNo = 1; fragNo < numFragments; fragNo++) {
      final fragDataSize = (dataOffset + fragmentSize <= data.length)
          ? fragmentSize
          : data.length - dataOffset;

      _sendFragment(
        seqno,
        data.length,
        fragmentOffset,
        fragNo,
        numFragments,
        channel,
        null,
        data.sublist(dataOffset, dataOffset + fragDataSize),
      );

      dataOffset += fragDataSize;
      fragmentOffset += fragDataSize;
    }

    return data.length;
  }

  void _sendFragment(
    int seqno,
    int msgSize,
    int fragmentOffset,
    int fragmentNo,
    int fragmentsInMsg,
    String channel,
    List<int>? channelBytes,
    Uint8List fragmentData,
  ) {
    // Calculate packet size
    final headerSize = 20; // magic (4) + seqno (4) + msg_size (4) + frag_offset (4) + frag_no (2) + frags_in_msg (2)
    final channelSize = (channelBytes != null) ? channelBytes.length + 1 : 0;
    final packetSize = headerSize + channelSize + fragmentData.length;

    final packet = Uint8List(packetSize);
    final buffer = LcmBuffer.fromUint8List(packet);

    // Write header
    buffer.putUint32(_lcmMagicLong);
    buffer.putUint32(seqno);
    buffer.putUint32(msgSize);
    buffer.putUint32(fragmentOffset);
    buffer.putUint16(fragmentNo);
    buffer.putUint16(fragmentsInMsg);

    // Write channel name for first fragment
    if (channelBytes != null) {
      buffer.putUint8List(channelBytes);
      buffer.putUint8(0);
    }

    // Write fragment data
    buffer.putUint8List(fragmentData);

    // Send packet
    _sendSocket!.send(packet, _multicastAddress!, _port);
  }

  /// Subscribe to messages on the given channel.
  ///
  /// [channel] - Channel name or regex pattern to subscribe to
  /// [handler] - Callback function to handle received messages
  ///
  /// Returns an [LcmSubscription] object that can be used to unsubscribe.
  LcmSubscription subscribe(String channel, LcmMessageHandler handler) {
    if (_closed) {
      throw StateError('LCM instance has been closed');
    }

    // Convert channel to regex (LCM channels are implicitly anchored)
    final pattern = RegExp('^$channel\$');
    final subscription = LcmSubscription._(pattern, handler);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Unsubscribe from a channel.
  ///
  /// [subscription] - The subscription object returned by [subscribe]
  void unsubscribe(LcmSubscription subscription) {
    _subscriptions.remove(subscription);
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _recvSocket!.receive();
      if (datagram != null) {
        _handleDatagram(datagram);
      }
    }
  }

  void _handleDatagram(Datagram datagram) {
    final data = datagram.data;
    if (data.length < 8) {
      // Too short to be valid LCM packet
      return;
    }

    final buffer = LcmBuffer.fromUint8List(data);
    final magic = buffer.getUint32();

    if (magic == _lcmMagicShort) {
      _handleShortMessage(buffer, data);
    } else if (magic == _lcmMagicLong) {
      _handleFragmentedMessage(buffer, data, datagram.address);
    }
  }

  void _handleShortMessage(LcmBuffer buffer, Uint8List data) {
    // Skip sequence number (not needed for dispatching)
    buffer.getUint32();

    // Read channel name (null-terminated)
    final channelStart = buffer.position;
    var channelEnd = channelStart;
    while (channelEnd < data.length && data[channelEnd] != 0) {
      channelEnd++;
    }

    if (channelEnd >= data.length) {
      // Invalid packet: no null terminator
      return;
    }

    final channel = String.fromCharCodes(data.sublist(channelStart, channelEnd));
    buffer.position = channelEnd + 1; // Skip null terminator

    // Extract message data
    final messageData = data.sublist(buffer.position);

    // Dispatch to subscribers
    _dispatchMessage(channel, messageData);
  }

  void _handleFragmentedMessage(LcmBuffer buffer, Uint8List data, InternetAddress from) {
    final seqno = buffer.getUint32();
    final msgSize = buffer.getUint32();
    final fragmentOffset = buffer.getUint32();
    final fragmentNo = buffer.getUint16();
    final fragmentsInMsg = buffer.getUint16();

    // Create fragment buffer key
    final key = _makeFragmentKey(from, seqno);

    // Get or create fragment buffer
    var fragBuf = _fragmentBuffers[key];
    if (fragBuf == null || fragBuf.dataSize != msgSize) {
      // Clean up old fragment buffer if present
      _fragmentBuffers.remove(key);

      fragBuf = _FragmentBuffer(
        seqno: seqno,
        dataSize: msgSize,
        fragmentsRemaining: fragmentsInMsg,
      );
      _fragmentBuffers[key] = fragBuf;
    }

    // Read channel name if this is the first fragment
    if (fragmentNo == 0) {
      final channelStart = buffer.position;
      var channelEnd = channelStart;
      while (channelEnd < data.length && data[channelEnd] != 0) {
        channelEnd++;
      }

      if (channelEnd >= data.length) {
        // Invalid packet
        _fragmentBuffers.remove(key);
        return;
      }

      fragBuf.channel = String.fromCharCodes(data.sublist(channelStart, channelEnd));
      buffer.position = channelEnd + 1;
    }

    // Copy fragment data
    final fragmentData = data.sublist(buffer.position);
    final copyLength = fragmentData.length;
    
    if (fragmentOffset + copyLength > msgSize) {
      // Invalid fragment
      _fragmentBuffers.remove(key);
      return;
    }

    fragBuf.data!.setRange(fragmentOffset, fragmentOffset + copyLength, fragmentData);
    fragBuf.fragmentsRemaining--;

    // Check if message is complete
    if (fragBuf.fragmentsRemaining == 0) {
      _dispatchMessage(fragBuf.channel!, fragBuf.data!);
      _fragmentBuffers.remove(key);
    }
  }

  int _makeFragmentKey(InternetAddress from, int seqno) {
    // Simple key: combine address hash and sequence number
    return from.hashCode ^ seqno;
  }

  void _dispatchMessage(String channel, Uint8List data) {
    for (final subscription in _subscriptions) {
      if (subscription._pattern.hasMatch(channel)) {
        try {
          subscription._handler(channel, data);
        } catch (e, stackTrace) {
          stderr.writeln('Error in LCM message handler for channel $channel: $e');
          stderr.writeln(stackTrace);
        }
      }
    }
  }

  /// Close the LCM instance and release all resources.
  void close() {
    if (_closed) {
      return;
    }

    _closed = true;
    _recvSubscription?.cancel();
    _recvSocket?.close();
    _sendSocket?.close();
    _subscriptions.clear();
    _fragmentBuffers.clear();
  }
}

/// Internal class to track fragmented messages being reassembled
class _FragmentBuffer {
  final int seqno;
  final int dataSize;
  String? channel;
  Uint8List? data;
  int fragmentsRemaining;

  _FragmentBuffer({
    required this.seqno,
    required this.dataSize,
    required this.fragmentsRemaining,
  }) {
    data = Uint8List(dataSize);
  }
}
