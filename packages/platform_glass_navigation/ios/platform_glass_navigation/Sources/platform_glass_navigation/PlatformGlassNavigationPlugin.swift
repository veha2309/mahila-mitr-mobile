import Flutter
import UIKit

public class PlatformGlassNavigationPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "platform_glass_navigation", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PlatformGlassNavigationPlugin(), channel: channel)
    registrar.register(TabBarFactory(messenger: registrar.messenger()), withId: "platform_glass_navigation/bar")
    registrar.register(SegmentedFactory(messenger: registrar.messenger()), withId: "platform_glass_navigation/segments")
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "supportsGlass" else { result(FlutterMethodNotImplemented); return }
    if #available(iOS 26.0, *) { result(true) } else { result(false) }
  }
}

final class TabBarFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    NativeTabBar(frame: frame, id: viewId, args: args, messenger: messenger)
  }
}

final class TabBarHost: UIView {
  let bar = UITabBar()
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    addSubview(bar)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func layoutSubviews() {
    super.layoutSubviews()
    // Keep the system bar at the bottom so UIKit handles its floating glass layout.
    let height = max(83, bar.sizeThatFits(bounds.size).height + safeAreaInsets.bottom)
    bar.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
  }
}

final class NativeTabBar: NSObject, FlutterPlatformView, UITabBarDelegate {
  let host: TabBarHost
  let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    host = TabBarHost(frame: frame)
    channel = FlutterMethodChannel(name: "platform_glass_navigation/bar/\(id)", binaryMessenger: messenger)
    super.init()
    do { try update(args) } catch { assertionFailure("Invalid initial tab configuration: \(error)") }
    host.bar.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
      guard let self else { result(nil); return }
      do { try self.update(call.arguments); result(nil) }
      catch { result(FlutterError(code: "invalid_tabs", message: "\(error)", details: nil)) }
    }
  }
  deinit { channel.setMethodCallHandler(nil) }
  private func update(_ args: Any?) throws {
    guard let config = args as? [String: Any],
      let tabs = config["items"] as? [[String: Any]], (2...5).contains(tabs.count),
      let selected = config["selected"] as? Int, tabs.indices.contains(selected),
      let tint = config["tint"] as? NSNumber else {
      throw NSError(domain: "Invalid tab configuration", code: 1)
    }
    let items = try tabs.enumerated().map { index, tab -> UITabBarItem in
      guard let label = tab["label"] as? String else {
        throw NSError(domain: "Missing tab label", code: 2)
      }
      let image: UIImage?
      if let bytes = tab["image"] as? FlutterStandardTypedData {
        image = UIImage(data: bytes.data, scale: 3)?.withRenderingMode(.alwaysTemplate)
      } else if let symbol = tab["symbol"] as? String {
        image = UIImage(systemName: symbol)
      } else { image = nil }
      guard let image else { throw NSError(domain: "Invalid tab image or SF Symbol", code: 3) }
      let item = UITabBarItem(title: label, image: image, tag: index)
      item.badgeValue = tab["badge"] as? String
      return item
    }
    host.bar.tintColor = color(tint)
    host.bar.unselectedItemTintColor = (config["unselectedTint"] as? NSNumber).map { color($0) }
    let style: UIUserInterfaceStyle
    switch config["brightness"] as? String {
      case "dark": style = .dark
      case "light": style = .light
      default: style = .unspecified
    }
    host.overrideUserInterfaceStyle = style
    host.bar.setItems(items, animated: false)
    host.bar.selectedItem = items[selected]
  }
  func view() -> UIView { host }
  private func color(_ number: NSNumber) -> UIColor {
    let value = number.uint32Value
    return UIColor(red: CGFloat((value >> 16) & 255) / 255,
      green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255,
      alpha: CGFloat((value >> 24) & 255) / 255)
  }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("selected", arguments: item.tag)
  }
}

final class SegmentedFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    NativeSegments(frame: frame, id: viewId, args: args, messenger: messenger)
  }
}

final class NativeSegments: NSObject, FlutterPlatformView, UIGestureRecognizerDelegate {
  let control = UISegmentedControl(items: [])
  let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "platform_glass_navigation/segments/\(id)", binaryMessenger: messenger)
    super.init()
    // The gallery sheet stays white even when the device uses dark appearance.
    control.overrideUserInterfaceStyle = .light
    control.frame = frame
    control.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    do { try update(args) } catch { assertionFailure("Invalid initial segments: \(error)") }
    control.addTarget(self, action: #selector(selected), for: .valueChanged)
    let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
    pan.delegate = self
    control.addGestureRecognizer(pan)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
      guard let self else { result(nil); return }
      do { try self.update(call.arguments); result(nil) }
      catch { result(FlutterError(code: "invalid_segments", message: "\(error)", details: nil)) }
    }
  }
  deinit { channel.setMethodCallHandler(nil) }
  private func update(_ args: Any?) throws {
    guard let config = args as? [String: Any],
      let labels = config["labels"] as? [String], labels.count >= 2,
      let index = config["selected"] as? Int, labels.indices.contains(index) else {
      throw NSError(domain: "Invalid segment configuration", code: 1)
    }
    let existing = (0..<control.numberOfSegments).map { control.titleForSegment(at: $0) ?? "" }
    if existing != labels {
      control.removeAllSegments()
      for (i, label) in labels.enumerated() {
        control.insertSegment(withTitle: label, at: i, animated: false)
      }
    }
    control.selectedSegmentIndex = index
  }
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: control)
    return abs(velocity.x) > abs(velocity.y)
  }
  @objc private func dragged(_ pan: UIPanGestureRecognizer) {
    guard pan.state == .began || pan.state == .changed || pan.state == .ended,
      control.bounds.width > 0, control.numberOfSegments > 0 else { return }
    let x = max(0, min(pan.location(in: control).x, control.bounds.width))
    let index = min(Int(x / control.bounds.width * CGFloat(control.numberOfSegments)),
      control.numberOfSegments - 1)
    guard index != control.selectedSegmentIndex else { return }
    control.selectedSegmentIndex = index
    selected()
  }
  @objc private func selected() {
    channel.invokeMethod("selected", arguments: control.selectedSegmentIndex)
  }
  func view() -> UIView { control }
}
