import SwiftUI

struct RuleEditView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let rule: OpenClashRule?
    let onSave: (OpenClashRule) -> Void
    
    @State private var selectedType: RuleType = .domain
    @State private var target: String = ""
    @State private var action: String = ""
    @State private var comment: String = ""
    @State private var showError = false
    @State private var errorMessage: String?
    
    // 添加常用策略选项
    private let commonActions = ["DIRECT", "REJECT"]
    
    init(title: String = "添加规则", rule: OpenClashRule? = nil, onSave: @escaping (OpenClashRule) -> Void) {
        self.title = title
        self.rule = rule
        self.onSave = onSave
        
        // 如果是编辑模式，设置初始值
        if let rule = rule {
            _selectedType = State(initialValue: RuleType(rawValue: rule.type) ?? .domain)
            _target = State(initialValue: rule.target)
            _action = State(initialValue: rule.action)
            _comment = State(initialValue: rule.comment ?? "")
        }
    }
    
    private func save() {
        // 验证输入
        guard !target.isEmpty else {
            errorMessage = "请输入匹配内容"
            showError = true
            return
        }
        
        guard !action.isEmpty else {
            errorMessage = "请输入策略"
            showError = true
            return
        }
        
        // 创建规则
        let newRule = OpenClashRule(
            id: rule?.id ?? UUID(),  // 如果是编辑模式，保持原有ID
            target: target.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType.rawValue,
            action: action.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: rule?.isEnabled ?? true,  // 如果是编辑模式，保持原有状态
            comment: comment.isEmpty ? nil : comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        onSave(newRule)
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 规则类型选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("规则类型")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Menu {
                            ForEach(RuleType.allCases, id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: type.iconName)
                                            .foregroundColor(type.iconColor)
                                            .frame(width: 20)
                                        Text(type.rawValue)
                                            .foregroundColor(.primary)
                                        Spacer(minLength: 8)
                                        Text(type.description)
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedType.iconName)
                                    .foregroundColor(selectedType.iconColor)
                                    .frame(width: 20)
                                Text(selectedType.rawValue)
                                    .foregroundColor(.primary)
                                Spacer(minLength: 8)
                                Text(selectedType.description)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                                    .imageScale(.small)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // 匹配内容
                    VStack(alignment: .leading, spacing: 8) {
                        Text("匹配内容")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入匹配内容", text: $target)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(selectedType.example)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 策略选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("策略")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入策略名称", text: $action)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        
                        // 常用策略快速选择
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(commonActions, id: \.self) { commonAction in
                                    Button {
                                        action = commonAction
                                    } label: {
                                        Text(commonAction)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(action == commonAction ? 
                                                      selectedType.iconColor : 
                                                      Color(.systemBackground))
                                            .foregroundColor(action == commonAction ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(action == commonAction ? 
                                                           Color.clear : 
                                                           Color(.separator), lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("常用策略说明", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("• DIRECT - 直接连接")
                                .font(.caption)
                            Text("• REJECT - 拒绝连接")
                                .font(.caption)
                            Text("• 其他策略需要与配置文件中的策略组名称一致")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 备注
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("可选", text: $comment)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("保存")
                            .bold()
                    }
                    .disabled(target.isEmpty || action.isEmpty)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
} 