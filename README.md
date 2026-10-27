# hackios-k90-build

REDMI K90 (annibale / SM8750) 的 HackiOS 构建流水线。

用 GitHub Actions (ubuntu-24.04, x86_64) 编译上游 [iola1999/hackios-redmi-k90-annibale](https://github.com/iola1999/hackios-redmi-k90-annibale) 的产物。

## 为什么用 Actions

上游构建需要 theos 的 x86_64 版 ld64，在 aarch64 设备上只能靠 qemu 模拟（慢 5-20 倍）。
Actions runner 原生 x86_64，且与 GitHub/Apple CDN 同机房，下载快。

## 触发

Actions -> build-k90-ios -> Run workflow -> 选 stage：

| stage | 说明 |
|---|---|
| `kernel` | 只编 XNU 内核（约 40-60 分钟，产物 19MB） |
| `userland` | 只构建 userland 与 APFS 系统盘（需下载 7.4GB IPSW） |
| `all` | 全跑 |

## 产物

- `kernel-mach-bcm2837` — XNU 内核
- `userland-apfs` — iOS 系统盘

## 注意

本仓库只跑构建，不含 Apple 任何文件。IPSW 由上游脚本从 Apple CDN 实时下载到 runner。
