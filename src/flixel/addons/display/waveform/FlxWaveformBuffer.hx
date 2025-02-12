package flixel.addons.display.waveform;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxDestroyUtil;
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import lime.media.howlerjs.Howl;
import lime.utils.Float32Array;

using flixel.addons.display.waveform._internal.BytesExt;

/**
 * A `FlxWaveformBuffer` holds various data related to an audio track
 * that is required for further processing.
 * @since 2.0.0
 */
class FlxWaveformBuffer implements IFlxDestroyable
{
    /**
     * The number of audio samples per second, in Hz.
     */
    public var sampleRate(default, null):Null<Float>;

    /**
     * The number of bits each audio sample takes.
     */
    public var bitsPerSample(default, null):Null<Int>;

    /**
     * The number of audio channels (1 for mono, 2 for stereo).
     */
    public var numChannels(default, null):Null<Int>;

    /**
     * Whether the buffer should be automatically destroyed when an associated
     * `FlxWaveform` instance is destroyed.
     * 
     * Set this to false if you want to reuse the same buffer on multiple waveforms,
     * at the cost of having to clean up the buffer manually.
     */
    public var autoDestroy:Bool = true;

    /**
     * Internal variable holding the actual raw audio data
     * for both audio channels.
     * 
     * Unless you have a reason to access this directly you
     * should probably use the `getChannelData()` function.
     */
    var _channels(default, null):ChannelPair;

    /**
     * Creates a `FlxWaveformBuffer` from a `lime.media.AudioBuffer`.
     * @param buffer The `lime.media.AudioBuffer` to be converted
     * @return A `FlxWaveformBuffer` or `null` if the Lime AudioBuffer isn't valid.
     */
    public static function fromLimeAudioBuffer(buffer:AudioBuffer):Null<FlxWaveformBuffer>
    {
        var bufferValid:Bool = isLimeAudioBufferValid(buffer);

        #if (js && lime_howlerjs)
        // If the buffer isn't valid anyway we might as well
        // try to get something from Howler
        @:privateAccess
        if (!bufferValid && buffer.__srcHowl != null)
            return fromHowl(cast buffer.src);
        #end

        #if flash
        @:privateAccess
        if (!bufferValid && buffer.__srcSound != null)
            return fromFlashSound(buffer.__srcSound);
        #end

        if (!bufferValid)
            return null;

        var _channels:ChannelPair = uninterleaveAndNormalize(buffer.data.toBytes(), buffer.bitsPerSample, buffer.channels == 2);
        return new FlxWaveformBuffer(buffer.sampleRate, buffer.bitsPerSample, buffer.channels, _channels);
    }

    #if js
    /**
     * Creates a `FlxWaveformBuffer` from a `js.html.audio.AudioBuffer` instance.
     * 
     * @param buffer The `js.html.audio.AudioBuffer` instance
     * @return A `FlxWaveformBuffer` or `null` if the buffer isn't valid.
     */
    public static function fromJSAudioBuffer(buffer:js.html.audio.AudioBuffer):Null<FlxWaveformBuffer>
    {
        if (!isJSAudioBufferValid(buffer))
            return null;

        var _channels:ChannelPair = new ChannelPair(cast buffer.getChannelData(0), buffer.numberOfChannels > 1 ? cast buffer.getChannelData(1) : null);
        return new FlxWaveformBuffer(buffer.sampleRate, 32, buffer.numberOfChannels, _channels);
    }

    #if lime_howlerjs
    /**
     * Creates a `FlxWaveformBuffer` from a `Howl` instance.
     * NOTE: The `Howl` sound has to have been played before
     * this function is called, otherwise it is not possible
     * to retrieve any data.
     * 
     * @param howl The `Howl` instance of the sound.
     * @return A `FlxWaveformBuffer` or `null` if it wasn't 
     * possible to get data from the `Howl` instance.
     */
    public static function fromHowl(howl:Howl):Null<FlxWaveformBuffer>
    {
        // On HTML5 Lime does not expose any kind of AudioBuffer
        // data which makes it difficult to do anything.
        // Our only hope is to try to get it from howler.js
        // TODO: This approach seems very unstable, as good as it gets right now?
        // bufferSource seems to be available DURING sound playback.
        // Attempting to access it before playing a sound will not work.
        var bufferSource:js.html.audio.AudioBufferSourceNode = untyped howl?._sounds[0]?._node?.bufferSource;
        if (bufferSource != null)
            return fromJSAudioBuffer(bufferSource.buffer);

        return null;
    }
    #end
    #end

