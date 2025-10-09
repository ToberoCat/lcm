import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:lcm_dart/lcm_dart.dart';

void main() {
  group('LCM Client', () {
    test('can be created with default settings', () async {
      final lcm = await Lcm.create();
      expect(lcm, isNotNull);
      lcm.close();
    });

    test('can publish and receive short messages', () async {
      final lcm = await Lcm.create();
      final completer = Completer<bool>();
      
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      // Subscribe before publishing
      lcm.subscribe('TEST_CHANNEL', (channel, data) {
        expect(channel, equals('TEST_CHANNEL'));
        expect(data, equals(testData));
        completer.complete(true);
      });

      // Give subscription time to register
      await Future.delayed(Duration(milliseconds: 100));

      // Publish message
      lcm.publish('TEST_CHANNEL', testData);

      // Wait for message to be received (with timeout)
      final received = await completer.future.timeout(
        Duration(seconds: 2),
        onTimeout: () => false,
      );

      expect(received, isTrue);
      lcm.close();
    });

    test('can handle multiple subscribers on same channel', () async {
      final lcm = await Lcm.create();
      final completer1 = Completer<bool>();
      final completer2 = Completer<bool>();
      
      final testData = Uint8List.fromList([10, 20, 30]);
      
      // Subscribe with two handlers
      lcm.subscribe('MULTI', (channel, data) {
        expect(data, equals(testData));
        completer1.complete(true);
      });

      lcm.subscribe('MULTI', (channel, data) {
        expect(data, equals(testData));
        completer2.complete(true);
      });

      await Future.delayed(Duration(milliseconds: 100));

      // Publish message
      lcm.publish('MULTI', testData);

      // Wait for both to receive
      final results = await Future.wait([
        completer1.future.timeout(Duration(seconds: 2), onTimeout: () => false),
        completer2.future.timeout(Duration(seconds: 2), onTimeout: () => false),
      ]);

      expect(results[0], isTrue);
      expect(results[1], isTrue);
      lcm.close();
    });

    test('supports regex pattern matching', () async {
      final lcm = await Lcm.create();
      final receivedChannels = <String>[];
      final completer = Completer<void>();
      var count = 0;
      
      // Subscribe with pattern
      lcm.subscribe('SENSOR_.*', (channel, data) {
        receivedChannels.add(channel);
        count++;
        if (count == 2) {
          completer.complete();
        }
      });

      await Future.delayed(Duration(milliseconds: 100));

      // Publish to matching channels
      lcm.publish('SENSOR_1', Uint8List.fromList([1]));
      lcm.publish('SENSOR_2', Uint8List.fromList([2]));
      
      // Publish to non-matching channel (should not trigger handler)
      lcm.publish('OTHER', Uint8List.fromList([3]));

      await completer.future.timeout(Duration(seconds: 2));

      expect(receivedChannels, hasLength(2));
      expect(receivedChannels, contains('SENSOR_1'));
      expect(receivedChannels, contains('SENSOR_2'));
      expect(receivedChannels, isNot(contains('OTHER')));
      
      lcm.close();
    });

    test('can unsubscribe from channel', () async {
      final lcm = await Lcm.create();
      var messageCount = 0;
      
      final subscription = lcm.subscribe('UNSUB_TEST', (channel, data) {
        messageCount++;
      });

      await Future.delayed(Duration(milliseconds: 100));

      // Publish first message
      lcm.publish('UNSUB_TEST', Uint8List.fromList([1]));
      await Future.delayed(Duration(milliseconds: 200));
      
      expect(messageCount, equals(1));

      // Unsubscribe
      lcm.unsubscribe(subscription);
      
      // Publish second message (should not be received)
      lcm.publish('UNSUB_TEST', Uint8List.fromList([2]));
      await Future.delayed(Duration(milliseconds: 200));
      
      // Count should still be 1
      expect(messageCount, equals(1));
      
      lcm.close();
    });

    test('throws error when channel name is too long', () async {
      final lcm = await Lcm.create();
      
      final longChannel = 'A' * 100;
      expect(
        () => lcm.publish(longChannel, Uint8List.fromList([1])),
        throwsA(isA<ArgumentError>()),
      );
      
      lcm.close();
    });
  });
}
