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
    output reg in_cache_line_ready,
    input wire [CACHE_LINE_SIZE-1:0] in_cache_line,

    input wire in_tuple_length_valid,
    output reg in_tuple_length_ready,
    input wire [LENGTH_W*TLNUM-1:0] in_tuple_length,

    input wire in_key_info_valid,
    output reg in_key_info_ready,
    input wire [LENGTH_W*2*TLNUM-1:0] in_key_info,

    input wire out_ready,
    output reg out_valid,
    output reg [HASH_WIDTH-1:0] out_hash,
    output reg [CACHE_LINE_SIZE-1:0] out_cache_line,
    output reg [LENGTH_W-1:0] out_num,
    output reg [LENGTH_W*TLNUM-1:0] out_lengths,

    output reg error,
    output reg runned,
    output reg finish
);
  reg [HASH_WIDTH + CACHE_LINE_SIZE + (LENGTH_W * 3 * TLNUM) + 4:0] temp;
  assign temp = {
      PARTITION_NUM,
      in_cache_line_valid,
      in_cache_line,
      in_tuple_length_valid,
      in_tuple_length,
      in_key_info_valid,
      in_key_info,
      out_ready,
      1'b0
  };
  always @(*) begin
      in_cache_line_ready = 1'b1;  
      in_tuple_length_ready = 1'b1;
      in_key_info_ready = 1'b1;
      out_valid = 1'b0;           
      out_hash = '0;
      out_cache_line = '0;
      out_num = '0;
      out_lengths = '0;
      error = 1'b0;
      runned = 1'b0;
      finish = temp[0];
  end

endmodule