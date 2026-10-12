Pod::Spec.new do |s|
  s.name = 'ReadingOCR'
  s.version = '0.1.0'
  s.summary = 'On-device word recognition for Reading Translator'
  s.description = 'Apple Vision OCR with word-level image coordinates.'
  s.license = { :type => 'MIT' }
  s.author = 'Reading Translator'
  s.homepage = 'https://github.com/12hleb/ReadingApp'
  s.platforms = { :ios => '15.1' }
  s.source = { :git => 'https://github.com/12hleb/ReadingApp.git' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.frameworks = 'Vision', 'ImageIO'
  s.source_files = '**/*.{h,m,mm,swift}'
  s.swift_version = '5.9'
end
