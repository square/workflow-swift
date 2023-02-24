Pod::Spec.new do |s|
  s.name         = 'AlertContainer'
  s.version      = '1.0.0.LOCAL'
  s.summary      = 'See the README.'
  s.homepage     = 'https://www.github.com/square/workflow-swift'
  s.license      = 'Apache License, Version 2.0'
  s.author       = 'Square'
  s.source       = { git: 'Not Published', tag: "podify/#{s.version}" }

  # 1.7 is needed for `swift_versions` support
  s.cocoapods_version = '>= 1.7.0' 

  s.swift_versions = [WORKFLOW_SWIFT_VERSION]
  s.ios.deployment_target = WORKFLOW_IOS_DEPLOYMENT_TARGET

  s.source_files = 'Sources/**/*.swift'

  s.dependency 'WorkflowUI'

end
