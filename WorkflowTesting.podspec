require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowTesting'
    s.version      = WORKFLOW_VERSION
    s.summary      = 'Reactive application architecture'
    s.homepage     = 'https://www.github.com/square/workflow-swift'
    s.license      = 'Apache License, Version 2.0'
    s.author       = 'Square'
    s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }

    # 1.7 is needed for `swift_versions` support
    s.cocoapods_version = '>= 1.7.0'

    s.swift_versions = [WORKFLOW_SWIFT_VERSION]
    s.ios.deployment_target = WORKFLOW_IOS_DEPLOYMENT_TARGET
    s.osx.deployment_target = WORKFLOW_MACOS_DEPLOYMENT_TARGET

    s.source_files = 'WorkflowTesting/Sources/**/*.swift'

    s.dependency 'Workflow', "#{s.version}"
    s.dependency 'CustomDump', '~> 0.6.1'
    s.framework = 'XCTest'

    s.pod_target_xcconfig = {
        'APPLICATION_EXTENSION_API_ONLY' => 'YES',
        'ENABLE_TESTING_SEARCH_PATHS' => 'YES',
    }

    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = 'WorkflowTesting/Tests/**/*.swift'
        test_spec.framework = 'XCTest'
        test_spec.libraries = 'swiftDispatch', 'swiftFoundation', 'swiftos'
    end
end
