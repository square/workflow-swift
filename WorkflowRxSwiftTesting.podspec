require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowRxSwiftTesting'
    s.version      = WORKFLOW_VERSION
    s.summary      = 'Infrastructure for Workflow-powered Swift'
    s.homepage     = 'https://www.github.com/square/workflow-swift'
    s.license      = 'Apache License, Version 2.0'
    s.author       = 'Square'
    s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }

    # 1.7 is needed for `swift_versions` support
    s.cocoapods_version = '>= 1.7.0'

    s.swift_versions = ['5.7']
    s.ios.deployment_target = '14.0'
    s.osx.deployment_target = '10.13'

    s.source_files = 'WorkflowRxSwift/Testing/**/*.swift'

    s.dependency 'Workflow', "#{s.version}"
    s.dependency 'WorkflowRxSwift', "#{s.version}"
    s.dependency 'WorkflowTesting', "#{s.version}"
    s.dependency 'RxSwift'

    s.framework = 'XCTest'

    # https://github.com/ReactiveX/RxSwift/pull/2475
    # s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }

    s.test_spec 'WorkflowRxSwiftTestingTests' do |test_spec|
        test_spec.requires_app_host = true
        test_spec.source_files = 'WorkflowRxSwift/TestingTests/**/*.swift'
        test_spec.framework = 'XCTest'
        test_spec.dependency 'WorkflowTesting'
        test_spec.library = 'swiftos'
    end
end
