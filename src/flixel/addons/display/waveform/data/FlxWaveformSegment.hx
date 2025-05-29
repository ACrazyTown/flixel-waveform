package flixel.addons.display.waveform.data;

/**
 * Represents the minimum and maximum sample value in
 * a segment of the audio data.
 */
@:forward
abstract FlxWaveformSegment(FlxWaveformSegmentRaw) from FlxWaveformSegmentRaw to FlxWaveformSegmentRaw
{
    /**
     * Merges two `FlxWaveformSegment`s into one by taking the highest maximum and lowest minimum values.
     * 
     * If `segment1` or `segment2` are `null`
     * 
     * @param segment1 The first waveform segment.
     * @param segment2 The second waveform segment.
     * @return A new `FlxWaveformSegment` with merged min and max values.
     */
    public static function merge(segment1:FlxWaveformSegment, segment2:FlxWaveformSegment):FlxWaveformSegment
    {
        var rms:Float = 0.0;
        if (segment1.rms != 0 && segment2.rms != 0)
            rms = Math.sqrt((segment1.numSamples * segment1.rms * segment1.rms + segment2.numSamples * segment2.rms * segment2.rms) / (segment1.numSamples + segment2.numSamples));

        var segment:FlxWaveformSegment = {
            startIndex: Std.int(Math.min(segment1.startIndex, segment2.startIndex)),
            endIndex: Std.int(Math.max(segment1.max, segment2.max)),
            max: Math.max(segment1.max, segment2.max),
            min: Math.min(segment1.min, segment2.min),
            rms: rms
        }

        return segment;
    }

    /**
     * Helper function that merges all `FlxWaveformSegment`s from an array.
     * 
     * @param array Array of waveform segments to be merged into one.
     * @return Merged segment.
     */
    public static function mergeArray(array:Array<FlxWaveformSegment>):FlxWaveformSegment
    {
        var segment:FlxWaveformSegment = array[0];
        for (i in 1...array.length)
        {
            var arraySegment:FlxWaveformSegment = array[i];
            if (arraySegment == null)
                continue;

            segment = FlxWaveformSegment.merge(segment, arraySegment);
        }

        return segment;
    }

    /**
     * Whether this segment is silent (both min and max are equal to 0).
     */
    public var silent(get, never):Bool;
    
    @:noCompletion function get_silent():Bool
    {
        // // TODO: Don't check this here but rather ensure it's never null in our generated data?
        // if (this == null) return true;

        return this.min == 0 && this.max == 0;
    }

    /**
     * The number of audio samples this segment covers.
     * 
     * This is merely a shortcut for `segment.endIndex - segment.startIndex`.
     */
    public var numSamples(get, never):Int;

    @:noCompletion function get_numSamples():Int
    {
        return this.endIndex - this.startIndex;
    }
}

private typedef FlxWaveformSegmentRaw =
{
    startIndex:Int,
    endIndex:Int,
    min:Float,
    max:Float,
    rms:Float
}
