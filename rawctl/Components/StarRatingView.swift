//
//  StarRatingView.swift
//  rawctl
//
//  Star rating component for photo organization
//

import SwiftUI

/// Star rating view (0-5 stars)
struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 14
    var spacing: CGFloat = 2
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.5))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            // Tap same star to clear
                            if rating == star {
                                rating = 0
                            } else {
                                rating = star
                            }
                        }
                    }
            }
        }
    }
}

/// Compact inline star rating for file list
struct CompactStarRating: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Circle()
                    .fill(star <= rating ? Color.yellow : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

/// Flag status for photo
enum FlagStatus: String, Codable, CaseIterable {
    case none = "none"
    case pick = "pick"
    case reject = "reject"
    
    var icon: String {
        switch self {
        case .none: return "flag"
        case .pick: return "flag.fill"
        case .reject: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .pick: return .white
        case .reject: return .red
        }
    }
}

/// Flag picker view
struct FlagPickerView: View {
    @Binding var flag: FlagStatus
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(FlagStatus.allCases, id: \.self) { status in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        flag = status
                    }
                }) {
                    Image(systemName: status.icon)
                        .font(.system(size: 12))
                        .foregroundColor(flag == status ? status.color : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: .constant(3))
        StarRatingView(rating: .constant(5), size: 20)
        CompactStarRating(rating: .constant(4))
        FlagPickerView(flag: .constant(.pick))
    }
    .padding()
    .preferredColorScheme(.dark)
}
