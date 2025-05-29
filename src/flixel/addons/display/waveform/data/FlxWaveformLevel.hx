package flixel.addons.display.waveform.data;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;

@:allow(flixel.addons.display.waveform.data.FlxWaveformData)
class FlxWaveformLevel implements IFlxDestroyable
{
    final SPP_LOOKUP_FROM_BUFFER_MAX:Int = 15;

    public var samplesPerPixel(default, null):Int;

    public var dataLength(get, never):Int;

    var dataLeft:Array<FlxWaveformSegment>;
    var dataRight:Array<FlxWaveformSegment>;

    var holdsData:Bool;
    var parent:FlxWaveformData;

    function new(parent:FlxWaveformData, samplesPerPixel:Int)
    {
        this.parent = parent;
        this.samplesPerPixel = samplesPerPixel;

        holdsData = samplesPerPixel > SPP_LOOKUP_FROM_BUFFER_MAX;

        if (holdsData)
        {
            dataLeft = [];
            dataRight = [];
        }
    }

    public function destroy():Void
    {
        dataLeft = null;
        dataRight = null;
    }

    public function getSegment(channel:Int, index:Int):FlxWaveformSegment
    {
        // Fetch from cached segments
        if (samplesPerPixel > SPP_LOOKUP_FROM_BUFFER_MAX)
            return channel == 0 ? dataLeft[index] : dataRight[index];

        // Fetch from buffer
        return parent.buffer.getSegment(channel, index * samplesPerPixel, index * samplesPerPixel + 1, true);
    }

    public function generateRangeFromLevel(level:FlxWaveformLevel, start:Int, end:Int):Void
    {
        var durationSamples:Int = samplesPerPixel * parent.size;
        var arrayLength:Int = Math.ceil(end / durationSamples * parent.size);
        var lengthDiff = level.dataLength / arrayLength;

        dataLeft.resize(arrayLength);
        dataRight.resize(arrayLength);

        trace(level.dataLength);
        trace(arrayLength);
        trace(lengthDiff);

        for (i in 0...arrayLength)
        {
            var levelIndex:Int = Std.int(i * lengthDiff);
            var nextLevelIndex:Int = Std.int(Math.min(Std.int((i + 1) * lengthDiff), level.dataLength));

            // FIXME please make this better and ensure there's no nulls to deal with at all to begin wiht

            // var thing1 = level.dataLeft[levelIndex];
            // var thing2 = level.dataLeft[nextLevelIndex];
            // var thing3 = level.dataRight[levelIndex];
            // var thing4 = level.dataRight[nextLevelIndex];

            // if (thing1 == null || thing2 == null || thing3 == null || thing4 == null)
            // {
            //     trace("NUILLL!!!");
            //     continue;
            // }

            // dataLeft[i] = FlxWaveformSegment.merge(level.dataLeft[levelIndex], level.dataLeft[nextLevelIndex]);
            // dataRight[i] = FlxWaveformSegment.merge(level.dataRight[levelIndex], level.dataRight[nextLevelIndex]);

            var segmentsToMergeLeft = level.dataLeft.slice(levelIndex, nextLevelIndex);
            var segmentsToMergeRight = level.dataRight.slice(levelIndex, nextLevelIndex);

            dataLeft[i] = FlxWaveformSegment.mergeArray(segmentsToMergeLeft);
            dataRight[i] = FlxWaveformSegment.mergeArray(segmentsToMergeRight);
        }
    }

    public function generateRange(start:Int, end:Int):Void
    {
        trace("hey. im DEFINITELY being called!");

        var durationSamples:Int = samplesPerPixel * parent.size;

        var arrayLength:Int = Math.ceil(end / durationSamples * parent.size);
        dataLeft.resize(arrayLength);
        dataRight.resize(arrayLength);

        var samplesGenerated:Int = start;
        var toGenerate:Int = end; // full ? waveformBuffer.length : _durationSamples;

        // FIXME: This will either overshoot or undershoot due to decimals
        while (samplesGenerated < toGenerate)
        {
            var offset:Int = Math.round(samplesGenerated / samplesPerPixel);

            for (i in 0...parent.size)
            {
                var index:Int = offset + i;
                if (index < 0)
                    continue;

                var startIndex:Int = samplesGenerated + i * samplesPerPixel;
                var endIndex:Int = Std.int(Math.min(startIndex + samplesPerPixel, end));

                dataLeft[index] = parent.buffer.getSegment(0, startIndex, endIndex, true);
                dataRight[index] = parent.buffer.getSegment(1, startIndex, endIndex, true);
            }

            samplesGenerated += durationSamples;
        }

        trace(dataLeft.length);
        trace(dataRight.length);
    }
    
    @:noCompletion function get_dataLength():Int
    {
        return dataLeft?.length;
    }
}
