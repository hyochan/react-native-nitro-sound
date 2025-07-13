#include <jni.h>
#include "audiorecorderplayerOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::audiorecorderplayer::initialize(vm);
}
