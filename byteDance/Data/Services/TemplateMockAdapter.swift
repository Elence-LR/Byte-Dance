import Foundation

public final class TemplateMockAdapter: LLMServiceProtocol {
    private let template: String

    public init(template: String? = nil) {
        self.template = template ?? TemplateMockAdapter.defaultTemplate
    }

    public func sendMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) async throws -> Message {
        Message(role: .assistant, content: template)
    }

    public func streamMessage(sessionID: UUID, messages: [Message], config: AIModelConfig) -> AsyncThrowingStream<Message, Error> {
        let chunks = chunk(template, size: 80)
        return AsyncThrowingStream { continuation in
            Task {
                for c in chunks {
                    continuation.yield(Message(role: .assistant, content: c))
                    try? await Task.sleep(nanoseconds: 60_000_000)
                }
                continuation.finish()
            }
        }
    }


    private func chunk(_ s: String, size: Int) -> [String] {
        var result: [String] = []
        var idx = s.startIndex
        while idx < s.endIndex {
            let end = s.index(idx, offsetBy: size, limitedBy: s.endIndex) ?? s.endIndex
            result.append(String(s[idx..<end]))
            idx = end
        }
        return result
    }

    private static let defaultTemplate = """
# 🚀 项目开发指南

## 📋 目录概览

本文档将介绍项目的核心功能、技术栈以及开发规范。

---

## 💻 技术栈介绍

### 前端技术

我们采用现代化的前端技术栈，主要包括：

- **React 18.2** - 用户界面库
- **TypeScript 4.9** - 类型安全
- **Tailwind CSS** - 样式解决方案
- **Vite** - 构建工具

### 后端技术

后端服务基于以下技术构建：

1. Node.js v18 LTS
2. Express.js 框架
3. PostgreSQL 数据库
4. Redis 缓存层

---

## 🔧 快速开始

### 安装依赖

首先克隆项目并安装依赖包：
```bash
# 克隆仓库
git clone https://github.com/your-repo/project.git

# 进入项目目录
cd project

# 安装依赖
npm install
```

### 配置环境变量

创建 `.env` 文件并添加以下配置：
```env
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
REDIS_URL=redis://localhost:6379
API_KEY=your_secret_key_here
PORT=3000
```

### 启动开发服务器
```javascript
// server.js
const express = require('express');
const app = express();

app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: Date.now()
  });
});

app.listen(3000, () => {
  console.log('🎉 Server running on port 3000');
});
```

---

## 📊 性能指标对比

| 指标 | 优化前 | 优化后 | 提升幅度 |
|------|--------|--------|----------|
| 首屏加载时间 | 3.2s | 1.1s | ⬆️ 65% |
| API 响应时间 | 450ms | 120ms | ⬆️ 73% |
| 内存占用 | 512MB | 256MB | ⬇️ 50% |
| 打包体积 | 2.8MB | 980KB | ⬇️ 65% |

---

## 🎨 组件开发规范

### React 组件示例

以下是一个标准的函数组件写法：
```typescript
import React, { useState, useEffect } from 'react';

interface UserCardProps {
  userId: string;
  onUpdate?: (user: User) => void;
}

export const UserCard: React.FC<UserCardProps> = ({ userId, onUpdate }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchUser(userId).then(data => {
      setUser(data);
      setLoading(false);
    });
  }, [userId]);

  if (loading) return <div>Loading... ⏳</div>;
  
  return (
    <div className="user-card">
      <h3>{user?.name} 👤</h3>
      <p>{user?.email} 📧</p>
    </div>
  );
};
```

---

## ⚠️ 注意事项

### 重要提醒

> ⚡ **性能优化建议**  
> 在生产环境中，务必启用代码压缩和懒加载功能。

> 🔒 **安全提示**  
> 永远不要在客户端代码中硬编码敏感信息！

### 常见问题

#### 1. 如何处理跨域问题？

在开发环境中配置代理：
```json
{
  "proxy": {
    "/api": {
      "target": "http://localhost:3000",
      "changeOrigin": true
    }
  }
}
```

#### 2. 数据库连接失败怎么办？

检查以下几点：
- ✅ 数据库服务是否启动
- ✅ 连接字符串是否正确
- ✅ 防火墙规则是否允许连接
- ✅ 用户权限是否充足

---

## 🎯 路线图

### Q4 2024

- [x] 完成用户认证模块 ✨
- [x] 实现实时通知功能 🔔
- [ ] 添加数据导出功能 📤
- [ ] 性能优化（目标：LCP < 2s） 🚀

### Q1 2025

- [ ] 移动端适配 📱
- [ ] 多语言支持 🌍
- [ ] AI 辅助功能 🤖
- [ ] 暗黑模式 🌙

---

## 📞 联系我们

有任何问题或建议，欢迎通过以下方式联系：

- 📧 Email: support@example.com
- 💬 Discord: https://discord.gg/example
- 🐦 Twitter: https://twitter.com/projectname
- 📝 GitHub Issues: https://github.com/your-repo/issues

---

## 📄 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

© 2024 Your Company. All rights reserved. 🎉
"""
}
