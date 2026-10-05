#if canImport(UIKit)
import UIKit

/// Dynamic Island–style toast.
///
///     IslandToast.show("Transfer completed", style: .success)
///
/// - Dynamic Island phones: grows out of the island; content sits below the camera.
/// - Notch / classic phones, or landscape: pops in as a pill just below the status bar.
/// - Toasts are queued, shown above sheets and alerts, and pass touches through.
@MainActor
public final class IslandToast: NSObject {
  
  // MARK: Public API
  
  public static var configuration = IslandToastConfiguration()
  
  public static func show(_ message: String,
                          style: IslandToastStyle = .info,
                          duration: TimeInterval? = nil) {
    shared.enqueue(Item(message: message,
                        style: style,
                        duration: duration ?? configuration.defaultDuration))
  }
  
  /// Collapses the toast on screen now; queued toasts continue.
  public static func dismiss() { shared.collapse() }
  
  /// Clears the queue and collapses the toast on screen.
  public static func cancelAll() {
    shared.queue.removeAll()
    shared.collapse()
  }
  
  public static var isPresenting: Bool { shared.isShowing }
  
  // MARK: State
  
  static let shared = IslandToast()
  
  private struct Item {
    let message: String
    let style: IslandToastStyle
    let duration: TimeInterval
  }
  
  private var queue: [Item] = []
  private var isShowing = false
  private var isCollapsing = false
  private var collapseTask: Task<Void, Never>?
  
  private var window: PassthroughWindow?
  private let pill = UIView()
  private let content = UIView()
  private let iconView = UIImageView()
  private let label = UILabel()
  
  private var collapsedFrame: CGRect = .zero
  private var usesIsland = false
  private var expandedRadius: CGFloat = 0
  
  private override init() {
    super.init()
    pill.layer.cornerCurve = .continuous
    pill.clipsToBounds = true
    pill.alpha = 0
    pill.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    
    // Fixed size, centered horizontally, fixed top margin -> stays put while the pill animates.
    content.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
    
    iconView.contentMode = .scaleAspectFit
    iconView.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
    label.lineBreakMode = .byTruncatingTail
    
    content.addSubview(iconView)
    content.addSubview(label)
    pill.addSubview(content)
  }
  
  // MARK: Queue
  
  private func enqueue(_ item: Item) {
    queue.append(item)
    if !isShowing { showNext() }
  }
  
  private func finish() {
    isShowing = false
    isCollapsing = false
    window?.isHidden = true
  }
  
  private func showNext() {
    guard !queue.isEmpty else { finish(); return }
    guard let window = prepareWindow() else { queue.removeAll(); finish(); return }
    
    let config = Self.configuration
    let item = queue.removeFirst()
    isShowing = true
    isCollapsing = false
    
    pill.backgroundColor = config.backgroundColor
    iconView.image = UIImage(systemName: item.style.symbolName)
    iconView.tintColor = item.style.tint
    label.font = config.font
    label.textColor = config.textColor
    label.numberOfLines = config.maxLines
    label.text = item.message
    
    let bounds = window.bounds
    let isPortrait = bounds.height > bounds.width
    usesIsland = isPortrait && DeviceScreen.topFeature() == .dynamicIsland
    let fullWidth = isPortrait && config.isFullWidth
    let safeTop = DeviceScreen.keyWindow?.safeAreaInsets.top ?? window.safeAreaInsets.top
    let island = config.islandFrame
      ?? DeviceScreen.defaultDynamicIslandFrame(screenWidth: bounds.width)
    // Same gap on the sides as above the island, so the toast hugs the screen evenly.
    let sideInset = config.fullWidthInset ?? (usesIsland ? island.minY : 10)

    // ---- Measure content ----
    let padH: CGFloat = 16, iconSize: CGFloat = 24, spacing: CGFloat = 10
    // Island: content hangs a fixed gap below the hardware island, with extra room at the
    // bottom so text clears the large rounded corners.
    let padTop: CGFloat = usesIsland ? 10 : 12
    let padBottom: CGFloat = usesIsland ? 20 : 12
    let maxWidth = fullWidth
      ? bounds.width - sideInset * 2
      : min(bounds.width - 24, config.maxWidth)
    let labelMax = maxWidth - padH * 2 - iconSize - spacing
    let fitted = label.sizeThatFits(CGSize(width: labelMax, height: .greatestFiniteMagnitude))
    let labelW = min(ceil(fitted.width), labelMax)
    let labelH = ceil(fitted.height)
    let contentW = padH * 2 + iconSize + spacing + labelW
    let rowH = max(labelH, iconSize)
    let contentH = padTop + rowH + padBottom
    
    // ---- Geometry ----
    let expandedFrame: CGRect
    let contentTop: CGFloat
    if usesIsland {
      collapsedFrame = island
      contentTop = island.height              // starts at the island's bottom edge
      let w = fullWidth ? maxWidth : max(contentW, island.width + 60)
      expandedFrame = CGRect(x: bounds.midX - w / 2, y: island.minY,
                             width: w, height: contentTop + contentH)
    } else {
      let top = safeTop + 6                   // just below notch / status bar
      collapsedFrame = CGRect(x: bounds.midX - 18, y: top, width: 36, height: 36)
      contentTop = 0
      let w = fullWidth ? maxWidth : max(contentW, 160)
      expandedFrame = CGRect(x: bounds.midX - w / 2, y: top, width: w, height: contentH)
    }
    
    // Full width: concentric with the display corners (classic phones have none -> capsule).
    let deviceRadius = DeviceScreen.displayCornerRadius - sideInset
    let defaultRadius = fullWidth && deviceRadius > 0
      ? deviceRadius
      : (usesIsland ? 28 : expandedFrame.height / 2)
    expandedRadius = min(config.expandedCornerRadius ?? defaultRadius, expandedFrame.height / 2)
    
    // ---- Initial state ----
    UIView.performWithoutAnimation {
      pill.transform = .identity
      pill.frame = expandedFrame
      content.frame = CGRect(x: 0, y: contentTop, width: expandedFrame.width, height: contentH)
      // Full width: leading-aligned like system island alerts; otherwise centered.
      let startX = fullWidth ? padH : (expandedFrame.width - contentW) / 2 + padH
      iconView.frame = CGRect(x: startX, y: padTop + (rowH - iconSize) / 2,
                              width: iconSize, height: iconSize)
      label.frame = CGRect(x: startX + iconSize + spacing, y: padTop + (rowH - labelH) / 2,
                           width: labelW, height: labelH)
      
      pill.frame = collapsedFrame             // autoresizing keeps content centered
      pill.layer.cornerRadius = collapsedFrame.height / 2
      content.alpha = 0
      // On island phones the black pill sits exactly on the black hardware island.
      pill.alpha = usesIsland ? 1 : 0
      if !usesIsland { pill.transform = CGAffineTransform(scaleX: 0.6, y: 0.6) }
    }
    window.isHidden = false
    if config.announcesForVoiceOver {
      UIAccessibility.post(notification: .announcement, argument: item.message)
    }
    
    if usesIsland {
      expand(to: expandedFrame, item: item)
    } else {
      UIView.animate(withDuration: 0.18, animations: {
        self.pill.alpha = 1
        self.pill.transform = .identity
      }, completion: { _ in
        self.expand(to: expandedFrame, item: item)
      })
    }
  }
  
