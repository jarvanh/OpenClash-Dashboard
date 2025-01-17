import SwiftUI
import Charts

// 2. 更新 OverviewTab
struct OverviewTab: View {
    let server: ClashServer
    @ObservedObject var monitor: NetworkMonitor
    @StateObject private var settings = OverviewCardSettings()
    @StateObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedTab: Int
    
    init(server: ClashServer, monitor: NetworkMonitor, selectedTab: Binding<Int>) {
        self.server = server
        self.monitor = monitor
        self._selectedTab = selectedTab
        self._subscriptionManager = StateObject(wrappedValue: SubscriptionManager(server: server))
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    private func maxMemoryValue(_ memoryHistory: [MemoryRecord]) -> Double {
        // 获取当前数据中的最大值
        let maxMemory = memoryHistory.map { $0.usage }.max() ?? 0
        
        // 如果没有数据或数据小，使用最小刻度
        if maxMemory < 50 { // 小于 50MB
            return 50 // 50MB
        }
        
        // 计算合适的刻度值
        let magnitude = pow(10, floor(log10(maxMemory)))
        let normalized = maxMemory / magnitude
        
        // 选择合适的刻度倍数：1, 2, 5, 10
        let scale: Double
        if normalized <= 1 {
            scale = 1
        } else if normalized <= 2 {
            scale = 2
        } else if normalized <= 5 {
            scale = 5
        } else {
            scale = 10
        }
        
        // 计算最终的最大值，并留出一些余量（120%）
        return magnitude * scale * 1.2
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear
                    .frame(height: 8)
                
                ForEach(settings.cardOrder) { card in
                    if settings.cardVisibility[card] ?? true {
                        switch card {
                        case .speed:
                            // 速度卡片
                            if settings.cardVisibility[.speed] ?? true {
                                HStack(spacing: 16) {
                                    StatusCard(
                                        title: "下载",
                                        value: monitor.downloadSpeed,
                                        icon: "arrow.down.circle",
                                        color: .blue,
                                        monitor: monitor
                                    )
                                    StatusCard(
                                        title: "上传",
                                        value: monitor.uploadSpeed,
                                        icon: "arrow.up.circle",
                                        color: .green,
                                        monitor: monitor
                                    )
                                }
                            }
                            
                        case .totalTraffic:
                            // 总流量卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "下载总量",
                                    value: monitor.totalDownload,
                                    icon: "arrow.down.circle.fill",
                                    color: .blue,
                                    monitor: monitor
                                )
                                StatusCard(
                                    title: "上传总量",
                                    value: monitor.totalUpload,
                                    icon: "arrow.up.circle.fill",
                                    color: .green,
                                    monitor: monitor
                                )
                            }
                            
                        case .status:
                            // 状态卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "活动连接",
                                    value: "\(monitor.activeConnections)",
                                    icon: "link.circle.fill",
                                    color: .orange,
                                    monitor: monitor
                                )
                                .onTapGesture {
                                    selectedTab = 3
                                    HapticManager.shared.impact(.light)
                                }
                                StatusCard(
                                    title: "内存使用",
                                    value: monitor.memoryUsage,
                                    icon: "memorychip",
                                    color: .purple,
                                    monitor: monitor
                                )
                            }
                            
                        case .speedChart:
                            // 速率图表
                            SpeedChartView(speedHistory: monitor.speedHistory)
                                .padding()
                                .background(cardBackgroundColor)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                        case .memoryChart:
                            // 只在 Meta 服务器上显示内存图表
                            if server.serverType != .premium {
                                ChartCard(title: "内存使用", icon: "memorychip") {
                                    Chart {
                                        // 添加预设的网格线和标签
                                        ForEach(Array(stride(from: 0, to: maxMemoryValue(monitor.memoryHistory), by: maxMemoryValue(monitor.memoryHistory)/4)), id: \.self) { value in
                                            RuleMark(
                                                y: .value("Memory", value)
                                            )
                                            .lineStyle(StrokeStyle(lineWidth: 1))
                                            .foregroundStyle(.gray.opacity(0.1))
                                        }
                                        
                                        ForEach(monitor.memoryHistory) { record in
                                            AreaMark(
                                                x: .value("Time", record.timestamp),
                                                y: .value("Memory", record.usage)
                                            )
                                            .foregroundStyle(.purple.opacity(0.3))
                                            
                                            LineMark(
                                                x: .value("Time", record.timestamp),
                                                y: .value("Memory", record.usage)
                                            )
                                            .foregroundStyle(.purple)
                                        }
                                    }
                                    .frame(height: 200)
                                    .chartYAxis {
                                        AxisMarks(position: .leading) { value in
                                            if let memory = value.as(Double.self) {
                                                AxisGridLine()
                                                AxisValueLabel {
                                                    Text("\(Int(memory)) MB")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .chartYScale(domain: 0...maxMemoryValue(monitor.memoryHistory))
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 3))
                                    }
                                }
                            }
                            
                        case .modeSwitch:
                            ModeSwitchCard(server: server)
                            
                        case .subscription:
                            if !subscriptionManager.subscriptions.isEmpty {
                                let subscriptions = subscriptionManager.subscriptions
                                let lastUpdateTime = subscriptionManager.lastUpdateTime
                                let isLoading = subscriptionManager.isLoading
                                
                                SubscriptionInfoCard(
                                    subscriptions: subscriptions,
                                    lastUpdateTime: lastUpdateTime,
                                    isLoading: isLoading
                                ) {
                                    await subscriptionManager.refresh()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            monitor.resetData() // 重置监控数据
            Task {
                await subscriptionManager.fetchSubscriptionInfo() // 获取订阅信息
            }
        }
    }
} 