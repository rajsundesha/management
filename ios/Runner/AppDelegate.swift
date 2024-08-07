import Flutter
import UIKit
import Firebase  // Add this import


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// import UIKit
// import Flutter
// import FirebaseCore
// import FirebaseMessaging

// @UIApplicationMain
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     FirebaseApp.configure()

//     if #available(iOS 10.0, *) {
//       UNUserNotificationCenter.current().delegate = self
//       let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
//       UNUserNotificationCenter.current().requestAuthorization(
//         options: authOptions,
//         completionHandler: { _, _ in }
//       )
//     } else {
//       let settings: UIUserNotificationSettings =
//         UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
//       application.registerUserNotificationSettings(settings)
//     }

//     application.registerForRemoteNotifications()

//     Messaging.messaging().delegate = self

//     GeneratedPluginRegistrant.register(with: self)
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }

// extension AppDelegate: MessagingDelegate {
//   func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
//     print("Firebase registration token: \(String(describing: fcmToken))")
//   }
// }
