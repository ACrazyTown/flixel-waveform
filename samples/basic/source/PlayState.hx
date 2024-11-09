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

		#if debug
		FlxG.console.registerEnum(WaveformDrawMode);
		#end
		FlxG.autoPause = false;
		FlxG.camera.bgColor = 0xFF152E5A;

		FlxG.sound.playMusic("assets/beeper.ogg");
		FlxG.sound.music.stop();
		FlxG.sound.music.looped = true;

		// How far can we stretch the sound before hitting bitmap max limits?
		if (FlxG.bitmap.maxTextureSize != -1)
			pixelsPerMs = Math.ceil(FlxG.sound.music.length / FlxG.bitmap.maxTextureSize);
		else
			pixelsPerMs = 16; // Random number as fallback

		waveform = new FlxWaveform(0, 0, Std.int(FlxG.sound.music.length / pixelsPerMs), FlxG.height, 0xFF1C98E0);
		waveform.loadDataFromFlxSound(FlxG.sound.music);
		waveform.setDrawRange();
		waveform.waveformDrawMode = SPLIT_CHANNELS;
		// We do it once here, and if we change any properties the bitmap will be automatically
		// updated because `waveform.autoUpdateBitmap` is true by default.
		waveform.generateWaveformBitmap();
		add(waveform);

		FlxG.sound.music.play(true);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music.playing)
		{
			camera.scroll.x = FlxG.sound.music.time / pixelsPerMs;
		}

		if (FlxG.keys.justPressed.SPACE)
		{
			FlxG.sound.music.playing ? FlxG.sound.music.pause() : FlxG.sound.music.resume();
		}
	}
}
