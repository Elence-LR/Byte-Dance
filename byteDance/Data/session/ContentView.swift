// ContentView.swift
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var vm = SessionListViewModel()
    @State private var newSessionTitle = ""
    @State private var showingNewSessionSheet = false
    
    // 长按删除相关状态
    @State private var showingDeleteConfirm = false
    @State private var sessionToDelete: ChatSession?
    // 震动反馈
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.sessions) { session in
                    VStack {
                        NavigationLink(destination: ChatView(sessionId: session.id)) {
                            Text(session.title)
                        }
                    }
                    // 1. 长按删除（
                    .onLongPressGesture(minimumDuration: 0.5) {
                        feedbackGenerator.impactOccurred()
                        sessionToDelete = session
                        showingDeleteConfirm = true
                    }
                    // 2. 侧滑删除
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            // 侧滑直接触发删除确认弹窗
                            sessionToDelete = session
                            showingDeleteConfirm = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("会话列表")
            .toolbar {
                Button("新建会话") {
                    showingNewSessionSheet = true
                }
            }
            .sheet(isPresented: $showingNewSessionSheet) {
                VStack(spacing: 20) {
                    TextField("输入会话标题", text: $newSessionTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                    Button("创建") {
                        Task {
                            await vm.createNewSession(title: newSessionTitle)
                            newSessionTitle = ""
                            showingNewSessionSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .onAppear {
                Task { await vm.loadSessions() }
            }
            // 共用的删除确认弹窗
            .alert("确认删除？", isPresented: $showingDeleteConfirm, actions: {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let session = sessionToDelete {
                        Task { await vm.deleteSession(session) }
                    }
                }
            }, message: {
                Text("删除后该会话的所有消息将被永久清除，无法恢复。")
            })
            // 错误提示弹窗
            .alert(item: $vm.errorMessage) { (alert: ErrorAlert) in
                Alert(title: Text("错误"), message: Text(alert.message))
            }
        }
    }
}

// 聊天页
struct ChatView: View {
    let sessionId: String
    @StateObject private var vm: ChatViewModel
    // 图片相关状态
    @State private var showingImagePicker = false
    @State private var selectedImageData: Data?
    init(sessionId: String) {
        self.sessionId = sessionId
        _vm = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }
    
    var body: some View {
        VStack {
            // 消息列表
            List(vm.messages) { msg in
                VStack(alignment: .leading, spacing: 8) {
                    // 文本内容
                    HStack {
                        Text(msg.role == .user ? "我：" : "AI：")
                        Text(msg.content.isEmpty ? (msg.streamingContent ?? "") : msg.content)
                    }
                    
                    // 图片预览
                    if let imagePath = msg.imageLocalPath,
                       let image = ChatPersistenceManager.shared.loadImage(from: imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(8)
                    }
                }
            }
            
            // 输入栏
            HStack {
                // 图片选择按钮
                Button {
                    showingImagePicker = true
                } label: {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                // 文本输入框
                TextField("输入消息...", text: $vm.draftContent)
                    .textFieldStyle(.roundedBorder)
                
                // 发送按钮
                Button("发送") {
                    Task { await vm.sendUserMessage() }
                }
            }
            .padding()
            
            // 图片选择器弹窗
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImageData: $selectedImageData)
            }
            // 选择图片后自动发送
            .onChange(of: selectedImageData) { newData in
                if let data = newData {
                    Task {
                        await vm.sendImageMessage(data, textContent: vm.draftContent)
                        vm.draftContent = ""  // 清空输入框
                        selectedImageData = nil
                    }
                }
            }
        }
        .navigationTitle("聊天")
        .onChange(of: vm.draftContent) {
            Task { await vm.saveDraft() }
        }
        .alert(item: $vm.errorMessage) { alert in
            Alert(title: Text("错误"), message: Text(alert.message))
        }
    }
}
#Preview {
    ContentView()
}
