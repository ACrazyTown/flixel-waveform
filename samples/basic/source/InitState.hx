package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxTimer;

class InitState extends FlxState
{
    override function create():Void
    {
        #if js
        // On JavaScript/HTML5 we have to get a user interaction first
        // otherwise we cannot create an AudioContext and the app
        // will crash.
        var text:FlxText = new FlxText(0, 0, 0, "Click to start", 32);
        text.screenCenter();
        add(text);
        #else
        // If on a different target we can just proceed as usual.
        FlxG.switchState(PlayState.new);
        #end
    }

    var switching:Bool = false;
    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        // Check for user interaction & switch state if we get one.
        #if js
        if (FlxG.mouse.justPressed && !switching)
        {
            switching = true;

            // Wait a small amount of time before switching to the state
            // to give time for the audio context to start and avoid a crash
            // See: https://github.com/ACrazyTown/flixel-waveform/issues/8#issuecomment-2585483164
            FlxTimer.wait(0.1, () -> FlxG.switchState(PlayState.new));
        }
        #end
    }
}
