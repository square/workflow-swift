require_relative('version')

Pod::Spec.new do |s|
    s.name         = 'WorkflowConcurrency'
    s.version      = WORKFLOW_VERSION
    s.summary      = 'Infrastructure for Concurrency-powered Workers'
    s.homepage     = 'https://www.github.com/square/workflow-swift'
    s.license      = 'Apache License, Version 2.0'
    s.author       = 'Square'
    s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }
  
    # 1.7 is needed for `swift_versions` support
    s.cocoapods_version = '>= 1.7.0'
  
    s.swift_versions = ['5.5']
    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '10.15'
  
    s.source_files = 'WorkflowConcurrency/Sources/*.swift'
    
    s.dependency 'Workflow', "#{s.version}"
  
  end
  
