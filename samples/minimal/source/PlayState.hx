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

		waveform = new FlxWaveform(0, 0, FlxG.width, FlxG.height, FlxColor.GRAY, FlxColor.WHITE, SPLIT_CHANNELS);
		waveform.loadDataFromFlxSound(FlxG.sound.music);
		add(waveform);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.sound.music?.playing)
			waveform.waveformTime = FlxG.sound.music.time;

		if (FlxG.keys.justPressed.SPACE)
		{
			FlxG.sound.music?.playing ? FlxG.sound.music?.resume() : FlxG.sound.music?.pause();
		}
	}
}
