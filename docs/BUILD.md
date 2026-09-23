# 构建、仿真与烧录

## 环境

- Vivado 2024.2，包含 Zynq-7000 器件支持；构建脚本会检查版本。
- HLS C 仿真或重新综合时使用 Vitis HLS 2024.2。
- 重新编译固件时需要 PowerShell 和 `riscv64-unknown-elf-gcc` 工具链；使用预编译镜像时不需要 GCC。

除 HLS 命令外，下列命令均从仓库根目录执行。脚本根据自身位置定位源码，不依赖固定安装路径。当前机器的 PowerShell 示例：

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch -source scripts/run.tcl -tclargs project
```

如果已经设置 Vivado 环境，直接使用下文的 `vivado` 命令。

## 创建完整工程

```text
vivado -mode batch -source scripts/run.tcl -tclargs project
```

省略 `-tclargs project` 时同样创建工程。共享配置位于 `vivado/project.tcl`；生成工程位于：

```text
vivado/project/mlkem_pynqz2.xpr
```

该工程包含 RTL、初始化文件、约束、VIO IP 和四个仿真集。可通过 Vivado 的 **Open Project** 打开 `.xpr`，并在 Simulation Sources 中选择仿真集：

| 仿真集 | 顶层 | 用途 |
|---|---|---|
| `sim_1` | `tb_pynqz2_profile_vio` | 默认板级与 VIO 验证 |
| `sim_board` | `tb_pynqz2_bram_board` | 无 VIO 的 LED 与按钮复位验证 |
| `sim_protocol` | `tb_bram_wrapper_protocol` | AXI/BRAM 协议与边界用例 |
| `sim_core` | `tb_v39e_true_one_dsp` | 加速核独立算术验证 |

生成工程引用仓库内的源文件。移动或复制工程时应包含整个仓库；换机器后可重新运行 Tcl 创建工程。Git 保存源文件、Tcl、`.xpr` 和同一工程树中的 VIO `.xci` 配置；完整运行目录保存在本机，缓存、运行数据库和日志由 Git 忽略。

首次打开克隆后的 XPR 时，Vivado 可能提示未找到已忽略的缓存和旧运行记录；IP 输出可由 Vivado 重新生成。Tcl 入口会重建固定目录中的工程配置，请先保存自行修改的工程设置；它不修改 `rtl/`、`hls/`、固件或 TB 源码。

## 仿真

```text
vivado -mode batch -source scripts/run.tcl -tclargs core
vivado -mode batch -source scripts/run.tcl -tclargs protocol
vivado -mode batch -source scripts/run.tcl -tclargs board
vivado -mode batch -source scripts/run.tcl -tclargs vio
```

| 模式 | 检查范围 | 测试通过标记 |
|---|---|---|
| `core` | 三组核心算术测试 | `V39-E MANUAL RTL COSIM PASS` |
| `protocol` | 复位、字节写使能、独立 AW/W、反压、忙时访问及算术边界 | `BRAM PROTOCOL PASS` |
| `board` | 固件自检、LED、按钮重新启动 | `PYNQZ2 BOARD SIM PASS` |
| `vio` | 三次复位、独立 256 系数参考计算、周期计数与 VIO 连接 | `BOARD VIO SIM PASS` |

各模式均根据 Tcl 创建 `vivado/project/` 工程，再选择对应仿真集运行。仿真日志位于 `vivado/project/mlkem_pynqz2.sim/<simset>/behav/xsim/simulate.log`；运行目录由 Git 忽略。周期断言对应仓库原有 RTL 和预编译固件；重新编译固件后，编译器差异可能改变周期数。

## 综合、实现与烧录文件

```text
vivado -mode batch -source scripts/run.tcl -tclargs implement
```

该模式使用 `vivado/project/` 工程，通过 `core`、`protocol`、`board`、`vio` 四组仿真后完成综合、布局布线和 bitstream 生成。匹配的 `mlkem_pynqz2.bit`、`mlkem_pynqz2.ltx` 导出至 `release/` 并纳入 Git；资源、时序、bus-skew 与 DRC 报告保存在 `build/reports/`。完成后执行 `./scripts/update_release_checksums.ps1` 更新产物校验文件。实际结果见 [验证记录](VALIDATION.md)。

连接 PYNQ-Z2 的 JTAG 后，可在 Hardware Manager 中加载同次构建的 BIT/LTX，或显式执行：

```text
vivado -mode batch -source scripts/program_board.tcl
```

**上述烧录命令会配置已连接的开发板。** 它使用 `release/` 的烧录文件；创建工程和实现命令均不会自动调用它。

固件上电后运行自检。`BTN0` 复位并重新启动系统；成功时 `LED[3:0] = 0101`，即 PASS 与 done 置位，error 与 trap 清零。在 GUI Hardware Manager 中连接并加载 BIT/LTX 后，可在 Tcl Console 运行：

```tcl
source scripts/read_board_vio.tcl
```

该脚本读取 VIO 状态并将快照保存至 `build/hardware/`。本次仓库整理未对实体开发板执行烧录或验收。

## 固件

运行 `./scripts/verify_sources.ps1` 可核对本次保留的 52 个源码、约束和初始化文件是否仍与整理前一致。

```powershell
./scripts/build_memory_transfer_compare.ps1 -ToolDir 'YOUR_RISCV_BIN_DIRECTORY'
```

也可通过 `RISCV_TOOLCHAIN_BIN` 环境变量指定工具链。脚本以 RV32I/ILP32、`-O2` 编译 `firmware/src/memory_transfer_compare_firmware.c`，使用 `firmware/linker/link.ld`，检查镜像容量、静态 RAM 布局及是否出现 M 扩展指令。输出位于 `build/firmware/`，不会覆盖 `firmware/images/`。

| 镜像 | 传输循环 |
|---|---|
| `transfer_baseline.mem` | 基线 |
| `transfer_write_unroll4.mem` | 写循环展开四次 |
| `transfer_read_unroll4.mem` | 读循环展开四次 |
| `transfer_both_unroll4.mem` | 读写循环均展开四次，默认镜像 |

使用新编译的默认镜像进行仿真：

```text
vivado -mode batch -source scripts/run.tcl -tclargs vio build/firmware
```

静态 RAM 检查不代表已测量运行时最大栈深度。不要仅因新编译结果导致周期断言失败就修改测试期望值，应先核对工具链与功能结果。

## HLS 源码与 C 仿真

在 Vitis 2024.2 环境中，先进入 `hls/`，使配置中的相对路径正确解析：

```text
vitis-run --mode hls --csim --config hls_config.cfg --work_dir ../build/hls_csim
```

独立 C 测试以直接卷积检查三组输入。主文件包含 `mlkem_poly_mul256_v39e_unified_stream_support.cpp`，不要将该支持文件再作为独立编译单元添加。

如需后续重新综合：

```text
v++ --mode hls --config hls_config.cfg --work_dir ../build/hls_synthesis
```

这些命令不替换 `rtl/accelerator/`。现有加速核 RTL 来自 Vitis HLS 2025.2；C 仿真通过不能证明 HLS 2024.2 重新生成的 RTL 与现有快照等价。更新快照需要单独完成 RTL 仿真、协同仿真及实现验证。
