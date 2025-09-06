#include <jni.h>
#include "NitroSoundOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::sound::initialize(vm);
}
