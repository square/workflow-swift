require_relative('version')

Pod::Spec.new do |s|
  s.name         = 'WorkflowRxSwift'
  s.version      = WORKFLOW_VERSION
  s.summary      = 'Infrastructure for Workflow-powered Swift'
  s.homepage     = 'https://www.github.com/square/workflow-swift'
  s.license      = 'Apache License, Version 2.0'
  s.author       = 'Square'
  s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }

  # 1.7 is needed for `swift_versions` support
  s.cocoapods_version = '>= 1.7.0'

  s.swift_versions = ['5.0']
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'

  s.source_files = 'WorkflowRxSwift/Sources/**/*.swift'

  s.dependency 'Workflow', "#{s.version}"
  s.dependency 'RxSwift', '~> 5.1.1'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'WorkflowRxSwift/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.library = 'swiftos'
  end
end
