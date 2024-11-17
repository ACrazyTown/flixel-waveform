
package flixel.addons.display.waveform;

import lime.utils.Float32Array;
import lime.utils.UInt8Array;
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import openfl.geom.Rectangle;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;

#if flash
import flash.media.Sound;
#end

using flixel.addons.display.waveform.BytesExt;

/**
 * An `FlxSprite` extension that provides an API to render waveforms.
 * 
 * @author ACrazyTown (https://github.com/acrazytown/)
 */
class FlxWaveform extends FlxSprite
{
    /* ----------- PUBLIC API ----------- */

    /**
     * Represents how many audio samples 1 pixel is equal to.
     * This value is dependant on the draw range & width of the waveform.
     */
    public var samplesPerPixel(default, null):Float;

    /**
     * An enum representing how the waveform will look visually.
     * 
     * `COMBINED` will draw both audio channels (if in stereo) onto the 
     * full area of the graphic, causing an overlap between the two.
     * 
     * `SPLIT_CHANNELS` will horizontally split the waveform into 
     * top and bottom parts, for the two audio channels.
     * The top part represents the left audio channel, 
     * while the bottom part represents the right channel.
     */
    public var waveformDrawMode(get, set):WaveformDrawMode;

    /**
     * The background color of the waveform graphic.
     */
    public var waveformBgColor(get, set):FlxColor;

    /**
     * The color used for rendering the actual waveform.
     */
    public var waveformColor(get, set):FlxColor;

    /**
     * The width of the entire waveform graphic.
     *
     * If you want to change both the width and height of the graphic
     * it is recommended to use the `resize()` function to prevent
     * a double redraw.
     */
    public var waveformWidth(get, set):Int;

    /**
     * The height of the entire waveform graphic.
     *
     * When `waveformDrawMode` is set to `SPLIT_CHANNELS`, each channel
     * will be half of `waveformHeight`.
     * 
     * If you want to change both the width and height of the graphic
     * it is recommended to use the `resize()` function to prevent
     * a double redraw.
     */
    public var waveformHeight(get, set):Int;

    /**
     * Whether the waveform graphic should be automatically 
     * regenerated when there's a change in data that would
     * affect the waveform visually.
     *
     *  If set to `false`, you have to call 
     * `FlxWaveform.generateWaveformBitmap()` to update the graphic.
     */
    public var autoUpdateBitmap:Bool = true;

    /* ----------- INTERNALS ----------- */

    /**
     * Internal variable holding a reference to a 
     * lime `AudioBuffer` used for analyzing the audio data.
     */
    var _buffer:AudioBuffer = null;

    /**
     * Internal variable that holds a reference to the 
     * Bytes representation of the lime `AudioBuffer` data
     */
    var _bufferDataBytes:Bytes;

    /**
     * Internal helper variable indicating whether the 
     * audio source is stereo (has 2 audio channels).
     */
    var _stereo:Bool = false;

    /**
     * Internal structure that holds a reference to 2 arrays 
     * holding normalized sample data for both channels.
     * The normalized sample data is an array of 
     * `Floats` that range from 0.0 to 1.0
     * 
     * If the sound is not in stereo, only the left channel array will be used.
     */
    var _normalizedSamples:NormalizedSampleData = null;

    /**
     * Internal variable holding the current start of the draw range (in miliseconds)
     */
    var _curRangeStart:Float = -1;

    /**
     * Internal variable holding the current end of the draw range (in miliseconds)
     */
    var _curRangeEnd:Float = -1;

    /**
     * Internal array of Floats that holds the values of audio peaks 
     * for the left channel from 0.0 to 1.0 in a specified time frame.
     */
    var _peaksLeft:Array<Float> = null;

    /**
     * Internal array of Floats that holds the values of audio peaks 
     * for the right channel from 0.0 to 1.0 in a specified time frame.
     */
    var _peaksRight:Array<Float> = null;

    // TODO: Move to a class or typedef?
    /**
     * Internal helper
     */
    var _waveformWidth:Int;

    /**
     * Internal helper
     */
    var _waveformHeight:Int;

    /**
     * Internal helper
     */
    var _waveformColor:FlxColor;

