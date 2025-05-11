package flixel.addons.display.waveform.data;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;

class FlxWaveformData implements IFlxDestroyable
{
    public var size(default, null):Int;
    public var buffer(default, null):FlxWaveformBuffer;

    public var currentLevel(get, never):FlxWaveformLevel;

    var levels:Map<Int, FlxWaveformLevel>;
    var activeLevel:Int;

    public function new(buffer:FlxWaveformBuffer, initialSize:Int)
    {
        this.buffer = buffer;
        size = initialSize;
        levels = [];
    }

    public function destroy():Void
    {
        clearLevels();
        levels = null;
    }

    public function resize(newSize:Int):Void
    {
        if (size != newSize)
        {
            size = newSize;
            clearLevels();
       }

       var level:FlxWaveformLevel = generateLevel(activeLevel);
    }

    public function setLevel(samplesPerPixel:Int):Void
    {
        trace('SETTING LEVEL TO $samplesPerPixel') ;
        trace(levels);

        if (levels.exists(samplesPerPixel))
        {
            activeLevel = samplesPerPixel;
            return;
        }

        trace("Pass done lets generateeeee");

        var level:FlxWaveformLevel = generateLevel(samplesPerPixel);
        registerLevel(samplesPerPixel, level);
        activeLevel = samplesPerPixel;
    }

    public function generateLevel(samplesPerPixel:Int, overwrite:Bool = false):FlxWaveformLevel
    {
        if (levels.exists(samplesPerPixel) && !overwrite)
            return levels[samplesPerPixel];

        var baseLevelKey:Int = -1;
        for (levelSamplesPerPixel in levels.keys())
        {
            if (levelSamplesPerPixel < samplesPerPixel && levelSamplesPerPixel > baseLevelKey)
                baseLevelKey = levelSamplesPerPixel;
        }
        
        var level:FlxWaveformLevel = new FlxWaveformLevel(this, samplesPerPixel);

        // // subsample existing level
        // if (baseLevelKey != -1)
        // {
        //     var baseLevel:FlxWaveformLevel = levels[baseLevelKey];
        //     level.generateRangeFromLevel(baseLevel, 0, buffer.length);
        // }
        // // read from buffer
        // else
        {
            level.generateRange(0, buffer.length);
        }

        return level;
    }

    inline public function registerLevel(samplesPerPixel:Int, level:FlxWaveformLevel):Void
    {
        levels.set(samplesPerPixel, level);
    }

    function clearLevels():Void
    {
        for (level in levels)
        {
            level.destroy();
        }

        levels.clear();
    }

    function get_currentLevel():FlxWaveformLevel {
        return levels[activeLevel];
    }
}
