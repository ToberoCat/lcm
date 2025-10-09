import org.junit.Test;
import static org.junit.Assert.*;

import java.io.*;
import lcmtest2.cross_package_t;
import lcmtest2.another_type_t;
import lcmtest.primitives_t;

/**
 * Test that nested LCM types are properly initialized in constructors.
 * This prevents NullPointerException when encoding messages with nested types.
 */
public class TestNestedTypeInit {
    
    @Test
    public void testNestedTypesAreInitialized() {
        cross_package_t msg = new cross_package_t();
        
        // Nested types should be automatically initialized, not null
        assertNotNull("primitives field should be initialized", msg.primitives);
        assertNotNull("another field should be initialized", msg.another);
        
        // Fixed-size arrays within nested types should also be initialized
        assertNotNull("primitives.position should be initialized", msg.primitives.position);
        assertNotNull("primitives.orientation should be initialized", msg.primitives.orientation);
        assertEquals("primitives.position should have size 3", 3, msg.primitives.position.length);
        assertEquals("primitives.orientation should have size 4", 4, msg.primitives.orientation.length);
    }
    
    @Test
    public void testEncodeDecodeWithInitializedNestedTypes() throws IOException {
        cross_package_t msg = new cross_package_t();
        
        // Set values on the auto-initialized nested types
        msg.primitives.i8 = 42;
        msg.primitives.i16 = 100;
        msg.primitives.i64 = 1000;
        msg.primitives.num_ranges = 2;
        msg.primitives.ranges = new short[]{10, 20};
        msg.primitives.position[0] = 1.0f;
        msg.primitives.position[1] = 2.0f;
        msg.primitives.position[2] = 3.0f;
        msg.primitives.orientation[0] = 1.0;
        msg.primitives.orientation[1] = 2.0;
        msg.primitives.orientation[2] = 3.0;
        msg.primitives.orientation[3] = 4.0;
        msg.primitives.name = "test";
        msg.primitives.enabled = true;
        msg.another.val = 123;
        
        // Encode
        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        DataOutputStream outs = new DataOutputStream(bout);
        msg.encode(outs);
        byte[] data = bout.toByteArray();
        
        // Decode
        cross_package_t decoded = new cross_package_t(data);
        
        // Verify values
        assertEquals(42, decoded.primitives.i8);
        assertEquals(100, decoded.primitives.i16);
        assertEquals(1000, decoded.primitives.i64);
        assertEquals(2, decoded.primitives.num_ranges);
        assertEquals(10, decoded.primitives.ranges[0]);
        assertEquals(20, decoded.primitives.ranges[1]);
        assertEquals(1.0f, decoded.primitives.position[0], 0.001f);
        assertEquals("test", decoded.primitives.name);
        assertTrue(decoded.primitives.enabled);
        assertEquals(123, decoded.another.val);
    }
}