    /**
     * Internal helper
     */
    var _waveformBgColor:FlxColor;

    /**
     * Internal helper
     */
    var _waveformDrawMode:WaveformDrawMode;

    /**
     * Creates a new `FlxWaveform` instance with the specified draw data.
     * The waveform is not ready to display anything yet.
     *
     * In order to display anything you need to load audio buffer data
     * from one of the available `loadDataFrom` functions & specify
     * a draw range using `setDrawRange()`.
     * 
     * @param x The initial position of the sprite on the X axis.
     * @param y The initial position of the sprite on the Y axis.
     * @param width The initial width of the waveform graphic.
     * @param height The initial height of the waveform graphic.
     * @param color The color used for drawing the actual waveform.
     * @param backgroundColor The background color of the waveform graphic.
     * @param drawMode The visual appearance of the waveform. See `FlxWaveform.drawMode` for more info.
     */
    public function new(x:Float, y:Float, ?width:Int, ?height:Int, ?color:FlxColor = 0xFFFFFFFF, ?backgroundColor:FlxColor = 0x00000000, ?drawMode:WaveformDrawMode = COMBINED)
    {
        super(x, y);

        _waveformBgColor = backgroundColor;
        _waveformColor = color;
        _waveformWidth = width;
        _waveformHeight = height;
        _waveformDrawMode = drawMode;
        makeGraphic(_waveformWidth, _waveformHeight, _waveformBgColor);
    }

    /**
     * Loads the audio buffer data neccessary for processing the 
     * waveform from a HaxeFlixel `FlxSound`.
     * 
     * @param sound The FlxSound to get data from.
     */
    public function loadDataFromFlxSound(sound:FlxSound):Void
    {
        if (sound == null)
        {
            FlxG.log.error("[FlxWaveform] Waveform sound null!");
            return;
        }

        #if flash
        @:privateAccess
        var flashSound:Sound = sound._sound;

        if (flashSound == null)
        {
            FlxG.log.error("[FlxWaveform] Waveform buffer null!");
            return;
        }

        loadDataFromFlashSound(flashSound);
        #else
        @:privateAccess
        var buffer:AudioBuffer = sound?._channel?.__audioSource?.buffer;

        if (buffer == null)
        {
            @:privateAccess
            buffer = sound?._sound?.__buffer;

            if (buffer == null)
            {
                FlxG.log.error("[FlxWaveform] Waveform buffer null!");
                return;
            }
        }
        
        loadDataFromAudioBuffer(buffer);
        #end
    }

    #if flash
    /**
     * Loads the audio buffer data neccessary for processing the
     * waveform from a `flash.media.Sound`.
     * @param sound The `flash.media.Sound` to get data from.
     * @param buffer The buffer to fill with data. If null will make a new one.
     */
    public function loadDataFromFlashSound(sound:Sound, ?buffer:AudioBuffer):Void
    {
        if (buffer == null)
            buffer = new AudioBuffer();

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
    }
    #end

