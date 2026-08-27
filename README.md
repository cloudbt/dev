https://docs.autohotkey.com/download/2.0/

当然可以。AutoHotkey（AHK）非常适合在 Windows 11 上做**快捷键、自定义键盘、自动输入、启动程序、窗口操作以及简单的桌面自动化**。

目前建议直接使用 **AutoHotkey v2**。官方截至 2026 年 5 月发布的稳定版是 **v2.0.26**；v2.1 目前仍属于 alpha，所以不建议日常使用。([AutoHotkey Documentation][1])

[AutoHotkey v2 官方下载](https://www.autohotkey.com/download/ahk-v2.exe?utm_source=chatgpt.com)

### 1. 安装

下载安装 AutoHotkey v2 后，基本保持默认安装即可。

然后桌面空白位置：

**鼠标右键 → 新建 → AutoHotkey Script**

比如建立：

```text
MyHotkey.ahk
```

右键这个文件：

```text
Edit Script
```

可以用记事本、Notepad++、VS Code 编辑。

---

### 2. 第一个 AutoHotkey

写：

```ahk
#Requires AutoHotkey v2.0

^!n::
{
    Run "notepad.exe"
}
```

保存，然后双击：

```text
MyHotkey.ahk
```

任务栏右下角会出现绿色的 **H** 图标。

现在按：

```text
Ctrl + Alt + N
```

就会打开记事本。

这里：

```text
^ = Ctrl
! = Alt
+ = Shift
# = Windows键
```

所以：

```ahk
^a
```

就是 Ctrl+A。

```ahk
!a
```

就是 Alt+A。

```ahk
+a
```

就是 Shift+A。

```ahk
#a
```

就是 Win+A。

---

### 3. 最常用的几个例子

例如按：

```text
Win + C
```

打开 Chrome：

```ahk
#c::
{
    Run "chrome.exe"
}
```

按：

```text
Ctrl + Alt + G
```

打开 Google：

```ahk
^!g::
{
    Run "https://www.google.com"
}
```

---

### 4. 自动输入文字

例如：

```ahk
^!m::
{
    SendText "こんにちは。お世話になっております。"
}
```

以后按：

**Ctrl + Alt + M**

自动输入：

```text
こんにちは。お世話になっております。
```

这个在工作中非常有用，比如经常输入的：

```text
お疲れ様です。
よろしくお願いいたします。
確認いたします。
```

都可以做成快捷键。

---

### 5. 输入缩写自动展开

这个功能叫 **Hotstring**。

例如：

```ahk
::ots::お疲れ様です。
::yor::よろしくお願いいたします。
::addr::東京都北区
```

输入：

```text
ots
```

然后按空格，就会自动变成：

```text
お疲れ様です。
```

对于经常写邮件、Teams、工单非常方便。

---

### 6. 修改键盘按键

例如把 CapsLock 改成 Ctrl：

```ahk
CapsLock::Ctrl
```

或者：

```ahk
CapsLock::Esc
```

把 CapsLock 变成 Esc。

也可以：

```ahk
F1::F5
```

这样按 F1 实际执行 F5。

---

### 7. 一个键执行多个动作

例如：

```ahk
F8::
{
    Run "notepad.exe"
    Sleep 1000
    SendText "Hello AutoHotkey"
}
```

按 F8：

```text
打开记事本
↓
等待 1 秒
↓
输入 Hello AutoHotkey
```

这里：

```ahk
Sleep 1000
```

代表等待 **1000ms = 1秒**。

---

### 8. 模拟键盘快捷键

例如：

```ahk
F9::
{
    Send "^c"
    Sleep 200
    Send "^v"
}
```

其中：

```ahk
Send "^c"
```

相当于按：

```text
Ctrl+C
```

例如：

```ahk
Send "^a"
Send "^c"
Send "!{Tab}"
Send "^v"
```

就是：

```text
Ctrl+A
Ctrl+C
Alt+Tab
Ctrl+V
```

这种方式已经可以做很多桌面自动化。

---

### 9. 控制鼠标

例如移动鼠标：

```ahk
F6::
{
    MouseMove 500, 300
}
```

移动到屏幕：

```text
X=500
Y=300
```

然后点击：

```ahk
F6::
{
    MouseMove 500, 300
    Click
}
```

或者直接：

```ahk
Click 500, 300
```

右键：

```ahk
Click "Right"
```

双击：

```ahk
Click 500, 300, 2
```

不过实际做自动化时，我建议**尽量不要依赖坐标点击**，因为分辨率、窗口位置变化以后容易失效。

---

### 10. 只在特定程序里启用快捷键

这个特别实用。

例如只在 Chrome 里面：

```ahk
#HotIf WinActive("ahk_exe chrome.exe")

F8::
{
    Send "^l"
}

#HotIf
```

现在 F8：

* Chrome 里 → Ctrl+L
* 其他软件 → 没反应

例如针对记事本：

```ahk
#HotIf WinActive("ahk_exe notepad.exe")

F9::
{
    SendText "Test"
}

#HotIf
```

---

### 11. 推荐先记住这些命令

| 命令            | 用途        |
| ------------- | --------- |
| `Run`         | 启动程序/网页   |
| `Send`        | 模拟键盘      |
| `SendText`    | 输入文字      |
| `Click`       | 鼠标点击      |
| `MouseMove`   | 移动鼠标      |
| `Sleep`       | 等待        |
| `WinActivate` | 激活窗口      |
| `WinWait`     | 等待窗口      |
| `WinExist`    | 判断窗口      |
| `#HotIf`      | 限制快捷键生效范围 |
| `MsgBox`      | 显示消息框     |

比如：

```ahk
MsgBox "Hello"
```

会弹出一个窗口。

---

### 12. 推荐你的基本模板

以后可以建一个：

```text
MyHotkey.ahk
```

内容：

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; Ctrl + Alt + N：记事本
^!n::
{
    Run "notepad.exe"
}

; Ctrl + Alt + G：Google
^!g::
{
    Run "https://www.google.com"
}

; Ctrl + Alt + M：常用日语
^!m::
{
    SendText "お疲れ様です。よろしくお願いいたします。"
}

; 快速输入
::ots::お疲れ様です。
::yor::よろしくお願いいたします。
```

`;` 后面是注释。

---

### 13. 修改脚本以后怎么生效

修改 `.ahk` 文件并保存以后，不需要关闭整个 AutoHotkey。

右下角找到绿色：

**H**

右键：

```text
Reload Script
```

即可。

也可以在脚本里加一个快捷键：

```ahk
^!r::Reload
```

以后：

```text
Ctrl + Alt + R
```

直接重新加载脚本。

非常方便。

---

### 14. Windows 11 开机自动运行

测试稳定后，可以把 `.ahk` 放进 Windows 启动目录。

按：

```text
Win + R
```

输入：

```text
shell:startup
```

打开启动文件夹。

把：

```text
MyHotkey.ahk
```

的**快捷方式**放进去即可。

以后登录 Windows 后自动运行。

---

有一点需要特别注意：你网上搜 AutoHotkey 时会看到非常多这样的老代码：

```ahk
Run, notepad.exe
Send, Hello
```

这是 **AutoHotkey v1** 写法。

现在 v2 是：

```ahk
Run "notepad.exe"
Send "Hello"
```

**v1 和 v2 语法差异很大**，所以你之后找代码时，尽量搜索：

```text
AutoHotkey v2
AHK v2
```

而不要直接复制老的 v1 代码。([AutoHotkey Documentation][1])

如果你告诉我**你具体想用 AutoHotkey 自动操作什么**，比如「控制另一个 Windows 软件」「自动点击按钮」「自动输入 Teams 内容」「监听某个键盘按键」「控制鼠标」「配合 Stream Deck / NanoKVM」，我可以直接给你写一份 **AHK v2 可以运行的完整脚本**。

[1]: https://docs.autohotkey.com/download/2.0/?utm_source=chatgpt.com "Index of /download/2.0"


有，而且 **AutoHotkey 官方就提供免安装 ZIP 版**，很适合你这种想直接解压使用的情况。

目前稳定版是 **AutoHotkey v2.0.26**，官方下载目录里同时提供：

* `AutoHotkey_2.0.26.zip` → **免安装 / Portable**
* `AutoHotkey_2.0.26_setup.exe` → 安装版

官方确实有 ZIP 包。([AutoHotkey Documentation][1])

[AutoHotkey v2.0.26 官方下载目录](https://www.autohotkey.com/download/2.0/?utm_source=chatgpt.com)

下载：

```text
AutoHotkey_2.0.26.zip
```

然后直接解压，例如：

```text
D:\Tools\AutoHotkey\
```

里面会有类似：

```text
AutoHotkey.exe
AutoHotkey32.exe
AutoHotkey64.exe
UX\
...
```

你的 Windows 11 基本都是 64 位，直接可以用 64 位版本。

例如你建立：

```text
D:\Tools\AutoHotkey\test.ahk
```

内容：

```ahk
#Requires AutoHotkey v2.0

F8::
{
    MsgBox "AutoHotkey Portable 正常运行！"
}
```

然后可以直接这样运行：

```cmd
D:\Tools\AutoHotkey\AutoHotkey.exe D:\Tools\AutoHotkey\test.ahk
```

或者把 `.ahk` 文件直接拖到 `AutoHotkey.exe` 上。

### Portable 版和安装版的主要区别

功能上基本一样。

| 项目             | Portable ZIP |  安装版 |
| -------------- | -----------: | ---: |
| 需要安装           |            ❌ |    ✅ |
| 需要管理员权限安装      |            ❌ | 可能需要 |
| 可放 U 盘         |            ✅ |  不方便 |
| 可直接运行脚本        |            ✅ |    ✅ |
| 注册 `.ahk` 文件关联 |         默认没有 |    ✅ |
| 右键菜单           |         默认没有 |    ✅ |
| 自动更新/管理方便      |           一般 |  更方便 |
| 自动化能力          |           一样 |   一样 |

所以如果你的目标是：

```text
公司电脑
↓
不能安装软件
↓
但可以运行 exe
↓
运行自己的 AHK 脚本
```

那么 **ZIP Portable 版反而非常合适**。

而且你甚至可以整个目录复制过去：

```text
AutoHotkeyPortable\
├─ AutoHotkey.exe
├─ script\
│  ├─ main.ahk
│  ├─ keyboard.ahk
│  └─ automation.ahk
└─ start.cmd
```

`start.cmd` 写：

```bat
@echo off
"%~dp0AutoHotkey.exe" "%~dp0script\main.ahk"
```

以后只需要双击：

```text
start.cmd
```

就运行了，**完全不用安装，也不用注册 Windows 文件关联**。

如果你是打算在**公司 Windows 11 / Citrix / 受限制电脑**上使用，我还可以进一步给你一个「**完全 Portable、无需管理员权限、一个文件夹复制过去就能运行**」的 AHK v2 目录结构和启动脚本。

[1]: https://docs.autohotkey.com/download/2.0/?utm_source=chatgpt.com "Index of /download/2.0"
