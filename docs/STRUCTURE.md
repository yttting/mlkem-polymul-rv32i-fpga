# 目录与维护规则

工程按硬件、固件、验证和工具入口组织。Vivado 工程位于 `vivado/project/`，烧录产物位于 `release/`；工具缓存与构建报告独立于主线源文件。

```text
mlkem-polymul-rv32i-fpga/
├── rtl/
│   ├── accelerator/       HLS 生成的 Verilog 与 ROM 数据，整体维护
│   ├── axi/               AXI4-Lite wrapper 与系数双口 RAM
│   ├── board/             PYNQ-Z2 顶层、时钟、复位、LED 与 VIO 连接
│   ├── cpu/               PicoRV32
│   └── system/            CPU、固件 RAM、总线、加速器与监测寄存器
├── constraints/           两份板级 XDC
├── hls/
│   ├── src/               HLS C++ 算法及支持代码
│   ├── tb/                独立 C 算术测试
│   └── hls_config.cfg     器件、时钟、顶层及文件配置
├── firmware/
│   ├── src/               transfer 固件
│   ├── include/           expected_words.h
│   ├── linker/            link.ld
│   └── images/            四种原始 transfer_*.mem 镜像
├── tb/
│   ├── core/              加速核独立 RTL 测试
│   ├── board/             无 VIO 与带 VIO 的板级测试
│   ├── protocol/          AXI/BRAM wrapper 协议测试
│   └── monitors/          核心周期监测器
├── vivado/
│   ├── project.tcl        统一器件、源文件、约束、IP 与仿真集配置
│   └── project/           完整工程，跟踪 .xpr 与 VIO .xci
├── scripts/
│   ├── run.tcl            创建工程、仿真与实现入口
│   ├── build_memory_transfer_compare.ps1
│   ├── verify_sources.ps1 / update_release_checksums.ps1
│   ├── program_board.tcl  显式 JTAG 烧录入口
│   └── read_board_vio.tcl  只读状态采集
├── docs/                  使用说明、结构图、验证记录与源码哈希清单
├── release/               纳入 Git 的 BIT 与匹配 LTX 烧录文件
└── build/                 本地生成目录，Git 忽略
    ├── reports/           资源、时序与 DRC 报告
    ├── firmware/          ELF、BIN、MEM、反汇编与布局报告
    ├── hls_csim/          HLS C 仿真输出
    ├── hls_synthesis/     可选 HLS 综合输出
    └── hardware/          VIO 读回快照
```

## 源码一致性

- 保留原有 HDL、HLS、固件、TB、初始化数据和板级约束内容。源码模块名及文件名不随目录整理改名。
- `rtl/accelerator/` 的 Verilog 和 `.dat` 属于同一生成快照，应整体保留。ROM 和固件采用文件名初始化，工程配置负责将其加入 Vivado 的源文件集合。
- `v39e` 等原有名称涉及模块层次与监测器引用，保留这些名称可避免改变设计连接关系。
- 默认板级镜像始终为 `transfer_both_unroll4.mem`。其他三种 transfer 镜像保留用于复现与比较，不自动替换默认镜像。
- `vivado/project.tcl` 是工程配置入口；需要调整源文件路径时先修改 Tcl，再重新生成本地工程。

## 保留范围

保留最终板级实现、HLS 源码、transfer 固件、四类必要仿真、板级约束及构建/烧录工具。旧 register wrapper 实验、软件基线、输入准备对比、历史 OOC 约束和归档报告不属于当前维护目录；其历史版本仍可通过 Git 查询。

版本库同时保存重建工程的输入、可直接打开的 `.xpr`、VIO `.xci` 和烧录文件。本机保留完整生成的工程树；`.cache`、`.runs`、`.sim` 等可生成内容不提交。

`docs/source_integrity.csv` 记录本次整理保留的 52 个代码、ROM、固件及 XDC 文件的 SHA-256，便于与整理前版本核对内容一致性。