    /**
     * Loads the audio buffer data neccessary for processing the 
     * waveform from a `lime.media.AudioBuffer`.
     * 
     * @param buffer The `lime.media.AudioBuffer` to get data from.
     */
    public function loadDataFromAudioBuffer(buffer:AudioBuffer):Void
    {
        #if (js && html5 && lime_howlerjs)
        // On HTML5 Lime does not expose any kind of AudioBuffer
        // data which makes it difficult to do anything.
        // Our only hope is to try to get it from howler.js

        @:privateAccess
        if (!bufferValid(buffer) && buffer.__srcHowl != null)
        {
            // TODO: This approach seems very unstable, as good as it gets right now?
            // bufferSource seems to be available DURING sound playback.
            // Attempting to access it before playing a sound will not work.
            var bufferSource:js.html.audio.AudioBufferSourceNode = buffer?.src?._sounds[0]?._node?.bufferSource;
            if (bufferSource != null)
            {
                var jsBuffer:js.html.audio.AudioBuffer = bufferSource.buffer;

                // Data is always a Float32Array
                buffer.bitsPerSample = 32;
                buffer.channels = jsBuffer.numberOfChannels;
                buffer.sampleRate = Std.int(jsBuffer.sampleRate);

                var left = jsBuffer.getChannelData(0);
                var right = null;
                if (buffer.channels == 2)
                    right = jsBuffer.getChannelData(1);
                
                // convert into lime friendly format
                // TODO: How does this affect memory?
                var combined:js.lib.Float32Array = null;
                if (buffer.channels == 2)
                {
                    combined = new Float32Array(left.length * 2);
                    for (i in 0...left.length)
                    {
                        combined[i * 2] = left[i];
                        if (buffer.channels == 2)
                            combined[i * 2 + 1] = right[i];
                    }
                }

                // TODO: is it safe to cast this?
                buffer.data = buffer.channels == 2 ? cast combined : cast left;
            }
        }
        #elseif flash
        @:privateAccess
        if (!bufferValid(buffer) && buffer.__srcSound != null)
        {
            @:privateAccess
            loadDataFromFlashSound(buffer.__srcSound, buffer);
            return;
        }
        #end

        if (!bufferValid(buffer))
        {
            FlxG.log.error("[FlxWaveform] Tried to load invalid buffer! Make sure the audio buffer has valid sampleRate, bitsPerSample, channels and data.");
            return;
        }

        _buffer = buffer;
        _bufferDataBytes = _buffer.data.toBytes();
        // trace('Processing sound data (channels: ${buffer.channels}, bps: ${buffer.bitsPerSample}, sample rate: ${buffer.sampleRate})');
        // trace(buffer.data);

        if (buffer.channels == 2)
            _stereo = true;
        else if (buffer.channels == 1)
            _stereo = false;
        else
            FlxG.log.error('Unsupported channels value: ${buffer.channels}');

        _peaksLeft = recycleArray(_peaksLeft);
        if (_stereo)
            _peaksRight = recycleArray(_peaksRight);

        _normalizedSamples = switch (buffer.bitsPerSample) 
        {
            // assume unsigned?
            case 8: normalizeSamplesUI8(_bufferDataBytes, _stereo);
            case 16: normalizeSamplesI16(_bufferDataBytes, _stereo);
            case 24: normalizeSamplesI24(_bufferDataBytes, _stereo);
        
            // Right now, we can't figure out if 32bit sounds are
            // stored as a float or int.
            // Temporarily, we'll handle it as a Float32 array 
            // as it seems they're more common.
            // If my Lime pull request gets merged it will be possible
            // to properly differentiate between 32bit int and 32bit float sounds:
            // https://github.com/openfl/lime/pull/1861
            case 32: 
                normalizeSamplesF32(_bufferDataBytes, _stereo);
                //normalizeSamplesI32(_bufferDataBytes, _stereo);
                
            case _: null;
        }

        if (_normalizedSamples == null)
            FlxG.log.error('Unsupported bitsPerSample value: ${buffer.bitsPerSample}');
    }

    /**
     * Sets the time range that the waveform represents.
     * 
     * @param endTime The end of the range, in miliseconds. If not specified will be the length of the sound.
     * @param startTime The start of the range, in miliseconds. If not specified will be the start of the sound.
     */
    public function setDrawRange(?endTime:Float = -1, ?startTime:Float = -1):Void
    {
        if (!bufferValid(_buffer))
        {
            FlxG.log.error("[FlxWaveform] Can't do any operations with invalid buffer.");
            return;
        }

        if (startTime < 0)
            startTime = 0.0;
        if (endTime < 0)
            endTime = (_normalizedSamples.left.length / _buffer.sampleRate) * 1000;

        _curRangeStart = startTime;
        _curRangeEnd = endTime;

        // clear previous peak data
        clearArray(_peaksLeft);
        if (_stereo)
            clearArray(_peaksRight);

        // ? run gc to hopefully clear old data?
        // System.gc();

        var slicePos:Int = Std.int((_curRangeStart / 1000) * _buffer.sampleRate);
        var sliceEnd:Int = Std.int((_curRangeEnd / 1000) * _buffer.sampleRate);
        var sectionSamplesLeft:Array<Float> = _normalizedSamples.left.slice(slicePos, sliceEnd);
        var sectionSamplesRight:Array<Float> = null;
        if (_stereo)
            sectionSamplesRight = _normalizedSamples.right.slice(slicePos, sliceEnd);

        samplesPerPixel = Math.max(sectionSamplesLeft.length, sectionSamplesRight != null ? sectionSamplesRight.length : 0) / _waveformWidth;
        calculatePeaks(sectionSamplesLeft, _peaksLeft);
        if (_stereo)
            calculatePeaks(sectionSamplesRight, _peaksRight);
    }

