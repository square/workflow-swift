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

    s.swift_versions = [WORKFLOW_SWIFT_VERSION]
    s.ios.deployment_target = WORKFLOW_IOS_DEPLOYMENT_TARGET
    s.osx.deployment_target = WORKFLOW_MACOS_DEPLOYMENT_TARGET

    s.source_files = 'WorkflowRxSwift/Sources/**/*.swift'

    s.dependency 'Workflow', "#{s.version}"
    s.dependency 'RxSwift', '~> 6.6'

    s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }

    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = 'WorkflowRxSwift/Tests/**/*.swift'
        test_spec.framework = 'XCTest'
        test_spec.library = 'swiftos'
        test_spec.dependency 'WorkflowTesting', "#{s.version}"
        test_spec.dependency 'WorkflowReactiveSwift', "#{s.version}"

        test_spec.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'NO' }
    end
end
