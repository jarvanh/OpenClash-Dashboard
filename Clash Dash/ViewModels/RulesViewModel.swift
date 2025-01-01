import Foundation

class RulesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isLoading = true
    @Published var rules: [Rule] = []
    @Published var providers: [RuleProvider] = []
    @Published var isRefreshingAll = false  // 添加更新全部状态标记
    
    let server: ClashServer
    
    struct Rule: Codable, Identifiable, Hashable {
        let type: String
        let payload: String
        let proxy: String
        let size: Int?  // 改为可选类型，适配原版 Clash 内核
        
        var id: String { "\(type)-\(payload)" }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Rule, rhs: Rule) -> Bool {
            lhs.id == rhs.id
        }
        
        var sectionKey: String {
            let firstChar = String(payload.prefix(1)).uppercased()
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }
    }
    
    struct RuleProvider: Codable, Identifiable {
        var name: String
        let behavior: String
        let type: String
        let ruleCount: Int
        let updatedAt: String
        let format: String?  // 改为可选类型
        let vehicleType: String
        var isRefreshing: Bool = false  // 添加刷新状态标记
        
        var id: String { name }
        
        enum CodingKeys: String, CodingKey {
            case behavior, type, ruleCount, updatedAt, format, vehicleType
            case name
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = ""
            self.behavior = try container.decode(String.self, forKey: .behavior)
            self.type = try container.decode(String.self, forKey: .type)
            self.ruleCount = try container.decode(Int.self, forKey: .ruleCount)
            self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
            self.format = try container.decodeIfPresent(String.self, forKey: .format)  // 使用 decodeIfPresent
            self.vehicleType = try container.decode(String.self, forKey: .vehicleType)
        }
        
        var formattedUpdateTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            guard let date = formatter.date(from: updatedAt) else {
                return "未知"
            }
            
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
            
            if let years = components.year, years > 0 {
                return "\(years)年前"
            }
            if let months = components.month, months > 0 {
                return "\(months)个月前"
            }
            if let days = components.day, days > 0 {
                return "\(days)天前"
            }
            if let hours = components.hour, hours > 0 {
                return "\(hours)小时前"
            }
            if let minutes = components.minute, minutes > 0 {
                return "\(minutes)分钟前"
            }
            return "刚刚"
        }
    }
    
    init(server: ClashServer) {
        self.server = server
        Task { await fetchData() }
    }
    
    @MainActor
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        // 获取规则
        if let rulesData = try? await fetchRules() {
            self.rules = rulesData.rules
        }
        
        // 获取规则提供者
        if let providersData = try? await fetchProviders() {
            self.providers = providersData.providers.map { name, provider in
                var provider = provider
                provider.name = name
                return provider
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }  // 按名称排序
        }
    }
    
    private func fetchRules() async throws -> RulesResponse {
        guard let url = server.baseURL?.appendingPathComponent("rules") else {
            throw URLError(.badURL)
        }
        let request = try server.makeRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RulesResponse.self, from: data)
    }
    
    private func fetchProviders() async throws -> ProvidersResponse {
        guard let url = server.baseURL?.appendingPathComponent("providers/rules") else {
            throw URLError(.badURL)
        }
        let request = try server.makeRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }
    
    @MainActor
    func refreshProvider(_ name: String) async {
        do {
            // 找到要刷新的提供者
            guard let provider = providers.first(where: { $0.name == name }) else {
                print("[RulesViewModel] Provider not found: \(name)")
                return
            }
            
            // 更新该提供者的加载状态
            if let index = providers.firstIndex(where: { $0.name == name }) {
                providers[index].isRefreshing = true
            }
            
            // 构建刷新 URL
            guard let baseURL = server.baseURL else {
                print("[RulesViewModel] Invalid base URL for server: \(server.name)")
                throw URLError(.badURL)
            }
            
            let url = baseURL
                .appendingPathComponent("providers")
                .appendingPathComponent("rules")
                .appendingPathComponent(name)
            
            print("[RulesViewModel] Refreshing provider URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
            
            print("[RulesViewModel] Request headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[RulesViewModel] Response status code: \(httpResponse.statusCode)")
                print("[RulesViewModel] Response headers: \(httpResponse.allHeaderFields)")
                
                if httpResponse.statusCode == 204 {
                    print("[RulesViewModel] Successfully refreshed provider: \(name)")
                    await fetchData()
                } else {
                    if httpResponse.statusCode == 401 {
                        print("[RulesViewModel] Authentication failed. Secret key: \(String(describing: server.secret))")
                        print("[RulesViewModel] Server URL: \(String(describing: server.url))")
                    }
                    print("[RulesViewModel] Unexpected status code: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[RulesViewModel] Response body: \(responseString)")
                    }
                }
            }
        } catch {
            print("[RulesViewModel] Error refreshing provider: \(error)")
            print("[RulesViewModel] Error details: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("[RulesViewModel] URL Error code: \(urlError.code.rawValue)")
                print("[RulesViewModel] URL Error description: \(urlError.localizedDescription)")
            }
        }
        
        // 重置刷新状态
        if let index = providers.firstIndex(where: { $0.name == name }) {
            providers[index].isRefreshing = false
        }
    }
    
    @MainActor
    func refreshAllProviders() async {
        guard !isRefreshingAll else { return }  // 防止重复刷新
        
        isRefreshingAll = true
        print("[RulesViewModel] Starting refresh all providers")
        
        for provider in providers {
            await refreshProvider(provider.name)
        }
        
        isRefreshingAll = false
        print("[RulesViewModel] Completed refresh all providers")
    }
}

// Response models
struct RulesResponse: Codable {
    let rules: [RulesViewModel.Rule]
}

struct ProvidersResponse: Codable {
    let providers: [String: RulesViewModel.RuleProvider]
} 