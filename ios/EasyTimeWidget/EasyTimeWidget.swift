import SwiftUI
import WidgetKit

#if WIDGET_BUNDLE_MAIN
@main
public struct EasyTimeWidgetBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        EasyTimeWidget()
    }
}
#endif

public struct EasyTimeWidget: Widget {
    public let kind: String = "EasyTimeWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CommuteTimelineProvider()) { entry in
            EasyTimeWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Easy Time Commute")
        .description("Track next departures, delays, and walking buffer for your saved Stockholm commute.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}