    #if flash
    /**
     * Creates a `FlxWaveformBuffer` from a `flash.media.Sound` instance.
     * 
     * @param sound The `flash.media.Sound` instance
     * @return A `FlxWaveformBuffer` instance or `null` if the sound isn't valid.
     */
    public static function fromFlashSound(sound:flash.media.Sound):Null<FlxWaveformBuffer>
    {
        if (sound == null)
            return null;

        // These values are always hardcoded:
        // Sample rate: 44100hz
        // Channels: 2
        // Bits per sample: 32
        // https://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/media/Sound.html#extract()

        var numSamples:Float = 44100 * (sound.length / 1000);
        var length:Int = Std.int(numSamples * 2 * (32 / 8));
        var bytes:Bytes = Bytes.alloc(length);

        sound.extract(bytes.getData(), numSamples);
        var _channels:ChannelPair = uninterleaveAndNormalize(bytes, 32, true);
        bytes = null;

        return new FlxWaveformBuffer(44100, 32, 2, _channels);
    }
    #end

    /**
     * Uninterleaves and normalizes audio data in a 32bit float 
     * format ranging from -1.0 to 1.0
     * 
     * @param data Interleaved audio data
     * @param inBitsPerSample The number of bits per audio sample in the data
     * @param stereo Whether the audio data is in stereo (has 2 channels)
     * @return A `ChannelPair` instance containing the uninterleaved audio data.
     */
    static function uninterleaveAndNormalize(data:Bytes, inBitsPerSample:Int, stereo:Bool):ChannelPair
    {
        var nbytes:Int = Std.int(inBitsPerSample / 8);
        var step:Int = stereo ? nbytes * 2 : nbytes;
        var len:Int = Std.int(data.length / step);

        var left:Float32Array = new Float32Array(len);
        var right:Float32Array = null;
        if (stereo)
            right = new Float32Array(len);

        for (i in 0...len)
        {
            left[i] = getNormalizedSample(data, i * step, inBitsPerSample);
            if (stereo)
                right[i] = getNormalizedSample(data, i * step + nbytes, inBitsPerSample);
        }

        var pair:ChannelPair = new ChannelPair(left, right);
        return pair;
    }

    /**
     * Gets a 32bit float sample from the provided bytes.
     * 
     * if `bitsPerSample` is 32 it will just read the float from the bytes.
     * Otherwise it will read the integer and normalize it as a 32bit float
     * in the range of -1.0 to 1.0
     * 
     * @param data The data to read the samples from
     * @param pos The position in the bytes to read from
     * @param bitsPerSample The number of bits per audio sample in the data
     * @return Audio sample in the range of -1.0 to 1.0
     */
    static function getNormalizedSample(data:Bytes, pos:Int, bitsPerSample:Int):Float
    {
        return switch (bitsPerSample)
        {
            case 8: data.normalizeUInt8(pos);
            case 16: data.normalizeInt16(pos);
            case 24: data.normalizeInt24(pos);

            // TODO: Don't assume 32bit is float
            // Right now, we can't figure out if 32bit sounds are
            // stored as a float or int.
            // Temporarily, we'll handle it as a Float32 array 
            // as it seems they're more common.
            // If my Lime pull request gets merged it will be possible
            // to properly differentiate between 32bit int and 32bit float sounds:
            // https://github.com/openfl/lime/pull/1861
            case 32: data.getFloat(pos);
            case _: 0.0;
        }
    }

    /**
     * Checks if the `lime.media.AudioBuffer` is valid and has all
     * the data required for further processing
     * 
     * @param buffer The `lime.media.AudioBuffer` to check
     * @return Bool Whether the buffer is valid
     */
    static inline function isLimeAudioBufferValid(buffer:AudioBuffer):Bool
    {
        return buffer != null 
            && buffer.data != null 
            // on js ints can be null, but on static targets they can't.
            #if js && buffer.bitsPerSample != null #end && buffer.bitsPerSample > 0
            #if js && buffer.channels != null #end && buffer.channels > 0
            #if js && buffer.sampleRate != null #end && buffer.sampleRate > 0;
    }

    #if js
    /**
     * Checks if the `js.html.audio.AudioBuffer` is valid and has all
     * the data required for further processing
     * 
     * @param buffer The `js.html.audio.AudioBuffer` to check
     * @return Bool Whether the buffer is valid
     */
    static inline function isJSAudioBufferValid(buffer:js.html.audio.AudioBuffer):Bool
    {
        return buffer != null
            && buffer.numberOfChannels > 0
            && buffer.length > 0
            && buffer.getChannelData(0) != null;
    }
    #end

