# DS 鲸鱼娘 · DeepSeek 余额桌面挂件

一只住在你桌面上的透明立绘「鲸鱼娘」，**实时显示 DeepSeek API 账户余额**。

灵感来自 [DSH (DeepSeek Harness)](https://github.com/deepseek-ai/deepseek-harness) 的鲸鱼娘余额挂件——但它是独立的：不需要安装任何软件，双击即用。

```
        ╭──────────────────╮
        │ 余额 ¥6.24        │  ← 点立绘弹气泡
        │ 21:17 更新 · -¥0.06│
        ╰──────────────────╯
           🐋 ← 鲸鱼娘立绘（透明悬浮，轻轻浮动）
        ╭────────────────────╮
        │ ● ¥6.24      正常  │  ← 底部胶囊常驻显示余额
        ╰────────────────────╯
```

## ✨ 特性

- **纯立绘透明悬浮** —— 用分层窗口（UpdateLayeredWindow）实现，立绘边缘平滑，背景完全透明，像真的"站"在桌面上
- **实时余额** —— 每 60 秒自动刷新 DeepSeek 账户余额（调用官方 `GET /user/balance` 接口）
- **轻浮动动画** —— 立绘轻轻上下浮动
- **点击弹气泡** —— 单击立绘弹出余额详情（余额 / 更新时间 / 较上次变化），6 秒后自动收起
- **拖动移动** —— 拖到顺手的位置，自动记住
- **多形象切换** —— 右键菜单可切换 3 张立绘
- **余额预警** —— 低于 ¥5 变橙色警示，欠费变红
- **音效** —— 点击时的轻快音效，可右键关闭
- **零依赖** —— 纯 Windows PowerShell 5.1 + .NET Framework（Win10/11 自带），不装任何东西
- **开机自启** —— 一键安装器可选配置（静默启动，无黑窗）

## 🚀 快速开始

### 方式一：一键安装（推荐）

1. 下载或克隆本仓库到任意目录
2. **双击 `install.bat`**，按提示操作：
   - 粘贴你的 DeepSeek API Key（在 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 创建）
   - 自动创建桌面快捷方式
   - 可选设置开机自启
3. 完成！鲸鱼娘会马上出现

### 方式二：手动安装

1. 在项目目录下创建 `.key` 文件（无 BOM 纯文本），内容为你的 API Key：
   ```
   sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
2. 运行：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File whale-hud.ps1
   ```

## 🖱️ 交互说明

| 操作 | 效果 |
|:-----|:-----|
| 单击立绘 | 弹出余额气泡（6 秒自动收起） |
| 双击立绘 | 立即刷新余额 |
| 拖动立绘 | 移动位置（自动记忆） |
| 右键立绘 | 菜单：刷新 / 换形象 / 音效开关 / 打开充值页 / 退出 |
| 60 秒 | 自动刷新余额 |

## 📁 项目结构

```
deepseek-whale-hud/
├── whale-hud.ps1    # 主程序：悬浮窗挂件（分层窗口 + 立绘 + 气泡）
├── check.ps1        # 命令行版：快速查询余额（无界面）
├── check.bat        # check.ps1 的双击入口
├── install.bat      # 一键安装
├── setup.ps1        # 安装脚本（快捷方式 / 开机自启）
├── assets/          # 立绘素材与音效
│   ├── DSniang1.png
│   ├── DSniang02.png
│   ├── DSH2.png
│   ├── whale.ico    # 快捷方式图标
│   └── minecraft-exp-orb.wav
├── .key             # (自行创建) 你的 API Key，已被 .gitignore 排除
└── README.md
```

## ❓ 常见问题

**Q: 会不会花钱？**
A: 余额查询接口本身是免费的，不消耗 token。

**Q: 立绘可以换成我自己的图吗？**
A: 可以。把图片改名为 `DSniang1.png` 覆盖 `assets/` 里的文件（用方形透明 PNG 效果最好），或修改脚本里 `$avatarChoices` 的列表。

**Q: 显示"查询失败"？**
A: 检查 `.key` 文件里的 API Key 是否正确、网络能否访问 `api.deepseek.com`。

**Q: 想看余额历史 / 今日消耗？**
A: 每次刷新会写入 `hud-heartbeat.txt`（时间 + 余额），可以自行统计分析。

**Q: 怎么关掉 / 卸载？**
A: 右键立绘 → 退出，即关闭本次。删除桌面快捷方式和启动文件夹里的 `WhaleHUD.lnk` 即完全卸载（无注册表、无残留）。

## ⚖️ 素材版权与致谢

- **脚本代码**：MIT License（见 [LICENSE](LICENSE)）
- **立绘与音效素材**：来自 [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)（MIT License），版权归原作者所有。本项目仅作风格学习与个人使用场景下的再分发，如需商用请先取得原作者授权。
- **灵感来源**：DeepSeek Harness 社区的"鲸鱼娘"余额挂件生态

## 📄 License

MIT
