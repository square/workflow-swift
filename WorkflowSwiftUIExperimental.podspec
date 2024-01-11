require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowSwiftUIExperimental'
    s.version      = '0.2'
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
  end
