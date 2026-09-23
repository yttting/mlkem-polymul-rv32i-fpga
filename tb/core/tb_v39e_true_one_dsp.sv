`timescale 1ns/1ps

module tb_v39e_true_one_dsp;
  reg ap_clk = 0;
  reg ap_rst = 1;
  reg ap_start = 0;
  wire ap_done, ap_idle, ap_ready;
  wire [7:0] a_address0, a_address1, b_address0, b_address1;
  wire a_ce0, a_ce1, b_ce0, b_ce1;
  reg [15:0] a_q0 = 0, a_q1 = 0, b_q0 = 0, b_q1 = 0;
  wire [7:0] output_r_address0;
  wire output_r_ce0, output_r_we0;
  wire [15:0] output_r_d0;

  reg [15:0] mem_a [0:255];
  reg [15:0] mem_b [0:255];
  reg [15:0] mem_out [0:255];
  reg signed [63:0] accum [0:255];
  integer expected [0:255];
  integer i, j, cycles, errors, total_errors;
  reg [31:0] random_state;

  always #5 ap_clk = ~ap_clk;

  always @(posedge ap_clk) begin
    if (a_ce0) a_q0 <= mem_a[a_address0];
    if (a_ce1) a_q1 <= mem_a[a_address1];
    if (b_ce0) b_q0 <= mem_b[b_address0];
    if (b_ce1) b_q1 <= mem_b[b_address1];
    if (output_r_ce0 && output_r_we0)
      mem_out[output_r_address0] <= output_r_d0;
  end

  mlkem_poly_mul256_v39e_true_one_dsp dut (
    .ap_clk(ap_clk), .ap_rst(ap_rst), .ap_start(ap_start),
    .ap_done(ap_done), .ap_idle(ap_idle), .ap_ready(ap_ready),
    .a_address0(a_address0), .a_ce0(a_ce0), .a_q0(a_q0),
    .a_address1(a_address1), .a_ce1(a_ce1), .a_q1(a_q1),
    .b_address0(b_address0), .b_ce0(b_ce0), .b_q0(b_q0),
    .b_address1(b_address1), .b_ce1(b_ce1), .b_q1(b_q1),
    .output_r_address0(output_r_address0), .output_r_ce0(output_r_ce0),
    .output_r_we0(output_r_we0), .output_r_d0(output_r_d0)
  );

  task automatic compute_oracle;
    reg signed [63:0] product;
    integer index;
    begin
      for (i = 0; i < 256; i = i + 1) accum[i] = 0;
      for (i = 0; i < 256; i = i + 1)
        for (j = 0; j < 256; j = j + 1) begin
          product = $signed({1'b0,mem_a[i]}) * $signed({1'b0,mem_b[j]});
          index = i + j;
          if (index < 256) accum[index] = accum[index] + product;
          else accum[index-256] = accum[index-256] - product;
        end
      for (i = 0; i < 256; i = i + 1) begin
        expected[i] = accum[i] % 3329;
        if (expected[i] < 0) expected[i] = expected[i] + 3329;
      end
    end
  endtask

  task automatic run_case(input [8*40-1:0] case_name);
    begin
      compute_oracle();
      for (i = 0; i < 256; i = i + 1) mem_out[i] = 16'hdead;
      repeat (2) @(posedge ap_clk);
      ap_start <= 1;
      @(posedge ap_clk);
      ap_start <= 0;
    cycles = 0;
    while (!ap_done && cycles < 10000) begin
      @(posedge ap_clk);
      cycles = cycles + 1;
    end
    if (!ap_done) begin
        $display("V39-E RTL FAIL [%0s]: timeout after %0d cycles", case_name, cycles);
      $finish;
    end
    @(posedge ap_clk);
    #1;
    errors = 0;
    for (i = 0; i < 256; i = i + 1) begin
        if (mem_out[i] !== expected[i][15:0]) begin
        if (errors < 8)
            $display("V39-E RTL mismatch [%0s] i=%0d actual=%0d expected=%0d",
                     case_name, i, mem_out[i], expected[i]);
        errors = errors + 1;
      end
    end
    if (errors == 0)
        $display("V39-E RTL PASS [%0s]: latency=%0d cycles", case_name, cycles);
    else
        $display("V39-E RTL FAIL [%0s]: mismatches=%0d latency=%0d", case_name, errors, cycles);
      total_errors = total_errors + errors;
    end
  endtask

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      mem_a[i] = 0;
      mem_b[i] = 0;
      mem_out[i] = 16'hdead;
    end
    repeat (5) @(posedge ap_clk);
    ap_rst <= 0;
    total_errors = 0;

    mem_a[255] = 1;
    mem_b[1] = 1;
    run_case("ring boundary x255*x");

    for (i = 0; i < 256; i = i + 1) begin
      mem_a[i] = (17*i*i + 31*i + 7) % 3329;
      mem_b[i] = (29*i*i + 11*i + 19) % 3329;
    end
    run_case("deterministic dense");

    random_state = 32'hc0dec0de;
    for (i = 0; i < 256; i = i + 1) begin
      random_state = random_state * 32'd1664525 + 32'd1013904223;
      mem_a[i] = random_state % 3329;
      random_state = random_state * 32'd1664525 + 32'd1013904223;
      mem_b[i] = random_state % 3329;
    end
    run_case("deterministic random");

    if (total_errors == 0)
      $display("V39-E MANUAL RTL COSIM PASS: all 3 transactions");
    else
      $display("V39-E MANUAL RTL COSIM FAIL: total mismatches=%0d", total_errors);
    $finish;
  end
endmodule
