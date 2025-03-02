
package flixel.addons.display.waveform;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import lime.media.AudioBuffer;
import lime.utils.Float32Array;
import openfl.display.Shape;
import openfl.geom.Rectangle;
#if flash
import flash.media.Sound;
#end

/**
 * A simple yet powerful [HaxeFlixel](https://haxeflixel.com/) addon for drawing waveforms from sounds
 * 
 * @author ACrazyTown (https://github.com/acrazytown/)
 */
class FlxWaveform extends FlxSprite
{
    /* ----------- PUBLIC API ----------- */

    /**
     * Represents how many audio samples are equal to 1px.
     * 
     * This value is set automatically when changing anything that
     * affets the "effective width" of the waveform (eg. changing bar size, padding...)
     */
    public var samplesPerPixel(default, null):Int;

    /**
     * An enum representing how the waveform will look visually.
     * 
     * `COMBINED` will draw both audio channels (if in stereo) onto the 
     * full area of the graphic, causing an overlap between the two.
     * It also may be slightly more expensive to compute.
     * 
     * `SPLIT_CHANNELS` will horizontally split the waveform into 
     * top and bottom parts, for the two audio channels.
     * The top part represents the left audio channel, 
     * while the bottom part represents the right channel.
     * 
     * `SINGLE_CHANNEL` draws one audio channel across the full area of the graphic.
     * The argument provided must be either 
     * 0 (for the left channel) or 1 (for the right channel)
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
     * 
     * @since 2.0.0
     */
    public var waveformRMSColor(default, set):FlxColor;

    /**
     * The width of the entire waveform graphic.
     * This is essentially a shortcut to `FlxSprite.frameWidth`
     * with a setter for resizing.
     */
    public var waveformWidth(get, set):Int;

    /**
     * The height of the entire waveform graphic.
     * This is essentially a shortcut to `FlxSprite.frameHeight`
     * with a setter for resizing.
     * 
     * When `waveformDrawMode` is set to `SPLIT_CHANNELS`, each channel
     * will be half of `waveformHeight`.
     */
    public var waveformHeight(get, set):Int;

    /**
     * Whether the waveform graphic should be automatically 
     * regenerated when there's a change in data that would
     * affect the waveform visually.
     *
     * If set to `false`, you have to call 
     * `FlxWaveform.generateWaveformBitmap()` to update the graphic.
     * 
     * Note that if a change that requires the draw data to be rebuilt, 
     * it will be done during the first draw call after the change,
     * which may result in a stutter.
     */
    public var autoUpdateBitmap(default, set):Bool = true;

    /**
     * Whether the waveform baseline should be drawn.
     * 
     * @since 2.0.0
     */
    public var waveformDrawBaseline(default, set):Bool;

    /**
     * Whether the waveform's RMS (root mean square) should be drawn.
     * The RMS represents the average/effective loudness of audio.
     * 
     * Use `waveformRMSColor` to control the color the RMS will be
     * drawn with.
     * 
     * Enabling this option may make the waveform more expensive to compute.
     *
     * @since 2.0.0
     */
    public var waveformDrawRMS(default, set):Bool;

    /**
     * The size (in pixels) of one waveform peak bar.
     * Default value is 1px.
     * Increasing this value will make the waveform less detailed,
     * which by extension will also make it less expensive to compute.
     * 
     * This value must be more than or equal to 1. 
     * 
     * This value doesn't affect anything when the samples are graphed.
     * 
     * @since 2.0.0
     */
    public var waveformBarSize(default, set):Int = 1;

    /**
     * The space (in pixels) between waveform peak bars.
     * Default value is 0px.
     * Increasing this value will make the waveform less detailed,
     * which by extension will also make it less expensive to compute.
     * 
     * This value must be more than or equal to 0.
     * 
     * This value doesn't affect anything when the samples are graphed.
     * 
     * @since 2.0.0
     */
    public var waveformBarPadding(default, set):Int = 0;

    /**
     * The audio time, in miliseconds, this waveform will start at.
     * 
     * @since 2.0.0
     */
    public var waveformTime(default, set):Float;

    /**
     * The amount of time, in miliseconds, this waveform will represent.
     * 
     * Changing this value will trigger a data rebuild, which may induce a
     * temporary freeze/stutter.
     * Avoid changing it frequently.
     * 
     * @since 2.0.0
     */
    public var waveformDuration(default, set):Float;
    
