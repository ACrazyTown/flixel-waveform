package flixel.addons.display.waveform.data;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import lime.utils.Float32Array;

@:allow(flixel.addons.display.waveform.data.FlxWaveformData)
class FlxWaveformLevel implements IFlxDestroyable
{
    public var samplesPerPixel(default, null):Int;

    public var dataLeft:Array<FlxWaveformSegment>;
    public var dataRight:Array<FlxWaveformSegment>;

    var parent:FlxWaveformData;

    function new(parent:FlxWaveformData, samplesPerPixel:Int)
    {
        this.parent = parent;
        this.samplesPerPixel = samplesPerPixel;

        dataLeft = [];
        dataRight = [];
    }

    public function destroy():Void
    {
        dataLeft = null;
        dataRight = null;
    }

    public function generateRangeFromLevel(level:FlxWaveformLevel, start:Int, end:Int):Void
    {

    }

    public function generateRange(start:Int, end:Int):Void
    {
        trace("hey. im DEFINITELY being called!");

        var durationSamples:Int = samplesPerPixel * parent.size;

        var arrayLength:Int = Math.ceil(parent.buffer.length / durationSamples) * parent.size;
        dataLeft.resize(arrayLength);
        dataRight.resize(arrayLength);

        var samplesGenerated:Int = start;
        var toGenerate:Int = end; // full ? waveformBuffer.length : _durationSamples;

        // FIXME: This will either overshoot or undershoot due to decimals
        while (samplesGenerated < toGenerate)
        {
            for (i in 0...parent.size)
            {
                var index:Int = Math.round(samplesGenerated / samplesPerPixel) + i;
                if (index < 0)
                    continue;

                var startIndex:Int = samplesGenerated + i * samplesPerPixel;
                var endIndex:Int = Std.int(Math.min(startIndex + samplesPerPixel, parent.buffer.length));

                dataLeft[index] = parent.buffer.getSegment(0, startIndex, endIndex, true);
                dataRight[index] = parent.buffer.getSegment(1, startIndex, endIndex, true);
            }

            samplesGenerated += durationSamples;
        }

        trace(dataLeft.length);
        trace(dataRight.length);
    }
}