  // MARK: Animations
  
  private func expand(to frame: CGRect, item: Item) {
    guard !isCollapsing else { return }
    item.style.playHaptic()
    
    let radius = expandedRadius
    let animator = UIViewPropertyAnimator(duration: 0.55, dampingRatio: 0.72) {
      self.pill.frame = frame
      self.pill.layer.cornerRadius = radius
    }
    animator.startAnimation()
    UIView.animate(withDuration: 0.18, delay: 0.14, options: .curveEaseOut) {
      self.content.alpha = 1
    }
    setStatusBarHidden(usesIsland && Self.configuration.hidesStatusBarOnIsland)
    
    collapseTask?.cancel()
    collapseTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64((item.duration + 0.4) * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.collapse()
    }
  }
  
  private func collapse() {
    guard isShowing, !isCollapsing else { return }  
    isCollapsing = true
    collapseTask?.cancel()
    collapseTask = nil
    setStatusBarHidden(false)
    
    UIView.animate(withDuration: 0.1) { self.content.alpha = 0 }
    
    // No bounce and no trailing fade: the toast is gone the moment the shrink ends.
    let target = collapsedFrame
    let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
      self.pill.frame = target
      self.pill.layer.cornerRadius = target.height / 2
      // Island phones: the pill lands on the black hardware island, so it can vanish instantly.
      if !self.usesIsland { self.pill.alpha = 0 }
    }
    animator.addCompletion { _ in
      self.pill.alpha = 0
      self.showNext()
    }
    animator.startAnimation()
  }
  
  @objc private func tapped() {
    if Self.configuration.tapToDismiss { collapse() }
  }
  
  // MARK: Window
  
  private func prepareWindow() -> PassthroughWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
            else { return nil }
    
    if let window, window.windowScene === scene {
      window.frame = scene.coordinateSpace.bounds
      return window
    }
    
    let newWindow = PassthroughWindow(windowScene: scene)
    newWindow.windowLevel = .alert + 1          // above sheets and alerts
    newWindow.backgroundColor = .clear
    let root = OverlayRootViewController()
    root.view.backgroundColor = .clear
    root.view.addSubview(pill)
    newWindow.rootViewController = root
    newWindow.isHidden = true
    window = newWindow
    return newWindow
  }
  
  private func setStatusBarHidden(_ hidden: Bool) {
    guard let root = window?.rootViewController as? OverlayRootViewController else { return }
    guard root.hidesStatusBar != hidden else { return }
    root.hidesStatusBar = hidden
    UIView.animate(withDuration: 0.2) { root.setNeedsStatusBarAppearanceUpdate() }
  }
}
#endif