    /**
     * A reference to the `FlxWaveformBuffer` that holds the raw audio data
     * and other information needed for further processing.
     * 
     * If the buffer's `autoDestroy` property is `false`, it will not be destroyed
     * when this waveform gets destroyed. You have to destroy it manually.
     * 
     * You cannot set this property directly, use the `FlxWaveform.loadDataFrom...()`
     * methods instead.
     * 
     * @since 2.1.0
     */
    public var waveformBuffer(default, null):Null<FlxWaveformBuffer> = null;

    /* ----------- INTERNALS ----------- */

    /**
     * Internal helper variable indicating whether the 
     * audio source is stereo (has 2 audio channels).
     */
    var _stereo:Bool = false;

    /**
     * Internal helper that stores the value of `waveformTime` but in audio samples.
     */
    var _timeSamples:Int;

    /**
     * Internal helper that stores the value of `waveformDuration` but in audio samples.
     */
    var _durationSamples:Int;

    /**
     * Internal array of Floats that contains
     * audio peaks of the left channel for the full length of the sound.
     * The length depends on the number of audio bars.
     * 
     * This array does not update in real time. 
     * If the draw data needs to be rebuilt, it will be done on
     * the first draw call after setting the `_drawDataDirty` flag.
     */
    var _drawPointsLeft:Array<Float> = null;

    /**
     * Internal array of Floats that contains
     * audio peaks of the right channel for the full length of the sound.
     * The length depends on the number of audio bars.
     * 
     * This array does not update in real time. 
     * If the draw data needs to be rebuilt, it will be done on
     * the first draw call after setting the `_drawDataDirty` flag.
     */
    var _drawPointsRight:Array<Float> = null;

    /**
     * Internal array of Floats that contains the RMS (root mean square) 
     * values of the left channel for the full length of the sound.
     * The length depends on the number of audio bars.
     * 
     * This array does not update in real time. 
     * If the draw data needs to be rebuilt, it will be done on
     * the first draw call after setting the `_drawDataDirty` flag.
     */
    var _drawRMSLeft:Array<Float> = null;

    /**
     * Internal array of Floats that contains the RMS (root mean square) 
     * values of the right channel for the full length of the sound.
     * The length depends on the number of audio bars.
     * 
     * This array does not update in real time. 
     * If the draw data needs to be rebuilt, it will be done on
     * the first draw call after setting the `_drawDataDirty` flag.
     */
    var _drawRMSRight:Array<Float> = null;

    /**
     * Internal helper that decides whether the waveform should be redrawn.
     */
    var _waveformDirty:Bool = true;

    /**
     * Internal helper that decides whether the waveform draw data should be rebuilt.
     */
    var _drawDataDirty:Bool = false;

    /**
     * Internal helper used for drawing lines.
     */
    var _shape:Shape;

    /**
     * Internal helper that includes `waveformBarSize` and `waveformBarPadding`
     * into the waveform width to calculate how much data is actually
     * needed to draw a waveform.
     */
    var _effectiveWidth:Int;

