//
//  ScrollWithKeyboard.swift
//  KeyboardAwareScrolling
//
//  Created by Joseph Levy on 5/11/26.
//

import SwiftUI

// MARK: - Environment key for focus notification

public struct NotifyFocusedKey: EnvironmentKey {
	public static var defaultValue: ((AnyHashable) -> Void)? = nil
}

public extension EnvironmentValues {
	var notifyFocused: ((AnyHashable) -> Void)? {
		get { self[NotifyFocusedKey.self] }
		set { self[NotifyFocusedKey.self] = newValue }
	}
}

// MARK: - View Modifiers

public struct NamedFocusModifier<ID: Hashable>: ViewModifier {
	let id: ID
	@FocusState<ID?>.Binding var focusedField: ID?
	@Environment(\.notifyFocused) private var notifyFocused
	
	public func body(content: Content) -> some View {
		if let notifyFocused { // if there is no notifyFocused callback do nothing
			content
				.focused($focusedField, equals: id)
				.id(id)
				.onChange(of: focusedField == id) { isFocused in
					if isFocused { notifyFocused(AnyHashable(id)) }
				}
		} else { content }
	}
}

public struct AnonymousFocusModifier: ViewModifier {
	@State  private var id = UUID()
	@FocusState private var isFocused: Bool
	@Environment(\.notifyFocused) private var notifyFocused
	
	public func body(content: Content) -> some View {
		if let notifyFocused {  // if there is no notifyFocused callback do nothing
			content
				.focused($isFocused)
				.id(id)
				.onChange(of: isFocused) { focused in
					if focused { notifyFocused(AnyHashable(id)) }
				}
		} else { content }
	}
}

public extension View {
	@ViewBuilder
	internal func scrollDisabledCompatible(_ disabled: Bool) -> some View { // scrolling always enabled on iOS 15
		if #available(iOS 16, *) { self.scrollDisabled(disabled) } else { self }
	}
	func trackFocus<ID: Hashable>(_ id: ID, equals: FocusState<ID?>.Binding) -> some View {
		self.modifier(NamedFocusModifier(id: id, focusedField: equals))
	}
	func trackFocus() -> some View {
		self.modifier(AnonymousFocusModifier())
	}
	func scrollsWithKeyboard(alwaysAllowScroll: Bool = false) -> some View {
		ScrollsWithKeyboard(alwaysAllowScroll: alwaysAllowScroll) { self }
	}
}

// MARK: - Keyboard Aware Scroll

public struct ScrollsWithKeyboard<Content: View>: View {
	@ViewBuilder let content: () -> Content
	
	@State private var alwaysAllowScroll: Bool = false
	@State private var baseHeight:     CGFloat   = 0
	@State private var keyboardHeight: CGFloat   = 0
	@State private var activeFocusId:  AnyHashable?   // persists for keyboard re-triggers
	@State private var scrollTrigger = UUID()         // new value = fire the scroll onChange
	@State private var animation     = Animation.easeInOut(duration: 0.25)
	
	public var body: some View {
		ZStack {
			/// Stable height reference that ignores the keyboard so content never collapses when the keyboard appears.
			GeometryReader { geo in
				Color.clear
					.onAppear { baseHeight = geo.size.height }
					.onChange(of: geo.size) { newSize in
						DispatchQueue.main.async {
							if baseHeight != newSize.height {
								baseHeight = newSize.height
							}
						}
					}
			}
			.ignoresSafeArea(.keyboard)
			
			ScrollViewReader { proxy in
					ScrollView {
						content()
							.frame(minHeight: baseHeight, alignment: .top)
							.padding(.bottom, keyboardHeight > 0 ? 50 : 0)
					}
					/// Fields call notifyFocused via onChange(of: isFocused) —  only the field that GAINS focus fires, the one losing focus does not.
					.environment(\.notifyFocused) { id in
						activeFocusId = id
						scrollTrigger = UUID()  // always a new value → onChange always fires
					}
					.onChange(of: scrollTrigger) { _ in 
						guard let id = activeFocusId else { return }
						withAnimation(animation) { proxy.scrollTo(id) }
					}
					.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {
						handleKeyboard($0, isShowing: true)
					}
					.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {
						handleKeyboard($0, isShowing: false)
					}
					.scrollDisabledCompatible(!alwaysAllowScroll && keyboardHeight == 0)
				
			}
		}
	}
	
	private func handleKeyboard(_ notification: Notification, isShowing: Bool) {
		guard let userInfo = notification.userInfo,
			  let endFrame  = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
			  let duration  = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
			  let curveRaw  = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
		else { return }
		
		animation = makeAnimation(duration: duration, curve: curveRaw)
		let newHeight: CGFloat = isShowing ? endFrame.height : 0
		withAnimation(animation) { keyboardHeight = newHeight }
		
		if isShowing && newHeight > 0 && activeFocusId != nil { scrollTrigger = UUID() }
	}
	
	private func makeAnimation(duration: Double, curve: Int) -> Animation {
		let d = duration > 0 ? duration : 0.25
		switch curve {
		case 1: return .easeIn(duration: d)
		case 2: return .easeOut(duration: d)
		case 3: return .linear(duration: d)
		default: return .easeInOut(duration: d)
		}
	}
}
