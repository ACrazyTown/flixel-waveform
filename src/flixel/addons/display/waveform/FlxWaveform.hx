
package flixel.addons.display.waveform;

import flixel.util.FlxDestroyUtil;
import openfl.display.Shape;
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
    public var samplesPerPixel(default, null):Int;

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
    public var waveformDrawMode(default, set):WaveformDrawMode;

    /**
     * The background color of the waveform graphic.
     */
    public var waveformBgColor(default, set):FlxColor;

    /**
     * The color used for rendering the actual waveform.
     */
    public var waveformColor(default, set):FlxColor;

    /**
     * The width of the entire waveform graphic.
     * This is essentially a shortcut to `FlxSprite.frameWidth`
     * with a setter for resizing.
     *
     * If you want to change both the width and height of the graphic
     * it is recommended to use the `resize()` function to prevent
     * a double redraw.
     */
    public var waveformWidth(get, set):Int;

    /**
     * The height of the entire waveform graphic.
     * This is essentially a shortcut to `FlxSprite.frameHeight`
     * with a setter for resizing.
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
    public var autoUpdateBitmap(default, set):Bool = true;

    /**
     * Whether the waveform baseline should be drawn.
     */
    public var waveformDrawBaseline(default, set):Bool;

    /* ----------- INTERNALS ----------- */

    /**
     * Internal variable holding a reference to a 
     * `FlxWaveformBuffer` used for analyzing the audio data.
     */
    var _buffer:Null<FlxWaveformBuffer> = null;

    /**
     * Internal helper variable indicating whether the 
     * audio source is stereo (has 2 audio channels).
     */
    var _stereo:Bool = false;

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

    /**
     * Internal helper
     */
    var _waveformDirty:Bool = true;

    /**
     * Internal helper used for drawing lines.
     */
    var _shape:Shape;

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

        waveformBgColor = backgroundColor;
        waveformColor = color;
        // _waveformWidth = width;
        // _waveformHeight = height;
        waveformDrawMode = drawMode;
        makeGraphic(width, height, waveformBgColor);

        _shape = new Shape();
    }

    @:inheritDoc(FlxSprite.destroy)
    override function destroy():Void
    {
        super.destroy();

        _shape = null;
        _peaksLeft = null;
        _peaksRight = null;

        // TODO: Should the buffer be disposed?
        FlxDestroyUtil.destroy(_buffer);
    }

    @:inheritDoc(FlxSprite.draw)
    override function draw():Void
    {
        if (_waveformDirty)
        {
            generateWaveformBitmap();
            _waveformDirty = false;
        }

        super.draw();
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
     */
    public function loadDataFromFlashSound(sound:Sound):Void
    {
        loadDataFromFlxWaveformBuffer(FlxWaveformBuffer.fromFlashSound(sound));
    }
    #end

    /**
     * Loads the audio buffer data neccessary for processing the 
     * waveform from a `lime.media.AudioBuffer`.
     * 
     * @param buffer The `lime.media.AudioBuffer` to get data from.
     */
    inline public function loadDataFromAudioBuffer(buffer:AudioBuffer):Void
    {
        loadDataFromFlxWaveformBuffer(FlxWaveformBuffer.fromLimeAudioBuffer(buffer));
    }

    public function loadDataFromFlxWaveformBuffer(buffer:FlxWaveformBuffer):Void
    {
        // TODO: Destroy previous buffer?
        FlxDestroyUtil.destroy(_buffer);
        
        _buffer = buffer;
        if (_buffer == null)
        {
            FlxG.log.error("[FlxWaveform] Invalid buffer");
            return;
        }

        _stereo = _buffer.numChannels == 2;

        _peaksLeft = recycleArray(_peaksLeft);
        if (_stereo)
            _peaksRight = recycleArray(_peaksRight);
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
            endTime = (_buffer.getChannelData(0).length / _buffer.sampleRate) * 1000;

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
        var sectionSamplesLeft = _buffer.getChannelData(0).subarray(slicePos, sliceEnd);
        var sectionSamplesRight = null;
        if (_stereo)
            sectionSamplesRight = _buffer.getChannelData(1).subarray(slicePos, sliceEnd);

        samplesPerPixel = Std.int(Math.max(sectionSamplesLeft.length, sectionSamplesRight != null ? sectionSamplesRight.length : 0) / waveformWidth);
        prepareDrawData(sectionSamplesLeft, _peaksLeft);
        if (_stereo)
            prepareDrawData(sectionSamplesRight, _peaksRight);

        if (autoUpdateBitmap)
            _waveformDirty = true;
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
        pixels.fillRect(new Rectangle(0, 0, pixels.width, pixels.height), waveformBgColor);

        if (samplesPerPixel > 1)
            drawPeaks();
        else
            drawGraphedSamples();
    }

    /**
     * Internal method which draws audio sample peaks as rectangles.
     * Used when `samplesPerPixel` is larger than 1
     */
    function drawPeaks():Void
    {
        if (waveformDrawMode == COMBINED)
        {
            var centerY:Float = waveformHeight / 2;

            if (waveformDrawBaseline)
                pixels.fillRect(new Rectangle(0, centerY, waveformWidth, 1), waveformColor);

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

            if (waveformDrawBaseline)
            {
                pixels.fillRect(new Rectangle(0, centerY, waveformWidth, 1), waveformColor);
                pixels.fillRect(new Rectangle(0, half + centerY, waveformWidth, 1), waveformColor);
            }

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

    /**
     * Internal method which graphs audio samples.
     * Used when `samplesPerPixel` is equal to 1.
     */
    function drawGraphedSamples():Void
    {
        _shape.graphics.clear();
        _shape.graphics.lineStyle(1, waveformColor);

        var centerY:Float = waveformHeight / 2;
        var halfCenter:Float = centerY / 2;

        if (waveformDrawMode == COMBINED)
        {
            var prevX:Float = 0;
            var prevY:Float = centerY;

            _shape.graphics.moveTo(prevX, prevY);

            for (i in 0...waveformWidth)
            {
                var peak:Float = _peaksLeft[i];
                if (_stereo)
                {
                    // Can't graph both so let's get average?
                    peak += _peaksRight[i];
                    peak /= 2;
                }

                var curX:Float = i;
                var curY:Float = centerY + peak * centerY;

                _shape.graphics.lineTo(curX, curY);

                prevX = curX;
                prevY = curY;
            }
        }
        else
        {
            var prevX:Float = 0;
            var prevYL:Float = halfCenter;
            var prevYR:Float = centerY + halfCenter;

            for (i in 0...waveformWidth)
            {
                var peakLeft:Float = _peaksLeft[i];
                var peakRight:Float = 0;
                if (_stereo)
                    peakRight = _peaksRight[i];

                var curX:Float = i;
                var curYL:Float = halfCenter - peakLeft * halfCenter;
                var curYR:Float = (centerY + halfCenter) - peakRight * halfCenter;

                // left
                _shape.graphics.moveTo(prevX, prevYL);
                _shape.graphics.lineTo(curX, curYL);

                // right
                _shape.graphics.moveTo(prevX, prevYR);
                _shape.graphics.lineTo(curX, curYR);

                prevX = curX;
                prevYL = curYL;
                prevYR = curYR;
            }
        }

        pixels.draw(_shape);
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
        if (waveformWidth != width)
            setDrawRange(_curRangeEnd, _curRangeStart);

        // waveformWidth = width;
        // waveformHeight = height;

        makeGraphic(width, height, waveformBgColor);
        if (autoUpdateBitmap)
            _waveformDirty = true;
    }

    /**
     * Writes `waveformWidth` elements to array `out` containing
     * the data neccessary for the waveform to be rendered.
     * 
     * If `samplesPerPixel` is higher than 1 this data will be
     * the highest sample out of a sample segment,
     * otherwise it will just contain the audio sample values
     * to be graphed.
     * 
     * @param samples Input samples
     * @param out Output array containing peaks.
     */
    private function prepareDrawData(samples:Float32Array, out:Array<Float>):Void
    {
        clearArray(out);

        if (samplesPerPixel > 1)
        {
            for (i in 0...waveformWidth)
            {
                var startIndex:Int = Math.floor(i * samplesPerPixel);
                var endIndex:Int = Std.int(Math.min(Math.ceil((i + 1) * samplesPerPixel), samples.length));

                var peak:Float = 0.0;
                for (j in startIndex...endIndex)
                {
                    var sample = Math.abs(samples[j]);
                    if (sample > peak)
                        peak = sample;
                }

                out.push(peak);
            }
        }
        else
        {
            var visibleSamples:Int = Std.int(Math.min(samples.length, waveformWidth));
            for (i in 0...visibleSamples)
            {
                out.push(samples[i]);
            }
        }
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

    @:deprecated("TODO: Beta")
    inline private function bufferValid(buffer:FlxWaveformBuffer):Bool
    {
        return buffer != null;
    }

    @:noCompletion private function get_waveformWidth():Int
    {
        return this.frameWidth;
    }

    @:noCompletion private function set_waveformWidth(value:Int):Int
    {
        if (waveformWidth != value)
            resize(waveformWidth, waveformHeight);

        return waveformWidth;
    }

    @:noCompletion private function get_waveformHeight():Int
    {
        return this.frameHeight;
    }

    @:noCompletion private function set_waveformHeight(value:Int):Int 
    {
        if (waveformHeight != value)
            resize(waveformWidth, waveformHeight);

        return waveformHeight;
    }

    @:noCompletion function set_waveformBgColor(value:FlxColor):FlxColor
    {
        if (waveformBgColor != value)
        {
            waveformBgColor = value;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformBgColor;
    }

    @:noCompletion function set_waveformColor(value:FlxColor):FlxColor
    {
        if (waveformColor != value)
        {
            waveformColor = value;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformColor;
    }

    @:noCompletion function set_waveformDrawMode(value:WaveformDrawMode):WaveformDrawMode 
    {
        if (waveformDrawMode != value)
        {
            waveformDrawMode = value;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformDrawMode;
    }

    @:noCompletion function set_waveformDrawBaseline(value:Bool):Bool 
    {
        if (waveformDrawBaseline != value)
        {
            waveformDrawBaseline = value;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformDrawBaseline;
    }

    @:noCompletion function set_autoUpdateBitmap(value:Bool):Bool
    {
        if (value)
            _waveformDirty = true;

        return autoUpdateBitmap = value;
    }
}

enum WaveformDrawMode
{
    COMBINED;
    SPLIT_CHANNELS;
}
