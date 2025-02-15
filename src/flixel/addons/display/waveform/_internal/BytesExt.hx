package flixel.addons.display.waveform._internal;

import haxe.io.Bytes;
import flixel.math.FlxMath;

/**
 * Helper class that adds additional functionality to
 * the `haxe.io.Bytes` class.
 * 
 * Meant to be used as a [static extension](https://haxe.org/manual/lf-static-extension.html).
 * 
 * @author ACrazyTown (https://github.com/acrazytown/)
 */
class BytesExt
{
    /**
     * The minimum value of a signed 8bit integer.
     */
    inline public static final INT8_MIN:Int = -128;

    /**
     * The maximum value of a signed 8bit integer.
     */
    inline public static final INT8_MAX:Int = 127;

    /**
     * The maximum value of an unsigned 8bit integer.
     */
    inline public static final UINT8_MAX:Int = 255;

    /**
     * The minimum value of a signed 16bit integer.
     */
    inline public static final INT16_MIN:Int = -32768;

    /**
     * The maximum value of a signed 16bit integer.
     */
    inline public static final INT16_MAX:Int = 32767;

    /**
     * The maximum value of an unsigned 16bit integer.
     */
    inline public static final UINT16_MAX:Int = 65535;

    /**
     * The minimum value of a signed 24bit integer.
     */
    inline public static final INT24_MIN:Int = -8388608;

    /**
     * The maximum value of a signed 24bit integer.
     */
    inline public static final INT24_MAX:Int = 8388607;

    /**
     * The minimum value of a signed 32bit integer.
     */
    inline public static final INT32_MIN:Int = -2147483648;

    /**
     * The maximum value of a signed 32bit integer.
     */
    inline public static final INT32_MAX:Int = 2147483647;

    /**
     * Reads a signed 16bit integer at the specified position.
     * @param bytes Bytes to read from
     * @param pos Position to read from 
     * @return Read value
     */
    inline public static function getInt16(bytes:Bytes, pos:Int):Int
    {
        return (bytes.getUInt16(pos) << 16) >> 16;
    }

    /**
     * Reads an unsigned 24bit integer at the specified position.
     * @param bytes Bytes to read from
     * @param pos Position to read from 
     * @return Read value
     */
    inline public static function getUInt24(bytes:Bytes, pos:Int):Int
    {
        return bytes.get(pos) | (bytes.get(pos + 1) << 8) | (bytes.get(pos + 2) << 16);
    }

    /**
     * Reads a signed 24bit integer at the specified position.
     * @param bytes Bytes to read from
     * @param pos Position to read from 
     * @return Read value
     */
    inline public static function getInt24(bytes:Bytes, pos:Int):Int
    {
        return (getUInt24(bytes, pos) << 8) >> 8;
    }

    /**
     * Reads & normalizes an unsigned 8bit integer in the range of -1 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    inline public static function normalizeUInt8(bytes:Bytes, pos:Int):Float
    {
        // bytes.get() returns an unsigned int8?
        return FlxMath.remapToRange(bytes.get(pos), 0, UINT8_MAX, -1, 1);
    }

    /**
     * Reads & normalizes a signed 16bit integer in the range of -1 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    inline public static function normalizeInt16(bytes:Bytes, pos:Int):Float
    {
        return FlxMath.remapToRange(getInt16(bytes, pos), INT16_MIN, INT16_MAX, -1, 1);
    }

    /**
     * Reads & normalizes a signed 24bit integer in the range of -1 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    inline public static function normalizeInt24(bytes:Bytes, pos:Int):Float
    {
        return FlxMath.remapToRange(getInt24(bytes, pos), INT24_MIN, INT24_MAX, -1, 1);
    }

    /**
     * Reads & normalizes a signed 32bit integer in the range of -1 to 1.
     * @param bytes Bytes to read from
     * @param pos Position to read from
     * @return Normalized value
     */
    inline public static function normalizeInt32(bytes:Bytes, pos:Int):Float
    {
        return FlxMath.remapToRange(bytes.getInt32(pos), INT32_MIN, INT32_MAX, -1, 1);
    }
}