    /**
     * Draws the waveform onto this sprite's graphic.
     *
     * If you have `autoUpdateBitmap` enabled, you most likely
     * do not need to call this function manually.
     */
    public function generateWaveformBitmap():Void
    {
        if (!bufferValid(_buffer))
        {
            FlxG.log.error("[FlxWaveform] Can't do any operations with invalid buffer.");
            return;
        }

        // clear previous draw
        // pixels.fillRect(new Rectangle(0, 0, waveformWidth, waveformHeight), waveformBg);
        pixels.fillRect(new Rectangle(0, 0, pixels.width, pixels.height), _waveformBgColor);

        if (waveformDrawMode == COMBINED)
        {
            var centerY:Float = _waveformHeight / 2;

            for (i in 0..._waveformWidth)
            {
                var peakLeft:Float = _peaksLeft[i];
                var peakRight:Float = 0;
                if (_stereo)
                    peakRight = _peaksRight[i];

                if ((!_stereo && peakLeft == 0) || (_stereo && peakLeft == 0 && peakRight == 0))
                    continue;

                var segmentHeightLeft:Float = peakLeft * centerY;
                var segmentHeightRight:Float = 0;
                if (_stereo)
                    segmentHeightRight = peakRight * centerY;

                var segmentHeight:Float = Math.max(segmentHeightLeft, segmentHeightRight);

                var y1:Float = centerY - segmentHeight;
                var y2:Float = centerY + segmentHeight;

                pixels.fillRect(new Rectangle(i, y1, 1, y2 - y1), _waveformColor);
            }
        }
        else if (waveformDrawMode == SPLIT_CHANNELS)
        {
            var half:Float = _waveformHeight / 2;
            var centerY:Float = _waveformHeight / 4;

            for (i in 0..._waveformWidth)
            {
                var peakLeft:Float = _peaksLeft[i];
                var peakRight:Float = 0;
                if (_stereo)
                    peakRight = _peaksRight[i];

                if ((!_stereo && peakLeft == 0) || (_stereo && peakLeft == 0 && peakRight == 0))
                    continue;

                var segmentHeightLeft:Float = peakLeft * centerY;
                var segmentHeightRight:Float = 0;
                if (_stereo)
                    segmentHeightRight = peakRight * centerY;

                var y1l:Float = centerY - segmentHeightLeft;
                var y2l:Float = centerY + segmentHeightLeft;
                var y1r:Float = half + (centerY - segmentHeightRight);
                var y2r:Float = half + (centerY + segmentHeightRight);

                pixels.fillRect(new Rectangle(i, y1l, 1, y2l - y1l), _waveformColor);
                pixels.fillRect(new Rectangle(i, y1r, 1, y2r - y1r), _waveformColor);
            }
        }
    }

    /**
     * Resizes the waveform's graphic.
     * 
     * It is recommended to use this function rather than 
     * modifying `waveformWidth` and `waveformHeight` seperately 
     * if you want to change both.
     * 
     * @param width New width of the graphic
     * @param height New height of the graphic
     */
    public function resize(width:Int, height:Int):Void
    {
        // We don't need to do this?
        // I think flixel will take care of it
        // if (graphic != null)
        //     graphic.destroy();

        makeGraphic(width, height, _waveformBgColor);
        if (autoUpdateBitmap)
            generateWaveformBitmap();
    }

    /**
     * Writes an array the size of `waveformWidth` containing audio peaks
     * for each pixel.
     * 
     * @param samples Input samples
     * @param out Output array containing peaks.
     */
    private function calculatePeaks(samples:Array<Float>, out:Array<Float>):Void
    {
        clearArray(out);
        for (i in 0..._waveformWidth)
        {
            var startIndex:Int = Math.floor(i * samplesPerPixel);
            var endIndex:Int = Std.int(Math.min(Math.ceil((i + 1) * samplesPerPixel), samples.length));

            var segment:Array<Float> = samples.slice(startIndex, endIndex);

            var peak:Float = 0.0;
            for (sample in segment)
            {
                if (sample > peak)
                    peak = sample;
            }

            out.push(peak);
        }
    }

