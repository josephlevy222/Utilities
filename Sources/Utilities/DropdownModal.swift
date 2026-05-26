//
//  DropdownModal.swift
//  Utilities
//
//  Created by Joseph Levy on 5/21/26.
//
import SwiftUI

// MARK: - ModalMenuItem

/// A single menu item with an AttributedString label and optional SF Symbol icon.
public struct ModalMenuItem: Identifiable {
	public let id = UUID()
	public let label: AttributedString
	public let icon: String?          // SF Symbol name, optional
	public let role: ButtonRole?      // .destructive tints red
	public let isDisabled: Bool
	public let action: () -> Void
	
	public init(
		_ label: AttributedString,
		icon: String? = nil,
		role: ButtonRole? = nil,
		isDisabled: Bool = false,
		action: @escaping () -> Void
	) {
		self.label      = label
		self.icon       = icon
		self.role       = role
		self.isDisabled = isDisabled
		self.action     = action
	}
}

// MARK: - ModalMenuSection

/// Optional grouping with an optional header label.
public struct ModalMenuSection: Identifiable {
	public let id = UUID()
	public let header: AttributedString?
	public let items: [ModalMenuItem]
	
	public init(header: AttributedString? = nil, items: [ModalMenuItem]) {
		self.header = header
		self.items  = items
	}
	// Called with a result-builder trailing closure (used at call sites)
	public init(
		header: AttributedString? = nil,
		@ModalMenuItemBuilder items: () -> [ModalMenuItem]
	) {
		self.header = header
		self.items  = items()
	}
}

// MARK: - ModalMenuContent (separate struct → proper dismiss injection)

private struct ModalMenuContent: View {
	@Environment(\.dismissModalOverlay) private var dismiss
	let sections: [ModalMenuSection]
	let minWidth: CGFloat
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(sections.enumerated()), id: \.element.id) { sectionIndex, section in
				
				// Section separator (between sections, not before the first)
				if sectionIndex > 0 {
					Divider()
				}
				
				// Optional section header
				if let header = section.header {
					Text(header)
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.horizontal, 14)
						.padding(.top, sectionIndex == 0 ? 8 : 6)
						.padding(.bottom, 2)
				}
				
				// Items
				ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIndex, item in
					MenuRow(item: item) {
						item.action()
						dismiss?()
					}
					
					// Thin divider between items (not after the last one in a section)
					if itemIndex < section.items.count - 1 {
						Divider()
							.padding(.horizontal, 8)
					}
				}
				
				// Bottom padding after last section
				if sectionIndex == sections.count - 1 {
					Spacer().frame(height: 4)
				}
			}
		}
		.frame(minWidth: minWidth)
		.fixedSize(horizontal: true, vertical: true)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
		.shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
	}
}

// MARK: - MenuRow

private struct MenuRow: View {
	let item: ModalMenuItem
	let onTap: () -> Void
	
	@State private var isHovered = false
	
	private var tintColor: Color {
		item.role == .destructive ? .red : .primary
	}
	
	var body: some View {
		Button(action: onTap) {
			HStack(spacing: 8) {
				if let icon = item.icon {
					Image(systemName: icon)
						.frame(width: 18, alignment: .center)
						.foregroundStyle(tintColor.opacity(item.isDisabled ? 0.4 : 1))
				}
				
				Text(item.label)
					.foregroundStyle(tintColor.opacity(item.isDisabled ? 0.4 : 1))
				
				Spacer(minLength: 24)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 9)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.disabled(item.isDisabled)
		.onHover { isHovered = $0 }  // macOS highlight; no-op on iOS
	}
}

// MARK: - ModalMenu

/// A drop-down menu using ModalOverlay with full AttributedString label support.
///
/// Flat list — single section, no headers:
///
///     ModalMenu("Actions", icon: "ellipsis.circle") {
///         ModalMenuItem("Edit",   icon: "pencil")   { edit() }
///         ModalMenuItem("Share",  icon: "square.and.arrow.up") { share() }
///         ModalMenuItem(deleteLabel, icon: "trash", role: .destructive) { delete() }
///     }
///
/// Multi-section with headers:
///
///     ModalMenu("File", icon: "doc") {
///         ModalMenuSection(header: "Document") {
///             ModalMenuItem("New",  icon: "plus")  { newDoc() }
///             ModalMenuItem("Open", icon: "folder") { open() }
///         }
///         ModalMenuSection(header: "Danger Zone") {
///             ModalMenuItem("Delete", icon: "trash", role: .destructive) { delete() }
///         }
///     }
///
public struct ModalMenu<Label: View>: View {
	@State private var isOpen = false
	
