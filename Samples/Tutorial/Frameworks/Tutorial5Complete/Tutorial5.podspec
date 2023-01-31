Pod::Spec.new do |s|
  s.name         = 'Tutorial5'
  s.version      = '1.0.0.LOCAL'
  s.summary      = 'See the README.'
  s.homepage     = 'https://github.com/square/workflow-swift'
  s.license      = 'Apache License, Version 2.0'
  s.author       = 'Square'
  s.source       = { git: 'Not Published', tag: "podify/#{s.version}" }

  # 1.7 is needed for `swift_versions` support
  s.cocoapods_version = '>= 1.7.0'

  s.swift_versions = ['5.7']
  s.ios.deployment_target = '14.0'

  s.source_files = 'Sources/**/*.swift'
  s.resource_bundle = { 'TutorialResources' => ['Resources/**/*'] }

  s.dependency 'TutorialViews'
  s.dependency 'Workflow'
  s.dependency 'WorkflowUI'
  s.dependency 'BackStackContainer'
  s.dependency 'WorkflowReactiveSwift'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'

    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
  end
end
