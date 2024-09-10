//
//  AppDelegate.swift
//  AsyncWorker
//
//  Created by Mark Johnson on 6/16/22.
//

import UIKit
import WorkflowUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)

        window.rootViewController = WorkflowHostingController(workflow: AsyncWorkerWorkflow())
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
