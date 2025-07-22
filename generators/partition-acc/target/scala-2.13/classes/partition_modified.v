// 合并的Verilog/SystemVerilog文件 - 生成于 Mon May  5 04:33:12 PM UTC 2025
// 包含 ./vsrc 目录及其所有子目录下的模块
// 所有include语句已被删除
// top.v模块已放置在文件开头并重命名为PartitionCore

// =============================================================
// 源文件 [1/特殊处理]: ./vsrc/top.v
// 目录: ./vsrc
// 类型: V 文件 (顶层模块，已从top重命名为PartitionCore)
// =============================================================


//  Function should be instantiated inside a module
//  But you are free to call it from anywhere by its hierarchical name
//
//  To add clogb2 function to your module:
//  `include "clogb2.svh"
//

function integer clogb2;
  input [31:0] depth;

  for( clogb2=0; depth>0; clogb2=clogb2+1 ) begin
    depth = depth >> 1;
  end

endfunction

module PartitionCore #(
    parameter integer CACHE_LINE_SIZE = 128,    // 512 -> 128 [极小化测试]
    parameter integer MAX_TUPLE_LENGTH = 128,   // 512 -> 128 [极小化测试] 
    parameter integer MAX_KEY_LENGTH = 64,      // 256 -> 64  [极小化测试]
    parameter integer LENGTH_W = 8,

    parameter integer TLNUM = 2,                // 8 -> 2 [极小化测试]
    parameter integer KEY_BLOCK_SIZE = 16,      // 32 -> 16 [适配64位key]
    parameter integer TUPLE_BLOCK_SIZE = 32,
    // 2021040906002 % INT_MAX
    parameter integer SEED = 258794175,
    parameter integer HASH_WIDTH = 8,           // 12 -> 8 [减少哈希位宽]
    parameter integer PARALLELISM = 2,          // 8 -> 2 [极小化测试]

    parameter integer TN_W   = $clog2(TLNUM + 1),
    parameter integer BLOCKS = CACHE_LINE_SIZE / TUPLE_BLOCK_SIZE,
    parameter integer FIFO_DEPTH_FOR_BACK_PRESSURE = 8
) (
    input wire clk,
    input wire nrst,
    input wire [HASH_WIDTH-1:0] PARTITION_NUM,

    input wire in_cache_line_valid,
    output wire in_cache_line_ready,
    input wire [CACHE_LINE_SIZE-1:0] in_cache_line,

    input wire in_tuple_length_valid,
    output wire in_tuple_length_ready,
    input wire [LENGTH_W*TLNUM-1:0] in_tuple_length,

    input wire in_key_info_valid,
    output wire in_key_info_ready,
    input wire [LENGTH_W*2*TLNUM-1:0] in_key_info,

    input wire out_ready,
    output logic out_valid,
    output logic [HASH_WIDTH-1:0] out_hash,
    output logic [CACHE_LINE_SIZE-1:0] out_cache_line,
    output logic [LENGTH_W-1:0] out_num,
    output logic [LENGTH_W*TLNUM-1:0] out_lengths,

    output logic error,
    output logic runned,
    output logic finish
);

  logic [CACHE_LINE_SIZE-1:0] ff_cache_line;
  logic ff_cache_line_wr_en, ff_cache_line_rd_en;
  logic ff_cache_line_almost_full;
  logic ff_cache_line_empty;

  assign in_cache_line_ready = ~ff_cache_line_almost_full;
  assign ff_cache_line_wr_en = in_cache_line_valid & in_cache_line_ready;

  fifo #(
    .DATA_WIDTH(CACHE_LINE_SIZE),
    .DEPTH(8)
  ) U_ff_cache_line (
    .clk(clk),
    .nrst(nrst),
    .wr_en(ff_cache_line_wr_en),
    .rd_en(ff_cache_line_rd_en),
    .din(in_cache_line),
    
    .dout(ff_cache_line),
    .full(),
    .empty(ff_cache_line_empty),
    .almost_full(ff_cache_line_almost_full),
    .almost_empty()
  );

  assign ff_cache_line_rd_en = runned & in_cache_line_req;

  logic [TLNUM * LENGTH_W-1:0] ff_tuple_length;
  logic ff_tuple_length_wr_en, ff_tuple_length_rd_en;
  logic ff_tuple_length_almost_full;
  logic ff_tuple_length_empty;

  assign in_tuple_length_ready = ~ff_tuple_length_almost_full;
  assign ff_tuple_length_wr_en = in_tuple_length_valid & in_tuple_length_ready;

  fifo #(
    .DATA_WIDTH(TLNUM * LENGTH_W),
    .DEPTH(8)
  ) U_ff_tuple_length (
    .clk(clk),
    .nrst(nrst),
    .wr_en(ff_tuple_length_wr_en),
    .rd_en(ff_tuple_length_rd_en),
    .din(in_tuple_length),
    .dout(ff_tuple_length),
    .full(),
    .empty(ff_tuple_length_empty),
    .almost_full(ff_tuple_length_almost_full),
    .almost_empty()
  );

  logic [2 * LENGTH_W * TLNUM-1:0] ff_key_info;
  logic ff_key_wr_en, ff_key_rd_en;
  logic ff_key_almost_full;
  logic ff_key_empty;

  assign in_key_info_ready = ~ff_key_almost_full;
  assign ff_key_wr_en = in_key_info_valid & in_key_info_ready;

  fifo #(
    .DATA_WIDTH(2 * LENGTH_W * TLNUM),
    .DEPTH(8)
  ) U_ff_key (
    .clk(clk),
    .nrst(nrst),
    .wr_en(ff_key_wr_en),
    .rd_en(ff_key_rd_en),
    .din(in_key_info),
    .dout(ff_key_info),
    .full(),
    .empty(ff_key_empty),
    .almost_full(ff_key_almost_full),
    .almost_empty()
  );

  wire presum_in_req, presum_in_empty;
  assign ff_tuple_length_rd_en = runned & presum_in_req & ~ff_key_empty & ~ff_tuple_length_empty;
  assign ff_key_rd_en = runned & presum_in_req & ~ff_key_empty & ~ff_tuple_length_empty;
  assign presum_in_empty = ff_tuple_length_empty | ff_key_empty;

  logic presum_in_valid, ff_cache_line_valid;
  always_ff @(posedge clk) begin
    if (~nrst) begin
      presum_in_valid <= 0;
      ff_cache_line_valid <= 0;
    end else begin
      presum_in_valid <= presum_in_req & ~ff_key_empty & ~ff_tuple_length_empty;
      ff_cache_line_valid <= ff_cache_line_rd_en & ~ff_cache_line_empty;
    end
  end

  wire [LENGTH_W-1:0] in_tuple_lengths[TLNUM];
  wire [LENGTH_W-1:0] in_key_offsets  [TLNUM];
  wire [LENGTH_W-1:0] in_key_lengths  [TLNUM];

  generate
    for (genvar i = 0; i < TLNUM; i++) begin : gen_in_data
      assign in_tuple_lengths[i] = ff_tuple_length[(TLNUM-1-i)*LENGTH_W+:LENGTH_W];
      assign in_key_lengths[i]   = ff_key_info[(TLNUM-1-i)*2*LENGTH_W+:LENGTH_W];
      assign in_key_offsets[i]   = ff_key_info[(TLNUM-1-i)*2*LENGTH_W+LENGTH_W+:LENGTH_W];
    end
  endgenerate

  wire pre_sum_out_valid;
  wire [LENGTH_W-1:0] pre_sum_out_num;
  wire [LENGTH_W-1:0] presum_out_tuple_offsets[TLNUM];
  wire [LENGTH_W-1:0] presum_out_tuple_lengths[TLNUM];
  wire [LENGTH_W-1:0] presum_out_key_offsets[TLNUM];
  wire [LENGTH_W-1:0] presum_out_key_lengths[TLNUM];

  presum #(
      .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
      .TLNUM(TLNUM),
      .LENGTH_W(LENGTH_W)
  ) U_presum (
      .clk (clk),
      .nrst(nrst),

      .in_req(presum_in_req),
      .in_empty(presum_in_empty),
      .in_valid(presum_in_valid),
      .in_tuple_lengths(in_tuple_lengths),
      .in_key_offsets(in_key_offsets),
      .in_key_lengths(in_key_lengths),

      .out_ready(splitter_in_ready),
      .out_valid(pre_sum_out_valid),
      .out_num(pre_sum_out_num),
      .out_tuple_offsets(presum_out_tuple_offsets),
      .out_tuple_lengths(presum_out_tuple_lengths),
      .out_key_offsets(presum_out_key_offsets),
      .out_key_lengths(presum_out_key_lengths)
  );


  logic splitter_in_ready;
  logic in_cache_line_req;
  reg splitter_out_valid;
  reg [LENGTH_W-1:0] splitter_out_num;
  reg [MAX_TUPLE_LENGTH-1:0] splitter_out_tuple[TLNUM];
  reg [MAX_KEY_LENGTH-1:0] splitter_out_key[TLNUM];
  reg [LENGTH_W-1:0] splitter_out_tuple_length[TLNUM];
  reg [LENGTH_W-1:0] splitter_out_key_length[TLNUM];

  splitter #(
      .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
      .TLNUM(TLNUM),
      .LENGTH_W(LENGTH_W),
      .MAX_TUPLE_LENGTH(MAX_TUPLE_LENGTH),
      .MAX_KEY_LENGTH(MAX_KEY_LENGTH)
  ) U_splitter (
      .clk (clk),
      .nrst(nrst),

      .in_cache_line_req(in_cache_line_req),
      .in_cache_line_valid(ff_cache_line_valid),
      .in_cache_line(ff_cache_line),

      .in_ready(splitter_in_ready),
      .in_valid(pre_sum_out_valid),
      .in_num(pre_sum_out_num),
      .in_tuple_offsets(presum_out_tuple_offsets),
      .in_tuple_lengths(presum_out_tuple_lengths),
      .in_key_offsets(presum_out_key_offsets),
      .in_key_lengths(presum_out_key_lengths),

      .out_ready(dispatch_in_ready),
      .out_valid(splitter_out_valid),
      .out_num(splitter_out_num),
      .out_tuple(splitter_out_tuple),
      .out_key(splitter_out_key),
      .out_tuple_length(splitter_out_tuple_length),
      .out_key_length(splitter_out_key_length)
  );


  logic dispatch_in_ready;
  logic [PARALLELISM-1:0] w_req;
  logic [MAX_KEY_LENGTH-1:0] dispatch_key[PARALLELISM];
  logic [LENGTH_W-1:0] dispatch_key_length[PARALLELISM];
  logic [MAX_TUPLE_LENGTH-1:0] dispatch_tuple[PARALLELISM];
  logic [LENGTH_W-1:0] dispatch_tuple_length[PARALLELISM];
  logic [LENGTH_W-1:0] dispatch_tuple_num;

  // 任务分发给若干个Hash Function
  task_dispatcher #(
      .TLNUM(TLNUM),
      .PARALLELISM(PARALLELISM),
      .MAX_KEY_LENGTH(MAX_KEY_LENGTH),
      .MAX_TUPLE_LENGTH(MAX_TUPLE_LENGTH),
      .LENGTH_W(LENGTH_W)
  ) U_task_dispatcher (
      .clk(clk),
      .nrst(nrst),
      .in_ready(dispatch_in_ready),
      .splitter_valid(splitter_out_valid),
      .splitter_key(splitter_out_key),
      .splitter_key_length(splitter_out_key_length),
      .splitter_tuple(splitter_out_tuple),
      .splitter_tuple_length(splitter_out_tuple_length),
      .splitter_tuple_num(splitter_out_num),

      .w_full(ff1_full_r),
      // .w_full(ff1_full),
      .w_req(w_req),
      .dispatch_key(dispatch_key),
      .dispatch_key_length(dispatch_key_length),
      .dispatch_tuple(dispatch_tuple),
      .dispatch_tuple_length(dispatch_tuple_length),
      .dispatch_tuple_num(dispatch_tuple_num)
  );

  always_ff @(posedge clk) begin
    if (!nrst)   ff1_full_r <= '1;   
    else         ff1_full_r <= ff1_full;
  end

  logic drain;
  always_ff @(posedge clk) begin
    if (~nrst) begin
      drain  <= 0;
      runned <= 0;
      finish <= 0;
    end else begin
      if (in_cache_line_valid & in_cache_line_ready) begin
        runned <= 1;
      end
      if (runned & ~in_cache_line_valid & ff_cache_line_empty & ~in_tuple_length_valid
       & ff_tuple_length_empty & ~in_key_info_valid & ff_key_empty & ~pre_sum_out_valid & ~splitter_out_valid
          & &ff1_empty & &ff2_empty & ~(|excute_valid)) begin
        drain <= 1;
      end
      if (runned & drain & &wb_finish && &ff2_empty) begin
        finish <= 1;
      end
    end
  end
  logic [PARALLELISM-1:0] ff1_full,ff1_full_r, ff1_empty, excute_valid, wb_finish;

  generate
    for (genvar i = 0; i < PARALLELISM; i++) begin : gen_excute
      assign ff1_full[i] = ff_key_full | ff_tuple_full;
      assign ff1_empty[i] = ff_key_empty | ff_tuple_empty;
      assign excute_valid[i] = ff_key_valid | hash_valid | wc_ff_wr_en;

      logic ff_key_rd_en;
      logic ff_key_empty, ff_key_full;
      logic ff_key_valid;
      logic ff_key_last_block;
      logic [KEY_BLOCK_SIZE-1:0] ff_key_block;

      fifo_width_converter #(
          .IN_DATA_WIDTH(MAX_KEY_LENGTH),
          .OUT_DATA_WIDTH(KEY_BLOCK_SIZE),
          .DEPTH(64)
      ) U_fifo_key (  // <-
          .clk(clk),
          .nrst(nrst),
          .wr_en(w_req[i]),
          .rd_en(~ff_key_empty),
          .din(dispatch_key[i]),
          .in_length(dispatch_key_length[i]),
          .valid(ff_key_valid),
          .dout(ff_key_block),
          .last_block(ff_key_last_block),
          .full(ff_key_full),
          .empty(ff_key_empty),
          .cnt()
      );

      logic ff_tuple_rd_en;
      logic ff_tuple_empty, ff_tuple_full;
      logic [MAX_TUPLE_LENGTH-1:0] ff_tuple;
      logic [LENGTH_W-1:0] ff_tuple_length;

      assign ff_tuple_rd_en = ff_key_last_block & ff_key_valid;

      fifo #(
          .DATA_WIDTH(MAX_TUPLE_LENGTH + LENGTH_W),
          .DEPTH(8)
      ) U_fifo_tuple (
          .clk  (clk),
          .nrst (nrst),
          .wr_en(w_req[i]),
          .rd_en(ff_tuple_rd_en),
          .din  ({dispatch_tuple[i], dispatch_tuple_length[i]}),
          .dout ({ff_tuple, ff_tuple_length}),
          .full (),
          .empty(ff_tuple_empty),
          .almost_full(ff_tuple_full),
          .almost_empty()
      );

      logic hash_valid;
      logic [HASH_WIDTH-1:0] hash;

      murmur_hash #(
          .SEED(SEED),
          .BATCH_SIZE(KEY_BLOCK_SIZE),
          .HASH_WIDTH(HASH_WIDTH)
      ) U_murmur_hash (
          .clk(clk),
          .nrst(nrst),
          .data_in(ff_key_block),
          .valid_in(ff_key_valid),
          .last_data(ff_key_last_block),
          .valid(hash_valid),
          .hash_out(hash)
      );

      /*
        murmur_hash.h_process0 -> write_combiner.fill_rate_r_addr
          |  
          |  murmur_hash:
          |    | h_process0 -...-> hash_out
          |  
          |  murmur_hash.hash_out -( hash % PARTITION_NUM) -> write_combiner.hash_in
          |
          |  write_combiner
          |    | fill_rate_r_addr = drain ? dp_cur : hash_in

      */
      logic hash_valid_r;
      logic [HASH_WIDTH-1:0] hash_r;
      always_ff @(posedge clk) begin
        if (~nrst) begin
          hash_valid_r <= 0;
          hash_r <= '0;
        end else begin
          hash_valid_r <= hash_valid;
          hash_r <= hash;
        end
      end

      logic wc_ff_wr_en;
      logic [HASH_WIDTH-1:0] wc_hash;
      logic [LENGTH_W-1:0] wc_num;
      logic [LENGTH_W-1:0] wc_lengths[TLNUM];
      logic [CACHE_LINE_SIZE-1:0] wc_cache_line;

      write_combiner #(
          .MAX_TUPLE_LENGTH(MAX_TUPLE_LENGTH),
          .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
          .HASH_WIDTH(HASH_WIDTH),
          .BLOCK_SIZE(TUPLE_BLOCK_SIZE),
          .LENGTH_W(LENGTH_W),
          .TLNUM(TLNUM)
      ) U_write_combiner (
          .clk(clk),
          .nrst(nrst),
          .PARTITION_NUM(PARTITION_NUM),
          // .in_valid(hash_valid),
          // .hash_in(hash % PARTITION_NUM),
          .in_valid(hash_valid_r),
          .hash_in(hash_r & (PARTITION_NUM - 1) ),
          .tuple_in(ff_tuple),
          .length_in(ff_tuple_length),
          .drain_in(drain),

          .out_fifo_wr_en(wc_ff_wr_en),
          .hash_out(wc_hash),
          .num_out(wc_num),
          .lengths_out(wc_lengths),
          .cache_line_out(wc_cache_line),

          .finish(wb_finish[i])
      );

      wire [LENGTH_W*TLNUM-1:0] wc_lengths_flatten;
      for (genvar j = 0; j < TLNUM; j++) begin : gen_lengths
        assign wc_lengths_flatten[j*LENGTH_W+:LENGTH_W] = wc_lengths[j];
      end

      // TODO: 输出阶段的反压

      /*
        Design :
          CACHE_LINE_SIZE = 512
          HASH_WIDTH = 12
          LENGTH_W = 8
          TLNUM = 8
        Test :
          CACHE_LINE_SIZE = 256
          HASH_WIDTH = 12
          LENGTH_W = 8
          TLNUM = 4
      */
      fifo #( 
          .DATA_WIDTH(CACHE_LINE_SIZE + HASH_WIDTH + LENGTH_W + LENGTH_W * TLNUM),
          .DEPTH(FIFO_DEPTH_FOR_BACK_PRESSURE)
      ) U_fifo2 (
          .clk  (clk),
          .nrst (nrst),
          .wr_en(wc_ff_wr_en),
          .rd_en(ff2_rd_en[i]),
          .din  ({wc_cache_line, wc_hash, wc_num, wc_lengths_flatten}),
          .dout ({ff2_cache_line[i], ff2_hash[i], ff2_num[i], ff2_lengths[i]}),
          .full (ff2_full[i]),
          .empty(ff2_empty[i]),
          .almost_full(),
          .almost_empty()
      );
    end
  endgenerate

  logic [PARALLELISM-1:0] ff2_rd_en, ff2_empty, ff2_full;
  logic [CACHE_LINE_SIZE-1:0] ff2_cache_line[PARALLELISM];
  logic [HASH_WIDTH-1:0] ff2_hash[PARALLELISM];
  logic [LENGTH_W-1:0] ff2_num[PARALLELISM];
  logic [LENGTH_W*TLNUM-1:0] ff2_lengths[PARALLELISM];

  fifo_combiner #(
      .PARALLEL(PARALLELISM),
      .HASH_WIDTH(HASH_WIDTH),
      .CACHE_LINE_SIZE(CACHE_LINE_SIZE),
      .LENGTH_W(LENGTH_W),
      .TLNUM(TLNUM)
  ) U_fifo_combiner (
      .clk(clk),
      .nrst(nrst),
      .r_empty(ff2_empty),
      .r_req(ff2_rd_en),
      .r_hash(ff2_hash),
      .r_data(ff2_cache_line),
      .r_num(ff2_num),
      .r_lengths(ff2_lengths),

      .w_full(),
      .w_req(out_valid),
      .w_hash(out_hash),
      .w_data(out_cache_line),
      .w_num(out_num),
      .w_lengths(out_lengths)
  );