    /**
     * Does nothing really, as Float32 data is already normalized.
     * Just seperates both channels into different arrays.
     * 
     * @param samples The audio buffer bytes data containing audio samples.
     * @param stereo Whether the data should be treated as stereo (2 channels).
     * @return A `NormalizedSampleData` containing normalized samples for both channels.
     */
    private function normalizeSamplesF32(samples:Bytes, stereo:Bool):NormalizedSampleData
    {
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
    }

    /**
     * Processes a `Bytes` instance containing audio data in 
     * a signed 32bit integer format and returns 2 arrays
     * containing normalized samples in the range from -1 to 1
     * for both audio channels.
     * 
     * @param samples The audio buffer bytes data containing audio samples.
     * @param stereo Whether the data should be treated as stereo (2 channels).
     * @return A `NormalizedSampleData` containing normalized samples for both channels.
     */
    private function normalizeSamplesI32(samples:Bytes, stereo:Bool):NormalizedSampleData
    {
        var left:Array<Float> = [];
        var right:Array<Float> = null;
        if (stereo)
            right = [];

        // Int32 is 4 bytes, times 2 for both channels.
        var step:Int = stereo ? 8 : 4;
        for (i in 0...Std.int(samples.length / step))
        {
            left.push(samples.normalizeInt32(i * step));
            if (stereo)
                right.push(samples.normalizeInt32(i * step + 4));
        }

        return {left: left, right: right};
    }

    /**
     * Processes a `Bytes` instance containing audio data in 
     * a signed 24bit integer format and returns 2 arrays
     * containing normalized samples in the range from -1 to 1
     * for both audio channels.
     * 
     * @param samples The audio buffer bytes data containing audio samples.
     * @param stereo Whether the data should be treated as stereo (2 channels).
     * @return A `NormalizedSampleData` containing normalized samples for both channels.
     */
    private function normalizeSamplesI24(samples:Bytes, stereo:Bool):NormalizedSampleData
    {
        var left:Array<Float> = [];
        var right:Array<Float> = null;
        if (stereo)
            right = [];

        // Int24 is 3 bytes, times 6 for both channels.
        var step:Int = stereo ? 6 : 3;
        for (i in 0...Std.int(samples.length / step))
        {
            left.push(samples.normalizeInt24(i * step));
            if (stereo)
                right.push(samples.normalizeInt24(i * step + 3));
        }

        return {left: left, right: right};
    }

    /**
     * Processes a `Bytes` instance containing audio data in 
     * a signed 16bit integer format and returns 2 arrays
     * containing normalized samples in the range from -1 to 1
     * for both audio channels.
     * 
     * @param samples The audio buffer bytes data containing audio samples.
     * @param stereo Whether the data should be treated as stereo (2 channels).
     * @return A `NormalizedSampleData` containing normalized samples for both channels.
     */
    private function normalizeSamplesI16(samples:Bytes, stereo:Bool):NormalizedSampleData
    {
        var left:Array<Float> = [];
        var right:Array<Float> = null;
        if (stereo)
            right = [];

        // Int16 is 2 bytes, times 2 for both channels.
        var step:Int = stereo ? 4 : 2;
        for (i in 0...Std.int(samples.length / step))
        {
            left.push(samples.normalizeInt16(i * step));
            if (stereo)
                right.push(samples.normalizeInt16(i * step + 2));
        }

        return {left: left, right: right};
    }

