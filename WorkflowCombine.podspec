require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowCombine'
    s.version      = WORKFLOW_VERSION
    s.summary      = 'Infrastructure for Combined-powered Workers'
    s.homepage     = 'https://www.github.com/square/workflow-swift'
    s.license      = 'Apache License, Version 2.0'
    s.author       = 'Square'
    s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }

    # 1.7 is needed for `swift_versions` support
    s.cocoapods_version = '>= 1.7.0'

    s.swift_versions = ['5.1']
    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '10.15'

    s.source_files = 'WorkflowCombine/Sources/*.swift'

    s.dependency 'Workflow', "#{s.version}"

    s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
end
