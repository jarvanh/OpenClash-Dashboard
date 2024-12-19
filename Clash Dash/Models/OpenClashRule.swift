import Foundation

struct OpenClashRule: Identifiable, Equatable {
    let id = UUID()
    let target: String      // 例如: checkipv6.dyndns.org
    let type: String        // 例如: DOMAIN-SUFFIX
    let action: String      // 例如: DIRECT
    let isEnabled: Bool     // 是否启用
    let comment: String?    // 备注
    
    init(from ruleString: String) {
        // 移除前导空格
        let trimmedString = ruleString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否被禁用（以##开头）
        self.isEnabled = !trimmedString.hasPrefix("##")
        
        // 清理字符串，移除"- "和"##- "
        let cleanString = trimmedString
            .replacingOccurrences(of: "##- ", with: "")
            .replacingOccurrences(of: "- ", with: "")
        
        // 分割字符串，获取规则和注释
        let components = cleanString.components(separatedBy: "#")
        let ruleComponents = components[0].components(separatedBy: ",")
        
        if ruleComponents.count >= 3 {
            self.type = ruleComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)
            self.target = ruleComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
            self.action = ruleComponents[2].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.type = ""
            self.target = ""
            self.action = ""
        }
        
        // 提取注释
        if components.count > 1 {
            self.comment = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.comment = nil
        }
    }
} 