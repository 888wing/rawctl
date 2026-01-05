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
    @State private var showImportSheet = false
    @State private var selectedCard: DetectedCard?

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
        if !detectedCards.isEmpty {
            DisclosureGroup("Devices", isExpanded: $isExpanded) {
                VStack(spacing: 2) {
                    ForEach(detectedCards) { card in
                        DeviceRow(
                            card: card,
                            onImport: {
                                selectedCard = card
                                showImportSheet = true
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func refreshCards() {
        // TODO: Integrate with MemoryCardService when available
        // Task {
        //     let cards = await MemoryCardService.shared.getDetectedCards()
        //     await MainActor.run {
        //         detectedCards = cards.map { url in
        //             DetectedCard(
        //                 url: url,
        //                 name: url.lastPathComponent,
        //                 photoCount: 0,
        //                 cardType: detectCardType(url)
        //             )
        //         }
        //     }
        // }
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
}

/// Single device row
struct DeviceRow: View {
    let card: DevicesSection.DetectedCard
    let onImport: () -> Void

    @State private var isHovering = false
    @State private var photoCount: Int?

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

                    if let count = photoCount {
                        Text("\(count) photos")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Scanning...")
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
