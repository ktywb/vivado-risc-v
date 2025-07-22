
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
      for (int j = 0; j < PARALLELISM; j++) begin
        int ch = (rr + j) & (PARALLELISM - 1);
        if (!w_full[ch] && !dispatch_en[ch]) begin
          dispatch_en[ch] = 1'b1;
          dispatch_idx[ch] = i[PARALLELISM_W-1:0];
          rr = (ch + 1) & (PARALLELISM - 1);
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
      dispatch_key <= '0;
      dispatch_key_length <= '0;
      dispatch_tuple <= '0;
      dispatch_tuple_length <= '0;
    end else begin
      if (splitter_valid && in_ready) begin
        dispatch_tuple_num <= splitter_tuple_num;
        rr_pointer <= rr[PARALLELISM_W-1:0];
        for (int i = 0; i < PARALLELISM; i++) begin
          if (dispatch_en[i]) begin
            w_req[i] <= 1'b1;
            dispatch_key[i]          <= splitter_key[dispatch_idx[i]];
            dispatch_key_length[i]   <= splitter_key_length[dispatch_idx[i]];
            dispatch_tuple[i]        <= splitter_tuple[dispatch_idx[i]];
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
