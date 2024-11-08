
package flixel.addons.display.waveform;

import haxe.io.Bytes;
import lime.media.AudioBuffer;
import openfl.system.System;
import openfl.geom.Rectangle;
import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flixel.FlxSprite;

using flixel.addons.display.waveform.BytesExt;

/**
 * An `FlxSprite` extension that provides an API to render waveforms.
 * 
 * @author ACrazyTown (https://github.com/acrazytown/)
 */
class FlxWaveform extends FlxSprite
{
    /**
     * Represents how many audio samples 1 pixel is equal to.
     */
    public var samplesPerPixel(default, null):Float;

    /**
     * How the waveform will be rendered.
     * 
     * `COMBINED` will draw both channels onto a single sprite.
     * 
     * `SPLIT_CHANNELS` will split the sprite in half, one half will render the left channel while the other will render the right channel.
     */
    public var waveformDrawMode(default, set):WaveformDrawMode;

    /**
     * The background color of the waveform graphic.
     */
    public var waveformBg(default, set):FlxColor;

    /**
     * The color used for rendering the actual waveform.
     */
    public var waveformColor(default, set):FlxColor;

    /**
     * The width of the waveform.
     */
    public var waveformWidth(default, set):Int = FlxG.width;

    /**
     * The height of the entire waveform sprite.
     * 
     * if waveformDrawMode is set to `SPLIT_CHANNELS` the height of one waveform will be half of `waveformHeight`
     */
    public var waveformHeight(default, set):Int = FlxG.height;

    /**
     * Whether the waveform graphic should be automatically regenerated when there's a change in data.
     *
     *  If set to `false`, you have to call `FlxWaveform.generateWaveformBitmap()` to update the graphic.
     */
    public var autoUpdateBitmap:Bool = true;

    /**
     * Internal variable holding a reference to a lime `AudioBuffer` used for analyzing the audio data.
     */
    var _buffer:AudioBuffer = null;

    /**
     * Internal variable that holds a reference to the Bytes representation of the lime `AudioBuffer` data
     */
    var _bufferDataBytes:Bytes;

    /**
     * Internal helper variable indicating whether the audio source is stereo (has 2 audio channels).
     */
    var _stereo:Bool = false;

    /**
     * Internal structure that holds a reference to 2 arrays holding normalized sample data for both channels.
     * The normalized sample data is an array of `Floats` that range from 0.0 to 1.0
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
     * Internal array of Floats that holds the values of audio peaks for the left channel from 0.0 to 1.0 in a specified time frame.
     */
    var _peaksLeft:Array<Float> = null;

    /**
     * Internal array of Floats that holds the values of audio peaks for the right channel from 0.0 to 1.0 in a specified time frame.
     */
    var _peaksRight:Array<Float> = null;

    /**
     * Creates a new `Waveform` instance. The waveform is NOT ready to display any data at this point.
     * 
     * You need to load data, set a draw range and generate the waveform bitmap in order for it to display anything.
     * 
     * @param x The X position of the waveform
     * @param y The Y position of the waveform
     * @param width The width of the waveform
     * @param height The height of the waveform 
     * @param color The color of the waveform audio data
     * @param backgroundColor The background color of the waveform
     * @param drawMode The rendering method the waveform will use, see `waveform.drawMode` for additional info
     */
    public function new(x:Float, y:Float, ?width:Int, ?height:Int, ?color:FlxColor = 0xFFFFFFFF, ?backgroundColor:FlxColor = 0x00000000, ?drawMode:WaveformDrawMode = COMBINED)
    {
        super(x, y);

        waveformBg = backgroundColor;
        waveformColor = color;
        waveformWidth = width;
        waveformHeight = height;
        waveformDrawMode = drawMode;
        makeGraphic(waveformWidth, waveformHeight, waveformBg);
    }

    /**
     * Loads raw audio data neccessary for drawing the waveform from a flixel `FlxSound`
     * @param sound The FlxSound
     */
    public function loadDataFromFlxSound(sound:FlxSound):Void
    {
        if (sound == null)
        {
            FlxG.log.error("[FlxWaveform] Waveform sound null!");
            return;
        }

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
    }

    /**
     * Loads raw audio data neccessary for drawing the waveform from a lime `AudioBuffer`
     * @param buffer The audio buffer
     */
    public function loadDataFromAudioBuffer(buffer:AudioBuffer):Void
    {
        if (buffer == null)
        {
            FlxG.log.error("[FlxWaveform] Buffer is null!");
            return;
        }

        _buffer = buffer;
        _bufferDataBytes = _buffer.data.toBytes();
        // trace('Processing sound data (channels: ${buffer.channels}, bps: ${buffer.bitsPerSample}, sample rate: ${buffer.sampleRate})');

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
            case 32: normalizeSamplesI32(_bufferDataBytes, _stereo);
            case _: null;
        }