    /**
     * Creates a new `FlxWaveform` instance with the specified parameters.
     * 
     * The waveform is **NOT** ready to display anything yet.
     * Use a `FlxWaveform.loadDataFrom...()` method to load audio data before adjusting any other options.
     * 
     * @param x The initial X position of the waveform
     * @param y The initial Y position of the waveform
     * @param width The initial width of the waveform
     * @param height The initial height of the waveform
     * @param color The color the waveform will be drawn with
     * @param backgroundColor The background color of the wavefm.
     * @param drawMode How the waveform should visually appear. See `FlxWaveform.waveformDrawMode` for more info.
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
        calcEffectiveWidth();

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

        if (waveformBuffer?.autoDestroy)
            FlxDestroyUtil.destroy(waveformBuffer);
    }

    @:inheritDoc(FlxSprite.draw)
    override function draw():Void
    {
        if (_waveformDirty)
        {
            generateWaveformBitmap();
            dirty = true;
            _waveformDirty = false;
        }

        super.draw();
    }

    /**
     * Loads the audio buffer data neccessary for processing the 
     * waveform from a `flixel.sound.FlxSound`
     * 
     * @param sound The `flixel.sound.FlxSound` to get data from.
     */
    public function loadDataFromFlxSound(sound:FlxSound):Void
    {
        loadDataFromFlxWaveformBuffer(FlxWaveformBuffer.fromFlxSound(sound));
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

   /**
     * Loads the audio buffer data neccessary for processing the 
     * waveform from a `FlxWaveformBuffer`.
     * 
     * @param buffer The `FlxWaveformBuffer` to get data from.
     * 
     * @since 2.0.0
     */
    public function loadDataFromFlxWaveformBuffer(buffer:FlxWaveformBuffer):Void
    {
        if (waveformBuffer?.autoDestroy)
            FlxDestroyUtil.destroy(waveformBuffer);
        
        waveformBuffer = buffer;
        if (waveformBuffer == null)
        {
            FlxG.log.error("[FlxWaveform] Invalid buffer");
            return;
        }

        _stereo = waveformBuffer.numChannels == 2;

        _drawPointsLeft = recycleArray(_drawPointsLeft);
        _drawRMSLeft = recycleArray(_drawRMSLeft);

        if (_stereo)
        {
            _drawPointsRight = recycleArray(_drawPointsRight);
            _drawRMSRight = recycleArray(_drawRMSRight);
        }
    }

    /**
     * Draws the waveform onto this sprite's graphic.
     *
     * If you have `autoUpdateBitmap` enabled, you most likely
     * do not need to call this function manually.
     * 
     * Note that if a change that requires the draw data to be rebuilt, 
     * it will be done during the first draw call after the change,
     * which may result in a stutter.
     */
    public function generateWaveformBitmap():Void
    {
        if (_drawDataDirty)
        {
            refreshDrawData();
            _drawDataDirty = false;
        }

        // clear previous draw
        // pixels.fillRect(new Rectangle(0, 0, waveformWidth, waveformHeight), waveformBg);
        pixels.fillRect(new Rectangle(0, 0, pixels.width, pixels.height), waveformBgColor);

        // TODO: Enable graphed sample renderer!
        // if (samplesPerPixel > 1)
        //     drawPeaks();
        // else
        //     drawGraphedSamples();
        drawPeaks();
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
        // if (waveformWidth != width)
        // {
        //     setDrawRange(_rangeEndMS, _rangeStartMS)
        // }

        // waveformWidth = width;
        // waveformHeight = height;

        makeGraphic(width, height, waveformBgColor);
        calcEffectiveWidth();
        calcSamplesPerPixel();

        _drawDataDirty = true;

        if (autoUpdateBitmap)
            _waveformDirty = true;
    }

    /**
     * Internal method which draws audio sample peaks as rectangles.
     * Used when `samplesPerPixel` is larger than 1
     */
    function drawPeaks():Void
    {
        var half:Float = waveformHeight / 2;
        var timeOffset:Float = _timeSamples / samplesPerPixel;

        switch (waveformDrawMode)
        {
            case COMBINED:
                if (waveformDrawBaseline)
                    pixels.fillRect(new Rectangle(0, half, waveformWidth, 1), waveformColor);

                for (i in 0..._effectiveWidth)
                {
                    var sampleIndex:Int = Math.round(timeOffset + i);

                    var peakLeft:Float = _drawPointsLeft[sampleIndex];
                    var peakRight:Float = 0;
                    if (_stereo)
                        peakRight = _drawPointsRight[sampleIndex];

                    if ((!_stereo && peakLeft == 0) || (_stereo && peakLeft == 0 && peakRight == 0))
                        continue;

                    var peakest:Float = Math.max(peakLeft, peakRight);
                    var x:Float = i * (waveformBarSize + waveformBarPadding);

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformHeight, peakest), waveformColor);
                    if (waveformDrawRMS)
                    {
                        var rmsLeft:Float = _drawRMSLeft[sampleIndex];
                        var rmsRight:Float = 0;
                        if (_stereo)
                            rmsRight = _drawRMSRight[sampleIndex];

                        if ((!_stereo && rmsLeft == 0) || (_stereo && rmsLeft == 0 && rmsRight == 0))
                            continue;

                        var combinedRMS:Float = Math.sqrt((rmsLeft * rmsLeft + rmsRight * rmsRight) / 2);
                        pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformHeight, combinedRMS), waveformRMSColor);
                    }
                }

            case SPLIT_CHANNELS:
                var centerY:Float = waveformHeight / 4;

                if (waveformDrawBaseline) 
                {
                    pixels.fillRect(new Rectangle(0, centerY, waveformWidth, 1), waveformColor);
                    pixels.fillRect(new Rectangle(0, half + centerY, waveformWidth, 1), waveformColor);
                }

                for (i in 0..._effectiveWidth)
                {
                    var sampleIndex:Int = Math.round(timeOffset + i);

                    var peakLeft:Float = _drawPointsLeft[sampleIndex];
                    var peakRight:Float = 0;
                    if (_stereo)
                        peakRight = _drawPointsRight[sampleIndex];

                    if ((!_stereo && peakLeft == 0) || (_stereo && peakLeft == 0 && peakRight == 0))
                        continue;

                    var x:Float = i * (waveformBarSize + waveformBarPadding);

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, half, peakLeft), waveformColor);
                    pixels.fillRect(getPeakRect(x, half, waveformBarSize, half, peakRight), waveformColor);

                    if (waveformDrawRMS)
                    {
                        var rmsLeft:Float = _drawRMSLeft[sampleIndex];
                        var rmsRight:Float = 0;
                        if (_stereo)
                            rmsRight = _drawRMSRight[sampleIndex];

                        if ((!_stereo && rmsLeft == 0) || (_stereo && rmsLeft == 0 && rmsRight == 0))
                            continue;

                        pixels.fillRect(getPeakRect(x, 0, waveformBarSize, half, rmsLeft), waveformRMSColor);
                        pixels.fillRect(getPeakRect(x, half, waveformBarSize, half, rmsRight), waveformRMSColor);
                    }
                }

            case SINGLE_CHANNEL(channel):
                if (waveformDrawBaseline)
                    pixels.fillRect(new Rectangle(0, half, waveformWidth, 1), waveformColor);

                for (i in 0..._effectiveWidth)
                {
                    var sampleIndex:Int = Math.round(timeOffset + i);

                    var peak:Float = channel == 0 ? _drawPointsLeft[sampleIndex] : _drawPointsRight[sampleIndex];

                    if (peak == 0)
                        continue;

                    var x:Float = i * (waveformBarSize + waveformBarPadding);

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformHeight, peak), waveformColor);
                    if (waveformDrawRMS)
                    {
                        var rms:Float = channel == 0 ? _drawRMSLeft[sampleIndex] : _drawRMSRight[sampleIndex];
                        if (rms == 0)
                            continue;

                        pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformHeight, rms), waveformRMSColor);
                    }
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

        switch (waveformDrawMode)
        {
            case COMBINED:
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

            case SPLIT_CHANNELS:
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

            case SINGLE_CHANNEL(channel):
                var prevX:Float = 0;
                var prevY:Float = centerY;

                _shape.graphics.moveTo(prevX, prevY);

                for (i in 0...waveformWidth)
                {
                    var peak:Float = channel == 0 ? _drawPointsLeft[i] : _drawPointsRight[i];

                    var curX:Float = i;
                    var curY:Float = centerY - peak * centerY;

                    _shape.graphics.lineTo(curX, curY);

                    prevX = curX;
                    prevY = curY;
                }
        }

        pixels.draw(_shape);
    }

    /**
     * Prepares data neccessary for the waveform to be drawn. 
     * @param channel The channel to prepare the data for
     */
    function prepareDrawData(channel:Int):Void
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

        var samples:Null<Float32Array> = waveformBuffer.getChannelData(channel);

        // TODO: Enable graphed sample renderer!
        // if (samplesPerPixel > 1)
        // {
        var samplesGenerated:Int = 0;
        while (samplesGenerated < samples.length)
        {
            for (i in 0..._effectiveWidth)
            {
                var startIndex:Int = samplesGenerated + i * samplesPerPixel;
                var endIndex:Int = Std.int(Math.min(startIndex + samplesPerPixel, samples.length));

                drawPoints.push(waveformBuffer.getPeakForSegment(channel, startIndex, endIndex));

                // Avoid calculating RMS if we don't need to draw it
                drawRMS.push(waveformDrawRMS ? waveformBuffer.getRMSForSegment(channel, startIndex, endIndex) : 0.0);
            }

            samplesGenerated += _durationSamples;
        }
        // }
        // else
        // {
        //     var endSamples:Int = _timeSamples + _durationSamples;
        //     for (i in _timeSamples...endSamples)
        //         drawPoints.push(samples[i]);
        // }
    }

    /**
     * Helper function that calls `prepareDrawData` for both audio channels.
     */
    function refreshDrawData():Void
    {
        switch (waveformDrawMode)
        {
            case SINGLE_CHANNEL(channel):
                prepareDrawData(channel);

            default:
                prepareDrawData(0);
                if (_stereo)
                    prepareDrawData(1);
        }
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
    function getPeakRect(x:Float, y:Float, width:Float, height:Float, sample:Float):Rectangle
    {
        var half:Float = height / 2;
        var segmentHeight:Float = sample * half;

        var y1:Float = half - segmentHeight;
        var y2:Float = half + segmentHeight;

        return new Rectangle(x, y + y1, width, y2 - y1);
    }

    /**
     * Helper function to calculate the effective width.
     */
    inline function calcEffectiveWidth():Void
    {
        _effectiveWidth = Math.ceil(waveformWidth / (waveformBarSize + waveformBarPadding));
    }

    /**
     * Helper function to calculate the amount of samples per pixel.
     */
    inline function calcSamplesPerPixel():Void
    {
        samplesPerPixel = Std.int(_durationSamples / _effectiveWidth);
    }

    /**
     * Clears an array in the fastest possible way.
     * 
     * @param array The array to be cleared.
     */
    function clearArray<T>(array:Array<T>):Void
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
    function recycleArray<T>(array:Array<T>):Array<T>
    {
        if (array == null)
            return [];

        clearArray(array);
        return array;
    }

    @:noCompletion function get_waveformWidth():Int
    {
        return this.frameWidth;
    }

    @:noCompletion function set_waveformWidth(value:Int):Int
    {
        if (waveformWidth != value)
        {
            resize(value, waveformHeight);
            calcEffectiveWidth();
        }

        return waveformWidth;
    }

    @:noCompletion function get_waveformHeight():Int
    {
        return this.frameHeight;
    }

    @:noCompletion function set_waveformHeight(value:Int):Int 
    {
        if (waveformHeight != value)
            resize(waveformWidth, value);

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

            switch (waveformDrawMode)
            {
                case SINGLE_CHANNEL(channel):
                    if (channel != 0 && channel != 1)
                        FlxG.log.error('[FlxWaveform] Invalid SINGLE_CHANNEL argument: $channel (must be 0 or 1)');

                default:
            }

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
            if (value < 1)
                FlxG.log.error('[FlxWaveform] waveformBarSize cannot be less than 1!');

            waveformBarSize = value;

            calcEffectiveWidth();
            calcSamplesPerPixel();

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
            if (value < 0)
                FlxG.log.error('[FlxWaveform] waveformBarPadding cannot be less than 0!');

            calcEffectiveWidth();
            calcSamplesPerPixel();

            _drawDataDirty = true;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformBarPadding;
    }
    
    @:noCompletion function set_waveformTime(value:Float):Float 
    {
        if (waveformTime != value)
        {
            waveformTime = value;
            if (value < 0)
                FlxG.log.error('[FlxWaveform] waveformTime cannot be less than 0!');

            _timeSamples = Std.int((value / 1000) * waveformBuffer.sampleRate);

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformTime;
    }
    
    @:noCompletion function set_waveformDuration(value:Float):Float
    {
        if (waveformDuration != value)
        {
            waveformDuration = value;
            if (value < 0)
                FlxG.log.error('[FlxWaveform] waveformDuration cannot be less than 0!');

            _durationSamples = Std.int((value / 1000) * waveformBuffer.sampleRate);

            calcSamplesPerPixel();

            _drawDataDirty = true;

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

       return waveformDuration;
    }
    
}

/**
 * An enum representing how the waveform will look visually.
 * 
 * `COMBINED` will draw both audio channels (if in stereo) onto the 
 * full area of the graphic, causing an overlap between the two.
 * It also may be slightly more expensive to compute.
 * 
 * `SPLIT_CHANNELS` will horizontally split the waveform into 
 * top and bottom parts, for the two audio channels.
 * The top part represents the left audio channel, 
 * while the bottom part represents the right channel.
 * 
 * `SINGLE_CHANNEL` draws one audio channel across the full area of the graphic.
 * The argument provided must be either 
 * 0 (for the left channel) or 1 (for the right channel)
 */
enum WaveformDrawMode
{
    COMBINED;
    SPLIT_CHANNELS;
    SINGLE_CHANNEL(channel:Int);
}
