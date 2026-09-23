`timescale 1ns/1ps
module tb_bram_wrapper_protocol;
  reg clk=0, resetn=0;
  always #5 clk=~clk;
  reg [15:0] awaddr=0, araddr=0;
  reg [31:0] wdata=0;
  reg [3:0] wstrb=0;
  reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
  wire awready,wready,bvalid,arready,rvalid,irq;
  wire [1:0] bresp,rresp;
  wire [31:0] rdata;
  reg [31:0] value,expected,mask;
  integer i,j,bank;
  mlkem_polymul_axi_wrapper dut(
    .s_axi_aclk(clk),.s_axi_aresetn(resetn),
    .s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
    .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
    .s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_bresp(bresp),
    .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
    .s_axi_rdata(rdata),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.s_axi_rresp(rresp),.interrupt(irq));
  task automatic address_write(input [15:0] addr);
    @(negedge clk); awaddr=addr; awvalid=1;
    do @(posedge clk); while(!awready);
    @(negedge clk); awvalid=0;
  endtask
  task automatic data_write(input [31:0] data,input [3:0] strb);
    @(negedge clk); wdata=data; wstrb=strb; wvalid=1;
    do @(posedge clk); while(!wready);
    @(negedge clk); wvalid=0;
  endtask
  task automatic wr(input [15:0] addr,input [31:0] data,input [3:0] strb,input integer order);
    if(order==0) begin address_write(addr); repeat(3) @(negedge clk); data_write(data,strb); end
    else if(order==1) begin data_write(data,strb); repeat(3) @(negedge clk); address_write(addr); end
    else fork address_write(addr); data_write(data,strb); join
    wait(bvalid);
    repeat(3) begin @(negedge clk); if(!bvalid || bresp!=0) $fatal(1,"B response lost under backpressure"); end
    bready=1; @(posedge clk); @(negedge clk); bready=0;
  endtask
  task automatic rd(input [15:0] addr,output [31:0] data);
    @(negedge clk); araddr=addr; arvalid=1;
    do @(posedge clk); while(!arready);
    @(negedge clk); arvalid=0;
    wait(rvalid); @(negedge clk); data=rdata;
    repeat(3) begin @(negedge clk); if(!rvalid || rdata!==data || rresp!=0) $fatal(1,"R response changed under backpressure"); end
    rready=1; @(posedge clk); @(negedge clk); rready=0;
  endtask
  task automatic reset_and_check;
    @(negedge clk); resetn=0;
    repeat(4) @(negedge clk);
    resetn=1;
    for(integer b=0;b<3;b=b+1) for(integer n=0;n<128;n=n+1) begin
      rd(16'h1000+b*512+n*4,value);
      if(value!==0) $fatal(1,"Reset zero check failed bank=%0d word=%0d",b,n);
    end
  endtask
  initial begin
    reset_and_check();
    // Exercise every byte-enable pattern, both banks and boundary words.
    for(bank=0;bank<2;bank=bank+1) for(i=0;i<16;i=i+1) begin
      wr(16'h1000+bank*512+(i%2)*508,32'h12345678,15,i%3);
      wr(16'h1000+bank*512+(i%2)*508,32'habcdef90,i[3:0],(i+1)%3);
      mask=0;
      for(j=0;j<4;j=j+1) if(i & (1<<j)) mask=mask | (32'hff << (8*j));
      expected=(32'h12345678 & ~mask) | (32'habcdef90 & mask);
      rd(16'h1000+bank*512+(i%2)*508,value);
      if(value!==expected) $fatal(1,"Byte-enable mismatch");
    end
    // Simultaneous CPU read and write must serialize without losing either.
    fork
      wr(16'h1000,32'h00420021,15,0);
      begin rd(16'h1200,value); end
    join
    rd(16'h1000,value); if(value!==32'h00420021) $fatal(1,"Concurrent channels lost write");
    reset_and_check();
    wr(16'h11fc,32'h00010000,15,0); // a=x^255
    wr(16'h1200,32'h00010000,15,1); // b=x
    wr(0,1,1,2);
    if(!dut.busy) $fatal(1,"Core did not start");
    wr(16'h1000,32'hffffffff,15,0); // busy write must be rejected
    wr(0,1,1,1); // duplicate start must not restart the core
    rd(0,value); if(!value[4]) $fatal(1,"Busy access error missing");
    // Memory read may wait for done, but must not steal HLS RAM ports.
    rd(16'h1400,value); if(value!==3328) $fatal(1,"x^255*x coefficient zero mismatch");
    rd(4,value); if(value!==4789) $fatal(1,"Core cycle count changed: %0d",value);
    for(i=1;i<128;i=i+1) begin
      rd(16'h1400+i*4,value); if(value!==0) $fatal(1,"Impulse output mismatch word=%0d",i);
    end
    // Repeat without reset to exercise port ownership across transactions.
    wr(0,7,1,2);
    rd(16'h1400,value); if(value!==3328) $fatal(1,"Repeated execution failed");
    reset_and_check();
    $display("BRAM PROTOCOL PASS: reset, 16 byte masks, split AW/W, backpressure, busy access, repeat, impulse");
    $finish;
  end
  initial begin #3000000; $fatal(1,"Protocol timeout"); end
endmodule
