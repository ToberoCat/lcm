# Fix for Nested Type Initialization in Java

## Problem

Prior to this fix, when using an LCM type as a scalar field in another LCM message in Java, the nested type was not automatically initialized in the constructor. This caused `NullPointerException` when trying to encode the message.

### Example Problem Code

```java
// Before fix
cross_package_t msg = new cross_package_t();
// msg.primitives was null!
// msg.another was null!

// This would throw NullPointerException
msg.encode(outs);
```

## Solution

Modified `lcmgen/emit_java.c` to automatically initialize scalar nested user types in constructors. The fix distinguishes between:

1. **Scalar nested types** - NOW INITIALIZED: `inner_type_t scalar_field;`
2. **Fixed-size arrays** - Already initialized: `inner_type_t fixed_array[3];`
3. **Variable-size arrays** - Not initialized (correct): `inner_type_t var_array[count];`

### Example After Fix

```java
// After fix
cross_package_t msg = new cross_package_t();
// msg.primitives is now automatically initialized!
// msg.another is now automatically initialized!

// Can now set values directly
msg.primitives.i8 = 42;
msg.another.val = 123;

// Encoding works!
msg.encode(outs);
```

## Code Changes

### File: `lcmgen/emit_java.c` (lines 638-667)

**Before:**
```c
emit(1, "public %s()", structure->structname->shortname);
emit(1, "{");

// pre-allocate any fixed-size arrays.
for (unsigned int member = 0; member < g_ptr_array_size(structure->members); member++) {
    lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(structure->members, member);
    primitive_info_t *pinfo =
        (primitive_info_t *) g_hash_table_lookup(type_table, lm->type->lctypename);

    if (g_ptr_array_size(lm->dimensions) == 0 || !lcm_is_constant_size_array(lm))
        continue;
    // ... initialize arrays
}
```

**After:**
```c
emit(1, "public %s()", structure->structname->shortname);
emit(1, "{");

// Initialize scalar nested user types and pre-allocate any fixed-size arrays.
for (unsigned int member = 0; member < g_ptr_array_size(structure->members); member++) {
    lcm_member_t *lm = (lcm_member_t *) g_ptr_array_index(structure->members, member);
    primitive_info_t *pinfo =
        (primitive_info_t *) g_hash_table_lookup(type_table, lm->type->lctypename);

    // NEW: Initialize scalar nested user types (non-primitive, zero dimensions)
    if (pinfo == NULL && g_ptr_array_size(lm->dimensions) == 0) {
        emit(2, "%s = new %s();", lm->membername, make_fqn(lcm, lm->type->lctypename));
        continue;
    }

    if (g_ptr_array_size(lm->dimensions) == 0 || !lcm_is_constant_size_array(lm))
        continue;
    // ... initialize arrays
}
```

## Testing

### New Test: `test/java/lcmtest/TestNestedTypeInit.java`

Added comprehensive JUnit tests that verify:
1. Nested types are automatically initialized (not null)
2. Fixed-size arrays within nested types are also initialized
3. Encode/decode round-trip works correctly with initialized nested types

### Manual Testing

All manual tests pass, including:
- Simple nested type encoding/decoding
- Array of nested types
- Cross-package references
- C++ tests remain unaffected (C++ uses value semantics, not references)

## Impact

This fix only affects Java code generation. Other language bindings are not affected:
- **C++**: Uses value semantics, nested types are always initialized
- **Python**: Dynamic typing, no initialization issues
- **C**: Uses structs, users must initialize
- **Go**: Similar to C++

## Backwards Compatibility

This change is **backwards compatible**. Code that explicitly initializes nested types will continue to work. The only difference is that code that forgets to initialize will now work instead of throwing `NullPointerException`.

### Before Fix (error-prone)
```java
cross_package_t msg = new cross_package_t();
msg.primitives = new primitives_t();  // User must remember this
msg.another = new another_type_t();   // User must remember this
// ... set values
```

### After Fix (automatic, safer)
```java
cross_package_t msg = new cross_package_t();
// msg.primitives and msg.another are already initialized!
// ... set values directly
```