endmodule


// =============================================================
// 源文件 [1/17]: ./vsrc/include/clogb2.svh
// 目录: ./vsrc/include
// 类型: SVH 文件
// =============================================================

//------------------------------------------------------------------------------
// clogb2.svh
// published as part of https://github.com/pConst/basic_verilog
// Konstantin Pavlov, pavlovconst@gmail.com
//------------------------------------------------------------------------------

// INFO ------------------------------------------------------------------------
//  Calculates counter width based on specified vector/RAM depth
//  see also: http://www.sunburst-design.com/papers/CummingsHDLCON2001_Verilog2001.pdf
//
//  WARNING:
//  ========
//  - clogb2() usage is a quite obsolete technique, left from Verilog-2001 era
//    when system function $clog2() was not supported or was implemented falcely
//
//  - don`t use clogb2() for new designs! Instead:
//
//  - use $clog2(DEPTH) when declaring wr_addr[] pointer, which can refer any
//    RAM element from 0 to DEPTH-1
//
//  - use $clog2(DEPTH+1) to declare counters, which should hold any walue from
//    0 up to the DEPTH (inclusive)
//
//
//  Compared with system function $clog2():
//  =======================================
//  $clog2(0) = 0;   clogb2(0) = 0;
//  $clog2(1) = 0;   clogb2(1) = 1;
//  $clog2(2) = 1;   clogb2(2) = 2;
//  $clog2(3) = 2;   clogb2(3) = 2;
//  $clog2(4) = 2;   clogb2(4) = 3;
//  $clog2(5) = 3;   clogb2(5) = 3;
//  $clog2(6) = 3;   clogb2(6) = 3;
//  $clog2(7) = 3;   clogb2(7) = 3;
//  $clog2(8) = 3;   clogb2(8) = 4;
//  $clog2(9) = 4;   clogb2(9) = 4;
//  $clog2(10)= 4;   clogb2(10)= 4;
//  $clog2(11)= 4;   clogb2(11)= 4;
//  $clog2(12)= 4;   clogb2(12)= 4;
//  $clog2(13)= 4;   clogb2(13)= 4;
//  $clog2(14)= 4;   clogb2(14)= 4;
//  $clog2(15)= 4;   clogb2(15)= 4;
//  $clog2(16)= 4;   clogb2(16)= 5;
//




