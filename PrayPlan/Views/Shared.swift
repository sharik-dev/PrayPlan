import SwiftUI

struct SegmentBadge: View {
    let segment: PrayerSegment

    var body: some View {
        Label(segment.displayName, systemImage: segment.systemIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(segment.bandColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(segment.softFill)
                    .overlay(Capsule().strokeBorder(segment.softStroke, lineWidth: 1))
            )
            .clipShape(Capsule())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
