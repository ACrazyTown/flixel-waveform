## 2.0.0
- ✨ **Added** `waveformTime` and `waveformDuration`
    - Set `waveformDuration` to the length (in miliseconds) you want to visualize.
    - Set `waveformTime` to set the audio time (in miliseconds) the waveform will start at.
- 🗑️ **Removed** `setDrawRange()` in favor of `waveformTime` and `waveformDuration`
- ✨ **Added** `waveformBarSize`, `waveformBarPadding`,
    - Allows for more customizable waveform designs!
    - Increase the bar size for more blockier waveforms which are also less expensive to compute
- ✨ **Added** `waveformRMSColor`, `waveformDrawRMS`
    - Allows for visualizing the RMS (root mean square) of the audio data.
    - The RMS represents the average/effective loudness of audio.
- ✨ **Added** `waveformDrawBaseline`
    - Simply draws a line in the middle of the waveform to represent 0
- ✨ **Added** sample graph renderer when trying to view very low time ranges
    - A seamless way of transitioning from the peak-based renderer and the graphed samples is planned for a future release.
- ✨ **Added** `SINGLE_CHANNEL(channel)` to `WaveformDrawMode` to allow drawing a single channel across the entire waveform area.
- 🛠️ **Moved** `flixel.addons.display.waveform.BytesExt` to `flixel.addons.display.waveform._internal.BytesExt`
    - This was never meant to be a public class anyways...
- A good chunk of code was refactored, so probably quite a few bug fixes?

## 1.2.0
- ✨ **Added** experimental HTML5 support
- 32bit audio now assumes it's stored as in Float32 format
    - This is temporary until a proper way to differentiate the two is found. See https://github.com/ACrazyTown/flixel-waveform/issues/9
- Samples are now normalized in the range (-1, 1) instead of (0, 1)
    - This is an internal change and should have no effect on anything public.

## 1.1.0
- ✨ **Added** support for 24bit audio
- 🛠️ **Fix** crashing when using mono sounds.

## 1.0.1
- Bugfixes

## 1.0.0
- Initial release
