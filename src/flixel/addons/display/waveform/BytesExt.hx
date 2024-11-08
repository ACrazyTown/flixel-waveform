package flixel.addons.display.waveform;

import haxe.io.Bytes;

/**
 * Helper class that adds additional functionality to
 * the `haxe.io.Bytes` class.
 * 
 * Meant to be used as a [static extension](https://haxe.org/manual/lf-static-extension.html).
 */
class BytesExt
{
    /**
     * The maximum value of a signed 8bit integer.
     */
    public static inline final INT8_MAX:Int = 128;

    /**
     * The maximum value of an unsigned 8bit integer.
     */
    public static inline final UINT8_MAX:Int = 255;

    /**
     * The maximum value of a signed 16bit integer.
     */
    public static inline final INT16_MAX:Int = 32767;

    /**
     * The maximum value of an unsigned 16bit integer.
     */
    public static inline final UINT16_MAX:Int = 65535;

    /**
     * The maximum value of a signed 32bit integer.
     */
    public static inline final INT32_MAX:Int = 2147483647;

    /**
     * Reads an signed 16bit integer at the specified position.
     * @param bytes Bytes to read from
     * @param pos Position to read from 
     * @return Read value
     */
    public static inline function getInt16(bytes:Bytes, pos:Int):Int
    {
        return (bytes.getUInt16(pos) << 16) >> 16;
    }

    /**
     * Reads & normalizes an unsigned 8bit integer in the range of 0 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    public static inline function normalizeUInt8(bytes:Bytes, pos:Int):Float
    {
        // bytes.get() returns an unsigned int8?
        return bytes.get(pos) / UINT8_MAX;
    }

    /**
     * Reads & normalizes a signed 16bit integer in the range of 0 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    public static inline function normalizeInt16(bytes:Bytes, pos:Int):Float
    {
        return getInt16(bytes, pos) / INT16_MAX;
    }

    /**
     * Reads & normalizes a signed 32bit integer in the range of 0 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    public static inline function normalizeInt32(bytes:Bytes, pos:Int):Float
    {
        return bytes.getInt32(pos) / INT32_MAX;
    }
}
