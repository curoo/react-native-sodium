require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = package['name']
  s.version      = package['version']
  s.summary      = package['description']
  s.license      = package['license']

  s.authors      = package['author']
  s.homepage     = package['homepage']
  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/lyubo/react-native-sodium.git", :tag => "v#{s.version}" }
  s.source_files = "ios/**/*.{h,m,mm}", "cpp/**/*.{h,cpp}", "libsodium/libsodium-ios/include/**/*.h"
  s.header_mappings_dir = "libsodium/libsodium-ios/include"
  s.preserve_paths = "libsodium/**/*", "precompiled.tgz"
  s.vendored_libraries = "libsodium/libsodium-ios/lib/libsodium.a"
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/libsodium/libsodium-ios/include"',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }

  s.dependency 'React'
end
