
package flixel.addons.display.waveform;

import flixel.util.FlxDestroyUtil;
import openfl.display.Shape;
import lime.utils.Float32Array;
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
 * A `FlxWaveform` is an `FlxSprite` extension that provides a simple yet 
 * powerful API for drawing waveforms from audio data.
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
     * The color used for drawing the actual waveform.
     */
    public var waveformColor(default, set):FlxColor;

    /**
     * The color used for drawing the waveform RMS.
     * @since 1.3.0
     */
    public var waveformRMSColor(default, set):FlxColor;

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
     * @since 1.3.0
     */
    public var waveformDrawBaseline(default, set):Bool;

    /**
     * Whether the waveform's RMS (root mean square) should be drawn.
     * The RMS represents the average/effective loudness of audio.
     * 
     * Use `waveformRMSColor` to control the color the RMS will be
     * drawn with.
     *
     * @see https://manual.audacityteam.org/man/audacity_waveform.html#rms
     * @since 1.3.0
     */
    public var waveformDrawRMS(default, set):Bool;

    /**
     * The size (in pixels) of one waveform peak bar.
     * Default value is 1.
     * 
     * This value doesn't affect anything when the samples are graphed.
     * @since 1.3.0
     */
    public var waveformBarSize(default, set):Int = 1;

    /**
     * The space (in pixels) between waveform peak bars.
     * Default value is 0.
     * 
     * This value doesn't affect anything when the samples are graphed.
     * @since 1.3.0
     */
    public var waveformBarPadding(default, set):Int = 0;

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
     * Internal variable holding the start of the draw range (in miliseconds)
     */
    var _rangeStartMS:Float;

    /**
     * Internal variable holding the end of the draw range (in miliseconds)
     */
    var _rangeEndMS:Float;

    /**
     * Internal variable holding the start of the draw range (in samples)
     */
    var _rangeStartSample:Int;

    /**
     * Internal variable holding the end of the draw range (in samples)
     */
    var _rangeEndSample:Int;

    /**
     * Internal array of Floats that either contain:
     * - Peaks in a range of 0.0 to 1.0 for a given time frame.
     * - Audio samples in a range of -1.0 to 1.0 to be graphed
     * 
     * What the array will contain is dependant on `samplesPerPixel`
     */
    var _drawPointsLeft:Array<Float> = null;

    /**
     * Internal array of Floats that either contain:
     * - Peaks in a range of 0.0 to 1.0 for a given time frame.
     * - Audio samples in a range of -1.0 to 1.0 to be graphed
     * 
     * What the array will contain is dependant on `samplesPerPixel`
     */
    var _drawPointsRight:Array<Float> = null;

    /**
     * Internal array of Floats that contains the RMS (root mean square) 
     * values of the left channel for a given time frame.
     */
    var _drawRMSLeft:Array<Float> = null;

    /**
     * Internal array of Floats that contains the RMS (root mean square) 
     * values of the right channel for a given time frame.
     */
    var _drawRMSRight:Array<Float> = null;

    /**
     * Internal helper that decides whether the waveform should be redrawn.
     */
    var _waveformDirty:Bool = true;

    /**
     * Internal helper that decides whether the waveform draw data 
     * should be rebuilt.
     */
    var _drawDataDirty:Bool = false;

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
        _drawPointsLeft = null;
        _drawPointsRight = null;
        _drawRMSLeft = null;
        _drawRMSRight = null;

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

    @:inheritDoc(flixel.FlxBasic.update)
    override function update(elapsed:Float):Void
    {
        if (_drawDataDirty)
        {
            refreshDrawData();
            _drawDataDirty = false;
        }

        super.update(elapsed);
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
     * 
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

        _drawPointsLeft = recycleArray(_drawPointsLeft);
        _drawRMSLeft = recycleArray(_drawRMSLeft);

        if (_stereo)
        {
            _drawPointsRight = recycleArray(_drawPointsRight);
            _drawRMSRight = recycleArray(_drawRMSRight);
        }
    }

    /**
     * Sets the time range that the waveform represents.
     * 
     * @param endTime The end of the range, in miliseconds. If not specified will be the length of the sound.
     * @param startTime The start of the range, in miliseconds. If not specified will be the start of the sound.
     */
    public function setDrawRange(?endTime:Float = -1, ?startTime:Float = -1):Void
    {
        if (startTime < 0)
            startTime = 0.0;
        if (endTime < 0)
            endTime = (_buffer.getChannelData(0).length / _buffer.sampleRate) * 1000;

        // TODO: Some kind of cache? If the range is not completely different but like only slightly
        // eg. startTime goes from 0 to 100 don't dump whole array but add to it?
        _rangeStartMS = startTime;
        _rangeEndMS = endTime;
        _rangeStartSample = Std.int((_rangeStartMS / 1000) * _buffer.sampleRate);
        _rangeEndSample = Std.int((_rangeEndMS / 1000) * _buffer.sampleRate);

        samplesPerPixel = Std.int((_rangeEndSample - _rangeStartSample) / waveformWidth);
        _drawDataDirty = true;

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
        // clear previous draw
        // pixels.fillRect(new Rectangle(0, 0, waveformWidth, waveformHeight), waveformBg);
        pixels.fillRect(new Rectangle(0, 0, pixels.width, pixels.height), waveformBgColor);

        if (samplesPerPixel > 1)
            drawPeaks();
        else
            drawGraphedSamples();
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
            setDrawRange(_rangeEndMS, _rangeStartMS);

        // waveformWidth = width;
        // waveformHeight = height;

        makeGraphic(width, height, waveformBgColor);
        if (autoUpdateBitmap)
            _waveformDirty = true;
    }

    /**
     * Internal method which draws audio sample peaks as rectangles.
     * Used when `samplesPerPixel` is larger than 1
     */
    private function drawPeaks():Void
    {
        var effectiveWidth:Int = Math.ceil(waveformWidth / (waveformBarSize + waveformBarPadding));

        if (waveformDrawMode == COMBINED)
        {
            var centerY:Float = waveformHeight / 2;

            if (waveformDrawBaseline)
                pixels.fillRect(new Rectangle(0, centerY, waveformWidth, 1), waveformColor);

            for (i in 0...effectiveWidth)
            {
                var peakLeft:Float = _drawPointsLeft[i];
                var peakRight:Float = 0;
                if (_stereo)
                    peakRight = _drawPointsRight[i];

                if ((!_stereo && peakLeft == 0) || (_stereo && peakLeft == 0 && peakRight == 0))
                    continue;

                var peakest:Float = Math.max(peakLeft, peakRight);
                var x:Float = i * (waveformBarSize + waveformBarPadding);

                pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformHeight, peakest), waveformColor);
                if (waveformDrawRMS)
                {
                    var rmsLeft:Float = _drawRMSLeft[i];
                    var rmsRight:Float = 0;
                    if (_stereo)
                        rmsRight = _drawRMSRight[i];

                    if ((!_stereo && rmsLeft == 0) || (_stereo && rmsLeft == 0 && rmsRight == 0))
                        continue;

                    var combinedRMS:Float = Math.sqrt((rmsLeft * rmsLeft + rmsRight * rmsRight) / 2);
                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformHeight, combinedRMS), waveformRMSColor);
                }
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

            for (i in 0...effectiveWidth)
            {
                var peakLeft:Float = _drawPointsLeft[i];
                var peakRight:Float = 0;
                if (_stereo)
                    peakRight = _drawPointsRight[i];

                if ((!_stereo && peakLeft == 0) || (_stereo && peakLeft == 0 && peakRight == 0))
                    continue;

                var x:Float = i * (waveformBarSize + waveformBarPadding);

                pixels.fillRect(getPeakRect(x, 0, waveformBarSize, half, peakLeft), waveformColor);
                pixels.fillRect(getPeakRect(x, half, waveformBarSize, half, peakRight), waveformColor);

                if (waveformDrawRMS)
                {
                    var rmsLeft:Float = _drawRMSLeft[i];
                    var rmsRight:Float = 0;
                    if (_stereo)
                        rmsRight = _drawRMSRight[i];

                    if ((!_stereo && rmsLeft == 0) || (_stereo && rmsLeft == 0 && rmsRight == 0))
                        continue;

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, half, rmsLeft), waveformRMSColor);
                    pixels.fillRect(getPeakRect(x, half, waveformBarSize, half, rmsRight), waveformRMSColor);
                }
            }
        }
    }

    /**
     * Internal method which graphs audio samples.
     * Used when `samplesPerPixel` is equal to 1.
     */
    private function drawGraphedSamples():Void
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
                var peak:Float = _drawPointsLeft[i];
                if (_stereo)
                {
                    // Can't graph both so let's get average?
                    peak += _drawPointsRight[i];
                    peak /= 2;
                }

                var curX:Float = i;
                var curY:Float = centerY - peak * centerY;

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
                var peakLeft:Float = _drawPointsLeft[i];
                var peakRight:Float = 0;
                if (_stereo)
                    peakRight = _drawPointsRight[i];

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
     * Prepares data neccessary for the waveform to be drawn. 
     * @param channel The channel to prepare the data for
     */
    private function prepareDrawData(channel:Int):Void
    {
        var drawPoints:Array<Float> = null;
        var drawRMS:Array<Float> = null;

        switch (channel)
        {
            case 0:
                drawPoints = _drawPointsLeft;
                drawRMS = _drawRMSLeft;

            case 1:
                drawPoints = _drawPointsRight;
                drawRMS = _drawRMSRight;
        }

        clearArray(drawPoints);
        clearArray(drawRMS);

        var samples:Null<Float32Array> = _buffer.getChannelData(channel);

        // effectiveWidth takes in account barSize/padding only when samplesPerPixel > 1 (not graphing)
        var effectiveWidth:Int = samplesPerPixel > 1 ? Math.ceil(waveformWidth / (waveformBarSize + waveformBarPadding)) : waveformWidth;
        var samplesPerBar:Int = samplesPerPixel * waveformBarSize;

        if (samplesPerPixel > 1)
        {
            for (i in 0...effectiveWidth)
            {
                var startIndex:Int = Math.floor(_rangeStartSample + i * samplesPerBar);
                var endIndex:Int = Std.int(Math.min(Math.ceil(_rangeStartSample + (i + 1) * samplesPerBar), samples.length));
                drawPoints.push(_buffer.getPeakForSegment(channel, startIndex, endIndex));

                // Avoid calculating RMS if we don't need to draw it
                drawRMS.push(waveformDrawRMS ? _buffer.getRMSForSegment(channel, startIndex, endIndex) : 0.0);
            }
        }
        else
        {
            for (i in _rangeStartSample..._rangeEndSample)
                drawPoints.push(samples[i]);
        }
    }

    /**
     * Helper function that calls `prepareDrawData` for both audio channels.
     */
    inline private function refreshDrawData():Void
    {
        prepareDrawData(0);
        if (_stereo)
            prepareDrawData(1);
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
     * Returns an `openfl.geom.Rectangle` representing the rectangle
     * of the audio peak.
     * 
     * @param x The rectangle's position on the X axis
     * @param y Y offset
     * @param width The width of the peak rectangle
     * @param height The height of the peak rectangle
     * @param sample The audio sample in the range of -1.0 to 1.0
     * @return A `openfl.geom.Rectangle` instance
     */
    private function getPeakRect(x:Float, y:Float, width:Float, height:Float, sample:Float):Rectangle
    {
        var half:Float = height / 2;
        var segmentHeight:Float = sample * half;

        var y1:Float = half - segmentHeight;
        var y2:Float = half + segmentHeight;

        return new Rectangle(x, y + y1, width, y2 - y1);
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

    @:noCompletion function set_waveformRMSColor(value:FlxColor):FlxColor 
    {
        if (waveformRMSColor != value)
        {
            waveformRMSColor = value;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformRMSColor;
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

    @:noCompletion function set_waveformDrawRMS(value:Bool):Bool 
    {
        if (waveformDrawRMS != value)
        {
            waveformDrawRMS = value;
            
            _drawDataDirty = true;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformDrawRMS;
    }
    
    @:noCompletion function set_waveformBarSize(value:Int):Int 
    {
        if (waveformBarSize != value)
        {
            waveformBarSize = value;

            _drawDataDirty = true;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformBarSize;
    }
    
    @:noCompletion function set_waveformBarPadding(value:Int):Int 
    {
        if (waveformBarPadding != value)
        {
            waveformBarPadding = value;

            _drawDataDirty = true;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformBarPadding;
    }
    
}

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
enum WaveformDrawMode
{
    COMBINED;
    SPLIT_CHANNELS;
}