	let label: () -> Label
	let sections: [ModalMenuSection]
	let minWidth: CGFloat
	let prefersDown: Bool
	
	// MARK: Convenience — String trigger label
	// Internal designated init — takes the pre-built array
	private init(
		label: @escaping () -> Label,
		sections: [ModalMenuSection],
		minWidth: CGFloat,
		prefersDown: Bool
	) {
		self.label       = label
		self.sections    = sections
		self.minWidth    = minWidth
		self.prefersDown = prefersDown
	}
	
	// Public builder init
	public init(
		minWidth: CGFloat = 180,
		prefersDown: Bool = true,
		@ViewBuilder label: @escaping () -> Label,
		@ModalMenuSectionBuilder sections: () -> [ModalMenuSection]
	) {
		self.init(label: label, sections: sections(), minWidth: minWidth, prefersDown: prefersDown)
	}
	
	// Convenience String init — Label == MenuTriggerLabel
	public init(
		_ title: String,
		icon: String? = nil,
		minWidth: CGFloat = 180,
		prefersDown: Bool = true,
		@ModalMenuSectionBuilder sections: () -> [ModalMenuSection]
	) where Label == MenuTriggerLabel {
		// sections() is called here — array is passed directly, no re-transformation
		self.init(
			label: { MenuTriggerLabel(title: title, icon: icon, isOpen: false) },
			sections: sections(),
			minWidth: minWidth,
			prefersDown: prefersDown
		)
	}
	
	public var body: some View {
		label()
			.onTapGesture { isOpen.toggle() }
			.contentShape(Rectangle())
			.modalOverlay(
				isVisible: $isOpen,
				dimBackground: false,
				blockHits: true,
				dismissOnTapOutside: true,
				prefersDown: prefersDown
			) {
				ModalMenuContent(sections: sections, minWidth: minWidth)
			}
	}
}

// MARK: - MenuTriggerLabel (default label style)

public struct MenuTriggerLabel: View {
	let title: String
	let icon: String?
	let isOpen: Bool
	
	public var body: some View {
		HStack(spacing: 4) {
			if let icon { Image(systemName: icon) }
			Text(title)
			Image(systemName: "chevron.down")
				.font(.caption2.weight(.semibold))
				.rotationEffect(.degrees(isOpen ? 180 : 0))
				.animation(.easeInOut(duration: 0.2), value: isOpen)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
	}
}

// MARK: - Result Builder

@resultBuilder
public struct ModalMenuSectionBuilder {
	
	// A single ModalMenuSection passes through as-is
	public static func buildBlock(_ sections: ModalMenuSection...) -> [ModalMenuSection] {
		sections
	}
	
	// A mix of ModalMenuItems gets auto-wrapped in one anonymous section
	public static func buildBlock(_ items: ModalMenuItem...) -> [ModalMenuSection] {
		[ModalMenuSection(items: items)]
	}
	
	public static func buildArray(_ sections: [[ModalMenuSection]]) -> [ModalMenuSection] {
		sections.flatMap { $0 }
	}
	
	public static func buildOptional(_ section: [ModalMenuSection]?) -> [ModalMenuSection] {
		section ?? []
	}
	
	public static func buildEither(first: [ModalMenuSection]) -> [ModalMenuSection]  { first }
	public static func buildEither(second: [ModalMenuSection]) -> [ModalMenuSection] { second }
}

// MARK: - Flat-list convenience on ModalMenu

extension ModalMenu {
	/// Build directly from ModalMenuItems without section grouping.
	public init(
		minWidth: CGFloat = 180,
		prefersDown: Bool = true,
		@ViewBuilder label: @escaping () -> Label,
		@ModalMenuItemBuilder items: () -> [ModalMenuItem]
	) {
		self.init(minWidth: minWidth, prefersDown: prefersDown, label: label) {
			ModalMenuSection(items: items())
		}
	}
}

@resultBuilder
public struct ModalMenuItemBuilder {
	public static func buildBlock(_ items: ModalMenuItem...) -> [ModalMenuItem] { items }
	public static func buildArray(_ components: [[ModalMenuItem]]) -> [ModalMenuItem] { components.flatMap { $0 } }
	public static func buildOptional(_ component: [ModalMenuItem]?) -> [ModalMenuItem] { component ?? [] }
	public static func buildEither(first: [ModalMenuItem]) -> [ModalMenuItem]  { first }
	public static func buildEither(second: [ModalMenuItem]) -> [ModalMenuItem] { second }
}

// MARK: - Demo / Preview

#Preview {
	DemoView()
		.modalOverlayRoot()
		.padding(40)
}

private struct DemoView: View {
	@State private var log: [String] = []
	
