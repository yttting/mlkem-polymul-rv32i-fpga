# Vivado 2024.2 验证记录

本文件记录目录整理后的实际验证结果，不沿用历史报告作为本次验证结论。

## 环境与范围

- 目标器件：PYNQ-Z2，`xc7z020clg400-1`。
- 验证日期：2026-09-22。
- 构建工具：Vivado 2024.2（Build 5239630）、Vitis HLS 2024.2、随附 RISC-V GCC 13.3.0。
- 板级时钟：输入 125 MHz，PL 工作时钟 100 MHz。
- 默认镜像：`firmware/images/transfer_both_unroll4.mem`。
- 加速核：原有 Vitis HLS 2025.2 生成 RTL，未重新生成。
- 整理范围：目录移动、删除非主线文件、构建入口与文档更新；功能源码和保留的测试/初始化文件内容不变。

## 本次检查

| 检查项 | 状态 | 记录 |
|---|---|---|
| 保留源文件内容一致性 | PASS | 52 项 SHA256 与原提交 `601079b` 完全一致，记录于 `source_integrity.csv` |
| Vivado 2024.2 工程创建 | PASS | 完整工程位于 `vivado/project/`，包含 VIO IP 与四个仿真集 |
| 工程迁移与重复生成 | PASS | 仅导出 Git 待提交文件到新目录，直接打开 XPR、生成 VIO 输出后 62 个工程文件均在新根目录内且存在；再次用 Tcl 重建工程并通过核心仿真 |
| 核心仿真 `core` | PASS | 三组算术测试 |
| 协议仿真 `protocol` | PASS | AXI/BRAM 事务与边界用例 |
| 板级仿真 `board` | PASS | 固件、LED=0101 与按钮复位 |
| 板级 VIO 仿真 `vio` | PASS | 三次复位均通过独立 256 系数参考计算、周期和 VIO 连接检查 |
| 四模式固件重编译 | PASS | RV32I/ILP32、RAM 布局及无 M 指令检查通过；四个镜像逐 word 与原镜像相同 |
| 综合、布局布线、bitstream | PASS | BIT/LTX 位于 `release/`；时序满足约束，DRC 无 Error，存在下述 Warning |
| HLS 2024.2 C 仿真 | PASS | 三组测试通过，`CSim done with 0 errors`；只验证 C 算法，不建立 RTL 等价关系 |
| 实体开发板烧录与验收 | 未执行 | 本次整理未配置实体开发板 |

通过标记、复现命令和各测试覆盖范围见 [BUILD.md](BUILD.md)。后续验证应在本表记录实际结果和失败原因；不能把命令成功退出或 bitstream 文件存在单独视为功能正确及满足时序的证明。

## 本次实现结果

| 指标 | 数值 |
|---|---:|
| 工作时钟 | 100 MHz |
| WNS / WHS / WPWS | +1.027 / +0.023 / +2.000 ns |
| Setup / hold / pulse-width 失败端点 | 0 / 0 / 0 |
| 无时钟寄存器 / 未约束内部端点 | 0 / 0 |
| Bus-skew 最差余量（4 条约束全部通过） | +9.158 ns |
| LUT / FF | 3956 / 5053 |
| DSP48E1 | 1 |
| RAMB36 / RAMB18 | 4 / 5（6.5 BRAM36 等效） |
| 系统 Call / 核心 Core | 13952 / 4789 周期 |

周期结果来自 RTL 仿真。Call 范围为本地 RAM 输入就绪至结果读回，不含输入生成和结果检查；Core 与 Poll 重叠，不能额外加到 Call。实体板结果尚未重新验证。

## 报告与保留警告

资源、时序、DRC、bus-skew 报告位于本机 `build/reports/`。四套仿真的 `simulate.log` 位于 `vivado/project/mlkem_pynqz2.sim/` 对应仿真集；HLS 日志位于 `build/hls_csim/logs/hls_run_csim.log`。这些本地运行记录不加入 Git。

本轮没有通过修改源码或约束消除警告。DRC 共 23 个 Warning，涉及单 DSP 的 MREG 流水建议、调试核 LUT/布线检查，以及纯 PL 设计的 `ZPS7-1`（未实例化 PS7）。时序方法检查另提示异步复位 LUT 和 RAM 优化建议。BTN0 和四个 LED 按原有 XDC 设置时序例外。固件链接的 RWX 段警告符合原统一程序/数据 RAM 布局；HLS 编译还报告 AMD `gmp.h` 宏重定义。上述信息保留供后续维护，本次不改变设计实现。

VIO 有 13 个输入端口；生成 LTX 将最后一个两位端口拆为 `done`、`trap`，共 14 个探针条目，与现有读回脚本一致。