// =============================================================
// 源文件 [2/17]: ./vsrc/template/fifo_single_clock_ram.sv
// 目录: ./vsrc/template
// 类型: SV 文件
// =============================================================

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

//------------------------------------------------------------------------------
// fifo_single_clock_ram.sv
// published as part of https://github.com/pConst/basic_verilog
// Konstantin Pavlov, pavlovconst@gmail.com
//------------------------------------------------------------------------------

// INFO ------------------------------------------------------------------------
//  Single-clock FIFO buffer implementation, also known as "queue"
//
//  This fifo variant should synthesize into block RAM seamlessly, both for
//    Altera and for Xilinx chips. Simulation is also consistent.
//  Use this fifo when you need cross-vendor and sim/synth compatibility.
//
//  Features:
//  - single clock operation
//  - configurable depth and data width
//  - only "normal" mode is supported here, no FWFT mode
//  - protected against overflow and underflow
//  - simultaneous read and write operations supported BUT:
//        only read will happen if simultaneous rw from full fifo
//        only write will happen if simultaneous rw from empty fifo
//        Always honor empty and full flags!
//  - provides fifo contents initialization (!)
//  - CAUTION! block RAMs do NOT support fifo contents REinitialization after reset


/* --- INSTANTIATION TEMPLATE BEGIN ---

fifo_single_clock_ram #(
  .DEPTH( 8 ),
  .DATA_W( 32 ),

  // optional initialization
  .INIT_FILE( "fifo_single_clock_ram_init.mem" ),
  .INIT_CNT( 10 )
) FF1 (
  .clk( clk ),
  .nrst( 1'b1 ),

  .w_req(  ),
  .w_data(  ),

  .r_req(  ),
  .r_data(  ),

  .cnt(  ),
  .empty(  ),
  .full(  )
);

--- INSTANTIATION TEMPLATE END ---*/

