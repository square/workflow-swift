require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowConcurrencyTesting'
    s.version      = WORKFLOW_VERSION
    s.summary      = 'Infrastructure for Concurrency-powered Workers'
    s.homepage     = 'https://www.github.com/square/workflow-swift'
    s.license      = 'Apache License, Version 2.0'
    s.author       = 'Square'
    s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }

    # 1.7 is needed for `swift_versions` support
    s.cocoapods_version = '>= 1.7.0'

    s.swift_versions = ['5.1']
    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '10.15'

    s.source_files = 'WorkflowConcurrency/Testing/**/*.swift'

    s.dependency 'Workflow', "#{s.version}"
    s.dependency 'WorkflowConcurrency', "#{s.version}"
    s.dependency 'WorkflowTesting', "#{s.version}"

    s.framework = 'XCTest'

    s.test_spec 'WorkflowConcurrencyTestingTests' do |test_spec|
        test_spec.requires_app_host = true
        test_spec.source_files = 'WorkflowConcurrency/TestingTests/**/*.swift'
        test_spec.framework = 'XCTest'
        test_spec.dependency 'WorkflowTesting'
        test_spec.library = 'swiftos'
    end
end
