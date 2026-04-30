//
//  ModalOverlay.swift
//  ModalsAndOverlays
//
//  Created by Joseph Levy on 4/20/26.
//
//  Provides modalOverlay(_:) and modalOverlayRoot() view modifiers.
//  Requires iOS 14+ / macOS 11+.
//
//  Architecture:
//  - ModalOverlayRegistry     — ObservableObject class, shared via Environment,
//                               holds overlay content closures and dismiss actions.
//  - ModalPositionKey         — PreferenceKey carrying anchor + content size up the hierarchy to the root.
//  - ModalOverlayModifier     — Attaches to any View. Measures its content, publishes position, registers with the registry.
//                               Uses ContentRef to keep the content closure live so that state changes in the overlay
//                               (e.g. Slider, Toggle) are always reflected without re-registering.
//  - ModalOverlayRootModifier — Attaches once at the root. Reads both the registry and the positions, renders
//                               all visible overlays above everything. Injects dismissModalOverlay into each overlay's
//                               environment so overlay content can dismiss itself.
/// Usage:
/// 1. Attach root once — at the App level or top-level NavigationStack:
///    ContentView()
///        .modalOverlayRoot()
/// 2. Attach overlays to any view at any nesting depth:
///    SomeField()
///        .modalOverlay(isVisible: $isVisible) {
///            ErrorBubble(message: "Something went wrong")
///        }
/// 3. Multiple overlays on the same view are supported:
///    SomeField()
///        .modalOverlay(isVisible: $showError, dismissOnTapOutside: false) {
///            ErrorBubble(message: errorMessage)
///        }
///        .modalOverlay(isVisible: $showMenu) {
///            DropdownMenu(items: items, onSelect: handleSelect)
///        }
/// 4. Multiple views each with their own overlays are supported:
///    VStack {
///        FieldA().modalOverlay(isVisible: $aVisible) { BubbleA() }
///        FieldB().modalOverlay(isVisible: $bVisible) { BubbleB() }
///    }
/// 5. Sheets need their own root since they have a separate view hierarchy:
///    .sheet(isPresented: $showSheet) {
///        SheetContent()
///            .modalOverlayRoot()
///    }
/// 6. dismissOnTapOutside Dismiss Behavior — Hit Testing Boundaries & Environment
///    Whether buttons inside an overlay auto-dismiss, and whether dismissModalOverlay is accessible, depends on how the overlay content is structured:
///
///    a) Inline content (@ViewBuilder var or closure) — content is evaluated in the PARENT view's context, outside the overlay's environment subtree. This means:
///    - @Environment(\.dismissModalOverlay) will be nil — unusable.
///     - Button taps propagate up through the hit testing hierarchy and reach the background dismiss layer — auto-dismiss works.
///     - Toggles/Sliders consume taps — do NOT auto-dismiss.
///
///     SomeView().modalOverlay(isVisible: $show) {
///         VStack {
///             Button("Close") { doWork() }  // auto-dismisses via propagation
///             Toggle("Option", isOn: $opt)  // does NOT auto-dismiss
///         }
///     }
///
///     Use `.noModalDismiss()` to prevent a specific button from dismissing.  Use `@DismissingState` or `onChange + dismiss?()` for Toggle/Slider —
///     BUT dismiss?() will be nil here since environment injection only works in case (b). Use the isVisible binding directly instead:
///
///     Toggle("Option", isOn: $opt)
///        .onChange(of: opt) { _ in isVisible = false }  // no dismiss?() here
///
///  b) Separate struct content — the struct is a true child of the overlay system, rendered inside ModalOverlayRootModifier's environment subtree.
///     This means:
///     - @Environment(\.dismissModalOverlay) is correctly injected — usable.
///     - The struct forms its own hit testing boundary, containing all taps. Nothing propagates to the background dismiss layer.
///     - Buttons, Toggles, and Sliders all behave the same — no auto-dismiss.  Call dismiss?() explicitly wherever dismissal is needed.
///
///     struct MyPanel: View {
///         @Environment(\.dismissModalOverlay) private var dismiss
///         var body: some View {
///             Button("Close") { dismiss?(); doWork() } // explicit dismiss
///             Toggle("Option", isOn: $opt)             // dismiss?() if needed
///         }
///     }
///
///     SomeView().modalOverlay(isVisible: $show) { MyPanel() }
///
//  The struct approach (b) is strongly recommended for any panel that needs dismiss control — environment injection makes
//  intent explicit and dismiss behavior is consistent across all control types.  The inline approach (a) is fine for simple
//  non-dismissing overlays like ErrorBubble where no dismiss control is needed at all. Toggles and Sliders consume their own
//  taps so they never propagate — they do NOT dismiss on their own. To make one dismiss, use @DismissingState
//  or call dismiss explicitly via onChange:
import SwiftUI

