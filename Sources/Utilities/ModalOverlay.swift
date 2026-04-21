//
//  ModalOverlay.swift
//  ModalsAndOverlays
//
//  Created by Joseph Levy on 4/20/26.
//
//  ModalOverlay.swift
//
//  Provides modalOverlay(_:) and modalOverlayRoot() view modifiers.
//  Requires iOS 17+ (uses @Observable and two-parameter onChange).
//
//  Architecture:
//  - ModalOverlayRegistry     — @Observable class, shared via Environment,
//                               holds overlay content and dismiss actions.
//  - ModalPositionKey         — PreferenceKey carrying anchor + content size
//                               up the hierarchy to the root.
//  - ModalOverlayModifier     — Attaches to any View. Measures its content,
//                               publishes position, registers with the registry.
//  - ModalOverlayRootModifier — Attaches once at the root. Reads both
//                               the registry and the positions, renders
//                               all visible overlays above everything.
//
//  Usage:
//
//    // 1. Attach root once — at the App level or top-level NavigationStack:
//    ContentView()
//        .modalOverlayRoot()
//
//    // 2. Attach overlays to any view at any nesting depth:
//    SomeField()
//        .modalOverlay(isVisible: $isVisible) {
//            ErrorBubble(message: "Something went wrong")
//        }
//
//    // 3. Multiple overlays on the same view are supported:
//    SomeField()
//        .modalOverlay(isVisible: $showError, dismissOnTapOutside: false) {
//            ErrorBubble(message: errorMessage)
//        }
//        .modalOverlay(isVisible: $showMenu) {
//            DropdownMenu(items: items, onSelect: handleSelect)
//        }
//
//    // 4. Multiple views each with their own overlays are supported:
//    VStack {
//        FieldA().modalOverlay(isVisible: $aVisible) { BubbleA() }
//        FieldB().modalOverlay(isVisible: $bVisible) { BubbleB() }
//    }
//
//    // 5. Sheets need their own root since they have a separate view hierarchy:
//    .sheet(isPresented: $showSheet) {
//        SheetContent()
//            .modalOverlayRoot()
//    }

import SwiftUI

// MARK: - Registry

/// Shared store for overlay content and dismiss actions. Injected into the environment by modalOverlayRoot().
/// Written to by ModalOverlayModifier to register/unregister entries.  Read by ModalOverlayRootModifier to render visible overlays.
//@Observable
final class ModalOverlayRegistry : ObservableObject {
	
	struct Entry {
		let id: UUID
		let content: AnyView
		let dismiss: () -> Void
		let dimBackground: Bool
		let blockHits: Bool
		let dismissOnTapOutside: Bool
	}
	
	@Published var entries: [UUID: Entry] = [:]
	
	func register(_ entry: Entry) { entries[entry.id] = entry }
	
	func unregister(_ id: UUID) { entries.removeValue(forKey: id) }
}

// MARK: - Environment Key

private struct ModalOverlayRegistryKey: EnvironmentKey {
	static let defaultValue: ModalOverlayRegistry? = nil
}

extension EnvironmentValues {
	var modalOverlayRegistry: ModalOverlayRegistry? {
		get { self[ModalOverlayRegistryKey.self] }
		set { self[ModalOverlayRegistryKey.self] = newValue }
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
struct ModalOverlayModifier<OverlayContent: View>: ViewModifier {
	@Binding var isVisible: Bool
	let dimBackground: Bool
	let blockHits: Bool
	let dismissOnTapOutside: Bool
	@ViewBuilder let overlayContent: () -> OverlayContent
	
	@Environment(\.modalOverlayRegistry) private var registry
	@State private var id = UUID()          // stable per-modifier identity
	@State private var contentSize: CGSize = .zero
	
	func body(content: Content) -> some View {
		content
		// Publish this overlay's anchor and measured size upward
			.anchorPreference(key: ModalPositionKey.self, value: .bounds) { anchor in
				guard isVisible else { return [] }
				return [ModalPositionPreference(
					id: id,
					anchor: anchor,
					contentSize: contentSize,
					isVisible: contentSize != .zero // if true render else wait
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
								.onChange(of: geo.size) { newSize in
									contentSize = newSize
								}
						}
					)
			)
		// Keep the registry entry in sync
			.onChange(of: isVisible)   { _ in syncRegistry() }
			.onChange(of: contentSize) { _ in syncRegistry() }
			.onAppear                  { syncRegistry() }
			.onDisappear               { registry?.unregister(id) }
	}
	
	private func syncRegistry() {
		guard let registry else { return }
		if isVisible {
			registry.register(.init(
				id: id,
				content: AnyView(overlayContent()),
				dismiss: { isVisible = false },
				dimBackground: dimBackground,
				blockHits: blockHits,
				dismissOnTapOutside: dismissOnTapOutside
			))
		} else { registry.unregister(id) }
	}
}

// MARK: - Root Modifier

/// Attach once at the top of the view hierarchy.
/// Responsibilities:
///   - Creates and injects the shared ModalOverlayRegistry.
///   - Collects all overlay positions via overlayPreferenceValue.
///   - Renders a single dim/block layer and each overlay content
///     at the correct window-level position, above all other views.
public struct ModalOverlayRootModifier: ViewModifier {
	@State private var registry = ModalOverlayRegistry()
	
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
						
						// One dim/block layer covering all active overlays. Driven by whether ANY visible entry requests it.
						let shouldDim   = visible.contains { registry.entries[$0.id]?.dimBackground == true }
						let shouldBlock = visible.contains { registry.entries[$0.id]?.blockHits     == true }
						
						if shouldDim || shouldBlock {
							Color.black
								.opacity(shouldDim ? 0.2 : 0)
								.ignoresSafeArea()
								//.contentShape(shouldBlock ? Rectangle() : Path()) // No good SwiftUI
								.onTapGesture {
									// Dismiss every overlay that permits tap-outside dismissal
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
							if let entry = registry.entries[pref.id], pref.contentSize != .zero { // wait until size is good
								let frame    = geo[pref.anchor]   // field rect in window coords
								let size     = pref.contentSize
								let gap: CGFloat = 6
								
								// Flip above/below depending on available space
								let showAbove = frame.minY - size.height - gap > 0
								
								// Clamp X so content never bleeds off screen edges
								let clampedX  = min(
									max(frame.minX, 8),
									windowWidth - size.width - 8
								)
								let yPos = showAbove
								? frame.minY - size.height - gap
								: frame.maxY + gap
								
								entry.content
									.frame(width: size.width, height: size.height) /// Constrain rendered content size
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
	///   - blockHits:           Absorbs taps outside the overlay content. Default `true`.
	///   - dismissOnTapOutside: Tapping the dim layer sets isVisible to false. Default `true`.
	///   - content:             The view to display as the overlay.
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
	
	/// Attach once at the root of a view hierarchy to enable all
	/// modalOverlay modifiers below it.
	///
	/// Sheets and fullScreenCovers have separate view hierarchies
	/// and each need their own `.modalOverlayRoot()`.
	public func modalOverlayRoot() -> some View { modifier(ModalOverlayRootModifier()) }
}

// MARK: - ErrorBubble

/// A simple error tooltip intended for use as modalOverlay content.
///
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
			isVisible: Binding(
				get: { message != nil },
				set: { _ in }
			),
			dimBackground: false,
			blockHits: false,
			dismissOnTapOutside: false
		) {
			ErrorBubble(message: message ?? "")
		}
	}
}
