## 1.2.1
- Fix waveform not properly scaling when resizing

## 1.2
- Added experimental HTML5 support
- 32bit audio now assumes it's stored as in Float32 format
    - This is temporary until a proper way to differentiate the two is found. See https://github.com/ACrazyTown/flixel-waveform/issues/9
- Samples are now normalized in the range (-1, 1) instead of (0, 1)
    - This is an internal change and should have no effect on anything public.

## 1.1
- Added support for 24bit audio
- Fix crashing when using mono sounds.

## 1.0.1
- Bugfixes

## 1.0.0
- Initial release
