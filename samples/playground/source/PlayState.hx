package;

import flixel.util.FlxTimer;
import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.display.waveform.FlxWaveform;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUIState;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxStringUtil;

class PlayState extends FlxUIState
{
    var waveform:FlxWaveform;

    override public function create():Void
    {
        super.create();

        FlxG.autoPause = false;
        FlxG.sound.music = FlxG.sound.load("assets/beeper" + #if flash ".mp3" #else ".ogg" #end, 1.0, true);

        // NOTE: Due to a limitation, on HTML5 you have to play the audio source
        // before trying to make a waveform from it.
        // See: https://github.com/ACrazyTown/flixel-waveform/issues/8
        FlxG.sound.music.play(true);
        
        // Create a new FlxWaveform instance.
        waveform = new FlxWaveform(0, 50, FlxG.width, FlxG.height - 50);

        // Load data from the FlxSound so the waveform renderer can process it.
        waveform.loadDataFromFlxSound(FlxG.sound.music);

        // Set our waveform's starting time at 0ms.
        waveform.waveformTime = 0;

        // We want to visualize up to 5000ms (5s) ahead
        waveform.waveformDuration = 5000;

        // We'll render both channels of the waveform seperately.
        waveform.waveformDrawMode = SPLIT_CHANNELS;

        // We don't have to manually generate the bitmap here, because `FlxWaveform.autoUpdateBitmap`
        // is true by default, and changing anything that visually affects the wavefrom will trigger a redraw.
        // waveform.generateWaveformBitmap();

        // Set the color of the waveform.
        waveform.waveformColor = 0xFF4577BE;

        // Set the color of the waveform's background.
        waveform.waveformBgColor = 0xFF253475;

        // Toggle whether the RMS (root mean square) of the waveform should be drawn.
        // The RMS represents the average/effective loudness of audio.
        waveform.waveformDrawRMS = true;

        // Set the color of the RMS waveform.
        waveform.waveformRMSColor = 0xFF68C3FF;

        // Whether the waveform baseline (line in the middle representing 0.0 of the sample) should be drawn
        waveform.waveformDrawBaseline = true;

        // For extra style points we can adjust the size and spacing of the waveform bars!
        // As a demonstration, we'll set the size to 4px and the padding to 2px
        waveform.waveformBarSize = 4;
        waveform.waveformBarPadding = 2;

        // Set the padding between channels to be 2px.
        waveform.waveformChannelPadding = 2;

        // Add our waveform to the state.
        add(waveform);

        // Sets up the UI for the sample. You can ignore this.
        setupUI();

        // Register a drag and drop callback so that we can change the audio
        // by simply dragging a new audio file to the window
        FlxG.stage.window.onDropFile.add(onDropFile);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (FlxG.sound.music.playing)
        {
            // Set our waveform's time to the music's time, keeping them in sync.
            waveform.waveformTime = FlxG.sound.music.time + getLatency();
            time.text = '${FlxStringUtil.formatTime(waveform.waveformTime / 1000, true)} - ${FlxStringUtil.formatTime((waveform.waveformTime + waveform.waveformDuration) / 1000, true)}';
        }

        if (FlxG.keys.justPressed.SPACE)
            playPause();
    }

    override public function destroy():Void
    {
        super.destroy();
        FlxG.stage.window.onDropFile.remove(onDropFile);
    }

    // --- Beyond this point is UI code you should not care about --
    var ui:FlxUI;
    var playPauseBtn:FlxButton;
    var time:FlxText;

    function setupUI():Void
    {
        ui = new FlxUI();
        add(ui);

        playPauseBtn = new FlxButton(5, 0, "Pause Music", playPause);
        playPauseBtn.y = 5;
        ui.add(playPauseBtn);

        var drawRMSCheckbox:FlxUICheckBox = new FlxUICheckBox(5, 0, null, null, "Draw RMS", 70);
        drawRMSCheckbox.y = 30;
        drawRMSCheckbox.checked = true;
        drawRMSCheckbox.callback = () ->
        {
            waveform.waveformDrawRMS = !waveform.waveformDrawRMS;
        };
        ui.add(drawRMSCheckbox);

        var paddingStepper:FlxUINumericStepper = new FlxUINumericStepper(drawRMSCheckbox.x + drawRMSCheckbox.width - 5, 0, 1, 0, 0, 100, 0);
        paddingStepper.y = 10;
        paddingStepper.value = waveform.waveformBarPadding;
        paddingStepper.name = "s_padding";
        ui.add(paddingStepper);
        var paddingLabel:FlxText = new FlxText(0, 0, 0, "Bar Padding");
        paddingLabel.x = paddingStepper.x + paddingStepper.width;
        paddingLabel.y = paddingStepper.y;
        ui.add(paddingLabel);

        var sizeStepper:FlxUINumericStepper = new FlxUINumericStepper(drawRMSCheckbox.x + drawRMSCheckbox.width - 5, 0, 1, 1, 1, 100, 0);
        sizeStepper.y = paddingStepper.y + 20;
        sizeStepper.value = waveform.waveformBarSize;
        sizeStepper.name = "s_size";
        ui.add(sizeStepper);
        var sizeLabel:FlxText = new FlxText(0, 0, 0, "Bar Size");
        sizeLabel.x = sizeStepper.x + sizeStepper.width;
        sizeLabel.y = sizeStepper.y;
        ui.add(sizeLabel);

        var drawModeLabel:FlxText = new FlxText(paddingLabel.x + 70, 5, 0, "Waveform Draw Mode");
        ui.add(drawModeLabel);
        var drawModeDropdown:FlxUIDropDownMenu = new FlxUIDropDownMenu(drawModeLabel.x, 20, FlxUIDropDownMenu.makeStrIdLabelArray(["Combined", "Split Channels", "Single Channel (Left)", "Single Channel (Right)"]), (select) ->
        {
            switch (select)
            {
                case "Combined": waveform.waveformDrawMode = COMBINED;
                case "Split Channels": waveform.waveformDrawMode = SPLIT_CHANNELS;
                case "Single Channel (Left)": waveform.waveformDrawMode = SINGLE_CHANNEL(0);
                case "Single Channel (Right)": waveform.waveformDrawMode = SINGLE_CHANNEL(1);
            }
        });
        drawModeDropdown.selectedLabel = "Split Channels";
        ui.add(drawModeDropdown);

        // i hate flixel-ui
        var orientationCheckbox:FlxUICheckBox = new FlxUICheckBox(drawModeDropdown.x + drawModeDropdown.width + 5, 0, null, null, "", 0);
        orientationCheckbox.y = 5;
        orientationCheckbox.callback = () ->
        {
            waveform.waveformOrientation = orientationCheckbox.checked ? VERTICAL : HORIZONTAL;
        };
        ui.add(orientationCheckbox);

        var orientationCheckboxLabel:FlxText = new FlxText(orientationCheckbox.x + orientationCheckbox.width, orientationCheckbox.y, 0, "Vertical?");
        ui.add(orientationCheckboxLabel);

        var baselineCheckbox:FlxUICheckBox = new FlxUICheckBox(orientationCheckbox.x, orientationCheckbox.y + orientationCheckbox.width + 5, null, null, "Baseline", 70);
        baselineCheckbox.checked = waveform.waveformDrawBaseline;
        baselineCheckbox.callback = () ->
        {
            waveform.waveformDrawBaseline = baselineCheckbox.checked;
        };
        ui.add(baselineCheckbox);

        var durationStepper:FlxUINumericStepper = new FlxUINumericStepper(orientationCheckboxLabel.x + orientationCheckboxLabel.width + 5, 1, 0.5, 5, 0.1, Math.round(FlxG.sound.music.length / 1000), 1);
        durationStepper.y = 10;
        durationStepper.value = Std.int(waveform.waveformDuration / 1000);
        durationStepper.name = "s_duration";
        ui.add(durationStepper);
        var durationLabel:FlxText = new FlxText(0, 0, 0, "Duration (s)");
        durationLabel.x = durationStepper.x + durationStepper.width;
        durationLabel.y = durationStepper.y;
        ui.add(durationLabel);

        var channelPaddingStepper:FlxUINumericStepper = new FlxUINumericStepper(durationStepper.x, durationStepper.y + durationStepper.height + 5, 1, 0, 0, 100);
        channelPaddingStepper.value = waveform.waveformChannelPadding;
        channelPaddingStepper.name = "s_channelPadding";
        ui.add(channelPaddingStepper);
        var channelPaddingLabel:FlxText = new FlxText(0, 0, 0, "Channel padding (px)");
        channelPaddingLabel.x = channelPaddingStepper.x + channelPaddingStepper.width;
        channelPaddingLabel.y = channelPaddingStepper.y;
        ui.add(channelPaddingLabel);

        time = new FlxText(5, waveform.y, 0, "0");
        ui.add(time);
    }

    function playPause():Void
    {
        FlxG.sound.music.playing ? FlxG.sound.music.pause() : FlxG.sound.music.resume();
        playPauseBtn.text = (FlxG.sound.music.playing ? "Pause" : "Play") + " Music";
    }

    override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
    {
        super.getEvent(id, sender, data, params);

        if (id == FlxUINumericStepper.CHANGE_EVENT && sender is FlxUINumericStepper)
        {
            var stepper:FlxUINumericStepper = cast sender;
            if (stepper.name == "s_padding") 
                waveform.waveformBarPadding = Std.int(stepper.value);
            else if (stepper.name == "s_size")
                waveform.waveformBarSize = Std.int(stepper.value);
            else if (stepper.name == "s_duration")
                waveform.waveformDuration = stepper.value * 1000;
            else if (stepper.name == "s_channelPadding")
                waveform.waveformChannelPadding = Std.int(stepper.value);
        }
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

    function getLatency():Float
    {
        #if js
        var ctx = lime.media.AudioManager.context.web;
		if (ctx != null)
		{
			var baseLatency:Float = untyped ctx.baseLatency != null ? untyped ctx.baseLatency : 0;
			var outputLatency:Float = untyped ctx.outputLatency != null ? untyped ctx.outputLatency : 0;

			return (baseLatency + outputLatency) * 1000;
		}

		return 0;
        #else
        return 0;
        #end
    }
}
