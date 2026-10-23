Pod::Spec.new do |s|
  s.name             = 'PushCRM'
  s.version          = '1.0.0'
  s.summary          = 'Lightweight push notification and analytics SDK for iOS.'
  s.description      = <<-DESC
    PushCRM is an offline-first iOS SDK for push notification management,
    user identification, and event tracking with automatic batching,
    retry, and file-based persistence.
  DESC

  s.homepage         = 'https://github.com/MMPanchal/PushCRM-IOS-SDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PushCRM' => 'sdk@pushcrm.com' }
  s.source           = { :git => 'https://github.com/MMPanchal/PushCRM-IOS-SDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_versions        = ['5.9']

  s.source_files = 'Sources/PushCRM/**/*.swift'

  s.frameworks = 'Foundation', 'UIKit'
end