    /**
     * Processes a `Bytes` instance containing audio data in 
     * an unsigned 8bit integer format and returns 2 arrays
     * containing normalized samples in the range from -1 to 1
     * for both audio channels.
     * 
     * @param samples The audio buffer bytes data containing audio samples.
     * @param stereo Whether the data should be treated as stereo (2 channels).
     * @return A `NormalizedSampleData` containing normalized samples for both channels.
     */
    private function normalizeSamplesUI8(samples:Bytes, stereo:Bool):NormalizedSampleData
    {
        var left:Array<Float> = [];
        var right:Array<Float> = null;
        if (stereo)
            right = [];

        // Int8 is 1 bytes, times 2 for both channels.
        var step:Int = stereo ? 2 : 1;
        for (i in 0...Std.int(samples.length / step))
        {
            left.push(samples.normalizeUInt8(i * step));
            if (stereo)
                right.push(samples.normalizeUInt8(i * step + 1));
        }

        return {left: left, right: right};
    }

    /**
     * Clears an array in the fastest possible way.
     * 
     * @param array The array to be cleared.
     */
    private function clearArray<T>(array:Array<T>):Void
    {
        // TODO: untyped array.length = 0;
        // seems to be the fastest method, but it doesn't seem to work
        // on either C++ or HL, presumably because of Array<T>?
        #if js
        untyped array.length = 0;
        #else
        array.splice(0, array.length);
        #end
    }

    /**
     * If `array` is `null` creates a new array instance, otherwise 
     * clears the old reference and returns it
     * 
     * @param array Input array
     * @return Array<T> Output array
     */
    private function recycleArray<T>(array:Array<T>):Array<T>
    {
        if (array == null)
            return [];

        clearArray(array);
        return array;
    }

    /**
     * Checks if a `lime.media.AudioBuffer` has all the
     * properties required for rendering a waveform.
     * 
     * @param buffer Audio buffer
     * @return Whether the audio buffer is valid
     */
    private inline function bufferValid(buffer:AudioBuffer):Bool
    {
        return buffer != null 
            && buffer.data != null 
            // on js ints can be null, but on static targets they can't.
            && buffer.bitsPerSample != #if js null #else 0 #end
            && buffer.channels != #if js null #else 0 #end
            && buffer.sampleRate != #if js null #else 0 #end;
    }

    @:noCompletion private function get_waveformWidth():Int
    {
        return _waveformWidth;
    }

    @:noCompletion private function set_waveformWidth(value:Int):Int
    {
        if (_waveformWidth != value)
        {
            _waveformWidth = value;

            setDrawRange(_curRangeEnd, _curRangeStart);
            resize(_waveformWidth, _waveformHeight);
        }

        return _waveformWidth;
    }

    @:noCompletion private function get_waveformHeight():Int
    {
        return _waveformHeight;
    }

    @:noCompletion private function set_waveformHeight(value:Int):Int 
    {
        if (_waveformHeight != value)
        {
            _waveformHeight = value;

            resize(_waveformWidth, _waveformHeight);
        }

        return _waveformHeight;
    }

    @:noCompletion function get_waveformBgColor():FlxColor
    {
        return _waveformBgColor;
    }

    @:noCompletion function set_waveformBgColor(value:FlxColor):FlxColor
    {
        if (_waveformBgColor != value)
        {
            _waveformBgColor = value;

            if (autoUpdateBitmap)
                generateWaveformBitmap();
        }

        return _waveformBgColor;
    }

    @:noCompletion function get_waveformColor():FlxColor
    {
        return _waveformColor;
    }

    @:noCompletion function set_waveformColor(value:FlxColor):FlxColor
    {
        if (_waveformColor != value)
        {
            _waveformColor = value;

            if (autoUpdateBitmap)
                generateWaveformBitmap();
        }

        return _waveformColor;
    }

    @:noCompletion function get_waveformDrawMode():WaveformDrawMode
    {
        return _waveformDrawMode;
    }

    @:noCompletion function set_waveformDrawMode(value:WaveformDrawMode):WaveformDrawMode 
    {
        if (_waveformDrawMode != value)
        {
            _waveformDrawMode = value;

            if (autoUpdateBitmap)
                generateWaveformBitmap();
        }

        return _waveformDrawMode;
    }
}

// TODO: Should this be a class with structInit? Do typedefs negatively impact performance?
typedef NormalizedSampleData =
{
    left:Array<Float>,
    ?right:Array<Float>
}

enum WaveformDrawMode
{
    COMBINED;
    SPLIT_CHANNELS;
}
