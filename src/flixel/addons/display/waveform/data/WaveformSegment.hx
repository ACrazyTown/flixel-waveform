package flixel.addons.display.waveform.data;

/**
 * Represents the minimum and maximum sample value in
 * a segment of the audio data.
 */
@:forward
abstract WaveformSegment(WaveformSegmentRaw) from WaveformSegmentRaw to WaveformSegmentRaw
{
    /**
     * Merges two `WaveformSegment`s into one by taking the highest maximum and lowest minimum values.
     * 
     * If `segment1` or `segment2` are `null`
     * 
     * @param segment1 The first waveform segment.
     * @param segment2 The second waveform segment.
     * @return A new `WaveformSegment` with merged min and max values.
     */
    public static function merge(segment1:WaveformSegment, segment2:WaveformSegment):WaveformSegment
    {
        var segment:WaveformSegment = {
            max: Math.max(segment1.max, segment2.max),
            min: Math.min(segment1.min, segment2.min)
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
}

private typedef WaveformSegmentRaw =
{
    min:Float,
    max:Float
}
