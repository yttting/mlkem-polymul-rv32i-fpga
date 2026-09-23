# ML-KEM PolyMul · PicoRV32 · PYNQ-Z2

本工程在 PYNQ-Z2 的 PL 端运行 PicoRV32 RV32I，通过 AXI4-Lite 和 BRAM 接口驱动 ML-KEM 多项式乘法加速核。目标器件为 `xc7z020clg400-1`，板载 125 MHz 时钟经 MMCM 转为 100 MHz；工程采用纯 RTL，不使用 Zynq PS 或 Block Design。

运算为 `FNTT(A) → FNTT(B) → BaseMul → INTT → FinalScale`，计算环 `Z_3329[x]/(x^256+1)` 中的多项式乘法。这是完整 ML-KEM 算法中的运算模块。

![系统结构](docs/architecture.svg)

## 快速开始

使用 **Vivado 2024.2**，安装 Zynq-7000 器件支持。克隆后可直接打开 [mlkem_pynqz2.xpr](vivado/project/mlkem_pynqz2.xpr)。如需重新生成完整工程，从仓库根目录运行：

```text
vivado -mode batch -source scripts/run.tcl -tclargs project
```

生成的完整工程位于 `vivado/project/`，打开其中的 `mlkem_pynqz2.xpr` 即可使用 GUI。默认顶层为 `mlkem_polymul_pynqz2_top`，启用只读 VIO，固件为 `firmware/images/transfer_both_unroll4.mem`。

```text
vivado -mode batch -source scripts/run.tcl -tclargs vio
vivado -mode batch -source scripts/run.tcl -tclargs implement
```

`vio` 运行板级仿真；`implement` 通过四组仿真后完成综合、布局布线和 bitstream 生成，导出烧录文件至 `release/`、报告至 `build/reports/`。工程创建和实现不会自动烧录开发板。

## 目录

```text
rtl/          CPU、加速核、AXI/BRAM 接口、系统与板级 RTL
constraints/  PYNQ-Z2 引脚、时钟与复位约束
hls/          HLS C++ 源码、独立 C 测试与配置
firmware/     固件源码、链接脚本和四种预编译 transfer 镜像
tb/           核心、板级、协议测试与周期监测器
vivado/       Vivado 工程共享配置、完整工程与 VIO IP 配置
scripts/      工程创建、仿真、实现、固件编译与 JTAG 烧录入口
docs/         构建说明、目录职责与本次验证记录
release/      已验证构建的 BIT 与匹配 LTX 烧录文件
build/        本地编译结果与报告（Git 忽略）
```

- [构建、仿真与烧录](docs/BUILD.md)
- [目录与维护规则](docs/STRUCTURE.md)
- [验证记录](docs/VALIDATION.md)
- [保留源码哈希清单](docs/source_integrity.csv)
- [第三方组件说明](THIRD_PARTY_NOTICES.md)

版本库包含 `.xpr`、VIO `.xci` 和 `release/` 烧录文件。仿真、综合、实现缓存保留在本地，并由 Git 忽略。

本次整理保留功能源码、测试代码和预编译镜像的原始内容；仅调整组织方式和构建路径。`rtl/accelerator/` 是原有 Vitis HLS 2025.2 生成的 RTL，本工程使用 Vivado 2024.2 构建该快照，并未用 HLS 2024.2 重新生成或证明两版 HLS 输出等价。