	// Build an AttributedString with mixed styling
	private func styledLabel(_ base: String, badge: String) -> AttributedString {
		var result = AttributedString(base)
		result.font = .body
		
		var badgePart = AttributedString("  \(badge)")
		badgePart.font            = .caption.bold()
		badgePart.foregroundColor = .white
		
		// Combine
		var full = result + badgePart
		// Tint badge characters
		if let range = full.range(of: badge) {
			full[range].backgroundColor = .accentColor
		}
		return full
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 32) {
			
			// ── Example 1: flat list with plain strings ──────────────────────
			ModalMenu("File", icon: "doc") {
				ModalMenuItem("New",   icon: "doc.badge.plus")       { log.append("New") }
				ModalMenuItem("Open",  icon: "folder")               { log.append("Open") }
				ModalMenuItem("Close", icon: "xmark.circle",
							  isDisabled: true)                      { log.append("Close") }
				ModalMenuItem("Delete", icon: "trash",
							  role: .destructive)                    { log.append("Delete") }
			}
			
			// ── Example 2: sections with AttributedString headers/labels ─────
			ModalMenu(minWidth: 220) {
				Label("Format", systemImage: "textformat")
			} sections: {
				ModalMenuSection(header: "Style") {
					ModalMenuItem(styledLabel("Bold", badge: "⌘B"),
								  icon: "bold")                      { log.append("Bold") }
					ModalMenuItem(styledLabel("Italic", badge: "⌘I"),
								  icon: "italic")                    { log.append("Italic") }
					ModalMenuItem(styledLabel("Underline", badge: "⌘U"),
								  icon: "underline")                 { log.append("Underline") }
				}
				ModalMenuSection(header: "Alignment") {
					ModalMenuItem("Left",   icon: "text.alignleft")  { log.append("Left") }
					ModalMenuItem("Center", icon: "text.aligncenter"){ log.append("Center") }
					ModalMenuItem("Right",  icon: "text.alignright") { log.append("Right") }
				}
			}
			
			// ── Log ──────────────────────────────────────────────────────────
			if !log.isEmpty {
				VStack(alignment: .leading, spacing: 4) {
					Text("Actions")
						.font(.caption.bold())
						.foregroundStyle(.secondary)
					ForEach(log.indices.reversed(), id: \.self) { i in
						Text("▸ \(log[i])")
							.font(.caption)
							.foregroundStyle(.primary)
					}
				}
				.padding(10)
				.background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

#Preview("ModalMenu") {
	PreviewContainer()
		.modalOverlayRoot()
}

private struct PreviewContainer: View {
	@State private var log: [String] = []
	@State private var fontSize: CGFloat = 14
	
	// MARK: - Styled label helpers
	
	private func keyLabel(_ title: String, shortcut: String) -> AttributedString {
		var base = AttributedString(title)
		base.font = .body
		
		var key = AttributedString(" \(shortcut)")
		key.font            = .caption.bold()
		key.foregroundColor = .secondary
		return base + key
	}
	
	private func badgeLabel(_ title: String, badge: String, color: Color = .accentColor) -> AttributedString {
		var base = AttributedString(title)
		base.font = .body
		
		var b = AttributedString(" \(badge)")
		b.font            = .caption2.bold()
		b.foregroundColor = color
		return base + b
	}
	
	private func warningLabel(_ title: String) -> AttributedString {
		var s = AttributedString(title)
		s.font            = .body.bold()
		s.foregroundColor = .red
		return s
	}
	
	// MARK: - Body
	
	var body: some View {
		ZStack(alignment: .topLeading) {
			Color(.systemGroupedBackground).ignoresSafeArea()
			
			VStack(alignment: .leading, spacing: 0) {
				
				// ── Toolbar row ──────────────────────────────────────────────
				HStack(spacing: 12) {
					
					// 1. Simple flat menu
					ModalMenu("File", icon: "doc") {
						ModalMenuItem("New",    icon: "doc.badge.plus")          { record("New") }
						ModalMenuItem("Open…",  icon: "folder")                  { record("Open") }
						ModalMenuItem("Save",   icon: "square.and.arrow.down")   { record("Save") }
						ModalMenuItem("Close",  icon: "xmark.circle",
									  isDisabled: true)                          { record("Close") }
					}
					
					// 2. Edit menu with keyboard shortcut labels
					ModalMenu("Edit", icon: "pencil") {
						ModalMenuSection {
							ModalMenuItem(keyLabel("Undo", shortcut: "⌘Z"),
										  icon: "arrow.uturn.backward")          { record("Undo") }
							ModalMenuItem(keyLabel("Redo", shortcut: "⇧⌘Z"),
										  icon: "arrow.uturn.forward")           { record("Redo") }
						}
						ModalMenuSection {
							ModalMenuItem(keyLabel("Cut",  shortcut: "⌘X"),
										  icon: "scissors")                      { record("Cut") }
							ModalMenuItem(keyLabel("Copy", shortcut: "⌘C"),
										  icon: "doc.on.doc")                    { record("Copy") }
							ModalMenuItem(keyLabel("Paste",shortcut: "⌘V"),
										  icon: "clipboard")                     { record("Paste") }
						}
					}
					
					// 3. Format menu with sections + badge labels
					ModalMenu(minWidth: 210) {
						Label("Format", systemImage: "textformat")
							.padding(.horizontal, 10)
							.padding(.vertical, 6)
							.background(.quaternary,
										in: RoundedRectangle(cornerRadius: 8))
					} sections: {
						ModalMenuSection(header: "Style") {
							ModalMenuItem(keyLabel("Bold",      shortcut: "⌘B"),
										  icon: "bold")                          { record("Bold") }
							ModalMenuItem(keyLabel("Italic",    shortcut: "⌘I"),
										  icon: "italic")                        { record("Italic") }
							ModalMenuItem(keyLabel("Underline", shortcut: "⌘U"),
										  icon: "underline")                     { record("Underline") }
							ModalMenuItem(keyLabel("Strikethrough", shortcut: "⇧⌘X"),
										  icon: "strikethrough")                 { record("Strikethrough") }
						}
						ModalMenuSection(header: "Size") {
							ModalMenuItem(badgeLabel("Bigger",  badge: "A+", color: .blue),
										  icon: "plus.circle")                   { fontSize = min(fontSize + 2, 32); record("Bigger → \(Int(fontSize))pt") }
							ModalMenuItem(badgeLabel("Smaller", badge: "A−", color: .orange),
										  icon: "minus.circle")                  { fontSize = max(fontSize - 2, 8);  record("Smaller → \(Int(fontSize))pt") }
						}
						ModalMenuSection(header: "Alignment") {
							ModalMenuItem("Left",    icon: "text.alignleft")     { record("Align Left") }
							ModalMenuItem("Center",  icon: "text.aligncenter")   { record("Align Center") }
							ModalMenuItem("Right",   icon: "text.alignright")    { record("Align Right") }
							ModalMenuItem("Justify", icon: "text.justify")       { record("Justify") }
						}
					}
					
					Spacer()
					
					// 4. Danger zone — destructive action
					ModalMenu(minWidth: 160) {
						Image(systemName: "ellipsis.circle")
							.font(.title3)
							.padding(6)
							.background(.quaternary,
										in: RoundedRectangle(cornerRadius: 8))
					} sections: {
						ModalMenuSection {
							ModalMenuItem("Share",     icon: "square.and.arrow.up")  { record("Share") }
							ModalMenuItem("Duplicate", icon: "plus.square.on.square"){ record("Duplicate") }
						}
						ModalMenuSection {
							ModalMenuItem(warningLabel("Delete"),
										  icon: "trash",
										  role: .destructive)                     { record("Delete") }
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 10)
				.background(.bar)
				
				Divider()
				
				// ── Mock document area ───────────────────────────────────────
				ScrollView {
					VStack(alignment: .leading, spacing: 16) {
						Text("The quick brown fox jumps over the lazy dog.")
							.font(.system(size: fontSize))
							.frame(maxWidth: .infinity, alignment: .leading)
						
						Text("Tap any menu above to try it out.")
							.font(.caption)
							.foregroundStyle(.secondary)
						
						// Action log
						if !log.isEmpty {
							VStack(alignment: .leading, spacing: 1) {
								ForEach(log.indices.reversed(), id: \.self) { i in
									HStack(spacing: 6) {
										Text("▸")
											.foregroundStyle(.tertiary)
										Text(log[i])
									}
									.font(.system(.caption, design: .monospaced))
									.padding(.horizontal, 10)
									.padding(.vertical, 5)
									.frame(maxWidth: .infinity, alignment: .leading)
									.background(i == log.indices.last
												? Color.accentColor.opacity(0.08)
												: Color.clear)
								}
							}
							.background(.quaternary,
										in: RoundedRectangle(cornerRadius: 8))
						}
					}
					.padding(20)
				}
			}
		}
		.frame(width: 480, height: 360)
	}
	
	private func record(_ action: String) {
		log.append(action)
		if log.count > 12 { log.removeFirst() }
	}
}