module fifo_single_clock_ram #(
    parameter FWFT_MODE = "TRUE",  // "TRUE"  - first word fall-trrough" mode
                                   // "FALSE" - normal fifo mode
    DEPTH = 8,  // max elements count == DEPTH, DEPTH MUST be power of 2
    DEPTH_W = clogb2(DEPTH) + 1,  // elements counter width, extra bit to store
                                  // "fifo full" state, see cnt[] variable comments

    DATA_W = 32,  // data field width

    RAM_STYLE = "",  // "block","register","M10K","logic",...

    // optional initialization
    INIT_FILE = "",  // .HEX or .MEM file to initialize fifo contents
    INIT_CNT  = '0   // sets desired initial cnt[]
) (

    input clk,
    input nrst, // inverted reset

    // input port
    input w_req,
    input [DATA_W-1:0] w_data,

    // output port
    input r_req,
    output [DATA_W-1:0] r_data,

    // helper ports
    output logic [DEPTH_W-1:0] cnt = INIT_CNT[DEPTH_W-1:0],
    output logic empty,
    output logic full,

    output logic fail
);


  // read and write pointers
  logic [DEPTH_W-1:0] w_ptr = INIT_CNT[DEPTH_W-1:0];
  logic [DEPTH_W-1:0] r_ptr = '0;

  // filtered requests
  logic w_req_f;
  assign w_req_f = w_req && ~full;

  logic r_req_f;
  assign r_req_f = r_req && ~empty;


  true_dual_port_write_first_2_clock_ram #(
      .RAM_WIDTH(DATA_W),
      .RAM_DEPTH(DEPTH),
      .RAM_STYLE(RAM_STYLE),  // "block","register","M10K","logic",...
      .INIT_FILE(INIT_FILE)
  ) data_ram (
      .clka (clk),
      .addra(w_ptr[DEPTH_W-1:0]),
      .ena  (w_req_f),
      .wea  (1'b1),
      .dina (w_data[DATA_W-1:0]),
      .douta(),

      .clkb (clk),
      .addrb(r_ptr[DEPTH_W-1:0]),
      .enb  (r_req_f),
      .web  (1'b0),
      .dinb ('0),
      .doutb(r_data[DATA_W-1:0])
  );


  always_ff @(posedge clk) begin
    if (~nrst) begin
      w_ptr[DEPTH_W-1:0] <= INIT_CNT[DEPTH_W-1:0];
      r_ptr[DEPTH_W-1:0] <= '0;

      cnt[DEPTH_W-1:0]   <= INIT_CNT[DEPTH_W-1:0];
    end else begin
      unique case ({
        w_req, r_req
      })
        2'b00: ;  // nothing

        2'b01: begin  // reading out
          if (~empty) begin
            r_ptr[DEPTH_W-1:0] <= inc_ptr(r_ptr[DEPTH_W-1:0]);
            cnt[DEPTH_W-1:0]   <= cnt[DEPTH_W-1:0] - 1'b1;
          end
        end

        2'b10: begin  // writing in
          if (~full) begin
            w_ptr[DEPTH_W-1:0] <= inc_ptr(w_ptr[DEPTH_W-1:0]);
            cnt[DEPTH_W-1:0]   <= cnt[DEPTH_W-1:0] + 1'b1;
          end
        end

        2'b11: begin  // simultaneously reading and writing
          if (empty) begin
            w_ptr[DEPTH_W-1:0] <= inc_ptr(w_ptr[DEPTH_W-1:0]);
            cnt[DEPTH_W-1:0]   <= cnt[DEPTH_W-1:0] + 1'b1;
          end else if (full) begin
            r_ptr[DEPTH_W-1:0] <= inc_ptr(r_ptr[DEPTH_W-1:0]);
            cnt[DEPTH_W-1:0]   <= cnt[DEPTH_W-1:0] - 1'b1;
          end else begin
            w_ptr[DEPTH_W-1:0] <= inc_ptr(w_ptr[DEPTH_W-1:0]);
            r_ptr[DEPTH_W-1:0] <= inc_ptr(r_ptr[DEPTH_W-1:0]);
            //cnt[DEPTH_W-1:0] <=  // data counter does not change here
          end
        end
      endcase
    end
  end

  always_comb begin
    empty = (cnt[DEPTH_W-1:0] == '0);
    full  = (cnt[DEPTH_W-1:0] == DEPTH);

    fail  = (empty && r_req) || (full && w_req);
  end

  function [DEPTH_W-1:0] inc_ptr(input [DEPTH_W-1:0] ptr);
    if (ptr[DEPTH_W-1:0] == DEPTH - 1) begin
      inc_ptr[DEPTH_W-1:0] = '0;
    end else begin
      inc_ptr[DEPTH_W-1:0] = ptr[DEPTH_W-1:0] + 1'b1;
    end
  endfunction


endmodule

/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */


// =============================================================
// 源文件 [3/17]: ./vsrc/template/true_dual_port_write_first_2_clock_ram.sv
// 目录: ./vsrc/template
// 类型: SV 文件
// =============================================================

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

//------------------------------------------------------------------------------
// true_dual_port_write_first_2_clock_ram.sv
// published as part of https://github.com/pConst/basic_verilog
// Konstantin Pavlov, pavlovconst@gmail.com
//------------------------------------------------------------------------------

// INFO ------------------------------------------------------------------------
//  This is originally a Vivado template for block RAM with some minor edits
//  Also tested for Quartus IDE to automatically infer block memories
//


/* --- INSTANTIATION TEMPLATE BEGIN ---

true_dual_port_write_first_2_clock_ram #(
  .RAM_WIDTH( DATA_W ),
  .RAM_DEPTH( DEPTH ),
  .RAM_STYLE( "block" ),  // "block","register","M10K","logic",...
  .INIT_FILE( "init.mem" )
) DR1 (
  .clka( w_clk ),
  .addra( w_ptr[DEPTH_W-1:0] ),
  .ena( w_req ),
  .wea( 1'b1 ),
  .dina( w_data[DATA_W-1:0] ),
  .douta(  ),

  .clkb( r_clk ),
  .addrb( r_ptr[DEPTH_W-1:0] ),
  .enb( r_req ),
  .web( 1'b0 ),
  .dinb( '0 ),
  .doutb( r_data[DATA_W-1:0] )
);

--- INSTANTIATION TEMPLATE END ---*/


module true_dual_port_write_first_2_clock_ram #(
    parameter RAM_WIDTH = 16,
    RAM_DEPTH = 8,

    // optional initialization parameters
    RAM_STYLE = "block",
    INIT_FILE = ""
) (
    input clka,
    input [clogb2(RAM_DEPTH-1)-1:0] addra,
    input ena,
    input wea,
    input [RAM_WIDTH-1:0] dina,
    output [RAM_WIDTH-1:0] douta,

    input clkb,
    input [clogb2(RAM_DEPTH-1)-1:0] addrb,
    input enb,
    input web,
    input [RAM_WIDTH-1:0] dinb,
    output [RAM_WIDTH-1:0] doutb
);

  // Xilinx:
  // ram_style = "{ auto | block | distributed | register | ultra }"
  // "ram_style" is equivalent to "ramstyle" in Vivado

  // Altera:
  // ramstyle = "{ logic | M9K | MLAB }" and other variants

  // ONLY FOR QUARTUS IDE
  // You can provide initialization in convinient .mif format
  //(* ram_init_file = INIT_FILE *) logic [RAM_WIDTH-1:0] data_mem [RAM_DEPTH-1:0];

  (* ramstyle = RAM_STYLE *) logic [RAM_WIDTH-1:0] data_mem[RAM_DEPTH-1:0];


  logic [RAM_WIDTH-1:0] ram_data_a = {RAM_WIDTH{1'b0}};
  logic [RAM_WIDTH-1:0] ram_data_b = {RAM_WIDTH{1'b0}};

  // either initializes the memory values to a specified file or to all zeros
  generate
    if (INIT_FILE != "") begin : use_init_file
      initial $readmemh(INIT_FILE, data_mem, 0, RAM_DEPTH - 1);
    end else begin : init_bram_to_zero
      integer i;
      initial begin
        for (i = 0; i < RAM_DEPTH; i = i + 1) begin
          data_mem[i] = {RAM_WIDTH{1'b0}};
        end
      end
    end
  endgenerate

  always @(posedge clka) begin
    if (ena) begin
      if (wea) begin
        data_mem[addra] <= dina;
        ram_data_a <= dina;
      end else begin
        ram_data_a <= data_mem[addra];
      end
    end
  end

  always @(posedge clkb) begin
    if (enb) begin
      if (web) begin
        data_mem[addrb] <= dinb;
        ram_data_b <= dinb;
      end else begin
        ram_data_b <= data_mem[addrb];
      end
    end
  end

  // no output register
  assign douta = ram_data_a;
  assign doutb = ram_data_b;


endmodule

/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */


// =============================================================
// 源文件 [4/17]: ./vsrc/fifo_combiner.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

module fifo_combiner #(
    parameter integer PARALLEL = 8,
    parameter integer HASH_WIDTH = 8,
    parameter integer LENGTH_W = 8,
    parameter integer CACHE_LINE_SIZE = 512,
    parameter integer TLNUM = 8,

    parameter integer PARALLEL_W = $clog2(PARALLEL)  // input port index width

) (
    input clk,  // clock
    input nrst, // inverted reset

    // input ports
    input [PARALLEL-1:0] r_empty,
    output [PARALLEL-1:0] r_req,
    input [HASH_WIDTH-1:0] r_hash[PARALLEL],
    input [CACHE_LINE_SIZE-1:0] r_data[PARALLEL],
    input [LENGTH_W-1:0] r_num[PARALLEL],
    input [LENGTH_W*TLNUM-1:0] r_lengths[PARALLEL],

    // output port
    input w_full,
    output logic w_req,
    output logic [HASH_WIDTH-1:0] w_hash,
    output logic [CACHE_LINE_SIZE-1:0] w_data,
    output logic [LENGTH_W-1:0] w_num,
    output logic [LENGTH_W*TLNUM-1:0] w_lengths
);

  logic enc_valid;
  logic [PARALLEL-1:0] enc_filt;
  logic [PARALLEL_W-1:0] enc_bin;

  logic [PARALLEL-1:0] r_empty_rev;
  for (genvar i = 0; i < PARALLEL; i++) begin : g_rev
    assign r_empty_rev[i] = r_empty[PARALLEL-1-i];
  end

  round_robin_performance_enc #(
      .WIDTH(PARALLEL)
  ) rr_perf_enc (
      .clk     (clk),
      .nrst    (nrst),
      .id      (~r_empty),
      .od_valid(enc_valid),
      .od_filt (enc_filt),
      .od_bin  (enc_bin)
  );

  logic r_valid;
  assign r_valid = enc_valid && ~w_full;
  assign r_req[PARALLEL-1:0] = {PARALLEL{r_valid}} & enc_filt[PARALLEL-1:0];

  logic r_valid_1d;
  logic [PARALLEL_W-1:0] enc_bin_1d;
  always_ff @(posedge clk) begin
    if (~nrst) begin
      r_valid_1d <= 1'b0;
      enc_bin_1d <= '0;
    end else begin
      r_valid_1d <= r_valid;
      enc_bin_1d <= enc_bin[PARALLEL_W-1:0];
    end
  end

  always_comb begin
    if (~nrst) begin
      w_req  = 1'b0;
      w_hash = '0;
      w_data = '0;
      w_num  = '0;
      w_lengths = '0;
    end else begin
      if (r_valid_1d) begin
        w_req  = 1'b1;
        w_hash = r_hash[enc_bin_1d[PARALLEL_W-1:0]];
        w_data = r_data[enc_bin_1d[PARALLEL_W-1:0]];
        w_num  = r_num[enc_bin_1d[PARALLEL_W-1:0]];
        w_lengths = r_lengths[enc_bin_1d[PARALLEL_W-1:0]];
      end else begin
        w_req  = 1'b0;
        w_hash = '0;
        w_data = '0;
        w_num  = '0;
        w_lengths = '0;
      end
    end
  end

endmodule


// =============================================================
// 源文件 [5/17]: ./vsrc/murmur_hash.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

module murmur_hash #(
    parameter integer SEED = 0,
    parameter integer BATCH_SIZE = 32,
    parameter integer HASH_WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   nrst,
    input  wire  [BATCH_SIZE-1:0] data_in,
    input  wire                   valid_in,
    input  wire                   last_data,
    output logic                  valid,
    output logic [HASH_WIDTH-1:0] hash_out
);

  localparam integer C1 = 32'hCC9E2D51;
  localparam integer C2 = 32'h1B873593;
  localparam integer C3 = 32'hE6546B64;
  localparam integer C4 = 32'h85EBCA6B;
  localparam integer C5 = 32'hC2B2AE35;

  function automatic [31:0] rotl(input logic [31:0] x, input logic [31:0] n);
    return (x << n) | (x >> (32 - n));
  endfunction : rotl

  logic valid_in_1d;
  logic [31:0] h_process0, h_process1;
  logic [31:0] h_final0, h_final1, h_final2, h_final3, h_final4, h_final5;

  logic [31:0] h_final2_r;
  logic        valid_r;   

  assign h_process1 = rotl(h_process0, 13);
  assign h_final0   = (h_process1 << 2) + h_process1 + C3;
  assign h_final1   = h_final0 ^ (h_final0 >> 16);
  assign h_final2   = h_final1 * C4;
  // assign h_final3   = h_final2 ^ (h_final2 >> 13);
  assign h_final3   = h_final2_r ^ (h_final2_r >> 13);
  assign h_final4   = h_final3 * C5;
  assign h_final5   = h_final4 ^ (h_final4 >> 16);
  // assign hash_out   = valid ? h_final5[HASH_WIDTH-1:0] : 0;
  assign hash_out   = valid_r ? h_final5[HASH_WIDTH-1:0] : 0;

  always_ff @(posedge clk) begin
    if (!nrst) begin
      h_final2_r <= 32'd0;
      valid_r    <= 1'b0;
    end else begin
      h_final2_r <= h_final2;
      valid_r    <= valid;
    end
  end

  always_ff @(posedge clk) begin
    if (!nrst) begin
      valid <= 0;
      valid_in_1d <= 0;
    end else begin
      valid_in_1d <= valid_in;
      if (valid_in) begin
        valid <= last_data;
        if (valid | ~valid_in_1d) begin
          h_process0 <= SEED ^ (rotl((data_in * C1), 15) * C2);
        end else begin
          h_process0 <= h_process1 ^ (rotl((data_in * C1), 15) * C2);
        end
      end else begin
        valid <= 0;
      end
    end
  end

endmodule


// =============================================================
// 源文件 [6/17]: ./vsrc/presum.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

module presum #(
    parameter integer CACHE_LINE_SIZE = 512,
    parameter integer TLNUM = 8,
    parameter integer LENGTH_W = 8,

    parameter integer DEPTH = 4 * TLNUM,
    parameter integer TN_W  = $clog2(TLNUM + 1)
) (
    input wire clk,
    input wire nrst,

    output reg in_req,
    input wire in_empty,
    input wire in_valid,
    input wire [LENGTH_W-1:0] in_tuple_lengths[TLNUM],
    input wire [LENGTH_W-1:0] in_key_offsets[TLNUM],
    input wire [LENGTH_W-1:0] in_key_lengths[TLNUM],

    input logic out_ready,
    output logic out_valid,
    output logic [LENGTH_W-1:0] out_num,
    output logic [LENGTH_W-1:0] out_tuple_offsets[TLNUM],
    output logic [LENGTH_W-1:0] out_tuple_lengths[TLNUM],
    output logic [LENGTH_W-1:0] out_key_offsets[TLNUM],
    output logic [LENGTH_W-1:0] out_key_lengths[TLNUM]
);

  localparam integer ADDRW = $clog2(DEPTH);
  localparam integer CacheLineBytes = CACHE_LINE_SIZE / 8;

  reg [LENGTH_W-1:0] reg_tuple_lengths[DEPTH];
  reg [LENGTH_W-1:0] reg_key_offsets  [DEPTH];
  reg [LENGTH_W-1:0] reg_key_lengths  [DEPTH];

  reg [LENGTH_W-1:0] cache_line_idx;

  reg [ADDRW-1:0] wr_ptr, rd_ptr;
  reg [ADDRW-1:0] next_rd_ptr;
  wire [ADDRW-1:0] cnt;

  logic [LENGTH_W-1:0] pre_sum[TLNUM + 1];
  logic [ADDRW-1:0] j;
  logic flag;

  logic valid;
  logic [LENGTH_W-1:0] num;
  logic [LENGTH_W-1:0] tuple_offsets[TLNUM];
  logic [LENGTH_W-1:0] tuple_lengths[TLNUM];
  logic [LENGTH_W-1:0] key_offsets[TLNUM];
  logic [LENGTH_W-1:0] key_lengths[TLNUM];

  always_comb begin
    pre_sum[0] = cache_line_idx;
    j = 0;
    for (int i = 0; (i < TLNUM) & (i[ADDRW-1:0] < cnt); i = i + 1) begin
      j = i[ADDRW-1:0] + rd_ptr;
      pre_sum[i+1] = pre_sum[i] + reg_tuple_lengths[j];
    end
    valid = 0;
    next_rd_ptr = 0;
    num = 0;
    for (int i = 0; (i < TLNUM) & (i[ADDRW-1:0] < cnt); i = i + 1) begin
      j = i[ADDRW-1:0] + rd_ptr;
      if (pre_sum[i+1] >= CacheLineBytes[LENGTH_W-1:0]) begin
        valid = 1;
        next_rd_ptr = j + 1;
        num[ADDRW-1:0] = j - rd_ptr + 1;
        break;
      end
    end

    if (in_empty && ~valid && cnt >0) begin //排空最后一组数据
      num = {{LENGTH_W-ADDRW{1'b0}}, cnt};
      next_rd_ptr = rd_ptr + cnt;
      valid = 1;
    end

    for (int i = 0; i < TLNUM; i = i + 1) begin
      tuple_offsets[i] = pre_sum[i];
      tuple_lengths[i] = i[LENGTH_W-1:0] < num ? reg_tuple_lengths[rd_ptr+i[ADDRW-1:0]] : '0;
      key_offsets[i]   = i[LENGTH_W-1:0] < num ? reg_key_offsets[rd_ptr+i[ADDRW-1:0]] : '0;
      key_lengths[i]   = i[LENGTH_W-1:0] < num ? reg_key_lengths[rd_ptr+i[ADDRW-1:0]] : '0;
    end
  end

  assign cnt = wr_ptr - rd_ptr;
  assign in_req = {{32-ADDRW{1'b0}},cnt} < (DEPTH - 2 * TLNUM);

  always_ff @(posedge clk) begin
    if (~nrst) begin
      for (int i = 0; i < DEPTH; i = i + 1) begin
        reg_tuple_lengths[i] <= '0;
        reg_key_offsets[i]   <= '0;
        reg_key_lengths[i]   <= '0;
      end
      wr_ptr <= 0;
      rd_ptr <= 0;
    end else begin
      if (in_valid) begin
        for (int i = 0; i < TLNUM; i = i + 1) begin
          reg_tuple_lengths[wr_ptr+i[ADDRW-1:0]] <= in_tuple_lengths[i];
          reg_key_offsets[wr_ptr+i[ADDRW-1:0]]   <= in_key_offsets[i];
          reg_key_lengths[wr_ptr+i[ADDRW-1:0]]   <= in_key_lengths[i];
        end
        wr_ptr <= (wr_ptr + TLNUM[ADDRW-1:0]);
      end

      if (valid && out_ready) begin
        rd_ptr <= next_rd_ptr;
        cache_line_idx <= pre_sum[num[TN_W-1:0]] & ((1 << 6) - 1);
        out_num <= num;
        out_tuple_offsets <= tuple_offsets;
        out_tuple_lengths <= tuple_lengths;
        out_key_offsets <= key_offsets;
        out_key_lengths <= key_lengths;
      end

      if (out_ready) begin
        out_valid <= valid;
      end
    end
  end
endmodule


// =============================================================
// 源文件 [7/17]: ./vsrc/round_robin.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

module round_robin #(
    parameter integer WIDTH = 32,
    parameter integer TLNUM = 8,
    parameter integer TN_W = $clog2(TLNUM + 1),
    parameter integer WIDTH_W = $clog2(WIDTH + 1),
    parameter integer ADDR_W = $clog2(WIDTH)
) (
    input                     clk,
    input                     nrst,
    input        [ WIDTH-1:0] id,        // input data bus with multiple hot bits
    input        [  TN_W-1:0] num,       // 请求输出的位数
    output                    od_valid,  // output valid (some bits are active)
    output logic [ WIDTH-1:0] od_filt,   // filtered data (多个位可以激活)
    output logic [ADDR_W-1:0] od_bin,    // 最高优先级位的二进制索引
    output logic              od_fail    // 当请求的位数大于可用位数时为1
);

  logic [ ADDR_W-1:0] priority_bit = '0;
  logic [2*WIDTH-1:0] id_double;
  logic [2*WIDTH-1:0] mask;
  logic [2*WIDTH-1:0] masked_id;
  logic [2*WIDTH-1:0] rotated_id_w;
  logic [  WIDTH-1:0] rotated_id;
  logic [WIDTH_W-1:0] valid_bits_count;

  always_comb begin
    valid_bits_count = '0;
    for (integer i = 0; i < WIDTH; i++) begin
      if (id[i]) valid_bits_count += 1'b1;
    end
  end

  logic [WIDTH_W-1:0] num_w;
  assign num_w = {{WIDTH_W - TN_W{'0}}, num};
  assign od_fail = (num_w > valid_bits_count);
  assign od_valid = |id && !od_fail;

  always_comb begin
    id_double = {id, id};
    for (int i = 0; i < 2 * WIDTH; i++) begin
      mask[i] = (i > priority_bit) ? 1'b1 : 1'b0;
    end
    masked_id = id_double & mask;
    rotated_id_w = (masked_id >> priority_bit);
    rotated_id = rotated_id_w[WIDTH-1:0];
  end

  always_comb begin
    integer count = 0;
    od_filt = '0;
    od_bin  = '0;
    if (od_valid) begin
      for (int i = 0; i < WIDTH && count < num; i++) begin
        if (rotated_id[i]) begin
          od_filt[i[ADDR_W-1:0]+priority_bit] = 1'b1;
          count += 1;
          od_bin = i[ADDR_W-1:0] + priority_bit;
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (~nrst) begin
      priority_bit <= '0;
    end else if (od_valid) begin
      priority_bit <= od_bin;
    end
  end

endmodule


// =============================================================
// 源文件 [8/17]: ./vsrc/splitter.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

module splitter #(
    parameter integer CACHE_LINE_SIZE = 512,
    parameter integer TLNUM = 8,
    parameter integer LENGTH_W = 8,
    parameter integer MAX_TUPLE_LENGTH = 512,
    parameter integer MAX_KEY_LENGTH = 512,

    parameter integer TN_W = $clog2(TLNUM + 1)
) (
    input wire clk,
    input wire nrst,

    output wire in_cache_line_req,
    input wire in_cache_line_valid,
    input wire [CACHE_LINE_SIZE-1:0] in_cache_line,

    output wire in_ready,
    input wire in_valid,
    input wire [LENGTH_W-1:0] in_num,
    input wire [LENGTH_W-1:0] in_tuple_offsets[TLNUM],
    input wire [LENGTH_W-1:0] in_tuple_lengths[TLNUM],
    input wire [LENGTH_W-1:0] in_key_offsets[TLNUM],
    input wire [LENGTH_W-1:0] in_key_lengths[TLNUM],

    input wire out_ready,
    output reg out_valid,
    output reg [LENGTH_W-1:0] out_num,
    output reg [MAX_TUPLE_LENGTH-1:0] out_tuple[TLNUM],
    output reg [MAX_KEY_LENGTH-1:0] out_key[TLNUM],
    output reg [LENGTH_W-1:0] out_tuple_length[TLNUM],
    output reg [LENGTH_W-1:0] out_key_length[TLNUM]
);

  assign in_ready = out_ready;

  logic cache_bit;
  reg  [2*CACHE_LINE_SIZE-1:0] cache_lines;
  reg  [CACHE_LINE_SIZE-1:0] cache_reg;
  wire [2*CACHE_LINE_SIZE-1:0] cache_lines_reverse;

  generate
    for (genvar i = 0; i < 2 * CACHE_LINE_SIZE / 8; i = i + 1) begin : g_cache_line_reverse
      assign cache_lines_reverse[i*8+:8] = cache_lines[2*CACHE_LINE_SIZE-1-i*8-:8];
    end
  endgenerate

  wire [31:0] in_tuple_offsets_w[TLNUM];
  wire [2 * CACHE_LINE_SIZE-1:0] cache_lines_offseted[TLNUM];
  wire [MAX_TUPLE_LENGTH-1:0] tuple_reversed[TLNUM], tuple[TLNUM];
  wire [MAX_TUPLE_LENGTH-1:0] tuple_offseted[TLNUM];
  wire [  MAX_KEY_LENGTH-1:0] key_reversed  [TLNUM];

  generate
    for (genvar i = 0; i < TLNUM; i = i + 1) begin : g_splittern
      assign cache_lines_offseted[i] = cache_lines_reverse >> {{in_tuple_offsets[i], 3'b0}};
      for (genvar j = 0; j < CACHE_LINE_SIZE / 8; j = j + 1) begin : g_cache_line_sliced
        assign tuple_reversed[i][j*8+:8] = j < in_tuple_lengths[i] ?
                                                  cache_lines_offseted[i][j*8+:8] : 0;
      end
      assign tuple_offseted[i] = tuple_reversed[i] >> {{in_key_offsets[i], 3'b0}};
      for (genvar j = 0; j < MAX_KEY_LENGTH / 8; j = j + 1) begin : g_tuple_sliced
        assign key_reversed[i][j*8+:8] = j < in_key_lengths[i] ? tuple_offseted[i][j*8+:8] : 0;
      end
    end
  endgenerate

  generate
    for (genvar i = 0; i < TLNUM; i = i + 1) begin : g_tuple_length
      for (genvar j = 0; j < MAX_TUPLE_LENGTH / 8; j = j + 1) begin : g_tuple_reversed
        assign tuple[i][j*8+:8] = j < in_tuple_lengths[i] ?
              tuple_reversed[i][in_tuple_lengths[i]*8-1-j*8-:8]:0;
      end
    end
  endgenerate

  reg [2:0] cache_line_cnt;
  assign in_cache_line_req = cache_line_cnt < 2 || (in_valid & in_ready);

  always_ff @(posedge clk) begin
    if (!nrst) begin
      cache_line_cnt <= 0;
      cache_lines <= 0;
      out_valid <= 0;
      cache_bit <= 0;
    end else begin

      if (in_cache_line_valid || (in_valid & in_ready)) begin
        if (cache_line_cnt == 2 && ~(in_valid & in_ready)) begin
          cache_reg <= in_cache_line;
          cache_bit <= 1;
        end else if (cache_bit) begin
          cache_lines <= {cache_lines[CACHE_LINE_SIZE-1:0], cache_reg};
          cache_bit <= 0;
          cache_reg <= 0;
        end else begin
          cache_lines <= {cache_lines[CACHE_LINE_SIZE-1:0], in_cache_line};
        end
      end

      if (in_cache_line_valid & ~(in_valid & in_ready)) begin
        cache_line_cnt <= cache_line_cnt + 1;
      end else if (~in_cache_line_valid & (in_valid & in_ready)) begin
        cache_line_cnt <= cache_line_cnt - 1;
      end

      if (in_valid & in_ready) begin // 下游准备好，且上游数据有效，进行流式处理。
        out_num <= in_num;
        out_tuple_length <= in_tuple_lengths;
        out_key_length <= in_key_lengths;
        out_tuple <= tuple;
        out_key <= key_reversed;
      end

      if (out_ready) begin // 如果自己准备好了，就把上游数据传递给下游
        out_valid <= in_valid;
      end

    end
  end

endmodule


// =============================================================
// 源文件 [9/17]: ./vsrc/task_dispatcher.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

/* verilator lint_off ALWCOMBORDER */

module task_dispatcher #(
    parameter integer MAX_KEY_LENGTH = 256,
    parameter integer MAX_TUPLE_LENGTH = 512,
    parameter integer LENGTH_W = 8,
    parameter integer TLNUM = 8,
    parameter integer PARALLELISM = 8,

    parameter integer TN_W = $clog2(TLNUM + 1),
    parameter integer PARALLELISM_W = $clog2(PARALLELISM)
) (
    input wire clk,
    input wire nrst,

    input wire splitter_valid,
    output wire in_ready,
    input [MAX_KEY_LENGTH-1:0] splitter_key[TLNUM],
    input [LENGTH_W-1:0] splitter_key_length[TLNUM],
    input [MAX_TUPLE_LENGTH-1:0] splitter_tuple[TLNUM],
    input [LENGTH_W-1:0] splitter_tuple_length[TLNUM],
    input [LENGTH_W-1:0] splitter_tuple_num,

    input wire [PARALLELISM-1:0] w_full,
    output logic [PARALLELISM-1:0] w_req,
    output logic [MAX_KEY_LENGTH-1:0] dispatch_key[PARALLELISM],
    output logic [LENGTH_W-1:0] dispatch_key_length[PARALLELISM],
    output logic [MAX_TUPLE_LENGTH-1:0] dispatch_tuple[PARALLELISM], // <- 
    output logic [LENGTH_W-1:0] dispatch_tuple_length[PARALLELISM],
    output logic [LENGTH_W-1:0] dispatch_tuple_num
);

  logic out_ready;

  assign in_ready = out_ready;

  logic [PARALLELISM_W-1:0] rr_pointer;
  // int rr, dispatched;
  int rr;

  logic [  PARALLELISM-1:0] dispatch_en;
  logic [PARALLELISM_W-1:0] dispatch_idx[PARALLELISM];

  // HERE？
  always_comb begin
    logic [LENGTH_W-1:0] cnt = 0;
    for (int i = 0; i < PARALLELISM; i++) begin
      if (!w_full[i]) begin
        cnt++;
      end
    end
    out_ready = cnt >= splitter_tuple_num;
  end
  

  always_comb begin
    // dispatched = 0;
    rr[PARALLELISM_W-1:0] = rr_pointer;
    for (int i = 0; i < PARALLELISM; i++) begin
      dispatch_en[i]  = 1'b0;
      dispatch_idx[i] = '0;
    end

    for (int i = 0; i < splitter_tuple_num; i++) begin
      // bit dispatched_one = 0;
      for (int j = 0; j < PARALLELISM; j++) begin
        // int ch = (rr + j) % PARALLELISM;
        int ch = (rr + j) & (PARALLELISM - 1);
        if (!w_full[ch] && !dispatch_en[ch]) begin
          dispatch_en[ch] = 1'b1;
          dispatch_idx[ch] = i[PARALLELISM_W-1:0];
          // rr = (ch + 1) % PARALLELISM;
          rr = (ch + 1) & (PARALLELISM - 1);
          // dispatched_one = 1;
          // dispatched++;
          break;
        end
      end
    end
  end
  
  /*
    splitter_tuple - dispatch_idx - w_full
                   - dispatch_en  - w_full
                   - out_ready    - cnt    - w_full
  */

  always_ff @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      rr_pointer <= '0;
      w_req <= '0;
      dispatch_tuple_num <= '0;
      for (int i = 0; i < PARALLELISM; i++) begin
        dispatch_key[i] <= '0;
        dispatch_key_length[i] <= '0;
        dispatch_tuple[i] <= '0;
        dispatch_tuple_length[i] <= '0;
      end
    end else begin
      if (splitter_valid && in_ready) begin
        dispatch_tuple_num <= splitter_tuple_num;
        rr_pointer <= rr[PARALLELISM_W-1:0];
        for (int i = 0; i < PARALLELISM; i++) begin
          if (dispatch_en[i]) begin
            w_req[i] <= 1'b1;
            dispatch_key[i] <= splitter_key[dispatch_idx[i]];
            dispatch_key_length[i] <= splitter_key_length[dispatch_idx[i]];
            dispatch_tuple[i] <= splitter_tuple[dispatch_idx[i]];
            dispatch_tuple_length[i] <= splitter_tuple_length[dispatch_idx[i]];
          end else begin
            w_req[i] <= 1'b0;
            dispatch_key[i] <= '0;
            dispatch_key_length[i] <= '0;
            dispatch_tuple[i] <= '0;
            dispatch_tuple_length[i] <= '0;
          end
        end
      end else begin
        w_req <= '0;
      end
    end
  end

endmodule

/* verilator lint_on ALWCOMBORDER */


// =============================================================
// 源文件 [10/17]: ./vsrc/template/fifo.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

/* verilator lint_off WIDTHEXPAND */
module fifo #(
    parameter integer DATA_WIDTH = 8,  // 数据宽度
    parameter integer DEPTH      = 15,  // FIFO深度
    parameter integer ALMOSTDELTA = 2
) (
    input  wire                   clk,    // 时钟
    input  wire                   nrst,   // 复位
    input  wire                   wr_en,  // 写使能
    input  wire                   rd_en,  // 读使能
    input  wire  [DATA_WIDTH-1:0] din,    // 输入数据
    output logic [DATA_WIDTH-1:0] dout,   // 输出数据
    output logic                  full,   // 满标志
    output logic                  empty,  // 空标志
    output logic                  almost_full,
    output logic                  almost_empty
);

  localparam integer ADDRW = $clog2(DEPTH);  // 地址宽度

  // 定义内部信号
  logic [DATA_WIDTH-1:0] mem_data[DEPTH];  // FIFO存储器 DATA
  logic [ADDRW-1:0] wr_ptr;  // 写指针
  logic [ADDRW-1:0] rd_ptr;  // 读指针
  logic [ADDRW:0] dcount;  // 数据计数器

  logic wr_en_s;
  logic rd_en_s;


  always_ff @(posedge clk) begin
    if (~nrst) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      dcount <= 0;
      dout   <= '0;
    end else begin
      if (wr_en_s) begin
        mem_data[wr_ptr[ADDRW-1:0]] <= din;
        if (wr_ptr == DEPTH[ADDRW-1:0] - 1) begin
          wr_ptr <= 0;
        end else begin
          wr_ptr <= wr_ptr + 1;
        end
      end

      if (rd_en_s) begin
        if (rd_ptr == DEPTH[ADDRW-1:0] - 1) begin
          rd_ptr <= 0;
        end else begin
          rd_ptr <= rd_ptr + 1;
        end
        dout <= mem_data[rd_ptr[ADDRW-1:0]];
      end

      if (wr_en_s && !rd_en_s) begin
        dcount <= dcount + 1;
      end else if (!wr_en_s && rd_en_s) begin
        dcount <= dcount - 1;
      end
    end
  end

  assign wr_en_s = wr_en && !full;
  assign rd_en_s = rd_en && !empty;

  // 满/空判断
  assign full = (dcount == DEPTH);
  assign empty = (dcount == 0);

  assign almost_full = (dcount >= DEPTH - ALMOSTDELTA);
  assign almost_empty = (dcount == ALMOSTDELTA);

endmodule
/* verilator lint_on WIDTHEXPAND */

// =============================================================
// 源文件 [11/17]: ./vsrc/template/fifo_width_converter.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

/* verilator lint_off SELRANGE */

module fifo_width_converter #(
    parameter integer IN_DATA_WIDTH = 256,  // 输入数据宽度
    parameter integer OUT_DATA_WIDTH = 32,  // 输出数据宽度
    parameter integer LENGTH_W = 8,
    parameter integer DEPTH = 64  // FIFO深度
) (
    input wire clk,
    input wire nrst,
    input wire wr_en,
    input wire rd_en,

    input wire [IN_DATA_WIDTH-1:0] din,
    input wire [LENGTH_W-1:0] in_length,

    output logic valid,
    output logic [OUT_DATA_WIDTH-1:0] dout,
    output logic last_block,

    output logic full,
    output logic empty,
    output logic [$clog2(DEPTH + 1)-1:0] cnt
);

  localparam integer DEPTHW = $clog2(DEPTH + 1);
  localparam integer ADDRW = $clog2(DEPTH);
  localparam integer WIDTH = IN_DATA_WIDTH / OUT_DATA_WIDTH;

  logic cache_bit, endFlag, endFlag_1d;
  logic rd_en_1d;
  logic [LENGTH_W-1:0] cur;
  logic [LENGTH_W-1:0] reg_length, out_length, in_length_1d;
  logic ff_len_empty, len_empty;
  logic ff_len_empty_1d;
  logic forward, forward_1d;
  wire [LENGTH_W-1:0] length;

  assign length = endFlag_1d ? (forward_1d ? in_length_1d : out_length) : reg_length;

  // assign length = (endFlag_1d & ~forward) ? out_length : reg_length;

  assign forward = endFlag & wr_en & cache_bit & ff_len_empty;
  assign endFlag = rd_en & (cur + OUT_DATA_WIDTH[LENGTH_W-1:0] >= (length << 3));
  assign last_block = endFlag_1d;
  assign len_empty = ff_len_empty & ~cache_bit;

  fifo #(
      .DATA_WIDTH(LENGTH_W),
      .DEPTH(DEPTH)
  ) U_ff_length (
      .clk  (clk),
      .nrst (nrst),
      .wr_en(wr_en & cache_bit & ~forward),
      .rd_en(endFlag),
      .din  (in_length),
      .dout (out_length),
      .full (),
      .empty(ff_len_empty),
      .almost_full(),
      .almost_empty()
  );

  always_ff @(posedge clk) begin
    if (~nrst) begin
      cache_bit       <= '0;
      reg_length      <= '0; // out_length <= 0;
      cur             <= '0;
      rd_en_1d        <= '0;
      endFlag_1d      <= '0;
      forward_1d      <= '0;
      in_length_1d    <= '0;
      ff_len_empty_1d <= '0;
    end else begin
      rd_en_1d        <= rd_en;
      endFlag_1d      <= endFlag;
      forward_1d      <= forward;
      in_length_1d    <= in_length;
      ff_len_empty_1d <= ff_len_empty;

      if (wr_en && ~cache_bit) begin
        cache_bit  <= 1;
      end else if (rd_en && endFlag && ff_len_empty & ~forward) begin
        cache_bit  <= 0;
      end

      if ((wr_en && ~cache_bit) || forward) begin
        reg_length <= in_length;
      end else if (~ff_len_empty_1d && endFlag_1d) begin
        reg_length <= out_length;
      end

      if (rd_en) begin
        if (endFlag) begin
          cur <= 0;
        end else begin
          cur <= cur + OUT_DATA_WIDTH[LENGTH_W-1:0];
        end
      end
     
    end
  end

  logic [DEPTHW-1:0] wr_ptr;  // 写指针  // <- 
  logic [DEPTHW-1:0] rd_ptr;  // 读指针
  logic [OUT_DATA_WIDTH-1:0] mem_data[DEPTH];  // FIFO存储器
  logic [LENGTH_W-1:0] delta;
  assign delta = ((in_length << 3) + OUT_DATA_WIDTH[LENGTH_W-1:0] - 1) / OUT_DATA_WIDTH[LENGTH_W-1:0];

  always_ff @(posedge clk) begin
    if (~nrst) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      dout   <= '0;
      valid  <= 0;

    end else begin
      if (wr_en && !full) begin
        for (int i = 0; i < WIDTH; i = i + 1) begin
          if (i < delta) begin
            mem_data[wr_ptr[ADDRW-1:0]+i[ADDRW-1:0]] <= din[i*OUT_DATA_WIDTH+:OUT_DATA_WIDTH];
          end
        end
        //                                   [ TAG ]
        //                                    DEPTH = 64
        // wr_ptr <= (wr_ptr + delta[DEPTHW-1:0]) % DEPTH[DEPTHW-1:0];
        wr_ptr <= (wr_ptr + delta[DEPTHW-1:0]) & (DEPTH[DEPTHW-1:0] - 1);
      end

      if (rd_en && !empty) begin
        valid <= 1;
        dout  <= mem_data[rd_ptr[ADDRW-1:0]];
        if (rd_ptr == DEPTH[DEPTHW-1:0] - 1) begin
          rd_ptr <= 0;
        end else begin
          rd_ptr <= rd_ptr + 1;
        end
      end else begin
        valid <= 0;
      end
    end
  end

  assign full  = DEPTH[DEPTHW-1:0] - cnt < 16;
  assign empty = (wr_ptr == rd_ptr);
  assign cnt   = wr_ptr - rd_ptr;

endmodule

/* verilator lint_on SELRANGE */

// =============================================================
// 源文件 [12/17]: ./vsrc/template/leave_one_hot.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

module leave_one_hot #(
    parameter integer WIDTH = 32
) (
    input [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);
  genvar i;
  generate
    for (i = 1; i < WIDTH; i++) begin : gen_for
      always_comb begin
        out[i] = in[i] && ~(|in[(i-1):0]);
      end
    end  // for i
  endgenerate

  assign out[0] = in[0];

endmodule


// =============================================================
// 源文件 [13/17]: ./vsrc/template/pos2bin.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

module pos2bin #(
    parameter integer BIN_WIDTH = 8,
    integer POS_WIDTH = 2 ** BIN_WIDTH
) (
    input [(POS_WIDTH-1):0] pos,
    output logic [(BIN_WIDTH-1):0] bin,

    // error flags
    output logic err_no_hot,    // no active bits in pos[] vector
    output logic err_multi_hot  // multiple active bits in pos[] vector
                                // only least-sensitive active bit affects the output
);

  assign err_no_hot = (pos[(POS_WIDTH-1):0] == 0);

  integer i;
  logic   found_hot;
  always_comb begin
    err_multi_hot = 0;
    bin[(BIN_WIDTH-1):0] = 0;
    found_hot = 0;
    for (i = 0; i < POS_WIDTH; i++) begin

      if (~found_hot && pos[i]) begin
        bin[(BIN_WIDTH-1):0] = i[(BIN_WIDTH-1):0];
      end

      if (found_hot && pos[i]) begin
        err_multi_hot = 1'b1;
      end

      if (pos[i]) begin
        found_hot = 1'b1;
      end

    end  // for
  end  // always_comb

endmodule


// =============================================================
// 源文件 [14/17]: ./vsrc/template/prefix_sum_find.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

module prefix_sum_find #(
    parameter integer LENGTH_W = 8,
    parameter integer TLNUM = 8,
    parameter integer TN_W = $clog2(TLNUM + 1)
) (
    input wire [LENGTH_W-1:0] data[2 * TLNUM],
    input wire [TN_W-1:0] offset,
    input wire [LENGTH_W-1:0] threshold,
    input wire [LENGTH_W-1:0] init,
    output logic [LENGTH_W-1:0] pre_sum[TLNUM + 1],
    output logic [TN_W-1:0] index,
    output logic [TN_W-1:0] psf_num
);

  logic [TN_W-1:0] j;
  logic flag;

  always_comb begin
    pre_sum[0] = init;
    for (int i = 0; i < TLNUM; i = i + 1) begin
      j = i[TN_W-1:0] + offset;
      pre_sum[i+1] = pre_sum[i] + data[j];
    end

    flag  = 0;
    index = 0;
    for (int i = 0; i < TLNUM; i = i + 1) begin
      j = i[TN_W-1:0] + offset;
      if (pre_sum[i+1] >= threshold) begin
        index = j;
        flag  = 1;
        break;
      end
    end
    psf_num = flag ? index - offset + 1 : TLNUM[TN_W-1:0];
  end

endmodule


// =============================================================
// 源文件 [15/17]: ./vsrc/template/reg_fifo.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

/* verilator lint_off WIDTHEXPAND */

/*===============================================================================================================================
   Design       : Single-clock Synchronous FIFO

   Description  : Fully synthesisable, configurable Single-clock Synchronous FIFO based on registers.
                  - Configurable Data width.
                  - Configurable Depth.
                  - Configurable Almost-full and Almost-empty signals.
                  - All status signals have zero cycle latency.

   Developer    : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic ™, https://chipmunklogic.com
   Date         : Feb-12-2021
===============================================================================================================================*/
module reg_fifo #(
    parameter integer DATA_W = 4,  // Data width
    parameter integer DEPTH  = 8,  // Depth of FIFO
    parameter integer UPP_TH = 4,  // Upper threshold to generate Almost-full
    parameter integer LOW_TH = 2   // Lower threshold to generate Almost-empty
) (
    input clk,  // Clock
    input rstn, // Active-low Synchronous Reset

    input                   i_wren,      // Write Enable
    input  [DATA_W - 1 : 0] i_wrdata,    // Write-data
    output                  o_alm_full,  // Almost-full signal
    output                  o_full,      // Full signal

    input                   i_rden,       // Read Enable
    output [DATA_W - 1 : 0] o_rddata,     // Read-data
    output                  o_alm_empty,  // Almost-empty signal
    output                  o_empty       // Empty signal
);

  /*-------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
-------------------------------------------------------------------------------------------------------------------------------*/
  logic [DATA_W - 1 : 0] data_rg[DEPTH];  // Data array
  logic [$clog2(DEPTH) - 1 : 0] wrptr_rg;  // Write pointer
  logic [$clog2(DEPTH) - 1 : 0] rdptr_rg;  // Read pointer
  logic [$clog2(DEPTH) : 0] dcount_rg;  // Data counter

  logic wren_s;  // Write Enable signal generated iff FIFO is not full
  logic rden_s;  // Read Enable signal generated iff FIFO is not empty
  logic full_s;  // Full signal
  logic empty_s;  // Empty signal

  /*-------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic to write to and read from FIFO
-------------------------------------------------------------------------------------------------------------------------------*/
  always @(posedge clk) begin
    if (!rstn) begin
      data_rg   <= '{default: '0};
      wrptr_rg  <= 0;
      rdptr_rg  <= 0;
      dcount_rg <= 0;
    end else begin
      /* FIFO write logic */
      if (wren_s) begin
        data_rg[wrptr_rg] <= i_wrdata;  // Data written to FIFO
        if (wrptr_rg == DEPTH - 1) begin
          wrptr_rg <= 0;  // Reset write pointer
        end else begin
          wrptr_rg <= wrptr_rg + 1;  // Increment write pointer
        end
      end

      /* FIFO read logic */
      if (rden_s) begin
        if (rdptr_rg == DEPTH - 1) begin
          rdptr_rg <= 0;  // Reset read pointer
        end else begin
          rdptr_rg <= rdptr_rg + 1;  // Increment read pointer
        end
      end

      /* FIFO data counter update logic */
      if (wren_s && !rden_s) begin  // Write operation
        dcount_rg <= dcount_rg + 1;
      end else if (!wren_s && rden_s) begin  // Read operation
        dcount_rg <= dcount_rg - 1;
      end
    end
  end

  /*-------------------------------------------------------------------------------------------------------------------------------
   Continuous Assignments
-------------------------------------------------------------------------------------------------------------------------------*/
  // Full and Empty internal
  assign full_s      = (dcount_rg == DEPTH) ? 1'b1 : 0;
  assign empty_s     = (dcount_rg == 0) ? 1'b1 : 0;

  // Write and Read Enables internal
  assign wren_s      = i_wren & !full_s;
  assign rden_s      = i_rden & !empty_s;

  // Full and Empty to output
  assign o_full      = full_s;
  assign o_empty     = empty_s;

  // Almost-full and Almost-empty to output
  assign o_alm_full  = ((dcount_rg > UPP_TH) ? 1'b1 : 0);
  assign o_alm_empty = (dcount_rg < LOW_TH) ? 1'b1 : 0;

  // Read-data to output
  assign o_rddata    = data_rg[rdptr_rg];


endmodule
/*=============================================================================================================================*/

/* verilator lint_on WIDTHEXPAND */


// =============================================================
// 源文件 [16/17]: ./vsrc/template/round_robin_performance_enc.v
// 目录: ./vsrc/template
// 类型: V 文件
// =============================================================

module round_robin_performance_enc #(
    parameter integer WIDTH = 32,
    integer WIDTH_W = $clog2(WIDTH)
) (
    input clk,  // clock
    input nrst, // inversed reset, synchronous

    input        [  WIDTH-1:0] id,        // input data bus
    output                     od_valid,  // output valid (some bits are active)
    output logic [  WIDTH-1:0] od_filt,   // filtered data (only one priority bit active)
    output logic [WIDTH_W-1:0] od_bin     // priority bit binary index
);

  // current bit selector
  logic [WIDTH_W-1:0] priority_bit = '0;

  // prepare double width buffer with LSB bits masked out
  logic [2*WIDTH-1:0] mask;
  logic [2*WIDTH-1:0] id_buf;
  always_comb begin
    integer i;
    for (i = 0; i < 2 * WIDTH; i++) begin
      if (i > priority_bit[WIDTH_W-1:0]) begin
        mask[i] = 1'b1;
      end else begin
        mask[i] = 1'b0;
      end
    end
    id_buf[2*WIDTH-1:0] = {2{id[WIDTH-1:0]}} & mask[2*WIDTH-1:0];
  end

  logic [2*WIDTH-1:0] id_buf_filt;
  leave_one_hot #(
      .WIDTH(2 * WIDTH)
  ) one_hot_b (
      .in (id_buf[2*WIDTH-1:0]),
      .out(id_buf_filt[2*WIDTH-1:0])
  );

  logic [(WIDTH_W+1)-1:0] id_buf_bin;  // one more bit to decode double width input

  logic err_no_hot;
  assign od_valid = ~err_no_hot;

  pos2bin #(
      .BIN_WIDTH((WIDTH_W + 1))
  ) pos2bin_b (
      .pos(id_buf_filt[2*WIDTH-1:0]),
      .bin(id_buf_bin[(WIDTH_W+1)-1:0]),

      .err_no_hot(err_no_hot),
      .err_multi_hot()
  );

  always_comb begin
    if (od_valid) begin
      od_bin[WIDTH_W-1:0] = WIDTH_W'(id_buf_bin[(WIDTH_W+1)-1:0] % (WIDTH_W + 1)'(WIDTH));
      od_filt[WIDTH-1:0]  = 1'b1 << od_bin[WIDTH_W-1:0];
    end else begin
      od_bin[WIDTH_W-1:0] = '0;
      od_filt[WIDTH-1:0]  = '0;
    end
  end

  // latching current
  always_ff @(posedge clk) begin
    if (~nrst) begin
      priority_bit[WIDTH_W-1:0] <= '0;
    end else begin
      if (od_valid) begin
        priority_bit[WIDTH_W-1:0] <= od_bin[WIDTH_W-1:0];
      end else begin
        // nop,
      end  // if
    end  // if nrst
  end

endmodule


// =============================================================
// 源文件 [17/17]: ./vsrc/write_combiner.v
// 目录: ./vsrc
// 类型: V 文件
// =============================================================

module write_combiner #(
    parameter integer MAX_TUPLE_LENGTH = 512,
    parameter integer CACHE_LINE_SIZE  = 512,

    parameter integer HASH_WIDTH = 8,
    parameter integer BLOCK_SIZE = 64,
    parameter integer LENGTH_W   = 8,
    parameter integer TLNUM      = 8,

    parameter integer PARALLEL = CACHE_LINE_SIZE / BLOCK_SIZE
) (
    input wire clk,
    input wire nrst,
    input wire [HASH_WIDTH-1:0] PARTITION_NUM,
    input wire in_valid,
    input wire [HASH_WIDTH-1:0] hash_in,
    input wire [MAX_TUPLE_LENGTH-1:0] tuple_in,
    input wire [LENGTH_W-1:0] length_in,
    input wire drain_in,

    output logic out_fifo_wr_en,
    output logic [HASH_WIDTH-1:0] hash_out,
    output logic [LENGTH_W-1:0] num_out,
    output logic [LENGTH_W-1:0] lengths_out[TLNUM],
    output logic [CACHE_LINE_SIZE-1:0] cache_line_out,

    output logic finish
);

  localparam integer ParallelWidth = $clog2(PARALLEL);

  genvar i;

  logic read, read_1d;
  logic drain_read, drain_read_1d;
  logic equ, equ_1d;
  logic in_valid_1d, in_valid_2d;
  logic drain_1d, drain_2d;
  logic [HASH_WIDTH-1:0] dp_cur, dp_cur_1d, dp_cur_2d;
  logic [HASH_WIDTH-1:0] hash_1d, hash_2d;
  logic [MAX_TUPLE_LENGTH-1:0] tuple_1d;
  logic [LENGTH_W-1:0] length_1d, length_2d;
  logic fill_rate_w_req;
  logic fill_rate_r_req;
  logic [HASH_WIDTH-1:0] fill_rate_r_addr;
  logic [ParallelWidth-1:0] fill_rate_next, fill_rate_next_1d;
  logic [ParallelWidth-1:0] len_num_next, len_num_next_1d;
  logic [ParallelWidth-1:0] fill_rate_r, len_num_r;

  logic [ParallelWidth-1:0] which_frrd, which_frrd_1d, which_len_num, which_len_num_1d;
  logic [LENGTH_W-1:0] delta;
  assign delta = ((length_1d << 3) + BLOCK_SIZE[LENGTH_W-1:0] - 1) / BLOCK_SIZE[LENGTH_W-1:0];
  assign which_frrd = ((hash_1d == hash_2d) && in_valid_1d && in_valid_2d) ?
                        fill_rate_next_1d : fill_rate_r;
  assign which_len_num = ((hash_1d == hash_2d) && in_valid_1d && in_valid_2d) ?
                        len_num_next_1d : len_num_r;
  wire [31:0] which_frrd_32, delta_32;
  assign which_frrd_32 = {{32 - ParallelWidth{'0}}, which_frrd};
  assign delta_32 = {{32 - LENGTH_W{'0}}, delta};
  assign read = in_valid_1d & which_frrd_32 + delta_32 >= PARALLEL;
  assign equ = in_valid_1d & which_frrd_32 + delta_32 == PARALLEL;

  assign fill_rate_next = equ ? 0 :
    (read ? delta[ParallelWidth-1:0] : which_frrd + delta[ParallelWidth-1:0]);
  assign len_num_next = equ ? 0 : (read ? 1 : which_len_num + 1);

  assign fill_rate_r_req = in_valid || drain;
  assign fill_rate_r_addr = drain ? dp_cur : hash_in;
  assign fill_rate_w_req = in_valid_1d;

  true_dual_port_write_first_2_clock_ram #(
      .RAM_WIDTH(ParallelWidth * 2),
      .RAM_DEPTH(1 << HASH_WIDTH)
  ) fill_rate (
      .clka (clk),
      .addra(hash_1d),
      .ena  (fill_rate_w_req),
      .wea  (1'b1),
      .dina ({fill_rate_next, len_num_next}),
      .douta(),

      .clkb (clk),
      .addrb(fill_rate_r_addr),
      .enb  (fill_rate_r_req),
      .web  (1'b0),
      .dinb (),
      .doutb({fill_rate_r, len_num_r})
  );

  logic [PARALLEL-1:0] bram_write_en;
  logic [BLOCK_SIZE-1:0] bram_din[PARALLEL], bram_din_1d[PARALLEL];
  logic [HASH_WIDTH-1:0] bram_addr;
  logic [BLOCK_SIZE-1:0] bram_dout [PARALLEL];
  assign bram_addr  = drain_1d ? dp_cur_1d : hash_1d;
  assign drain_read = drain_1d & (|fill_rate_r);
  generate
    for (i = 0; i < PARALLEL; i++) begin : g_bram
      true_dual_port_write_first_2_clock_ram #(
          .RAM_WIDTH(BLOCK_SIZE),
          .RAM_DEPTH(1 << HASH_WIDTH)
      ) bram (
          .clka (clk),
          .addra(hash_1d),
          .ena  (bram_write_en[i]),
          .wea  (1'b1),
          .dina (bram_din[i]),
          .douta(),

          .clkb (clk),
          .addrb(bram_addr),
          .enb  (read | drain_read),
          .web  (1'b0),
          .dinb ('0),
          .doutb(bram_dout[i])
      );
    end
  endgenerate

  logic [TLNUM-1:0] bram_len_write_en;
  logic [LENGTH_W-1:0] bram_len_out[TLNUM];
  assign bram_len_write_en = in_valid_1d ? (equ ? 0 : ((read ? 1 : (1 << which_len_num)))) : '0;
  generate
    for (i = 0; i < TLNUM; i++) begin : g_bram_length
      true_dual_port_write_first_2_clock_ram #(
          .RAM_WIDTH(LENGTH_W),
          .RAM_DEPTH(1 << HASH_WIDTH)
      ) bram_length (
          .clka (clk),
          .addra(hash_1d),
          .ena  (bram_len_write_en[i]),
          .wea  (1'b1),
          .dina (length_1d),
          .douta(),

          .clkb (clk),
          .addrb(bram_addr),
          .enb  (read | drain_read),
          .web  (1'b0),
          .dinb ('0),
          .doutb(bram_len_out[i])
      );
    end
  endgenerate

  assign bram_write_en = in_valid_1d ?
        (equ ?                          0:
        ((read ? ((1<<fill_rate_next)-1) :
        ((1<<fill_rate_next)-1) ^ ((1<<which_frrd)-1)))) :
                                           '0;

  generate
    for (i = 0; i < PARALLEL; i++) begin : g_slice
      assign bram_din[i] = (read & ~equ) ? tuple_1d[(i+1)*BLOCK_SIZE-1-:BLOCK_SIZE] :
        (
         (i < which_frrd_32) ?
         '0 : tuple_1d[(i-which_frrd_32+1)*BLOCK_SIZE-1-:BLOCK_SIZE]
        );
    end
  endgenerate

  assign out_fifo_wr_en = read_1d | (drain_read_1d);
  assign hash_out = drain_2d ? dp_cur_2d : hash_2d;
  assign num_out = {{(LENGTH_W - ParallelWidth) {'0}}, which_len_num_1d} + (equ_1d ? 1 : 0);
  generate
    for (i = 0; i < PARALLEL; i++) begin : g_concat
         assign cache_line_out[(i+1)*BLOCK_SIZE-1-:BLOCK_SIZE] = drain_read_1d ?
                                    (i < which_frrd_1d ? bram_dout[i]: '0) :
                                   (equ_1d? (i < which_frrd_1d ? bram_dout[i] : (bram_din_1d[i])):
                                                              bram_dout[i]);
    end
  endgenerate
  generate
    for (i = 0; i < TLNUM; i++) begin : g_concat_len
      assign lengths_out[i] = drain_read_1d ? (i < which_len_num_1d ? bram_len_out[i]: '0):
      (
        (read_1d) ?
        ((equ_1d && (i == which_len_num_1d )) ?
        length_2d : bram_len_out[i]) : '0
      );
    end
  endgenerate

  typedef enum logic [2:0] {
    IDLE,
    WORK,
    DRAIN
  } state_t;

  logic idle, work, drain;
  state_t state;
  assign idle  = (state == IDLE);
  assign work  = (state == WORK);
  assign drain = (state == DRAIN);

  logic drain_bit;
  always_ff @(posedge clk) begin
    if (~nrst) begin
      state <= WORK;
      drain_bit <= 0;
      finish <= 0;
    end else begin
      if (drain_in) begin
        if (dp_cur == (PARTITION_NUM - 1)) begin
          state <= IDLE;
        end else if (~drain_bit) begin
          state <= DRAIN;
          drain_bit <= 1;
        end
      end
      if (idle && dp_cur_2d == PARTITION_NUM) begin
        finish <= 1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (~nrst) begin
      dp_cur <= 0;
    end else begin
      in_valid_1d <= in_valid;
      in_valid_2d <= in_valid_1d;
      hash_1d <= hash_in;
      hash_2d <= hash_1d;
      tuple_1d <= tuple_in;
      length_1d <= length_in;
      length_2d <= length_1d;
      fill_rate_next_1d <= fill_rate_next;
      which_frrd_1d <= which_frrd;
      which_len_num_1d <= which_len_num;
      len_num_next_1d <= len_num_next;
      dp_cur_1d <= dp_cur;
      dp_cur_2d <= dp_cur_1d;
      read_1d <= read;
      drain_read_1d <= drain_read;
      bram_din_1d <= bram_din;
      drain_1d <= drain;
      drain_2d <= drain_1d;
      equ_1d <= equ;
      if (drain) begin
        dp_cur <= dp_cur + 1;
      end
    end
  end

endmodule


