//
//  AppDelegate.swift
//  scriptTest
//
//  Created by Babitha Shetty K on 12/11/21.
//

import Cocoa
import framework1
@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        TestClass.testOne()
        TestClass.testThree()
        TestClass.testSeven()
        TestClass.testEight()
        TestClass.testNine()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

