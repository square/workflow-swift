require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowSwiftUIExperimental'
    s.version      = '0.5'
    s.summary      = 'Infrastructure for Workflow-powered SwiftUI'
    s.homepage     = 'https://www.github.com/square/workflow-swift'
    s.license      = 'Apache License, Version 2.0'
    s.author       = 'Square'
    s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "swiftui-experimental/v#{s.version}" }

    # 1.7 is needed for `swift_versions` support
    s.cocoapods_version = '>= 1.7.0'

    s.swift_versions = [WORKFLOW_SWIFT_VERSION]
    s.ios.deployment_target = WORKFLOW_IOS_DEPLOYMENT_TARGET
    s.osx.deployment_target = WORKFLOW_MACOS_DEPLOYMENT_TARGET

    s.source_files = 'WorkflowSwiftUIExperimental/Sources/*.swift'

    s.dependency 'Workflow', "~> #{WORKFLOW_MAJOR_VERSION}.0"
    s.dependency 'WorkflowUI', "~> #{WORKFLOW_MAJOR_VERSION}.0"

    s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }

    s.test_spec 'Tests' do |test_spec|
      test_spec.source_files = 'WorkflowSwiftUIExperimental/Tests/**/*.swift'
      test_spec.framework = 'XCTest'
      test_spec.library = 'swiftos'

      # Create an app host so that we can host
      # view or view controller based tests in a real environment.
      test_spec.requires_app_host = true

      test_spec.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'NO' }
    end
  end