// MARK: - Registry

/// Shared store for overlay content closures and dismiss actions.  Injected into the environment by `modalOverlayRoot()`.
/// Written to by ModalOverlayModifier to register/unregister entries.
/// Read by ModalOverlayRootModifier to render visible overlays.
///
/// Content is stored as `() -> AnyView` rather than `AnyView` so that each render pass calls the closure fresh, picking up any state changes
/// (e.g. a Slider value) without needing to re-register the entry.
//@Observable // iOS 17+ but not available for 15.6
final class ModalOverlayRegistry: ObservableObject { // no ObservableObject needed for iOS 17+
	
	struct Entry {
		let id: UUID
		let content: () -> AnyView  // closure — called fresh on every render pass
		let dismiss: () -> Void
		let dimBackground: Bool
		let blockHits: Bool
		let dismissOnTapOutside: Bool
	}
	
	@Published var entries: [UUID: Entry] = [:] // no @Published needed for iOS 17+
	
	func register(_ entry: Entry) { entries[entry.id] = entry }
	
	func unregister(_ id: UUID) { entries.removeValue(forKey: id) }
}

// MARK: - Registry Environment Key

private struct ModalOverlayRegistryKey: EnvironmentKey {
	static let defaultValue: ModalOverlayRegistry? = nil
}

extension EnvironmentValues {
	var modalOverlayRegistry: ModalOverlayRegistry? {
		get { self[ModalOverlayRegistryKey.self] }
		set { self[ModalOverlayRegistryKey.self] = newValue }
	}
}

// MARK: - Dismiss Action Environment Key

/// Injected by ModalOverlayRootModifier into each overlay's environment.
/// Each overlay gets its own dismiss closure, so calling it only dismisses that specific overlay — not any others that may be visible.
///
/// Usage inside overlay content:
///
///     @Environment(\.dismissModalOverlay) private var dismiss
///
///     // Toggles and Sliders consume their taps — use onChange to dismiss:
///     Toggle("Dark Mode", isOn: $darkMode)
///         .onChange(of: darkMode) { _ in dismiss?() }
///
///     Slider(value: $brightness, in: 0...1)
///         .onChange(of: brightness) { _ in dismiss?() }
///
///     // For multiple controls, @DismissingState is cleaner — see property wrapper below.

private struct ModalDismissActionKey: EnvironmentKey {
	static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
	public var dismissModalOverlay: (() -> Void)? {
		get { self[ModalDismissActionKey.self] }
		set { self[ModalDismissActionKey.self] = newValue }
	}
}

// MARK: - Position Preference

/// One entry per visible overlay, carrying its anchor and measured content size.
/// PreferenceKey.reduce appends so all overlays in the hierarchy are collected.
struct ModalPositionPreference {
	let id: UUID
	let anchor: Anchor<CGRect>  // resolved by the root's GeometryProxy
	var contentSize: CGSize
	var isVisible: Bool
}

