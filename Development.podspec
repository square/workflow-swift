require_relative('version')

Pod::Spec.new do |s|
  s.name         = 'Development'
  s.version      = '0.1.0'
  s.summary      = 'Infrastructure for Workflow-powered UI'
  s.homepage     = 'https://www.github.com/square/workflow-swift'
  s.license      = 'Apache License, Version 2.0'
  s.author       = 'Square'
  s.source       = { :git => 'https://github.com/square/workflow-swift.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = WORKFLOW_IOS_DEPLOYMENT_TARGET
  s.swift_version = WORKFLOW_SWIFT_VERSION
  s.dependency 'Workflow'
  s.dependency 'WorkflowUI'
  s.dependency 'WorkflowReactiveSwift'
  s.dependency 'WorkflowRxSwift'
  s.dependency 'WorkflowCombine'
  s.dependency 'WorkflowConcurrency'
  s.dependency 'WorkflowSwiftUIExperimental'
  s.dependency 'ViewEnvironment'
  s.dependency 'ViewEnvironmentUI'
  
  s.source_files = 'Samples/Dummy.swift'

  s.subspec 'Dummy' do |ss|
  end

  s.default_subspecs = 'Dummy'

  dir = Pathname.new(__FILE__).dirname
  snapshot_test_env = {
    'IMAGE_DIFF_DIR' => dir.join('FailureDiffs'),
    'FB_REFERENCE_IMAGE_DIR' => dir.join('Samples/SnapshotTests/ReferenceImages'),
  }

  s.scheme = { 
    environment_variables: snapshot_test_env
  }

  s.app_spec 'SampleApp' do |app_spec|
    app_spec.source_files = 'Samples/SampleApp/Sources/**/*.swift'
    app_spec.resources = 'Samples/SampleApp/Resources/**/*.swift'
  end

  s.test_spec 'WorkflowTesting' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.dependency 'WorkflowTesting'
    test_spec.source_files = 'WorkflowTesting/Tests/**/*.swift'
  end

  s.app_spec 'SampleSwiftUIApp' do |app_spec|
    app_spec.ios.deployment_target = WORKFLOW_IOS_DEPLOYMENT_TARGET
    app_spec.dependency 'WorkflowSwiftUI'
    app_spec.pod_target_xcconfig = {
      'IFNFOPLIST_FILE' => '${PODS_ROOT}/../Samples/SampleSwiftUIApp/SampleSwiftUIApp/Configuration/Info.plist'
    }
    app_spec.source_files = 'Samples/SampleSwiftUIApp/SampleSwiftUIApp/**/*.swift'
  end

  s.app_spec 'SampleTicTacToe' do |app_spec|
    app_spec.source_files = 'Samples/TicTacToe/Sources/**/*.swift'
    app_spec.resources = 'Samples/TicTacToe/Resources/**/*'
    app_spec.dependency 'BackStackContainer'
    app_spec.dependency 'ModalContainer'
    app_spec.dependency 'AlertContainer'
  end

  s.test_spec 'TicTacToeTests' do |test_spec|
    test_spec.dependency 'Development/SampleTicTacToe'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowReactiveSwiftTesting'
    test_spec.dependency 'BackStackContainer'
    test_spec.dependency 'ModalContainer'
    test_spec.dependency 'AlertContainer'
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'Development/SampleTicTacToe'
    test_spec.source_files = 'Samples/TicTacToe/Tests/**/*.swift'
  end

  s.app_spec 'SwiftUITestbed' do |app_spec|
    app_spec.ios.deployment_target = '15.0'
    app_spec.source_files = 'Samples/SwiftUITestbed/Sources/**/*.swift'
    app_spec.dependency 'MarketWorkflowUI', '80.0.0'
    app_spec.dependency 'WorkflowSwiftUIExperimental'

    # app spec SPM dependencies not supported yet
    # app_spec.spm_dependency(
    #  :url => 'https://github.com/pointfreeco/swift-composable-architecture',
    #  :requirement => {:kind => 'upToNextMajorVersion',  :minimumVersion => '1.9.0'},
    #  :products => ['ComposableArchitecture']
    # )

  end

  s.test_spec 'SwiftUITestbedTests' do |test_spec|
    test_spec.dependency 'Development/SwiftUITestbed'
    test_spec.dependency 'WorkflowTesting'
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'Development/SwiftUITestbed'
    test_spec.source_files = 'Samples/SwiftUITestbed/Tests/**/*.swift'
  end

  s.app_spec 'SampleSplitScreen' do |app_spec|
    app_spec.dependency 'SplitScreenContainer'
    app_spec.source_files = 'Samples/SplitScreenContainer/DemoApp/**/*.swift'

    app_spec.scheme = {
      environment_variables: snapshot_test_env
    }
  end

  s.test_spec 'SplitScreenTests' do |test_spec|
    test_spec.dependency 'SplitScreenContainer'
    test_spec.dependency 'Development/SampleSplitScreen'
    test_spec.app_host_name = 'Development/SampleSplitScreen'
    test_spec.requires_app_host = true
    test_spec.source_files = 'Samples/SplitScreenContainer/SnapshotTests/**/*.swift'

    test_spec.framework = 'XCTest'

    test_spec.dependency 'iOSSnapshotTestCase'

    test_spec.scheme = { 
      environment_variables: snapshot_test_env
    }
  end

  s.test_spec 'ViewEnvironmentUITests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'ViewEnvironmentUI/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
  end

  s.test_spec 'WorkflowTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'Workflow/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
  end

  s.test_spec 'WorkflowUITests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowUI/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
  end

  s.test_spec 'WorkflowReactiveSwiftTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowReactiveSwift/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowReactiveSwiftTesting'
  end

  s.test_spec 'WorkflowReactiveSwiftTestingTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowReactiveSwift/TestingTests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowReactiveSwiftTesting'
  end

  s.test_spec 'WorkflowRxSwiftTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowRxSwift/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowRxSwiftTesting'
  end

  s.test_spec 'WorkflowRxSwiftTestingTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowRxSwift/TestingTests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowRxSwiftTesting'
  end

  s.app_spec 'WorkflowCombineSampleApp' do |app_spec|
    app_spec.source_files = 'Samples/WorkflowCombineSampleApp/WorkflowCombineSampleApp/**/*.swift'
  end
  
  s.test_spec 'WorkflowCombineSampleAppTests' do |test_spec|
    test_spec.dependency 'Development/WorkflowCombineSampleApp'
    test_spec.dependency 'WorkflowTesting'
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'Development/WorkflowCombineSampleApp'
    test_spec.source_files = 'Samples/WorkflowCombineSampleApp/WorkflowCombineSampleAppUnitTests/**/*.swift'
  end

  s.test_spec 'WorkflowCombineTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowCombine/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowCombineTesting'
  end

  s.test_spec 'WorkflowCombineTestingTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowCombine/TestingTests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowCombineTesting'
  end
  
  s.test_spec 'WorkflowConcurrencyTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowConcurrency/Tests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
  end
  
  s.test_spec 'WorkflowConcurrencyTestingTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'WorkflowConcurrency/TestingTests/**/*.swift'
    test_spec.framework = 'XCTest'
    test_spec.dependency 'WorkflowTesting'
    test_spec.dependency 'WorkflowConcurrencyTesting'
  end
end
