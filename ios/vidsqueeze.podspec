Pod::Spec.new do |s|
  s.name             = 'vidsqueeze'
  s.version          = '0.1.0-dev.1'
  s.summary          = 'Flutter video compression plugin with native Android and iOS cores.'
  s.description      = <<-DESC
Flutter plugin for cross-platform video compression. Android Media3 core and iOS native compression core are included in this workspace.
                       DESC
  s.homepage         = 'https://github.com/wat97/media3-compressi'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'wat97' => 'opensource@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
