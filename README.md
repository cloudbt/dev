区别主要在于 job 数量及当天最后一次执行时间：
1. 6/26 的 INC51130 仅咨询 Release，实际作业是 7/7 的 INC51218。当时只有 2 个 job，最后一次执行均在营业时间外，因此使用了 Release 功能。
2. 上周五共处理 6 个 job：
   - GD02、GD06：最后一次执行在营业时间外，使用 Release。
   - GN04～GN07：最后一次执行在营业时间内，按工藤告知的方法，先删除旧 job，再创建新 job。


https://itpfdoc.hitachi.co.jp/manuals/3021/30213D2520e/AJSJ0210.HTM#a0015f20


已发现明确的配置问题：**子级监视把 Jobnet 路径填进了只表示 Job group 的 `A0` 条件中。** 这足以解释目前的现象。

现场确认 `02_IF` 是 Job group，`NIN_IF`、`GDE_MASTER` 是其下的 Jobnet。异常事件 `4107` 中，`A0` 表示 Job group 路径，`A1` 才表示 Root Jobnet 名称。[日立官方说明，表 A-9](https://itpfdoc.hitachi.co.jp/manuals/3021/30213D2520e/AJSJ0210.HTM#a0015f20)

| 监视 | 当前 `A0` 条件 | 对该异常的匹配结果 |
|---|---|---|
| 父级 `DIID_02_IF` | `AJSROOT1:/DIID/02_IF` | 匹配 |
| 子级 `DIID_02_IF_NIN_IF-E` | `AJSROOT1:/DIID/02_IF/NIN_IF` | 不匹配，多出了 Jobnet 名 |
| 子级 `DIID_02_IF_GDE_MASTER-E` | `AJSROOT1:/DIID/02_IF/GDE_MASTER` | 同样的问题 |

以附件中的 NIN_IF 异常为例，事件的 Job group 仍是 `/DIID/02_IF`。因此父级条件成立并执行自己的邮件发送，子级条件不成立，其收件人列表就没有机会被使用。

修正方向应是：**用 `A0` 限定 Job group，再用 `A1` 区分具体 Jobnet**。若要求只发送子级邮件，还需设计父级的排除范围，避免修正后重复通知。

以上已确认的是**当前定义缺陷**；10/15 原始事件属性和当时生效的定义尚未核验，所以历史个案还未完全闭环。其他子级也尚未逐一检查。

全程只读，未修改、保存或提交任何设置，画面已回到 JobMonitoring 列表。


已核对日立官方文档，**支持刚才发现的 `A0` 配置问题**，并补充确认了以下规则。

| 核对点 | 官方定义 | 对本次问题的意义 |
|---|---|---|
| `4107` | Job 异常结束事件，对应 `KAVS0265-E` | 与附件邮件一致 |
| `A0` | Scheduler service 名＋Job group 路径 | 本例应对应 `AJSROOT1:/DIID/02_IF` |
| `A1` | Root Jobnet 名 | 用于区分 `NIN_IF`、`GDE_MASTER` |

出处：[《运用指南》A.2，表 A-9](https://itpfdoc.hitachi.co.jp/manuals/3021/30213D2520e/AJSJ0210.HTM#a0015f20)。

因此，目前子级条件中的：

`A0 = AJSROOT1:/DIID/02_IF/NIN_IF`

把 Jobnet 名混进了 Job group 属性，无法匹配该层级下的异常事件。父级的 `A0` 则能够匹配。

官方还明确说明：**字符串条件采用部分匹配，需要完全匹配时应使用带边界的正则表达式。** 所以后续设计条件时，也要避免相似名称误匹配。[《设计指南》7.6.1(3)](https://itpfdoc.hitachi.co.jp/manuals/3021/30213d2330/AJSG0082.HTM)

修正方向仍是：子级用 `A0` 限定 group、用 `A1` 限定 Jobnet。**修正子级不会自动排除父级的匹配范围**；若客户只希望收到子级邮件，父级通知范围也需一起设计。

另一个需要保留的核验点是时间：官方说明，未启用“执行前事件搜索”时，只监视开始运行之后的事件。因此，10/15 个案仍需对照当时的事件属性和监视运行记录，才能最终闭环。[《操作指南》12.4.15](https://itpfdoc.hitachi.co.jp/manuals/3021/30213b1820/AJSV0309.HTM)

本轮仅查阅官方资料，未操作或修改 JP1。


可以。**把“文件夹路径”和“Jobnet 名称”分成两个条件填写。**

你现在的结构是：

```text
DIID
 └─ 02_IF          ← Job group（文件夹）
     ├─ NIN_IF     ← Jobnet
     └─ GDE_MASTER ← Jobnet
```

`A0` 只看文件夹路径，`A1` 看 Jobnet 名称。

以监视 **NIN_IF** 为例，在 `DIID_02_IF_NIN_IF-E` → `.CONDITION` → `Abnormally2` → 扩展属性中，修正思路如下：

| 项目 | 现在的条件 | 修正例子 |
|---|---|---|
| Event ID | `4107` | 保持 `4107` |
| A0 | `AJSROOT1:/DIID/02_IF/NIN_IF` | `^AJSROOT1:/DIID/02_IF$` |
| A1 | 没有设置 | 新增 `^NIN_IF$` |

两个条件需要**同时满足**，意思就是：

> 只接收 `/DIID/02_IF` 文件夹中，属于 `NIN_IF` 这个 Jobnet 的 Job 异常。

这里的 `^` 和 `$` 表示“完整一致”，避免把名称相似的对象也匹配进去。GDE 的做法相同，只把 A1 换成 `^GDE_MASTER$`。

**父级监视需要另外考虑：**它目前覆盖整个 `02_IF`。即使修好了子级，父级仍可能发信，形成两封邮件。如果客户要求“只发子级收件人”，还需要让父级排除已由子级负责的范围；仅修子级不能完成这个要求。

以上只是具体修正示例，**我没有实际修改任何设置**。


A0 : ^AJSROOT1:/DIID/02_IF$
A1 : ^NIN_IF$