    /**
     * Creates a new `FlxWaveformBuffer` instance.
     * The buffer is not ready for data processing yet.
     * 
     * Unless you have a reason to access this directly you
     * should probably use one of the static methods 
     * to create the buffer from pre-existing data.
     * 
     * @param sampleRate The number of audio samples per second, in Hz
     * @param bitsPerSample The number of bits each audio sample takes
     * @param numChannels The number of audio channels (1 for mono, 2 for stereo)
     * @param channels A `ChannelPair` instance
     */
    function new(sampleRate:Null<Float>, bitsPerSample:Null<Int>, numChannels:Null<Int>, channels:Null<ChannelPair>):Void 
    {
        this.sampleRate = sampleRate;
        this.bitsPerSample = bitsPerSample;
        this.numChannels = numChannels;

        _channels = channels;
    }

    /**
     * Nulls all data related to the buffer.
     * The buffer is not safe to be used after this operation.
     */
    public function destroy():Void
    {
        sampleRate = null;
        bitsPerSample = null;
        numChannels = null;

        FlxDestroyUtil.destroy(_channels);
        _channels = null;
    }

    /**
     * Returns the raw audio data for the specified audio channel.
     * 
     * @param channel The audio channel (1 for mono, 2 for stereo)
     * @return Null<Float32Array> A `Float32Array` containing the raw audio data
     * or `null` if there's no audio data available for the specified channel.
     */
    inline public function getChannelData(channel:Int):Null<Float32Array>
    {
        return _channels.getChannelData(channel);
    }

    /**
     * Returns the highest sample (peak) of the audio for a specified segment.
     * 
     * @param channel The channel to get data from
     * @param startIndex The start index of the segment
     * @param endIndex The end index of the segment
     * @return The highest segment (peak) for the audio segment
     */
    public function getPeakForSegment(channel:Int, startIndex:Int, endIndex:Int):Float
    {
        var channel:Null<Float32Array> = getChannelData(channel);
        var peak:Float = 0.0;

        for (i in startIndex...endIndex)
        {
            var sample = Math.abs(channel[i]);
            if (sample > peak)
                peak = sample;
        }

        return peak;
    }

    /**
     * Returns the root mean square (RMS) of the audio for a specified segment.
     * The RMS represents the average/effective loudness of audio.
     * 
     * @param channel The channel to get data from
     * @param startIndex The start index of the segment
     * @param endIndex The end index of the segment
     * @return The RMS for the audio segment
     */
    public function getRMSForSegment(channel:Int, startIndex:Int, endIndex:Int):Float
    {
        var channel:Null<Float32Array> = getChannelData(channel);
        var numSamples:Int = endIndex - startIndex;

        // return now to avoid div by 0
        if (numSamples <= 0)
            return 0.0;

        var squareSum:Float = 0.0;

        for (i in startIndex...endIndex)
        {
            var sample = channel[i];
            squareSum += sample * sample;
        }

        return Math.sqrt(squareSum / numSamples);
    }
}

/**
 * A `ChannelPair` is a helper class containing
 * audio data for both audio channels.
 */
class ChannelPair implements IFlxDestroyable
{
    /**
     * Internal variable holding raw audio data 
     * in a 32bit float format for the left channel.
     */
    var _leftChannel:Null<Float32Array>;

    /**
     * Internal variable holding raw audio data 
     * in a 32bit float format for the right channel.
     */
    var _rightChannel:Null<Float32Array>;

    /**
     * Creates a new `ChannelPair` from two `Float32Array` instances.
     * @param left `Float32Array` instance containing 
     * audio data for the left channel
     * @param right `Float32Array` instance containing 
     * audio data for the right channel
     */
    public function new(left:Float32Array, right:Float32Array)
    {
        _leftChannel = left;
        _rightChannel = right;
    }

    /**
     * Returns a `Float32Array` containing raw audio data
     * for the specified audio channel.
     * @param channel The audio channel to get audio data for
     * @return A `Float32Array` or `null` if there's no 
     * audio data for the specified channel.
     */
    inline public function getChannelData(channel:Int):Null<Float32Array>
    {
        return switch (channel)
        {
            case 0: return _leftChannel;
            case 1: return _rightChannel;
            default: null;
        }
    }

    /**
     * Nulls all data related to the `ChannelPair`
     */
    public function destroy():Void
    {
        _leftChannel = null;
        _rightChannel = null;
    }
}
