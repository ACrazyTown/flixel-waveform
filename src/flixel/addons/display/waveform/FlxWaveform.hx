
package flixel.addons.display.waveform;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.waveform.FlxWaveformBuffer;
import flixel.addons.display.waveform.data.WaveformSegment;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import lime.media.AudioBuffer;
import lime.utils.Float32Array;
// import openfl.display.Shape;
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
    public var waveformTime(default, set):Float = 0;

    /**
     * The amount of time, in miliseconds, this waveform will represent.
     * 
     * Changing this value will trigger a data rebuild, which may induce a temporary freeze/stutter.
     * Avoid changing it frequently.
     * 
     * @since 2.0.0
     */
    public var waveformDuration(default, set):Float = 1000;
    
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

    /**
     * An enum representing whether the waveform should be 
     * drawn horizontally (left to right) or vertically (top to bottom).
     * 
     * Default value is `HORIZONTAL`.
     * 
     * @since 2.1.0
     */
    public var waveformOrientation(default, set):WaveformOrientation = HORIZONTAL;

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
    var _drawPointsLeft:Array<WaveformSegment> = null;

    /**
     * Internal array of Floats that contains
     * audio peaks of the right channel for the full length of the sound.
     * The length depends on the number of audio bars.
     * 
     * This array does not update in real time. 
     * If the draw data needs to be rebuilt, it will be done on
     * the first draw call after setting the `_drawDataDirty` flag.
     */
    var _drawPointsRight:Array<WaveformSegment> = null;

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
    // var _shape:Shape;

    /**
     * Internal helper that includes `waveformBarSize` and `waveformBarPadding`
     * into the waveform size to calculate how much data is actually
     * needed to draw a waveform.
     */
    var _effectiveSize:Int;

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
    public function new(?x:Float = 0, ?y:Float = 0, width:Int, height:Int, ?color:FlxColor = 0xFFFFFFFF, ?backgroundColor:FlxColor = 0x00000000, ?drawMode:WaveformDrawMode = COMBINED)
    {
        super(x, y);

        waveformBgColor = backgroundColor;
        waveformColor = color;
        // _waveformWidth = width;
        // _waveformHeight = height;
        waveformDrawMode = drawMode;
        makeGraphic(width, height, waveformBgColor);
        calcEffectiveSize();

        // _shape = new Shape();
    }

    @:inheritDoc(FlxSprite.destroy)
    override function destroy():Void
    {
        super.destroy();

        // _shape = null;
        _drawPointsLeft = null;
        _drawPointsRight = null;

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
    public function loadDataFromAudioBuffer(buffer:AudioBuffer):Void
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

        _drawPointsLeft = [];

        if (_stereo)
            _drawPointsRight = [];
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
        calcEffectiveSize();
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
        var halfWidth:Float = waveformWidth / 2;
        var halfHeight:Float = waveformHeight / 2;
        var timeOffset:Float = _timeSamples / samplesPerPixel;

        switch (waveformDrawMode)
        {
            case COMBINED:
                if (waveformDrawBaseline)
                {
                    var rect:Rectangle = new Rectangle(0, halfHeight, waveformWidth, 1);
                    if (waveformOrientation == VERTICAL)
                        rect.setTo(halfWidth, 0, 1, waveformHeight);

                    pixels.fillRect(rect, waveformColor);
                }

                for (i in 0..._effectiveSize)
                {
                    var sampleIndex:Int = Math.round(timeOffset + i);

                    var segmentLeft:WaveformSegment = _drawPointsLeft[sampleIndex];
                    var segmentRight:WaveformSegment = null;
                    if (_stereo)
                        segmentRight = _drawPointsRight[sampleIndex];

                    if ((!_stereo && segmentLeft == null) || (_stereo && segmentLeft == null && segmentRight == null))
                        continue;
                    if ((!_stereo && segmentLeft.silent) || (_stereo && segmentLeft.silent && segmentRight.silent))
                        continue;

                    // merge only if we have both
                    var peakest:WaveformSegment = segmentRight != null ? WaveformSegment.merge(segmentLeft, segmentRight) : segmentLeft;
                    var x:Float = i * (waveformBarSize + waveformBarPadding);

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformOrientation == HORIZONTAL ? waveformHeight : waveformWidth, peakest), waveformColor);

                    if (waveformDrawRMS)
                        pixels.fillRect(getRMSRect(x, 0, waveformBarSize, waveformOrientation == HORIZONTAL ? waveformHeight : waveformWidth, peakest), waveformRMSColor);
                }

            case SPLIT_CHANNELS:
                var centerX:Float = waveformWidth / 4;
                var centerY:Float = waveformHeight / 4;

                if (waveformDrawBaseline) 
                {
                    var rect:Rectangle = new Rectangle(0, centerY, waveformWidth, 1);
                    if (waveformOrientation == VERTICAL)
                        rect.setTo(centerX, 0, 1, waveformHeight);

                    pixels.fillRect(rect, waveformColor);

                    // Reuse same rect for other line
                    if (waveformOrientation == HORIZONTAL)
                        rect.setTo(0, halfHeight + centerY, waveformWidth, 1);
                    else
                        rect.setTo(halfWidth + centerX, 0, 1, waveformHeight);

                    pixels.fillRect(rect, waveformColor);
                }

                for (i in 0..._effectiveSize)
                {
                    var sampleIndex:Int = Math.round(timeOffset + i);

                    var segmentLeft:WaveformSegment = _drawPointsLeft[sampleIndex];
                    var segmentRight:WaveformSegment = null;
                    if (_stereo)
                        segmentRight = _drawPointsRight[sampleIndex];

                    if ((!_stereo && segmentLeft == null) || (_stereo && segmentLeft == null && segmentRight == null))
                        continue;
                    if ((!_stereo && segmentLeft.silent) || (_stereo && segmentLeft.silent && segmentRight.silent))
                        continue;

                    var x:Float = i * (waveformBarSize + waveformBarPadding);

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformOrientation == HORIZONTAL ? halfHeight : halfWidth, segmentLeft), waveformColor);
                    pixels.fillRect(getPeakRect(x, waveformOrientation == HORIZONTAL ? halfHeight : halfWidth, waveformBarSize, waveformOrientation == HORIZONTAL ? halfHeight : halfWidth, segmentRight), waveformColor);

                    if (waveformDrawRMS)
                    {
                        pixels.fillRect(getRMSRect(x, 0, waveformBarSize, waveformOrientation == HORIZONTAL ? halfHeight : halfWidth, segmentLeft), waveformRMSColor);
                        pixels.fillRect(getRMSRect(x, waveformOrientation == HORIZONTAL ? halfHeight : halfWidth, waveformBarSize, waveformOrientation == HORIZONTAL ? halfHeight : halfWidth, segmentRight), waveformRMSColor);
                    }
                }

            case SINGLE_CHANNEL(channel):
                if (waveformDrawBaseline)
                {
                   var rect:Rectangle = new Rectangle(0, halfHeight, waveformWidth, 1);
                    if (waveformOrientation == VERTICAL)
                        rect.setTo(halfWidth, 0, 1, waveformHeight);

                    pixels.fillRect(rect, waveformColor);
                }

                for (i in 0..._effectiveSize)
                {
                    var sampleIndex:Int = Math.round(timeOffset + i);

                    var segment:WaveformSegment = channel == 0 ? _drawPointsLeft[sampleIndex] : _drawPointsRight[sampleIndex];

                    if (segment == null)
                        continue;
                    if (segment.silent)
                        continue;

                    var x:Float = i * (waveformBarSize + waveformBarPadding);

                    pixels.fillRect(getPeakRect(x, 0, waveformBarSize, waveformOrientation == HORIZONTAL ? waveformHeight : waveformWidth, segment), waveformColor);
                    if (waveformDrawRMS)
                    {
                        pixels.fillRect(getRMSRect(x, 0, waveformBarSize, waveformOrientation == HORIZONTAL ? waveformHeight : waveformWidth, segment), waveformRMSColor);
                    }
                }
        }
    }

    /**
     * Internal method which graphs audio samples.
     * Used when `samplesPerPixel` is equal to 1.
     */
    // function drawGraphedSamples():Void
    // {
    //     // _shape.graphics.clear();
    //     // _shape.graphics.lineStyle(1, waveformColor);

    //     var centerY:Float = waveformHeight / 2;
    //     var halfCenter:Float = centerY / 2;

    //     switch (waveformDrawMode)
    //     {
    //         case COMBINED:
    //             var prevX:Float = 0;
    //             var prevY:Float = centerY;

    //             _shape.graphics.moveTo(prevX, prevY);

    //             for (i in 0...waveformWidth)
    //             {
    //                 var peak:Float = _drawPointsLeft[i];
    //                 if (_stereo)
    //                 {
    //                     // Can't graph both so let's get average?
    //                     peak += _drawPointsRight[i];
    //                     peak /= 2;
    //                 }

    //                 var curX:Float = i;
    //                 var curY:Float = centerY - peak * centerY;

    //                 _shape.graphics.lineTo(curX, curY);

    //                 prevX = curX;
    //                 prevY = curY;
    //             }

    //         case SPLIT_CHANNELS:
    //             var prevX:Float = 0;
    //             var prevYL:Float = halfCenter;
    //             var prevYR:Float = centerY + halfCenter;

    //             for (i in 0...waveformWidth)
    //             {
    //                 var peakLeft:Float = _drawPointsLeft[i];
    //                 var peakRight:Float = 0;
    //                 if (_stereo)
    //                     peakRight = _drawPointsRight[i];

    //                 var curX:Float = i;
    //                 var curYL:Float = halfCenter - peakLeft * halfCenter;
    //                 var curYR:Float = (centerY + halfCenter) - peakRight * halfCenter;

    //                 // left
    //                 _shape.graphics.moveTo(prevX, prevYL);
    //                 _shape.graphics.lineTo(curX, curYL);

    //                 // right
    //                 _shape.graphics.moveTo(prevX, prevYR);
    //                 _shape.graphics.lineTo(curX, curYR);

    //                 prevX = curX;
    //                 prevYL = curYL;
    //                 prevYR = curYR;
    //             }

    //         case SINGLE_CHANNEL(channel):
    //             var prevX:Float = 0;
    //             var prevY:Float = centerY;

    //             _shape.graphics.moveTo(prevX, prevY);

    //             for (i in 0...waveformWidth)
    //             {
    //                 var peak:Float = channel == 0 ? _drawPointsLeft[i] : _drawPointsRight[i];

    //                 var curX:Float = i;
    //                 var curY:Float = centerY - peak * centerY;

    //                 _shape.graphics.lineTo(curX, curY);

    //                 prevX = curX;
    //                 prevY = curY;
    //             }
    //     }

    //     pixels.draw(_shape);
    // }

    /**
     * Helper function that calls `prepareDrawData()` for both audio channels.
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
     * Prepares data neccessary for the waveform to be drawn. 
     * @param channel The channel to prepare the data for
     */
    function prepareDrawData(channel:Int):Void
    {
        var drawPoints:Array<WaveformSegment> = null;

        // todo: put in a function?
        if (channel == 0)
            drawPoints = _drawPointsLeft;
        else if (channel == 1)
            drawPoints = _drawPointsRight;

        var arrayLength:Int = Math.ceil(waveformBuffer.length / _durationSamples) * _effectiveSize;
        drawPoints.resize(arrayLength);
        resetDrawArray(drawPoints);

        // TODO: Enable graphed sample renderer!
        // if (samplesPerPixel > 1)
        // {
        buildDrawData(channel, drawPoints, true, true);
        // }
        // else
        // {
        //     var endSamples:Int = _timeSamples + _durationSamples;
        //     for (i in _timeSamples...endSamples)
        //         drawPoints.push(samples[i]);
        // }
    }

    /**
     * Internal function that builds the data neccessary to render the waveform.
     * @param channel What channel to build the data for
     * @param points The output array of draw points
     * @param rms The output array of draw RMS points
     * @param full Whether the data should be built for the entire waveform, or just the current segment.
     * @param forceRefresh Whether the data should be updated even if there's a non-zero value in the array.
     */
    function buildDrawData(channel:Int, points:Array<WaveformSegment>, full:Bool = true, forceRefresh:Bool = true):Void
    {
        var samplesGenerated:Int = 0;
        var toGenerate:Int = full ? waveformBuffer.length : _durationSamples;

        var step:Int = Math.round(_durationSamples / _effectiveSize);

        // FIXME: This will either overshoot or undershoot due to decimals
        while (samplesGenerated < toGenerate)
        {
            for (i in 0..._effectiveSize)
            {
                var index:Int = Math.round((full ? samplesGenerated : _timeSamples) / samplesPerPixel) + i;
                if (index < 0)
                    continue;

                if (!forceRefresh && !points[index].silent)
                    continue;

                var startIndex:Int = (full ? samplesGenerated : _timeSamples) + i * step;
                var endIndex:Int = Std.int(Math.min(startIndex + step, waveformBuffer.length));

                points[index] = waveformBuffer.getSegment(channel, startIndex, endIndex, waveformDrawRMS);
            }

            samplesGenerated += _durationSamples;
        }
    }

    /**
     * Returns an `openfl.geom.Rectangle` representing the rectangle
     * of a waveform segment.
     * 
     * This function takes `waveformOrientation` in account.
     * 
     * @param x The rectangle's position on the X axis.
     * @param y Y offset.
     * @param width The width of the peak rectangle.
     * @param height The height of the peak rectangle.
     * @param segment A `WaveformSegment` to visualize.
     * @return A `openfl.geom.Rectangle` instance.
     */
    function getPeakRect(x:Float, y:Float, width:Float, height:Float, segment:WaveformSegment):Rectangle
    {
        var half:Float = height / 2;

        var top:Float = segment.max * half;
        var bottom:Float = segment.min * half;
        var segmentHeight:Float = Math.abs(top) + Math.abs(bottom);

        if (waveformOrientation == VERTICAL)
            return new Rectangle(y + (half - top), x, segmentHeight, width);

        // horizontal
        return new Rectangle(x, y + (half - top), width, segmentHeight);
    }

     /**
     * Returns an `openfl.geom.Rectangle` representing the rectangle
     * of a waveform segment's RMS.
     * 
     * This function takes `waveformOrientation` in account.
     * 
     * @param x The rectangle's position on the X axis.
     * @param y Y offset.
     * @param width The width of the peak rectangle.
     * @param height The height of the peak rectangle.
     * @param segment A `WaveformSegment` with the RMS data.
     * @return A `openfl.geom.Rectangle` instance.
     */
    function getRMSRect(x:Float, y:Float, width:Float, height:Float, segment:WaveformSegment):Rectangle
    {
        var half:Float = height / 2;

        var top:Float = segment.max > 0 ? segment.rms * half : 0;
        var segmentHeight:Float = (segment.max > 0 && segment.min < 0) ? segment.rms * height : segment.rms * half;

        if (waveformOrientation == VERTICAL)
            return new Rectangle(y + (half - top), x, segmentHeight, width);

        // horizontal
        return new Rectangle(x, y + (half - top), width, segmentHeight);
    }

    /**
     * Helper function to calculate the effective size.
     */
    inline function calcEffectiveSize():Void
    {
        _effectiveSize = Math.ceil((waveformOrientation == HORIZONTAL ? waveformWidth : waveformHeight) / (waveformBarSize + waveformBarPadding));
    }

    /**
     * Helper function to calculate the amount of samples per pixel.
     */
    inline function calcSamplesPerPixel():Void
    {
        samplesPerPixel = Std.int(Math.max(Math.ceil(_durationSamples / _effectiveSize), 1));
    }

    /**
     * Sets all array members to `0`
     * @param array The array to be reset.
     */
    inline overload extern function resetDrawArray(array:Array<Float>):Void
    {
        for (i in 0...array.length) 
            array[i] = 0.0;
    }

    /**
     * Sets all array members to `null`
     * @param array The array to be reset.
     */
    inline overload extern function resetDrawArray(array:Array<WaveformSegment>):Void
    {
        for (i in 0...array.length) 
            array[i] = {numSamples: 0, max: 0, min: 0, rms: 0};
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
            calcEffectiveSize();
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

            _drawDataDirty = true;

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

            calcEffectiveSize();
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

            calcEffectiveSize();
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
    
    @:noCompletion function set_waveformOrientation(value:WaveformOrientation):WaveformOrientation 
    {
        if (waveformOrientation != value)
        {
            waveformOrientation = value;

            // if width and height is the same we dont need to rebuild
            if (pixels.width != pixels.height)
            {
                calcEffectiveSize();
                calcSamplesPerPixel();

                _drawDataDirty = true;
            }

            if (autoUpdateBitmap)
                _waveformDirty = true;
        }

        return waveformOrientation;
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

/**
 * An enum representing whether the waveform should be 
 * drawn horizontally (left to right) or vertically (top to bottom).
 * 
 * @since 2.1.0
 */
enum WaveformOrientation
{
    HORIZONTAL;
    VERTICAL;
}