        if (_normalizedSamples == null)
            FlxG.log.error('Unsupported bitsPerSample value: ${buffer.bitsPerSample}');
    }

    /**
     * Sets the time range from where the waveform will be drawn.
     * @param endTime The end of the range, in miliseconds. If not specified will be the length of the sound.
     * @param startTime The start of the range, in miliseconds. If not specified will be 0.
     */
    public function setDrawRange(?endTime:Float = -1, ?startTime:Float = -1):Void
    {
        if (startTime < 0)
            startTime = 0.0;
        if (endTime < 0)
            endTime = (_normalizedSamples.left.length / _buffer.sampleRate) * 1000;

        _curRangeStart = startTime;
        _curRangeEnd = endTime;

        // clear previous peak data
        clearArray(_peaksLeft);
        clearArray(_peaksRight);

        // ? run gc to hopefully clear old data?
        System.gc();

        var slicePos:Int = Std.int((_curRangeStart / 1000) * _buffer.sampleRate);
        var sliceEnd:Int = Std.int((_curRangeEnd / 1000) * _buffer.sampleRate);
        var sectionSamplesLeft:Array<Float> = _normalizedSamples.left.slice(slicePos, sliceEnd);
        var sectionSamplesRight:Array<Float> = null;
        if (_stereo)
            sectionSamplesRight = _normalizedSamples.right.slice(slicePos, sliceEnd);

        samplesPerPixel = Math.max(sectionSamplesLeft.length, sectionSamplesRight.length) / waveformWidth;
        calculatePeaks(sectionSamplesLeft, _peaksLeft);
        if (_stereo)
            calculatePeaks(sectionSamplesRight, _peaksRight);
    }

    public function generateWaveformBitmap():Void
    {
        // clear previous draw
        pixels.fillRect(new Rectangle(0, 0, waveformWidth, waveformHeight), waveformBg);

        if (waveformDrawMode == COMBINED)
        {
            var centerY:Float = waveformHeight / 2;

            for (i in 0...waveformWidth)
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

                pixels.fillRect(new Rectangle(i, y1, 1, y2 - y1), waveformColor);
            }
        }
        else if (waveformDrawMode == SPLIT_CHANNELS)
        {
            var half:Float = waveformHeight / 2;
            var centerY:Float = waveformHeight / 4;

            for (i in 0...waveformWidth)
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

                pixels.fillRect(new Rectangle(i, y1l, 1, y2l - y1l), waveformColor);
                pixels.fillRect(new Rectangle(i, y1r, 1, y2r - y1r), waveformColor);
            }
        }
    }

    private function calculatePeaks(samples:Array<Float>, out:Array<Float>):Void
    {
        clearArray(out);
        for (i in 0...waveformWidth)
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
     * If `array` is `null` creates a new array instance, otherwise clears the old reference and returns it
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

    @:noCompletion private function set_waveformWidth(value:Int):Int
    {
        // width changes samplesPerPixel, so we need to regenerate data
        if (_buffer != null)
            setDrawRange(_curRangeEnd, _curRangeStart);

        // Avoid unneccesary regenerate
        if (autoUpdateBitmap && _buffer != null)
        {
            var prev = waveformWidth;
            if (prev != value)
                generateWaveformBitmap();
        }

        return waveformWidth = value;
    }

    @:noCompletion private function set_waveformHeight(value:Int):Int 
    {
        // Avoid unneccesary regenerate
        if (autoUpdateBitmap && _buffer != null)
        {
            var prev = waveformHeight;
            if (prev != value)
                generateWaveformBitmap();
        }

        return waveformHeight = value;
    }

    @:noCompletion function set_waveformBg(value:FlxColor):FlxColor
    {
        // Avoid unneccesary regenerate
        if (autoUpdateBitmap && _buffer != null)
        {
            var prev = waveformBg;
            if (prev != value)
                generateWaveformBitmap();
        }

        return waveformBg = value;
    }

    @:noCompletion function set_waveformColor(value:FlxColor):FlxColor
    {
        // Avoid unneccesary regenerate
        if (autoUpdateBitmap && _buffer != null)
        {
            var prev = waveformColor;
            if (prev != value)
                generateWaveformBitmap();
        }

        return waveformColor = value;
    }

    @:noCompletion function set_waveformDrawMode(value:WaveformDrawMode):WaveformDrawMode 
    {
        // Avoid unneccesary regenerate
        if (autoUpdateBitmap && _buffer != null)
        {
            var prev = waveformDrawMode;
            if (prev != value)
                generateWaveformBitmap();
        }

        return waveformDrawMode = value;
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
