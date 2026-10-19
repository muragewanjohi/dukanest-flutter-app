import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let beaconRanger = BeaconRanger()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    beaconRanger.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

/// iOS hides iBeacon advertisements from Bluetooth scan. Core Location ranging
/// is the supported way to hear the DukaNest shelf beacon.
final class BeaconRanger: NSObject, CLLocationManagerDelegate, FlutterStreamHandler {
  private static let proximityUuid = UUID(uuidString: "6E8A4C12-9F3D-4B71-A2E8-1D7C0B5E4A91")!

  private let manager = CLLocationManager()
  private let constraint = CLBeaconIdentityConstraint(uuid: proximityUuid)
  private var eventSink: FlutterEventSink?
  private var startResult: FlutterResult?
  private var ranging = false

  func register(with messenger: FlutterBinaryMessenger) {
    let events = FlutterEventChannel(name: "com.dukanest.scan/beacons", binaryMessenger: messenger)
    events.setStreamHandler(self)
    let control = FlutterMethodChannel(name: "com.dukanest.scan/beacon_control", binaryMessenger: messenger)
    control.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      start(result: result)
    case "stop":
      stopRanging()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(result: @escaping FlutterResult) {
    manager.delegate = self
    guard CLLocationManager.locationServicesEnabled() else {
      result("disabled")
      return
    }
    let status = authorization()
    if status == .notDetermined {
      startResult = result
      manager.requestWhenInUseAuthorization()
      return
    }
    result(beginRanging(status))
  }

  private func authorization() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return manager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  private func beginRanging(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      if !ranging {
        manager.startRangingBeacons(satisfying: constraint)
        ranging = true
      }
      return "listening"
    default:
      return "denied"
    }
  }

  private func stopRanging() {
    if ranging {
      manager.stopRangingBeacons(satisfying: constraint)
      ranging = false
    }
  }

  private func resolveAuthorization(_ status: CLAuthorizationStatus) {
    guard let startResult else { return }
    if status == .notDetermined { return }
    self.startResult = nil
    startResult(beginRanging(status))
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    resolveAuthorization(authorization())
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    resolveAuthorization(status)
  }

  func locationManager(
    _ manager: CLLocationManager,
    didRange beacons: [CLBeacon],
    satisfying beaconConstraint: CLBeaconIdentityConstraint
  ) {
    let payload: [[String: Any]] = beacons.map { beacon in
      [
        "uuid": beacon.uuid.uuidString.lowercased(),
        "major": beacon.major.intValue,
        "minor": beacon.minor.intValue,
        "rssi": beacon.rssi,
      ]
    }
    eventSink?(payload)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
