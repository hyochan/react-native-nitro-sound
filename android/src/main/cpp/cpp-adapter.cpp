#include <jni.h>
#include "NitroAudioRecorderPlayerOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::audiorecorderplayer::initialize(vm);
}
