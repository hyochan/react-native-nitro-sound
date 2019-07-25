require 'json'
package = JSON.parse(File.read('../package.json'))

Pod::Spec.new do |s|
  s.name         = "RNAudioRecorderPlayer"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = <<-DESC
                  RNAudioRecorderPlayer
                   DESC
  s.homepage     = "https://github.com/dooboolab/react-native-audio-recorder-player"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "author" => "author@domain.cn" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/dooboolab/react-native-audio-recorder-player.git", :tag => "master" }
  s.source_files  = "RNAudioRecorderPlayer/**/*.{h,m}"
  s.requires_arc = true


  s.dependency "React"
  #s.dependency "others"

end

  
