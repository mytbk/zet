`timescale 1ns/100ps

module flash_prom_zet_cntrlr (
    output            NF_WE,
    output            NF_CE,
    output            NF_OE,
    output            NF_BYTE,
    output reg [21:1] NF_A,
    input      [15:0] NF_D,

    input         cpu_clk,
    input         sys_clk,
    input         reset,
    input  [16:0] addr,
    input         byte_m,
    output [15:0] rd_data,
    input         enable,
    output        ready
  );

  // Net and register declarations
  wire [15:0] addr0, addr1;
  wire [20:0] nf_addr0, nf_addr1;
  reg  [15:0] word0;
  reg  [15:0] word1;
  wire [7:0]  byte_l0, byte_l1, byte_h0, byte_h1;
  wire        a0;
  wire        sec_wrd;
  reg         old_clk, start_cmd;
  reg  [3:0]  state, next_state;
  reg         eff_ready;

  parameter   word0_st = 4'd0;
  parameter   wait1    = 4'd1;
  parameter   wait2    = 4'd2;
  parameter   wait3    = 4'd3;
  parameter   word1_st = 4'd4;
  parameter   wait4    = 4'd5;
  parameter   wait5    = 4'd6;
  parameter   wait6    = 4'd7;
  parameter   rd_word1 = 4'd8;
  parameter   rd_done  = 4'd9;

  // Assignments
  assign addr0   = addr[16:1];
  assign addr1   = addr0 + 16'd1;
  assign nf_addr0 = {5'b0, addr0};
  assign nf_addr1 = {5'b0, addr1};
  assign a0      = addr[0];

  assign byte_l0 = word0[7:0];
  assign byte_h0 = word0[15:8];
  assign byte_l1 = word1[7:0];
  assign byte_h1 = word1[15:8];

  assign rd_data = byte_m ? ( a0 ? { {8{byte_h0[7]}}, byte_h0 } 
                                  : { {8{byte_l0[7]}}, byte_l0 } ) 
                           : ( a0 ? { byte_l1, byte_h0 } : word0 );

  assign ready   = (next_state==rd_done) || !enable;
  assign sec_wrd = (!byte_m && a0);

  assign NF_BYTE = 1'b1;
  assign NF_WE   = 1'b1;
  assign NF_CE   = 1'b0;
  assign NF_OE   = 1'b0;

  // Read sequence
  always @(state)
    if (reset) next_state <= rd_done; 
    else
      case (state)
        word0_st: 
          begin 
            NF_A <= nf_addr0; 
            next_state <= wait1; 
          end
        wait1:    next_state <= wait2;
        wait2:    next_state <= wait3;
        wait3:    next_state <= word1_st;
        word1_st: 
          begin
            word0 <= NF_D;
            NF_A <= nf_addr1; 
            next_state <= sec_wrd ? wait4 : rd_done; 
          end
        wait4:    next_state <= wait5;
        wait5:    next_state <= wait6;
        wait6:    next_state <= rd_word1;
        rd_word1: begin word1 <= NF_D; next_state <= rd_done; end
        default: next_state <= word0_st;
      endcase

  always @(posedge sys_clk)
    if (reset) state <= rd_word1;
    else begin
      if (start_cmd) state <= word0_st;
      else state <= (next_state==rd_done) ? state : next_state;
    end

  // start_cmd signal
  always @(negedge sys_clk)
    if (reset)
      begin
        old_clk <= cpu_clk;
        start_cmd <= 1'b0;
      end
    else
      begin
        if (cpu_clk && !old_clk && eff_ready && enable) start_cmd <= 1'b1;
        else start_cmd <= 1'b0;
        old_clk = cpu_clk;
      end
   
  always @(posedge cpu_clk) eff_ready <= ready;
endmodule