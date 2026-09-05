import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var shareChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    shareChannel = FlutterMethodChannel(
      name: "dev.kukutx.tagverity/share",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    shareChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "shareTextFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let filename = arguments["filename"] as? String,
        let content = arguments["content"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing share file arguments.",
            details: nil
          )
        )
        return
      }
      self?.shareTextFile(filename: filename, content: content, result: result)
    }
  }
  private func shareTextFile(
    filename: String,
    content: String,
    result: @escaping FlutterResult
  ) {
    let temporaryDirectory = FileManager.default.temporaryDirectory
    if let urls = try? FileManager.default.contentsOfDirectory(
      at: temporaryDirectory,
      includingPropertiesForKeys: nil
    ) {
      for url in urls where url.lastPathComponent.hasPrefix("tagverity-") {
        try? FileManager.default.removeItem(at: url)
      }
    }
    let safeFilename = URL(fileURLWithPath: filename).lastPathComponent
    let fileURL = temporaryDirectory.appendingPathComponent(safeFilename)
    do {
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
      result(
        FlutterError(
          code: "share_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let presenter = self?.activeViewController() else {
        result(
          FlutterError(
            code: "share_failed",
            message: "No active view controller is available.",
            details: nil
          )
        )
        return
      }
      let controller = UIActivityViewController(
        activityItems: [fileURL],
        applicationActivities: nil
      )
      if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY,
          width: 1,
          height: 1
        )
      }
      presenter.present(controller, animated: true)
      result(nil)
    }
  }
  private func activeViewController() -> UIViewController? {
    let activeScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    let window = activeScene?.windows.first { $0.isKeyWindow } ?? activeScene?.windows.first
    return topViewController(from: window?.rootViewController)
  }
  private func topViewController(from root: UIViewController?) -> UIViewController? {
    if let navigation = root as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(from: presented)
    }
    return root
  }
}
