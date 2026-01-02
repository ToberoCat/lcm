import '../parser/ast.dart';

/// Calculator for LCM type fingerprints
///
/// The fingerprint is a 64-bit hash that uniquely identifies a message type.
/// It's used for runtime type checking when decoding messages.
class FingerprintCalculator {
  /// Compute the fingerprint for a struct
  ///
  /// Returns the final fingerprint value (not the base hash)
  int computeFingerprint(StructDecl struct) {
    final baseHash = computeStructHash(struct);
    return _transformToFingerprint(baseHash);
  }

  /// Compute the base hash for a struct (before fingerprint transformation)
  int computeStructHash(StructDecl struct) {
    int v = 0x12345678;

    for (final member in struct.members) {
      // Hash the member name
      v = _hashStringUpdate(v, member.name);

      // If the member is a primitive type, include the type signature
      // Do not include compound types - their contents will be included instead
      if (member.type.isPrimitive) {
        v = _hashStringUpdate(v, member.type.fullName);
      }

      // Hash the dimensionality information
      final ndim = member.dimensions.length;
      v = _hashUpdate(v, ndim);

      for (final dim in member.dimensions) {
        // Hash the dimension mode: 0 for constant, 1 for variable
        v = _hashUpdate(v, dim.isConstant ? 0 : 1);
        // Hash the size string
        v = _hashStringUpdate(v, dim.size);
      }
    }

    return v;
  }

  /// Transform a base hash to a fingerprint
  ///
  /// Uses the formula: (hash << 1) + (hash >> 63)
  /// with unsigned 64-bit arithmetic
  int _transformToFingerprint(int hash) {
    // Use >>> for logical (unsigned) right shift
    return ((hash << 1) + (hash >>> 63)).toSigned(64);
  }

  /// Update hash with a single byte value
  ///
  /// Formula: ((v << 8) ^ (v >> 55)) + c
  int _hashUpdate(int v, int c) {
    // Use arithmetic right shift (>>) to match C's int64_t behavior
    return ((v << 8) ^ (v >> 55)) + c;
  }

  /// Update hash with a string
  ///
  /// First hashes the length, then each character
  int _hashStringUpdate(int v, String s) {
    v = _hashUpdate(v, s.length);
    for (final c in s.codeUnits) {
      v = _hashUpdate(v, c);
    }
    return v;
  }
}
