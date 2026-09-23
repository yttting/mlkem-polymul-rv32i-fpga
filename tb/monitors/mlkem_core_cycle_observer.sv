`timescale 1ns/1ps
// Simulation-only observer. Counts exactly the wrapper's busy clock edges.
module mlkem_core_cycle_observer(
  input wire clk, resetn, busy,
  input wire [31:0] reported_cycles,
  input wire [65:0] fsm,
  input wire batch_start, batch_done,
  input wire [31:0] batch_mode,
  input wire request_fire, response_fire,
  input wire [5:0] move_start, move_done
);
  integer total, batch_count, batch_ticks, batch_tokens, batch_results;
  integer first_request, last_request, request_gaps;
  integer hist[0:65], phase[0:4], moves[0:5];
  integer tick, batch_begin, category, k, state_index, accounted;
  integer operations, overlap, other, move_only[0:5];
  reg batch_on_edge;
  reg previous_busy, batch_active;
  reg [5:0] move_active;
  always @(posedge clk) begin
    if (!resetn) begin
      total=0; batch_count=0; tick=0; previous_busy=0; batch_active=0; move_active=0;
      for(k=0;k<66;k=k+1) hist[k]=0;
      for(k=0;k<5;k=k+1) phase[k]=0;
      for(k=0;k<6;k=k+1) moves[k]=0;
      for(k=0;k<6;k=k+1) move_only[k]=0;
      overlap=0; other=0;
    end else begin
      tick=tick+1;
      if (busy) begin
        operations=0;
        total=total+1;
        state_index=-1;
        for(k=0;k<66;k=k+1) if(fsm[k]) begin
          if(state_index!=-1) $fatal(1,"CORE OBSERVER: FSM not one-hot");
          state_index=k;
        end
        if(state_index<0) $fatal(1,"CORE OBSERVER: missing FSM state");
        hist[state_index]=hist[state_index]+1;
        if(batch_start && !batch_active) begin
          batch_active=1; batch_count=batch_count+1; batch_begin=tick;
          batch_tokens=0; batch_results=0; first_request=-1; last_request=-1; request_gaps=0;
          if(batch_count<=7) category=0;
          else if(batch_count<=14) category=1;
          else if(batch_count<=19) category=2;
          else if(batch_count<=26) category=3;
          else category=4;
        end
        batch_on_edge=batch_active;
        if(batch_active) begin
          operations=operations+1;
          phase[category]=phase[category]+1;
          if(request_fire) begin
            batch_tokens=batch_tokens+1;
            if(first_request<0) first_request=tick;
            if(last_request>=0) request_gaps=request_gaps+tick-last_request-1;
            last_request=tick;
          end
          if(response_fire) batch_results=batch_results+1;
          if(batch_done) begin
            batch_ticks=tick-batch_begin+1;
            $display("CORE_BATCH index=%0d category=%0d mode=%0d cycles=%0d requests=%0d responses=%0d request_window=%0d request_gaps=%0d head=%0d tail=%0d",
              batch_count,category,batch_mode,batch_ticks,batch_tokens,batch_results,
              last_request-first_request+1,request_gaps,first_request-batch_begin,tick-last_request);
            if(batch_tokens!=128 || batch_results!=128) $fatal(1,"CORE OBSERVER: batch token mismatch");
            batch_active=0;
          end
        end
        for(k=0;k<6;k=k+1) begin
          if(move_start[k]) move_active[k]=1;
          if(move_active[k]) begin
            moves[k]=moves[k]+1;
            operations=operations+1;
            if(!batch_on_edge) move_only[k]=move_only[k]+1;
          end
          if(move_done[k]) move_active[k]=0;
        end
        if(operations==0) other=other+1;
        if(operations>1) overlap=overlap+operations-1;
      end
      if(previous_busy && !busy) begin
        if(total!=reported_cycles || batch_count!=28) $fatal(1,"CORE OBSERVER: total/batch mismatch %0d %0d",total,batch_count);
        accounted=0;
        for(k=0;k<5;k=k+1) begin
          $display("CORE_PHASE category=%0d cycles=%0d",k,phase[k]);
          accounted=accounted+phase[k];
        end
        for(k=0;k<6;k=k+1) begin
          $display("CORE_MOVE index=%0d window=%0d outside_batch=%0d",k,moves[k],move_only[k]);
          accounted=accounted+moves[k];
        end
        for(k=0;k<66;k=k+1) if(hist[k]) $display("CORE_FSM state=%0d cycles=%0d",k+1,hist[k]);
        $display("CORE_ACCOUNT total=%0d window_sum=%0d overlap=%0d other=%0d",total,accounted,overlap,other);
        if(accounted-overlap+other!=total) $fatal(1,"CORE OBSERVER: accounting mismatch");
      end
      previous_busy=busy;
    end
  end
endmodule
