`timescale 1ns/1ps
`define CORE dut.system_i.accel.core
`define BATCH dut.system_i.accel.core.grp_batch39d_fu_172
module tb_pynqz2_profile_vio;
  reg sys_clk=0, btn0=1;
  wire [3:0] led;
  integer trial, i, j, index;
  integer a[0:255], b[0:255], expected[0:255];
  reg signed [63:0] acc[0:255];
  reg signed [63:0] product;
  reg [255:0] seen=0;
  integer output_count=0;
  always #4 sys_clk=~sys_clk;
  mlkem_polymul_pynqz2_top #(.ENABLE_VIO(1)) dut(.sys_clk(sys_clk),.btn0(btn0),.led(led));
  mlkem_core_cycle_observer observer(
    .clk(dut.clk100),.resetn(dut.reset_sync[3]),.busy(dut.system_i.accel.busy),
    .reported_cycles(dut.system_i.accel.cycle_count),.fsm(`CORE.ap_CS_fsm),
    .batch_start(`CORE.grp_batch39d_fu_172_ap_start),.batch_done(`CORE.grp_batch39d_fu_172_ap_done),
    .batch_mode(`BATCH.mode),
    .request_fire(`BATCH.pe39c_U0_rq_read && `BATCH.rq_empty_n),
    .response_fire(`BATCH.write39d_U0_rs_read && `BATCH.rs_empty_n),
    .move_start({`CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_load_i39d_fu_416_ap_start,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_pack39d_fu_403_ap_start,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_save_b39d_fu_397_ap_start,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_load_b39d_fu_390_ap_start,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_save_a39d_fu_384_ap_start,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_load_a39d_fu_376_ap_start}),
    .move_done({`CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_load_i39d_fu_416_ap_done,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_pack39d_fu_403_ap_done,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_save_b39d_fu_397_ap_done,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_load_b39d_fu_390_ap_done,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_save_a39d_fu_384_ap_done,
      `CORE.grp_mlkem_poly_mul256_v39e_true_one_dsp_Pipeline_load_a39d_fu_376_ap_done})
  );
  always @(posedge dut.clk100) begin
    if(!dut.reset_sync[3]) begin seen=0; output_count=0; end
    else if(`CORE.output_r_ce0 && `CORE.output_r_we0) begin
      if(seen[`CORE.output_r_address0]) $fatal(1,"Duplicate output address");
      if(`CORE.output_r_d0 !== expected[`CORE.output_r_address0]) $fatal(1,"Independent convolution mismatch");
      seen[`CORE.output_r_address0]=1; output_count=output_count+1;
    end
  end
  initial begin
    for(i=0;i<256;i=i+1) begin
      a[i]=(17*i*i+31*i+7)%3329; b[i]=(29*i*i+11*i+19)%3329; acc[i]=0;
    end
    for(i=0;i<256;i=i+1) for(j=0;j<256;j=j+1) begin
      product=a[i]*b[j]; index=i+j;
      if(index<256) acc[index]=acc[index]+product;
      else acc[index-256]=acc[index-256]-product;
    end
    for(i=0;i<256;i=i+1) begin expected[i]=acc[i]%3329; if(expected[i]<0) expected[i]=expected[i]+3329; end
    for(trial=1;trial<=3;trial=trial+1) begin
      btn0=1; #2000; btn0=0;
      wait(led[0] || led[1] || led[3]);
      @(negedge dut.clk100);
      if(led!==4'b0101 || output_count!=256 || seen!=={256{1'b1}}) $fatal(1,"Board result failed");
      for(i=0;i<12;i=i+1)
        if(dut.profile_words[32*i+:32]!==dut.system_i.debug_regs[i]) $fatal(1,"Probe export mismatch");
      if(dut.debug_view.profile_vio.probe_in0!==32'h600d600d ||
         dut.debug_view.profile_vio.probe_in7!==13952 ||
         dut.debug_view.profile_vio.probe_in8!==4789 ||
         dut.debug_view.profile_vio.probe_in12!==2'b01) $fatal(1,"VIO input mismatch");
      if(dut.system_i.debug_regs[1]!==0 || dut.system_i.debug_regs[2]!==3 ||
         dut.system_i.debug_regs[3]!==5873 || dut.system_i.debug_regs[4]!==19 ||
         dut.system_i.debug_regs[5]!==4827 || dut.system_i.debug_regs[6]!==3233 ||
         dut.system_i.debug_regs[9]!==185 || dut.system_i.debug_regs[10]!==13952 ||
         dut.system_i.debug_regs[11]!==4) $fatal(1,"Profile regression");
      $display("BOARD VIO TRIAL PASS trial=%0d status=600d600d call=13952 core=4789 oracle_words=256",trial);
      #100;
    end
    $display("BOARD VIO SIM PASS: 3 resets, independent oracle, profile export and VIO inputs verified");
    $finish;
  end
  initial begin #3000000; $fatal(1,"Board VIO simulation timeout"); end
endmodule
`undef CORE
`undef BATCH
