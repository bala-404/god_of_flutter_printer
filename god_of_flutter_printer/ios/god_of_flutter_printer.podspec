#
# God of Flutter Printer — iOS BLE platform code.
#
Pod::Spec.new do |s|
  s.name             = 'god_of_flutter_printer'
  s.version          = '0.1.0'
  s.summary          = 'God of Flutter Printer iOS platform code'
  s.description      = 'BLE and network printing for God of Flutter Printer on iOS.'
  s.homepage         = 'https://github.com/bala-404/god_of_flutter_printer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Balamurugan' => 'messagetobalamurugan@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
