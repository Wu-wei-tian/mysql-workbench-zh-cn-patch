# MySQL Workbench 26.7.0 简体中文补丁

适用于 Windows x64 的非官方简体中文汉化补丁，当前版本为 **26.7.0-zh.1 社区预览版**。本项目独立制作，不代表 Oracle 或 MySQL 官方发布。

## 下载安装

前往[发布页面](https://github.com/Wu-wei-tian/mysql-workbench-zh-cn-patch/releases)下载安装程序。

| 你的情况 | 下载文件 | 安装方式 |
| --- | --- | --- |
| 已安装 Workbench 26.7.0 | `MySQL-Workbench-26.7.0-zh-CN-Patch.exe` | 离线安装汉化补丁，支持已核验的 MSI 和 ZIP 资源布局 |
| 尚未安装 Workbench | `MySQL-Workbench-26.7.0-zh-CN-Setup.exe` | 联网下载并校验官方程序，安装后使用独立的个人配置 |

安装前请保存工作并关闭 Workbench，阅读[使用前必读](READ%20ME%20BEFORE%20USE.txt)。发布附件包含使用说明、源码压缩包、许可说明和 SHA-256 校验值。

## 使用与恢复

- 默认界面语言为简体中文，可在“语言 / Language”菜单中切换中英文，重启后生效。
- 补丁安装前会校验资源并备份原文件；不兼容版本不会强行覆盖。
- 恢复原版时，在 Windows“已安装的应用”中卸载本补丁条目。请勿误卸载原版 Workbench，也不要删除原文件备份。
- 安装和卸载逻辑保留连接配置、SQL 脚本和数据库。本项目不安装 MySQL Server。

## 当前限制

目前包含 1,799 条翻译，部分动态提示和编辑器命令仍为英文。安装程序未签名，属于社区预览版。Windows 10 和干净系统环境尚未验证；具体范围及已记录证据请参阅[测试报告](docs/TEST_REPORT.txt)。不支持直接用于其他 Workbench 版本。

## 源码与构建

- `locales/`：翻译字典、翻译批次与资源清单。
- `src/`：运行时汉化代码。
- `scripts/`：提取、构建和打包脚本。
- `installer/`：安装、备份和恢复逻辑。
- `tests/`：自动测试与安装生命周期验证。

构建依赖、官方输入文件及命令见[构建说明](docs/BUILD.txt)。检查转换后应用资源的测试需要先生成相应构建产物。

## 许可与归属

新增汉化代码采用 GPL-2.0-only 许可。上游软件及第三方组件的许可和分发说明见 [LICENSE.txt](LICENSE.txt) 与[源码及许可说明](docs/SOURCE-LICENSE-NOTICE.txt)。Oracle 和 MySQL 名称仅用于指明适配产品，不表示官方认可或支持。
