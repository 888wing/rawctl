//
//  DevicesSection.swift
//  rawctl
//
//  Devices section showing memory cards and connected cameras
//

import SwiftUI

/// Devices section for memory cards
struct DevicesSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var detectedCards: [DetectedCard] = []

    struct DetectedCard: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let photoCount: Int
        let cardType: CardType

        enum CardType {
            case sdCard
            case cfCard
            case camera
            case phone

            var icon: String {
                switch self {
                case .sdCard: return "sdcard.fill"
                case .cfCard: return "internaldrive.fill"
                case .camera: return "camera.fill"
                case .phone: return "iphone"
                }
            }
        }
    }

    var body: some View {
        if AppFeatures.devicesEntryPointsEnabled && !detectedCards.isEmpty {
            DisclosureGroup("Devices", isExpanded: $isExpanded) {
                VStack(spacing: 2) {
                    ForEach(detectedCards) { card in
                        DeviceRow(
                            card: card,
                            onImport: {
                                Task {
                                    await MemoryCardService.shared.openCameraCard(card.url, appState: appState)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onAppear {
                refreshCards()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didMountNotification)) { _ in
                refreshCards()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
                refreshCards()
            }
        }
    }

    private func refreshCards() {
        let cardURLs = MemoryCardService.shared.getDetectedCards()
        detectedCards = cardURLs.map { url in
            DetectedCard(
                url: url,
                name: url.lastPathComponent,
                photoCount: estimatePhotoCount(in: url),
                cardType: detectCardType(url)
            )
        }
    }

    private func detectCardType(_ url: URL) -> DetectedCard.CardType {
        let name = url.lastPathComponent.uppercased()
        if name.contains("IPHONE") || name.contains("IPAD") {
            return .phone
        } else if name.contains("EOS") || name.contains("NIKON") || name.contains("SONY") {
            return .camera
        } else if name.contains("CF") {
            return .cfCard
        }
        return .sdCard
    }

    private func estimatePhotoCount(in url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var count = 0
        while let item = enumerator.nextObject() as? URL {
            if PhotoAsset.supportedExtensions.contains(item.pathExtension.lowercased()) {
                count += 1
            }
        }
        return count
    }
}

/// Single device row
struct DeviceRow: View {
    let card: DevicesSection.DetectedCard
    let onImport: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onImport) {
            HStack(spacing: 8) {
                Image(systemName: card.cardType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if card.photoCount > 0 {
                        Text("\(card.photoCount) photos")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ready to import")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isHovering {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    DevicesSection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
