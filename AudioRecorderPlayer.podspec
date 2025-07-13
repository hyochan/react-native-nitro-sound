require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "AudioRecorderPlayer"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/hyochan/react-native-audio-recorder-player.git", :tag => "#{s.version}" }


  s.source_files = [
    "ios/**/*.{swift}",
    "ios/**/*.{m,mm}",
  ]

  s.pod_target_xcconfig = {
    # C++ compiler flags, mainly for folly.
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) FOLLY_NO_CONFIG FOLLY_CFG_NO_COROUTINES",
    # Swift module configuration
    "SWIFT_VERSION" => "5.0",
    # Fix non-modular includes
    "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES" => "YES"
  }

  s.dependency 'React-jsi'
  s.dependency 'React-callinvoker'

  load 'nitrogen/generated/ios/AudioRecorderPlayer+autolinking.rb'
  add_nitrogen_files(s)

  s.info_plist = {
    'NSMicrophoneUsageDescription' => 'This app needs access to microphone to record audio.'
  }

  install_modules_dependencies(s)
end
