#pragma once
#include <QtGlobal>
#ifdef Q_OS_MACOS
#include <Limelight.h>
struct AVFrame;
void nativeRecorderVideoConfig(int codec, int width, int height, int fps);
void nativeRecorderAudioConfig(const OPUS_MULTISTREAM_CONFIGURATION*);
void nativeRecorderStart();
void nativeRecorderQuiesce();
void nativeRecorderStop();
void nativeRecorderCommand(unsigned);
void nativeRecorderVideo(PDECODE_UNIT);
void nativeRecorderPixel(const AVFrame*);
void nativeRecorderAudio(const void*, int);
#endif
