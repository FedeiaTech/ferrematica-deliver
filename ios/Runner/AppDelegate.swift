import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps API key is injected via Info.plist's GMSApiKey (populated from
    // ios/Runner/Config/Secrets.xcconfig, gitignored). A placeholder key
    // will fail Maps requests at runtime, not at build time — see
    // dart_define.example.json for the manual Google Cloud Console setup.
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !apiKey.isEmpty
    {
      GMSServices.provideAPIKey(apiKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
