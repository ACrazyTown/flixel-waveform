package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.display.waveform.FlxWaveform;

class PlayState extends FlxState
{
    var waveform:FlxWaveform;
    var pixelsPerMs:Int;

    override public function create():Void
    {
        super.create();

        // Setup some stuff
        #if debug
        FlxG.console.registerEnum(WaveformDrawMode);
        #end
        FlxG.autoPause = false;
        FlxG.camera.bgColor = 0xFF253475;

        FlxG.sound.music = FlxG.sound.load("assets/beeper" + #if flash ".mp3" #else ".ogg" #end, 1.0, true);

        // NOTE: Due to a limitation, on HTML5
        // you have to play the audio source
        // before trying to make a waveform from it.
        FlxG.sound.music.play(true);

        // Check if bitmap max texture size is available.
        #if FLX_OPENGL_AVAILABLE
        if (FlxG.bitmap.maxTextureSize != -1)
        {
            // Calculate how far can we stretch the waveform before hitting bitmap max limits?
            pixelsPerMs = Math.ceil(FlxG.sound.music.length / FlxG.bitmap.maxTextureSize);
        }
        else
        {
            // In case we don't have a hardware accelerated renderer, we can't accurately
            // get a maximum texture size, so let's just arbitrarily set it to a random number.
            pixelsPerMs = 16;
        }
        #else
        pixelsPerMs = 16;
        #end

        // Create a new FlxWaveform instance.
        waveform = new FlxWaveform(0, 0, Std.int(FlxG.sound.music.length / pixelsPerMs), FlxG.height);

        // Load data from the FlxSound so the waveform renderer can process it.
        waveform.loadDataFromFlxSound(FlxG.sound.music);

        // We set our draw range.
        // When we leave it blank it'll default to a range from the beginning to the full length of the sound.
        waveform.setDrawRange();

        // We'll render both channels of the waveform seperately.
        waveform.waveformDrawMode = SPLIT_CHANNELS;

        // We don't have to manually generate the bitmap here, because `FlxWaveform.autoUpdateBitmap`
        // is true by default, and changing the waveform draw mode above will trigger a redraw.
        // waveform.generateWaveformBitmap();

        // Set the color of the waveform.
        waveform.waveformColor = 0xFF4577BE;

        // Set the color of the waveform's background.
        // In this case we won't set it as our camera's bgColor is the same.
        // waveform.waveformBgColor = 0xFF152E5A;

        // Toggle whether the RMS (root mean square) of the waveform should be drawn.
        // The RMS represents the average/effective loudness of audio.
        waveform.waveformDrawRMS = true;

        // Set the color of the RMS waveform.
        waveform.waveformRMSColor = 0xFF68C3FF;

        // For extra style points we can adjust the size and spacing of the waveform bars!
        // As a demonstration, we'll set the size to 4px and the padding to 2px
        waveform.waveformBarSize = 4;
        waveform.waveformBarPadding = 2;

        add(waveform);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (FlxG.sound.music.playing)
        {
            // Make our camera follow the audio time.
            camera.scroll.x = (FlxG.sound.music.time / pixelsPerMs) * (waveform.waveformBarPadding + waveform.waveformBarSize) / waveform.waveformBarSize;
        }

        if (FlxG.keys.justPressed.SPACE)
        {
            FlxG.sound.music.playing ? FlxG.sound.music.pause() : FlxG.sound.music.resume();
        }
    }
}
