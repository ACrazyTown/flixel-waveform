package flixel.addons.display.waveform;

import lime.media.howlerjs.Howl;
import lime.utils.Float32Array;
import haxe.io.Bytes;
import lime.media.AudioBuffer;

using flixel.addons.display.waveform.BytesExt;

class ChannelPair
{
    var _leftChannel:Null<Float32Array>;
    var _rightChannel:Null<Float32Array>;

    public function new(left:Float32Array, right:Float32Array)
    {
        _leftChannel = left;
        _rightChannel = right;
    }

    inline public function getChannelData(channel:Int):Null<Float32Array>
    {
        return switch (channel)
        {
            case 0: return _leftChannel;
            case 1: return _rightChannel;
            default: null;
        }
    }

    public function dispose():Void
    {
        _leftChannel = null;
        _rightChannel = null;
    }
}

/**
 * A `FlxWaveformBuffer` holds various data related to an audio track
 * that is required for further processing.
 */
class FlxWaveformBuffer
{
    /**
     * The number of audio samples per second, in Hz.
     */
    public var sampleRate:Null<Float>;

    /**
     * The number of bits each audio sample takes.
     */
    public var bitsPerSample:Null<Int>;

    /**
     * The number of audio channels (1 for mono, 2 for stereo).
     */
    public var numChannels:Null<Int>;

    /**
     * Internal variable holding the actual raw audio data
     * for both audio channels.
     * 
     * Unless you have a reason to access this directly you
     * should probably use the `getChannelData()` function.
     */
    var _channels:ChannelPair;

    /**
     * Creates a `FlxWaveformBuffer` from a `lime.media.AudioBuffer`.
     * @param buffer The `lime.media.AudioBuffer` to be converted
     * @return A `FlxWaveformBuffer` or `null` if the Lime AudioBuffer isn't valid.
     */
    public static function fromLimeAudioBuffer(buffer:AudioBuffer):Null<FlxWaveformBuffer>
    {
        #if (js && lime_howlerjs)
        // If the buffer isn't valid anyway we might as well
        // try to get something from Howler
        @:privateAccess
        if (!isLimeAudioBufferValid(buffer) && buffer.__srcHowl != null)
            return fromHowl(cast buffer.src);
        #end

        // TODO: Flash

        if (!isLimeAudioBufferValid(buffer))
            return null;

        var _buffer:FlxWaveformBuffer = new FlxWaveformBuffer();
        _buffer.sampleRate = buffer.sampleRate;
        _buffer.bitsPerSample = buffer.bitsPerSample;
        _buffer.numChannels = buffer.channels;

        _buffer._channels = uninterleaveAndNormalize(buffer.data.toBytes(), buffer.bitsPerSample, buffer.channels == 2);

        return _buffer;
    }

    #if js
    public static function fromJSAudioBuffer(buffer:js.html.audio.AudioBuffer):Null<FlxWaveformBuffer>
    {
        // TODO: check if valid

        var _buffer:FlxWaveformBuffer = new FlxWaveformBuffer();
        _buffer.sampleRate = buffer.sampleRate;
        _buffer.bitsPerSample = 32; // always 32 on web?
        _buffer.numChannels = buffer.numberOfChannels;

        @:privateAccess _buffer._channels._leftChannel = cast buffer.getChannelData(0);
        if (_buffer.numChannels > 1)
            @:privateAccess _buffer._channels._rightChannel = cast buffer.getChannelData(1);

        return _buffer;
    }

    #if lime_howlerjs
    /**
     * Creates a `FlxWaveformBuffer` from a `Howl` instance.
     * NOTE: The `Howl` sound has to have been played before
     * this function is called, otherwise it is not possible
     * to retrieve any data.
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
        {
            var buffer:FlxWaveformBuffer = new FlxWaveformBuffer();
            var jsBuffer:js.html.audio.AudioBuffer = bufferSource.buffer;

            return fromJSAudioBuffer(jsBuffer);
        }

        return null;
    }
    #end
    #end

    #if flash
    public static function fromFlashSound(sound:flash.media.Sound):Null<FlxWaveformBuffer>
    {
        /*
        // These values are always hardcoded.
        // https://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/media/Sound.html#extract()
        buffer.sampleRate = 44100;
        buffer.channels = 2;
        buffer.bitsPerSample = 32;

        var numSamples:Float = 44100 * (sound.length / 1000);
        var length:Int = Std.int(numSamples * 2 * 4);
        var bytes:Bytes = Bytes.alloc(length);

        sound.extract(bytes.getData(), numSamples);
        buffer.data = UInt8Array.fromBytes(bytes);

        loadDataFromAudioBuffer(buffer);
        */

        var _buffer:FlxWaveformBuffer = new FlxWaveformBuffer();

        // These values are always hardcoded.
        // https://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/media/Sound.html#extract()
        _buffer.sampleRate = 44100;
        _buffer.bitsPerSample = 32;
        _buffer.numChannels = 2;

        var numSamples:Float = _buffer.sampleRate * (sound.length / 1000);
        var length:Int = Std.int(numSamples * _buffer.numChannels * (_buffer.bitsPerSample / 8));
        var bytes:Bytes = Bytes.alloc(length);

        sound.extract(bytes.getData(), numSamples);

        _buffer._channels = uninterleaveAndNormalize(bytes, _buffer.bitsPerSample, true);

        return _buffer;
    }
    #end

    static function uninterleaveAndNormalize(data:Bytes, inBitsPerSample:Int, stereo:Bool):ChannelPair
    {
        /*
        var left:Array<Float> = [];
        var right:Array<Float> = null;
        if (stereo)
            right = [];

        // Int32 is 4 bytes, times 2 for both channels.
        var step:Int = stereo ? 8 : 4;
        for (i in 0...Std.int(samples.length / step))
        {
            left.push(samples.getFloat(i * step));
            if (stereo)
                right.push(samples.getFloat(i * step + 4));
        }

        return {left: left, right: right};
        */

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
     * @param buffer The `lime.media.AudioBuffer` to check
     * @return Bool Whether the buffer is valid
     */
    static inline function isLimeAudioBufferValid(buffer:AudioBuffer):Bool
    {
        return buffer != null 
            && buffer.data != null 
            // on js ints can be null, but on static targets they can't.
            && buffer.bitsPerSample != #if js null #else 0 #end
            && buffer.channels != #if js null #else 0 #end
            && buffer.sampleRate != #if js null #else 0 #end;
    }

    public function new():Void 
    {
        sampleRate = null;
        bitsPerSample = null;
        numChannels = null;

        _channels = new ChannelPair(null, null);
    }

    /**
     * Returns the raw audio data for the specified audio channel.
     * @param channel The audio channel (1 for mono, 2 for stereo)
     * @return Null<Float32Array> A `Float32Array` containing the raw audio data
     * or `null` if there's no audio data available for the specified channel.
     */
    inline public function getChannelData(channel:Int):Null<Float32Array>
    {
        return _channels.getChannelData(channel);
    }

    public function dispose():Void
    {
        sampleRate = null;
        bitsPerSample = null;
        numChannels = null;

        if (_channels != null)
        {
            _channels.dispose();
            _channels = null;
        }
    }
}
