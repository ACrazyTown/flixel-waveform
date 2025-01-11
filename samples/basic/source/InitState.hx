package;

import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxState;

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

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        // Check for user interaction & switch state if we get one.
        #if js
        if (FlxG.mouse.justPressed)
            FlxG.switchState(PlayState.new);
        #end
    }
}