struct ModalPositionKey: PreferenceKey {
	static var defaultValue: [ModalPositionPreference] = []
	static func reduce(
		value: inout [ModalPositionPreference],
		nextValue: () -> [ModalPositionPreference]
	) {
		value.append(contentsOf: nextValue())
	}
}

// MARK: - Overlay Modifier

/// Attach to any view to give it an overlay.
/// Responsibilities:
///   - Measures overlay content size in a hidden background.
///   - Publishes anchor + size to the root via ModalPositionKey.
///   - Registers/unregisters content and dismiss action in the registry.
///
/// ContentRef is a reference-type wrapper updated on every render pass so the registered content closure always calls the latest overlayContent() closure,
/// reflecting any state changes without re-registering the entry.
struct ModalOverlayModifier<OverlayContent: View>: ViewModifier {
	@Binding var isVisible: Bool
	let dimBackground: Bool
	let blockHits: Bool
	let dismissOnTapOutside: Bool
	@ViewBuilder let overlayContent: () -> OverlayContent
	
	@Environment(\.modalOverlayRegistry) private var registry
	@State private var id = UUID()             // stable per-modifier identity
	@State private var contentSize: CGSize = .zero
	
	/// Reference type so the registry's closure always calls through to the
	/// latest overlayContent() without needing to re-register on every render.
	private class ContentRef {
		var make: () -> AnyView = { AnyView(EmptyView()) }
	}
	@State private var contentRef = ContentRef()
	
	func body(content: Content) -> some View {
		// Update contentRef on every render so it always captures current state.
		let _ = { contentRef.make = { AnyView(overlayContent()) } }()
		
		return content
		// Publish this overlay's anchor and measured size upward
			.anchorPreference(key: ModalPositionKey.self, value: .bounds) { anchor in
				guard isVisible else { return [] }
				return [ModalPositionPreference(
					id: id,
					anchor: anchor,
					contentSize: contentSize,
					isVisible: contentSize != .zero // wait until measured before rendering
				)]
			}
		// Measure the overlay content without displaying it
			.background(
				overlayContent()
					.fixedSize()
					.hidden()
					.background(
						GeometryReader { geo in
							Color.clear
								.onAppear {
									contentSize = geo.size
								}
								.onChange(of: geo.size) { newSize in  // no old/new params needed for iOS 17+
									contentSize = newSize
								}
						}
					)
			)
		// Keep the registry entry in sync
			.onChange(of: isVisible)   { _ in syncRegistry() } // no _ in needed for iOS 17+
			.onChange(of: contentSize) { _ in syncRegistry() } // no _ in needed for iOS 17+
			.onAppear                  { syncRegistry() }
			.onDisappear               { registry?.unregister(id) }
	}
	
	private func syncRegistry() {
		guard let registry else { return }
		if isVisible {
			registry.register(.init(
				id: id,
				content: { self.contentRef.make() }, // always calls latest closure
				dismiss: { isVisible = false },
				dimBackground: dimBackground,
				blockHits: blockHits,
				dismissOnTapOutside: dismissOnTapOutside
			))
		} else {
			registry.unregister(id)
		}
	}
}

// MARK: - Root Modifier

/// Attach once at the top of the view hierarchy.
/// Responsibilities:
///   - Creates and injects the shared ModalOverlayRegistry.
///   - Collects all overlay positions via overlayPreferenceValue.
///   - Renders a background tap layer and each overlay content at the correct window-level position, above all other views.
///   - Injects each entry's dismiss closure into its overlay's environment  via dismissModalOverlay so overlay content can self-dismiss.
///
/// Background tap layer behavior:
///   - Rendered whenever any visible entry has dimBackground, blockHits,  or dismissOnTapOutside set to true.
///   - Only dims when dimBackground is true for at least one entry.
///   - Only absorbs hits when blockHits or dismissOnTapOutside is true.
///   - Only dismisses entries that have dismissOnTapOutside true.
public struct ModalOverlayRootModifier: ViewModifier {
	@StateObject private var registry = ModalOverlayRegistry() // @State for iOS 17+
	
