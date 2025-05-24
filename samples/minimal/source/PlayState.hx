package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.display.waveform.FlxWaveform;
import flixel.util.FlxColor;

class PlayState extends FlxState
{
    var waveform:FlxWaveform;

    override public function create()
    {
        super.create();

        FlxG.autoPause = false;
        FlxG.sound.music = FlxG.sound.load("assets/beeper" + #if flash ".mp3" #else ".ogg" #end, 1.0, true);

        // NOTE: Due to a limitation, on HTML5 you have to play the audio source
        // before trying to make a waveform from it.
        // See: https://github.com/ACrazyTown/flixel-waveform/issues/8
        FlxG.sound.music.play(true);

		waveform = new FlxWaveform(0, 0, FlxG.width, FlxG.height, FlxColor.WHITE, FlxColor.GRAY, SPLIT_CHANNELS);
        waveform.loadDataFromFlxSound(FlxG.sound.music);
        add(waveform);

        // Register a drag and drop callback so that we can change the audio
        // by simply dragging a new audio file to the window
        FlxG.stage.window.onDropFile.add(onDropFile);
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.sound.music?.playing)
            waveform.waveformTime = FlxG.sound.music.time;

        if (FlxG.keys.justPressed.SPACE)
        {
			FlxG.sound.music?.playing ? FlxG.sound.music?.pause() : FlxG.sound.music?.resume();
        }
    }

    override public function destroy():Void
    {
        super.destroy();
        FlxG.stage.window.onDropFile.remove(onDropFile);
    }

    function onDropFile(file:String):Void
    {
        #if (js && html5 && lime_howlerjs)
        var fileList:js.html.FileList = cast file;
        var fileReader = new js.html.FileReader();
        fileReader.onload = () ->
        {
            // TODO: At the moment Lime forces audio buffers created from Base64/bytes
            // to use HTML5 audio, which makes it impossible for us to get audio data to analyze. 
            // Because of this, we need to make a Howl instance ourselves.

            var howl = new lime.media.howlerjs.Howl({
                src: [fileReader.result],
                preload: true
            });

            var buffer = new lime.media.AudioBuffer();
            buffer.src = howl;

            howl.once("play", () ->
            {
                waveform.loadDataFromAudioBuffer(buffer);
            });

            FlxG.sound.music.stop();
            FlxG.sound.playMusic(openfl.media.Sound.fromAudioBuffer(buffer), 1.0, true);
        };
        fileReader.readAsDataURL(fileList.item(0));
        #else
        var buffer = lime.media.AudioBuffer.fromFile(file);
        if (buffer != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.playMusic(openfl.media.Sound.fromAudioBuffer(buffer), 1.0, true);

            waveform.loadDataFromAudioBuffer(buffer);
        }
        #end
    }
}
