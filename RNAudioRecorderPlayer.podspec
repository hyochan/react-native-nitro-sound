require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = "RNAudioRecorderPlayer"
  s.version      = package['version']
  s.summary      = package['description']
  s.license      = package['license']

  s.authors      = package['author']
  s.homepage     = package['homepage']
  s.platform     = :ios, "11.0"
  s.ios.deployment_target = "10.0"

  s.source       = { :git => "https://github.com/hyochan/react-native-audio-recorder-player.git", :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,c,cc,cpp,m,mm,swift}"

  s.dependency 'React-Core'

  # Define the Nitro module
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES'
  }
end