	public func body(content: Content) -> some View {
		content
			.environment(\.modalOverlayRegistry, registry)
			.overlayPreferenceValue(ModalPositionKey.self) { prefs in
				
				// Entries that are visible and have registered content
				let visible = prefs.filter {
					$0.isVisible && registry.entries[$0.id] != nil
				}
				
				if !visible.isEmpty {
					GeometryReader { geo in
						let windowWidth = geo.size.width
						
						let shouldDim     = visible.contains { registry.entries[$0.id]?.dimBackground       == true }
						let shouldBlock   = visible.contains { registry.entries[$0.id]?.blockHits           == true }
						let shouldDismiss = visible.contains { registry.entries[$0.id]?.dismissOnTapOutside == true }
						
						// Render background layer whenever any flag requires it. A fully transparent layer still needs
						// .contentShape(Rectangle()) to receive taps when shouldDismiss is true but shouldDim is false.
						if shouldDim || shouldBlock || shouldDismiss {
							Color.black
								.opacity(shouldDim ? 0.2 : 0.0)
								.ignoresSafeArea()
								.contentShape(Rectangle())
								.allowsHitTesting(shouldBlock || shouldDismiss)
								.onTapGesture {
									// Dismiss only entries that opt in — others remain open
									visible.forEach { pref in
										if let entry = registry.entries[pref.id],
										   entry.dismissOnTapOutside {
											entry.dismiss()
										}
									}
								}
						}
						
						// Position and render each visible overlay
						ForEach(visible, id: \.id) { pref in
							if let entry = registry.entries[pref.id], pref.contentSize != .zero {
								let frame = geo[pref.anchor]  // anchor rect in root coords
								let size  = pref.contentSize
								let gap: CGFloat = 6
								
								// Flip above/below depending on available space
								let showAbove = frame.minY - size.height - gap > 0
								
								// Clamp X so content never bleeds off screen edges
								let clampedX = min(
									max(frame.minX, 8),
									windowWidth - size.width - 8
								)
								let yPos = showAbove
								? frame.minY - size.height - gap
								: frame.maxY + gap
								
								entry.content()                          // call closure — always fresh
									.environment(\.dismissModalOverlay, entry.dismiss) // per-overlay dismiss
									.frame(width: size.width, height: size.height)
									.position(
										x: clampedX + size.width  / 2,
										y: yPos     + size.height / 2
									)
									.transition(
										.opacity.combined(
											with: .scale(scale: 0.95, anchor: .top)
										)
									)
									.animation(
										.easeInOut(duration: 0.2),
										value: pref.isVisible
									)
							}
						}
					}
				}
			}
	}
}

// MARK: - View Extensions

extension View {
	
	/// Attach an overlay to this view.
	/// Renders at root level — unaffected by ancestor clipping (ScrollView, List, etc).
	///
	/// Requires `.modalOverlayRoot()` somewhere above this view in the hierarchy.
	///
	/// - Parameters:
	///   - isVisible:           Drives whether the overlay is shown.
	///   - dimBackground:       Dims everything behind the overlay. Default `true`.
	///   - blockHits:           Absorbs taps that land outside the overlay content. Default `true`.
	///   - dismissOnTapOutside: Tapping outside sets isVisible to false. Default `true`.
	///   - content:             The view to display as the overlay.
	///
	/// Dismissal behavior of content elements:
	///   - Buttons propagate taps to the background layer → dismiss automatically if in the modalOverlay directly not in a view struct in the overlay.
	///   - Toggles/Sliders consume taps → do NOT dismiss automatically, ever.
	///     Use @DismissingState or @Environment(\.dismissModalOverlay) + onChange to opt in on tap consuming views.
	///   - To prevent a button from dismissing, apply .noModalDismiss() or use in a view struct (with its own hit testing.)
	public func modalOverlay<Content: View>(
		isVisible: Binding<Bool>,
		dimBackground: Bool = true,
		blockHits: Bool = true,
		dismissOnTapOutside: Bool = true,
		@ViewBuilder content: @escaping () -> Content
	) -> some View {
		modifier(ModalOverlayModifier(
			isVisible: isVisible,
			dimBackground: dimBackground,
			blockHits: blockHits,
			dismissOnTapOutside: dismissOnTapOutside,
			overlayContent: content
		))
	}
	
