import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    application.registerForRemoteNotifications()
    Messaging.messaging().delegate = self

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }
}

extension AppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Team chat is the one push whose foreground presentation depends on app
    // state Dart owns: if the recipient already has that thread open, alerting
    // them about a message they are looking at is noise. Dart checks exactly
    // that in NotificationService._handleForegroundMessage and posts a local
    // notification (same sound, same channel) when the thread is *not* open.
    //
    // This delegate is what made that check dead code on iOS. It is installed in
    // didFinishLaunchingWithOptions before the plugins register, so it — not
    // FirebaseMessaging's setForegroundNotificationPresentationOptions — decides
    // what a foreground APNs alert does, and it was unconditionally asking for
    // the sound. The banner played before Dart ever saw the message.
    //
    // Narrowed to remote team-chat pushes only: local notifications still
    // present normally (this delegate is the one that shows them), and every
    // other push type keeps the behaviour it had.
    let isRemote = notification.request.trigger is UNPushNotificationTrigger
    let userInfo = notification.request.content.userInfo
    let isTenantChat = (userInfo["kind"] as? String) == "tenant_chat"
    if isRemote && isTenantChat {
      completionHandler([])
      return
    }

    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // Token handled on Flutter side via FirebaseMessaging.
  }
}
