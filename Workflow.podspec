require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'Workflow'
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
    s.osx.deployment_target = '10.13'

    s.source_files = 'Workflow/Sources/*.swift'

    s.dependency 'ReactiveSwift', '~> 7.1.1'

    s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }

    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = 'Workflow/Tests/**/*.swift'
        test_spec.framework = 'XCTest'
        test_spec.library = 'swiftos'
    end

end
