# flixel-waveform Changelog

Legend:
- ✨ - New addition
- 🗑️ - Removal
- 🛠️ - Bugfix/Adjustment
- ⚠️ - Breaking change

## 2.1.2 (July 9th, 2025)
- 🛠️ **Fix** waveforms of the same size reusing the same graphic.

## 2.1.1 (May 24, 2025)
- 🛠️ **Fix** crashes when using single channel (mono) audio.
- 🛠️ **Fix** waveform not rendering because some properties were outside of their intended range.
- 🛠️ **Fix** waveform overflowing outside of its intended area.

## 2.1.0 (May 3, 2025)
- ✨ **Added** support for making waveforms from streamed sounds.
    - No additional work on the user side needs to be done. If you pass a streamed sound to a `FlxWaveform.loadDataFrom...()` method, it will automatically detect and load it.
    - Use the `FlxWaveformBuffer.fromVorbisFile()` method to create an audio buffer from a `lime.media.vorbis.VorbisFile`.
- ✨ **Added** the `FlxWaveform.waveformBuffer` property that exposes the waveform's audio buffer.
- ✨ **Added** the `FlxWaveform.waveformOrientation` property that controls whether the waveform should be drawn horizontally (left to right) or vertically (top to bottom).
- ✨ **Added** the `FlxWaveform.waveformChannelPadding` property that controls the padding between waveform channels when the `FlxWaveform.waveformDrawMode` is set to `SPLIT_CHANNELS`.
- 🛠️ **Fixed** waveform appearance.
    - Previously the waveform would only store the peak value of an audio segment. This caused the waveform to always appear symmetrical. As part of the internal data rework, this has now been corrected and the waveform now keeps track of both the minimum and maximum values of a segment. As a side effect, this also makes the waveform accurate when visualizing very small durations.
- 🛠️ **Fixed** waveform desync.
- 🛠️ **Fixed** crash due to `FlxWaveformBuffer` trying to access a property on a null Lime audio buffer.
- 🛠️ **Adjusted** `FlxWaveform`'s constructor arguments.
    - `x` and `y` are now optional.
    - `width` and `height` are now mandatory.
- 🛠️ `FlxWaveform.waveformDuration` now defaults to 5 seconds (5000ms) instead of 0.
- 🛠️ Various documentation adjustments.

## 2.0.0 (February 15, 2025)
- ✨ **Added** `waveformTime` and `waveformDuration`.
    - Set `waveformDuration` to the length (in miliseconds) you want to visualize.
    - Set `waveformTime` to set the audio time (in miliseconds) the waveform will start at.
- ⚠️🗑️ **Removed** `setDrawRange()` in favor of `waveformTime` and `waveformDuration`.
- ✨ **Added** `waveformBarSize`, `waveformBarPadding`.
    - Allows for more customizable waveform designs!
    - Increase the bar size for more blockier waveforms which are also less expensive to compute.
- ✨ **Added** `waveformRMSColor`, `waveformDrawRMS`.
    - Allows for visualizing the RMS (root mean square) of the audio data.
    - The RMS represents the average/effective loudness of audio.
- ✨ **Added** `waveformDrawBaseline`.
    - Simply draws a line in the middle of the waveform to represent 0
- ✨ **Added** `SINGLE_CHANNEL(channel)` to `WaveformDrawMode` to allow drawing a single channel across the entire waveform area.
- ⚠️🛠️ **Moved** `flixel.addons.display.waveform.BytesExt` to `flixel.addons.display.waveform._internal.BytesExt`.
    - This was never meant to be a public class anyways...
- 🛠️ A good chunk of code was refactored, so probably quite a few bug fixes?

## 1.2.1 (November 21, 2024)
- 🛠️ **Fix** waveform not properly scaling when resizing

## 1.2.0 (November 17, 2024)
- ✨ **Added** Flash support.
- ✨ **Added** experimental HTML5 support.
- 🛠️ 32bit audio now assumes it's stored as in Float32 format.
    - This is temporary until a proper way to differentiate the two is found. See https://github.com/ACrazyTown/flixel-waveform/issues/9
- 🛠️ Samples are now normalized in the range (-1, 1) instead of (0, 1).
    - This is an internal change and should have no effect on anything public.

## 1.1.0 (November 14, 2024)
- ✨ **Added** support for 24bit audio.
- 🛠️ **Fix** crashing when using mono sounds.

## 1.0.1 (November 9, 2024)
- 🛠️ Bugfixes.

## 1.0.0 (November 8, 2024)
- 🎉 Initial release.