	/// Attach once at the root of a view hierarchy to enable all modalOverlay modifiers below it.
	/// Sheets and fullScreenCovers have separate view hierarchies  and each need their own `.modalOverlayRoot()`.

	public func modalOverlayRoot() -> some View {
		modifier(ModalOverlayRootModifier())
	}
	
	/// Prevents this button's tap from propagating to the background dismiss layer, keeping the overlay open after the button's action fires.
	/// Only needed for Button — Toggles and Sliders already consume their own taps.
	///
	/// Example:
	///     Button("Preview") { updatePreview() }
	///         .noModalDismiss()   // overlay stays open
	///
	///     Button("Confirm") { confirmAction() }
	///                             // no modifier — overlay dismisses
	public func noModalDismiss() -> some View {
		simultaneousGesture(TapGesture())
	}
}

// MARK: - DismissingState Property Wrapper

/// A @State replacement that automatically dismisses the enclosing modal overlay whenever the wrapped value changes.
/// Reads dismissModalOverlay from the environment, which is injected per-overlay by ModalOverlayRootModifier, so it only dismisses the overlay it lives in.
/// Use this in overlay content panels that have multiple controls you want to dismiss on change, avoiding repetitive .onChange(of:) { dismiss?() } calls.
///
/// Example:
///
///     struct ExportPanel: View {
///         @DismissingState var isLandscape: Bool = false
///         @DismissingState var printScale: CGFloat = 1.5
///
///         var body: some View {
///             Toggle("Landscape", isOn: $isLandscape)   // dismisses on change
///             Slider(value: $printScale, in: 0.5...2.0) // dismisses on change
///         }
///     }
///
/// For a single control, an explicit onChange is equally clear:
///
///     @Environment(\.dismissModalOverlay) private var dismiss
///     Toggle("Landscape", isOn: $isLandscape)
///         .onChange(of: isLandscape) { _ in dismiss?() }

@propertyWrapper
public struct DismissingState<Value: Equatable>: DynamicProperty {
	@State private var value: Value
	@Environment(\.dismissModalOverlay) private var dismiss
	
	public init(wrappedValue: Value) {
		self._value = State(initialValue: wrappedValue)
	}
	
	public var wrappedValue: Value {
		get { value }
		nonmutating set { value = newValue }
	}
	
	public var projectedValue: Binding<Value> {
		Binding(
			get: { value },
			set: { newValue in
				value = newValue
				dismiss?()
			}
		)
	}
}

// MARK: - ErrorBubble

/// A simple error tooltip intended for use as modalOverlay content.
/// Example:
///   SomeField()
///       .modalOverlay(
///           isVisible: Binding(get: { isFocused && error != nil }, set: { _ in }),
///           dismissOnTapOutside: false
///       ) {
///           ErrorBubble(message: error ?? "")
///       }
public struct ErrorBubble: View {
	let message: String
	
	public var body: some View {
		Text(message)
			.font(.caption)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.foregroundStyle(.white)
			.background(Color.red)
			.clipShape(RoundedRectangle(cornerRadius: 6))
	}
}

extension View {
	public func errorOverlay(_ message: String?) -> some View {
		modalOverlay(
			isVisible: Binding(get: { message != nil }, set: { _ in } ),
			dimBackground: false, blockHits: false, dismissOnTapOutside: false
		) {
			ErrorBubble(message: message ?? "")
		}
	}
}
