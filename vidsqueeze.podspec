Pod::Spec.new do |s|
  s.name             = 'vidsqueeze'
  s.version          = '0.1.0-dev.1'
  s.summary          = 'Flutter video compression plugin scaffold with Android Media3 core.'
  s.description      = <<-DESC
Flutter plugin scaffold for cross-platform video compression. Android Media3 core is included; iOS parity scaffolding is prepared for native implementation.
                       DESC
  s.homepage         = 'https://github.com/wat97/media3-compressi'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wat97' => 'opensource@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'ios/Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
