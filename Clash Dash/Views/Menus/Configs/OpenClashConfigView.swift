import SwiftUI

struct OpenClashConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
                                     
    @State private var configs: [OpenClashConfig] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isChanging = false
    @State private var showingSwitchAlert = false
    @State private var selectedConfig: OpenClashConfig?
    @State private var isDragging = false
    @State private var startupLogs: [String] = []
    @State private var editingConfig: OpenClashConfig?
    @State private var showingEditAlert = false
    @State private var configToEdit: OpenClashConfig?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isLoading {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                ConfigCardPlaceholder()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .shimmering()
                    } else if configs.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                                .frame(height: 10)
                            
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 45))
                                .foregroundColor(.secondary)
                            
                            Text("没有找到配置文件")
                                .font(.title3)
                            
                            Text("请确认配置文件目录不为空，并确保配置文件格式为 YAML")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(configs) { config in
                                ConfigCard(
                                    config: config,
                                    server: server,
                                    onSelect: {
                                        if !isDragging {
                                            handleConfigSelection(config)
                                        }
                                    },
                                    onEdit: {
                                        handleEditConfig(config)
                                    },
                                    onDelete: {
                                        handleDeleteConfig(config)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isDragging = true
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isDragging = false
                        }
                    }
            )
            .navigationTitle("配置文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: { dismiss() })
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await loadConfigs()
                            // 添加成功触觉反馈
                            
                            HapticManager.shared.notification(.success)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .disabled(isChanging)
        .overlay {
            if isChanging {
                ProgressView()
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .task {
            await loadConfigs()
            // 添加成功的触觉反馈
            
            HapticManager.shared.notification(.success)
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("切换配置", isPresented: $showingSwitchAlert) {
            Button("取消", role: .cancel) {
                selectedConfig = nil
            }
            Button("确认切换", role: .destructive) {
                if let config = selectedConfig {
                    switchConfig(config)
                }
            }
        } message: {
            Text("切换配置会重启 Clash 服务，这会导致当前连接中断。是否继续？")
        }
        .sheet(isPresented: $isChanging) {
            LogDisplayView(
                logs: startupLogs,
                title: "正在切换配置..."
            )
        }
        .sheet(item: $editingConfig) { config in
            ConfigEditorView(
                viewModel: viewModel,
                server: server,
                configName: config.name,
                configFilename: config.filename,
                isEnabled: config.state == .enabled,
                isSubscription: config.isSubscription,
                onConfigSaved: {
                    // 重新加载配置列表
                    Task {
                        await loadConfigs()
                        // 添加成功的触觉反馈
                        
                        HapticManager.shared.notification(.success)
                    }
                }
            )
        }
        .alert("提示", isPresented: $showingEditAlert) {
            Button("取消", role: .cancel) {
                configToEdit = nil
            }
            Button("继续编辑") {
                if let config = configToEdit {
                    editingConfig = config
                }
                configToEdit = nil
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleConfigSelection(_ config: OpenClashConfig) {
        // 添加触觉反馈
        HapticManager.shared.impact(.light)

        // 首先检查是否是当前启用的配置
        guard config.state != .enabled else { return }
        
        // 检查配置文件状态
        if config.check == .abnormal {
            errorMessage = "无法切换到配置检查不通过的配置文件，请检查配置文件格式是否正确"
            showError = true
            return
        }
        
        // 如果配置检查通过，则显示切换确认对话框
        selectedConfig = config
        showingSwitchAlert = true
    }
    
    private func loadConfigs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            switch server.luciPackage {
            case .openClash:
                configs = try await viewModel.fetchOpenClashConfigs(server)
            case .mihomoTProxy:
                configs = try await viewModel.fetchMihomoTProxyConfigs(server)
            }
            // 添加成功的触觉反馈
            
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // 添加失败的触觉反馈
            
            HapticManager.shared.notification(.error)
        }
    }
    
    private func switchConfig(_ config: OpenClashConfig) {
        guard !isChanging else { return }
        
        startupLogs.removeAll()
        isChanging = true
        
        Task {
            do {
                let logStream = try await viewModel.switchClashConfig(
                    server,
                    configFilename: config.filename,
                    packageName: server.luciPackage == .openClash ? "openclash" : "mihomoTProxy",
                    isSubscription: config.isSubscription
                )
                for try await log in logStream {
                    await MainActor.run {
                        startupLogs.append(log)
                    }
                }
                await loadConfigs()  // 重新加载配置列表以更新状态
                await MainActor.run {
                    isChanging = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isChanging = false
                }
            }
        }
    }
    
    private func handleEditConfig(_ config: OpenClashConfig) {
        // 添加触觉反馈
        HapticManager.shared.impact(.light)

        let maxEditSize: Int64 = 90 * 1024  // 90KB
        configToEdit = config
        
        if config.fileSize > maxEditSize {
            errorMessage = "配置文件较大（\(formatFileSize(config.fileSize))），可能无法保存"
            showingEditAlert = true
        } else {
            editingConfig = config
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func handleDeleteConfig(_ config: OpenClashConfig) {
        // 添加触觉反馈
        HapticManager.shared.impact(.light)
        
        // 如果是当前启用的配置，不允许删除
        guard config.state != .enabled else {
            errorMessage = "无法删除当前正在使用的配置文件"
            showError = true
            return
        }

        

    
        
        
        Task {
            do {
                try await viewModel.deleteOpenClashConfig(
                    server, configFilename: config.filename,
                    packageName: server.luciPackage == .openClash ? "openclash" : "mihomoTProxy",
                    isSubscription: config.isSubscription
                    )
                await loadConfigs()  // 重新加载配置列表
                // 添加成功触觉反馈
                
                HapticManager.shared.notification(.success)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                // 添加失败触觉反馈
                
                HapticManager.shared.notification(.error)
            }
        }
    }
}

struct ConfigCard: View {
    let config: OpenClashConfig
    let server: ClashServer
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteAlert = false
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题栏
                HStack {
                    Image(systemName: config.isSubscription ? "cloud.fill" : "house.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                    Text(config.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    
                    // 删除按钮
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .padding(.trailing, 4)
                    
                    // 编辑按钮
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .padding(.trailing, 8)
                    
                    StateLabel(state: config.state)
                }
                
                // 配置信息
                VStack(alignment: .leading, spacing: 8) {
                    // 更新时间
                    ConfigInfoRow(
                        icon: "clock",
                        text: "更新时间:",
                        message: config.mtime.relativeTimeString()
                    )
                    
                    // 语法检查
                    ConfigInfoRow(
                        icon: config.check == .normal ? "checkmark.circle" : "exclamationmark.triangle",
                        text: "语法检查:",
                        color: config.check == .normal ? .green : .orange,
                        message: config.check == .normal ? "正常" : "异常"
                    )

                    // 本地配置或订阅配置
                    // if config.isSubscription {
                    //     InfoRow(
                    //         icon: "cloud.fill",
                    //         text: "订阅配置"
                    //     )
                    // } else {
                    //     // 添加文件大小显示
                    //     InfoRow(
                    //         icon: "doc.circle",
                    //         text: "本地配置"
                    //     )
                    // }

                    // 添加文件大小显示
                    ConfigInfoRow(
                        icon: "doc.circle",
                        text: formatFileSize(config.fileSize)
                    )
                    
                    
                }
                .font(.subheadline)
                
                // 订阅信息
                if let subscription = config.subscription {
                    Divider()
                        .padding(.vertical, 4)
                    SubscriptionInfoView(info: subscription)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(
                        color: config.state == .enabled ? 
                            Color.accentColor.opacity(0.3) : 
                            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: config.state == .enabled ? 8 : 4,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        config.state == .enabled ? 
                            Color.accentColor.opacity(0.5) : 
                            Color(.systemGray4),
                        lineWidth: config.state == .enabled ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(ConfigCardButtonStyle())
        .alert("删除配置", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除该配置文件吗？此操作不可恢复。")
        }
    }
}

struct ConfigCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct StateLabel: View {
    let state: OpenClashConfig.ConfigState
    
    var body: some View {
        Text(state == .enabled ? "已启用" : "未启用")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(state == .enabled ? 
                          Color.green.opacity(0.15) : 
                          Color.secondary.opacity(0.1)
                    )
            )
            .foregroundColor(state == .enabled ? .green : .secondary)
            .overlay(
                Capsule()
                    .stroke(
                        state == .enabled ? 
                            Color.green.opacity(0.3) : 
                            Color.secondary.opacity(0.2),
                        lineWidth: 0.5
                    )
            )
    }
}

struct SubscriptionInfoView: View {
    let info: OpenClashConfig.SubscriptionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if info.subInfo != "No Sub Info Found" {
                // 流量信息
                HStack(spacing: 16) {
                    if let used = info.used {
                        DataLabel(title: "已使用", value: used)
                    }
                    if let surplus = info.surplus {
                        DataLabel(title: "剩余", value: surplus)
                    }
                    if let total = info.total {
                        DataLabel(title: "总量", value: total)
                    }
                }
                
                // 到期信息
                HStack(spacing: 16) {
                    if let dayLeft = info.dayLeft {
                        DataLabel(title: "剩余天数", value: "\(dayLeft)天")
                    }
                    if let expire = info.expire {
                        DataLabel(title: "到期时间", value: expire)
                    }
                }
                
                // 使用百分比
                if let percent = info.percent {
                    ProgressView(value: Double(percent) ?? 0, total: 100)
                        .tint(.blue)
                }
            } else {
                Text("无订阅信息")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
}

struct DataLabel: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}

struct ConfigCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行占位符
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 20)
            }
            
            // 更新时间占位符
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 16)
            }
            
            // 语法检查状态占位
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 16)
            }
            
            // 订阅信息占位符
            Divider()
                .padding(.vertical, 4)
            
            // 流量信息占位符
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 16)
                    }
                }
            }
            
            // 进度条占位符
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 4)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

struct ShimmeringView: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: -geometry.size.width + (geometry.size.width * 3 * phase))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            )
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmeringView())
    }
}

// 将InfoRow重命名为ConfigInfoRow
struct ConfigInfoRow: View {
    let icon: String
    let text: String
    var color: Color = .secondary
    var message: String? = nil
    
    var body: some View {
        Label {
            HStack {
                Text(text)
                    .foregroundColor(color)
                if let message = message {
                    Text(message)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundColor(color)
        }
    }
}

// 添加相对时间格化的扩展
private extension Date {
    func relativeTimeString() -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.second, .minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)周前更新"
        } else if let days = components.day, days > 0 {
            return "\(days)天前更新"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)小时前更新"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分钟前更新"
        } else if let seconds = components.second, seconds > 30 {
            return "\(seconds)秒前更新"
        } else if let seconds = components.second, seconds >= 0 {
            return "刚刚更新"
        } else {
            // 果是未来的时显示具体日期时间
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: self)
        }
    }
} 
