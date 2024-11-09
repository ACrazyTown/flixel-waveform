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

		// Check if bitmap max texture size is available.
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

		// Create a new FlxWaveform instance.
		waveform = new FlxWaveform(0, 0, Std.int(FlxG.sound.music.length / pixelsPerMs), FlxG.height, 0xFF1C98E0);
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
		add(waveform);

		FlxG.sound.music.play(true);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music.playing)
		{
			// Make our camera follow the audio time.
			camera.scroll.x = FlxG.sound.music.time / pixelsPerMs;
		}

		if (FlxG.keys.justPressed.SPACE)
		{
			FlxG.sound.music.playing ? FlxG.sound.music.pause() : FlxG.sound.music.resume();
		}
	}
}
