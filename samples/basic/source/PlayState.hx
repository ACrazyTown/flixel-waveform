package;

import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUICheckBox;
import flixel.text.FlxText;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIState;
import flixel.ui.FlxButton;
import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.display.waveform.FlxWaveform;

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

        // Asychronously rebuild the waveform's data
        waveform.rebuildDataAsync = true;

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

        // Add our waveform to the state.
        add(waveform);

        // Sets up the UI for the sample. You can ignore this.
        setupUI();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (FlxG.sound.music.playing)
        {
            // Set our waveform's time to the music's time, keeping them in sync.
            waveform.waveformTime = FlxG.sound.music.time;
        }

        if (FlxG.keys.justPressed.SPACE)
            playPause();
    }

    // --- Beyond this point is UI code you should not care about --
    var ui:FlxUI;
    var playPauseBtn:FlxButton;

    function setupUI():Void
    {
        ui = new FlxUI();
        add(ui);

        playPauseBtn = new FlxButton(5, 0, "Pause Music", playPause);
        playPauseBtn.y = 5;
        ui.add(playPauseBtn);

        var drawRMSCheckbox:FlxUICheckBox = new FlxUICheckBox(10, 0, null, null, "Draw RMS");
        drawRMSCheckbox.y = 30;
        drawRMSCheckbox.checked = true;
        drawRMSCheckbox.callback = () ->
        {
            waveform.waveformDrawRMS = !waveform.waveformDrawRMS;
        };
        ui.add(drawRMSCheckbox);

        var paddingStepper:FlxUINumericStepper = new FlxUINumericStepper(drawRMSCheckbox.x + drawRMSCheckbox.width - 10, 0, 1, 0, 0, 100, 0);
        paddingStepper.y = 10;
        paddingStepper.value = waveform.waveformBarPadding;
        paddingStepper.name = "s_padding";
        ui.add(paddingStepper);
        var paddingLabel:FlxText = new FlxText(0, 0, 0, "Bar Padding");
        paddingLabel.x = paddingStepper.x + paddingStepper.width;
        paddingLabel.y = paddingStepper.y;
        ui.add(paddingLabel);

        var sizeStepper:FlxUINumericStepper = new FlxUINumericStepper(drawRMSCheckbox.x + drawRMSCheckbox.width - 10, 0, 1, 1, 1, 100, 0);
        sizeStepper.y = paddingStepper.y + 20;
        sizeStepper.value = waveform.waveformBarSize;
        sizeStepper.name = "s_size";
        ui.add(sizeStepper);
        var sizeLabel:FlxText = new FlxText(0, 0, 0, "Bar Size");
        sizeLabel.x = sizeStepper.x + sizeStepper.width;
        sizeLabel.y = sizeStepper.y;
        ui.add(sizeLabel);

        var drawModeLabel:FlxText = new FlxText(paddingLabel.x + 80, 5, 0, "Waveform Draw Mode");
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
        }
    }
}
