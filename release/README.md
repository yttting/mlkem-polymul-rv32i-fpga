# PYNQ-Z2 烧录文件

本目录保存 2026-09-22 使用 Vivado 2024.2（Build 5239630）生成的同一套产物：

- `mlkem_pynqz2.bit`：`xc7z020clg400-1`、100 MHz、BRAM wrapper、只读 VIO。
- `mlkem_pynqz2.ltx`：与上述 BIT 匹配的调试探针配置。
- `SHA256SUMS`：上述两个文件的 SHA256。

固件为 `firmware/images/transfer_both_unroll4.mem`，已初始化在 bitstream 的程序 RAM 中，不需要再下载 ELF。使用 JTAG Hardware Manager 同时选择 BIT/LTX，或从仓库根目录运行 `vivado -mode batch -source scripts/program_board.tcl`。这是易失性的 PL 配置，不是 SD 卡启动镜像；没有创建 BOOT.BIN 或添加 PS 设计。

构建已通过四组 RTL 仿真、综合和布局布线。WNS=+1.027 ns，WHS=+0.023 ns；没有 DRC Error，保留的 Warning 及验证范围见 [验证记录](../docs/VALIDATION.md)。本次未对实体开发板烧录。自检成功时 `LED[3:0]=0101`，BTN0 可复位重跑。

重新构建：`vivado -mode batch -source scripts/run.tcl -tclargs implement`，然后运行 `./scripts/update_release_checksums.ps1` 更新校验文件。替换产物时应同时提交 BIT、LTX 和校验文件。
