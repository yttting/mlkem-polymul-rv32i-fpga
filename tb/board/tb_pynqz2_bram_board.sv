`timescale 1ns/1ps
module tb_pynqz2_bram_board;
  reg sys_clk=0, btn0=1;
  wire [3:0] led;
  always #4 sys_clk=~sys_clk;
  mlkem_polymul_pynqz2_top dut(.sys_clk(sys_clk),.btn0(btn0),.led(led));
  initial begin
    #2000; btn0=0;
    wait(led[0] || led[1] || led[3]);
    if(led!==4'b0101) $fatal(1,"Board startup failed: LED=%b",led);
    if(dut.system_i.debug_regs[7]!==13952 || dut.system_i.debug_regs[8]!==4789)
      $fatal(1,"Board cycle count mismatch");
    #100; btn0=1; #1000;
    if(led!==0) $fatal(1,"Button reset failed");
    btn0=0;
    wait(led[0] || led[1] || led[3]);
    if(led!==4'b0101) $fatal(1,"Board restart failed");
    $display("PYNQZ2 BOARD SIM PASS: LED=0101, call=13952 core=4789, button restart verified");
    $finish;
  end
  initial begin #2000000; $fatal(1,"Board simulation timeout"); end
endmodule
