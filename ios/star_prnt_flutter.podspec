#
# Podspec for the star_prnt_flutter plugin.
#
Pod::Spec.new do |s|
  s.name             = 'star_prnt_flutter'
  s.version          = '1.1.0'
  s.summary          = 'Flutter plugin for Star Micronics thermal printers (USB and Bluetooth via Star\'s native iOS SDK).'
  s.description      = <<-DESC
  Native bridge for star_prnt_flutter. Vendors Star\'s StarIO and StarIO_Extension
  frameworks to enable USB and Bluetooth printer connectivity on iOS, including
  MFi External Accessory support.
                       DESC
  s.homepage         = 'https://github.com/yourusername/star_prnt_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jeff Glenn' => 'jglenn@rootsnk.com' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.swift_version = '5.0'

  s.static_framework = true
  s.preserve_paths = 'Frameworks/*.framework'
  s.vendored_frameworks = 'Frameworks/*.framework'

  s.xcconfig = {
    "OTHER_LDFLAGS" => '$(inherited) -framework "ExternalAccessory" -framework "CoreBluetooth" -framework "StarIO" -framework "StarIO_Extension"'
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
end
