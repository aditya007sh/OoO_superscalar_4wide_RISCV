// LSQ - See user's module (too large for single write)
// Reviewed: 2 bugs found, see conversation notes
module LSQ #(
    parameter LSQ_DEPTH = 32,
    parameter AQ_DEPTH  = 16,
    parameter LSQ_PTR_W = 5,
    parameter AQ_PTR_W  = 4,
    parameter ROB_PTR_W = 6
)(
    input  wire clk,
    input  wire rst,
    input  wire flush,
    input  wire [7:0] flush_seq_num,

    // ================================================================
    // 4-WIDE DISPATCH INPUTS
    // ================================================================
    input  wire [3:0]                  dispatch_valid,
    input  wire [3:0]                  dispatch_is_load,
    input  wire [3:0]                  dispatch_is_store,
    input  wire [23:0]                 dispatch_phys_rd,
    input  wire [23:0]                 dispatch_phys_rs1,
    input  wire [23:0]                 dispatch_phys_rs2,
    input  wire [127:0]                dispatch_imm,
    input  wire [11:0]                 dispatch_funct3,
    input  wire [ROB_PTR_W-1:0]        rob_idx_in0,
    input  wire [ROB_PTR_W-1:0]        rob_idx_in1,
    input  wire [ROB_PTR_W-1:0]        rob_idx_in2,
    input  wire [ROB_PTR_W-1:0]        rob_idx_in3,
    
    output wire                        lsq_full,

    // ================================================================
    // AQ HEAD / AGU PORT
    // ================================================================
    output wire                        aq_valid,
    output wire [LSQ_PTR_W-1:0]        aq_lsq_idx,
    output wire [5:0]                  aq_phys_rs1,
    output wire [5:0]                  aq_phys_rs2,
    output wire [31:0]                 aq_imm,
    output wire [2:0]                  aq_funct3,
    output wire                        aq_is_load,
    output wire                        aq_is_store,
    input  wire                        agu_pop,

    // ================================================================
    // AGU WRITEBACK & SNOOPS
    // ================================================================
    input  wire                        agu_wb_valid,
    input  wire [LSQ_PTR_W-1:0]        agu_wb_lsq_idx,
    input  wire [31:0]                 agu_wb_addr,
    input  wire [31:0]                 agu_wb_store_data,
    input  wire                        agu_wb_data_valid,

    input  wire                        store_commit_valid,
    input  wire [ROB_PTR_W-1:0]        store_commit_rob_idx,

    output reg                         mem_req_valid,
    output reg                         mem_req_we,
    output reg  [31:0]                 mem_req_addr,
    output reg  [31:0]                 mem_req_wdata,
    output reg  [1:0]                  mem_req_size,
    output reg  [LSQ_PTR_W-1:0]        mem_req_lsq_idx,
    input  wire                        mem_req_ready,
    input  wire                        mem_resp_valid,
    input  wire [31:0]                 mem_resp_data,
    input  wire [LSQ_PTR_W-1:0]        mem_resp_lsq_idx,

    output reg                         cdb_valid,
    output reg  [7:0]                  cdb_tag,
    output reg  [5:0]                  cdb_phys_reg,
    output reg  [31:0]                 cdb_result,

    input  wire                        cdb_fu0_valid,
    input  wire [5:0]                  cdb_fu0_phys_reg,
    input  wire [31:0]                 cdb_fu0_result,
    input  wire                        cdb_fu1_valid,
    input  wire [5:0]                  cdb_fu1_phys_reg,
    input  wire [31:0]                 cdb_fu1_result,
    input  wire                        cdb_fu2_valid,
    input  wire [5:0]                  cdb_fu2_phys_reg,
    input  wire [31:0]                 cdb_fu2_result,
    input  wire                        cdb_fu3_valid,
    input  wire [5:0]                  cdb_fu3_phys_reg,
    input  wire [31:0]                 cdb_fu3_result,
    input  wire                        cdb_bpu_valid,
    input  wire [5:0]                  cdb_bpu_phys_reg,
    input  wire [31:0]                 cdb_bpu_result,
    input  wire                        cdb_lsq_snoop_valid,
    input  wire [5:0]                  cdb_lsq_snoop_phys_reg,
    input  wire [31:0]                 cdb_lsq_snoop_result,

    // ================================================================
    // ROB STORE DONE STATUS
    // ================================================================
    output reg                         store_done_valid,
    output reg  [ROB_PTR_W-1:0]        store_done_rob_idx,

    output wire [LSQ_PTR_W-1:0]        dbg_head,
    output wire [LSQ_PTR_W-1:0]        dbg_tail,
    output wire [LSQ_PTR_W:0]          dbg_count
);

    localparam ST_IDLE        = 3'd0;
    localparam ST_WAIT_ADDR   = 3'd1;
    localparam ST_ADDR_READY  = 3'd2;
    localparam ST_MEM_WAIT    = 3'd3;
    localparam ST_FWD_DONE    = 3'd4;
    localparam ST_WAIT_COMMIT = 3'd5;
    localparam ST_MEM_STORE   = 3'd6;
    localparam ST_DONE        = 3'd7;

    reg                  e_valid      [0:LSQ_DEPTH-1];
    reg                  e_is_load    [0:LSQ_DEPTH-1];
    reg                  e_is_store   [0:LSQ_DEPTH-1];
    reg [7:0]            e_seq_num    [0:LSQ_DEPTH-1];
    reg [ROB_PTR_W-1:0]  e_rob_idx    [0:LSQ_DEPTH-1];
    reg [5:0]            e_phys_rd    [0:LSQ_DEPTH-1];
    reg [5:0]            e_phys_rs1   [0:LSQ_DEPTH-1];
    reg [5:0]            e_phys_rs2   [0:LSQ_DEPTH-1];
    reg [31:0]           e_imm        [0:LSQ_DEPTH-1];
    reg [2:0]            e_funct3     [0:LSQ_DEPTH-1];
    reg                  e_addr_valid [0:LSQ_DEPTH-1];
    reg [31:0]           e_addr       [0:LSQ_DEPTH-1];
    reg                  e_data_valid [0:LSQ_DEPTH-1];
    reg [31:0]           e_data       [0:LSQ_DEPTH-1];
    reg [2:0]            e_state      [0:LSQ_DEPTH-1];

    reg [LSQ_PTR_W-1:0]  head;
    reg [LSQ_PTR_W-1:0]  tail;
    reg [LSQ_PTR_W:0]    count;

    assign dbg_head  = head;
    assign dbg_tail  = tail;
    assign dbg_count = count;

    // Address Queue
    reg [LSQ_PTR_W-1:0]  aq_data    [0:AQ_DEPTH-1];
    reg [AQ_PTR_W-1:0]   aq_head_r, aq_tail_r;
    reg [AQ_PTR_W:0]     aq_count_r;

    wire aq_empty_w = (aq_count_r == 0);
    // Synthesis fix: Use AQ_DEPTH - 1 to prevent aggressive throttling
    wire aq_full_w  = (aq_count_r >= AQ_DEPTH - 4); 

    // ================================================================
    // INPUT UNPACKING & COMPRESSOR LOGIC (Combinational)
    // ================================================================
    wire [5:0]  d_rd [0:3], d_rs1 [0:3], d_rs2 [0:3];
    wire [31:0] d_imm [0:3];
    wire [2:0]  d_fn3 [0:3];
    wire [ROB_PTR_W-1:0] d_rob [0:3];
    
    assign d_rd[0] = dispatch_phys_rd[5:0];   assign d_rd[1] = dispatch_phys_rd[11:6];
    assign d_rd[2] = dispatch_phys_rd[17:12]; assign d_rd[3] = dispatch_phys_rd[23:18];
    
    assign d_rs1[0] = dispatch_phys_rs1[5:0];   assign d_rs1[1] = dispatch_phys_rs1[11:6];
    assign d_rs1[2] = dispatch_phys_rs1[17:12]; assign d_rs1[3] = dispatch_phys_rs1[23:18];
    
    assign d_rs2[0] = dispatch_phys_rs2[5:0];   assign d_rs2[1] = dispatch_phys_rs2[11:6];
    assign d_rs2[2] = dispatch_phys_rs2[17:12]; assign d_rs2[3] = dispatch_phys_rs2[23:18];
    
    assign d_imm[0] = dispatch_imm[31:0];   assign d_imm[1] = dispatch_imm[63:32];
    assign d_imm[2] = dispatch_imm[95:64];  assign d_imm[3] = dispatch_imm[127:96];
    
    assign d_fn3[0] = dispatch_funct3[2:0];   assign d_fn3[1] = dispatch_funct3[5:3];
    assign d_fn3[2] = dispatch_funct3[8:6];   assign d_fn3[3] = dispatch_funct3[11:9];
    
    assign d_rob[0] = rob_idx_in0; assign d_rob[1] = rob_idx_in1;
    assign d_rob[2] = rob_idx_in2; assign d_rob[3] = rob_idx_in3;

    wire [3:0] is_mem_op;
    assign is_mem_op[0] = dispatch_valid[0] && (dispatch_is_load[0] || dispatch_is_store[0]);
    assign is_mem_op[1] = dispatch_valid[1] && (dispatch_is_load[1] || dispatch_is_store[1]);
    assign is_mem_op[2] = dispatch_valid[2] && (dispatch_is_load[2] || dispatch_is_store[2]);
    assign is_mem_op[3] = dispatch_valid[3] && (dispatch_is_load[3] || dispatch_is_store[3]);
    
    wire [2:0] mem_count = {2'b0, is_mem_op[0]} + {2'b0, is_mem_op[1]} + {2'b0, is_mem_op[2]} + {2'b0, is_mem_op[3]};

    assign lsq_full = (count >= LSQ_DEPTH - 4) || aq_full_w;
    
    // Calculate final valid dispatched count gated by full signal
    wire [2:0] actual_dispatched = lsq_full ? 3'd0 : mem_count;

    // Pre-compute array write indices combinationally to avoid sequential hazards
    wire [LSQ_PTR_W-1:0] next_idx0 = tail;
    wire [LSQ_PTR_W-1:0] next_idx1 = tail + {{(LSQ_PTR_W-1){1'b0}}, is_mem_op[0]};
    wire [LSQ_PTR_W-1:0] next_idx2 = next_idx1 + {{(LSQ_PTR_W-1){1'b0}}, is_mem_op[1]};
    wire [LSQ_PTR_W-1:0] next_idx3 = next_idx2 + {{(LSQ_PTR_W-1){1'b0}}, is_mem_op[2]};

    wire [AQ_PTR_W-1:0] next_aq0 = aq_tail_r;
    wire [AQ_PTR_W-1:0] next_aq1 = aq_tail_r + {{(AQ_PTR_W-1){1'b0}}, is_mem_op[0]};
    wire [AQ_PTR_W-1:0] next_aq2 = next_aq1 + {{(AQ_PTR_W-1){1'b0}}, is_mem_op[1]};
    wire [AQ_PTR_W-1:0] next_aq3 = next_aq2 + {{(AQ_PTR_W-1){1'b0}}, is_mem_op[2]};

    // ================================================================
    // OUTPUT ASSIGNMENTS
    // ================================================================
    assign aq_valid   = !aq_empty_w;
    assign aq_lsq_idx = aq_data[aq_head_r];

    wire [LSQ_PTR_W-1:0] aq_front = aq_data[aq_head_r];
    assign aq_phys_rs1 = e_phys_rs1[aq_front];
    assign aq_phys_rs2 = e_phys_rs2[aq_front];
    assign aq_imm      = e_imm     [aq_front];
    assign aq_funct3   = e_funct3  [aq_front];
    assign aq_is_load  = e_is_load [aq_front];
    assign aq_is_store = e_is_store[aq_front];

    // ================================================================
    // AGE COMPARISON
    // ================================================================
    function automatic older_than;
        input [7:0] a, b;
        begin
            older_than = (a != b) && (((b - a) & 8'h80) == 8'h00);
        end
    endfunction

    // ================================================================
    // STORE-TO-LOAD FORWARDING
    // ================================================================
    reg                  load_issue_valid;
    reg [LSQ_PTR_W-1:0]  load_issue_idx;
    reg                  load_fwd_hit;
    reg [31:0]           load_fwd_data;
    reg [7:0]            load_fwd_seq;
    reg                  load_conflict;
    reg [7:0]            load_conflict_seq;

    integer ci, si;

    always @(*) begin
        load_issue_valid  = 1'b0;
        load_issue_idx    = {LSQ_PTR_W{1'b0}};
        load_fwd_hit      = 1'b0;
        load_fwd_data     = 32'b0;
        load_fwd_seq      = 8'b0;
        load_conflict     = 1'b0;
        load_conflict_seq = 8'b0;

        for (ci = 0; ci < LSQ_DEPTH; ci = ci + 1) begin
            if (e_valid[ci] && e_is_load[ci] && e_state[ci] == ST_ADDR_READY) begin
                if (!load_issue_valid || older_than(e_seq_num[ci], e_seq_num[load_issue_idx])) begin
                    load_issue_valid = 1'b1;
                    load_issue_idx   = ci[LSQ_PTR_W-1:0];
                end
            end
        end

        if (load_issue_valid) begin
            for (si = 0; si < LSQ_DEPTH; si = si + 1) begin
                if (e_valid[si] && e_is_store[si] && older_than(e_seq_num[si], e_seq_num[load_issue_idx])) begin
                    if (e_addr_valid[si]) begin
                        if (e_addr[si] == e_addr[load_issue_idx]) begin
                            if (e_data_valid[si]) begin
                                if (!load_fwd_hit || older_than(load_fwd_seq, e_seq_num[si])) begin
                                    load_fwd_hit  = 1'b1;
                                    load_fwd_data = e_data[si];
                                    load_fwd_seq  = e_seq_num[si];
                                end
                            end else begin
                                if (!load_conflict || older_than(load_conflict_seq, e_seq_num[si])) begin
                                    load_conflict     = 1'b1;
                                    load_conflict_seq = e_seq_num[si];
                                end
                            end
                        end
                    end else begin
                        if (!load_conflict || older_than(load_conflict_seq, e_seq_num[si])) begin
                            load_conflict     = 1'b1;
                            load_conflict_seq = e_seq_num[si];
                        end
                    end
                end
            end

            if (load_conflict && load_fwd_hit) begin
                if (!older_than(load_fwd_seq, load_conflict_seq)) load_issue_valid = 1'b0;
            end else if (load_conflict && !load_fwd_hit) begin
                load_issue_valid = 1'b0;
            end
        end
    end

    // ================================================================
    // COMBINATIONAL STORE DONE LOGIC (Deadlock Fix)
    // Constantly broadcasts any store that has both Address and Data
    // ready but hasn't been committed by the ROB yet.
    // ================================================================
    integer sdv_i;
    always @(*) begin
        store_done_valid   = 1'b0;
        store_done_rob_idx = {ROB_PTR_W{1'b0}};
        for (sdv_i = 0; sdv_i < LSQ_DEPTH; sdv_i = sdv_i + 1) begin
            if (e_valid[sdv_i] && e_is_store[sdv_i] && e_state[sdv_i] == ST_WAIT_COMMIT) begin
                store_done_valid   = 1'b1;
                store_done_rob_idx = e_rob_idx[sdv_i];
            end
        end
    end

    // ================================================================
    // STORE COMMIT SEARCH
    // ================================================================
    reg                  store_commit_found;
    reg [LSQ_PTR_W-1:0]  store_commit_idx;

    integer sci;
    always @(*) begin
        store_commit_found = 1'b0;
        store_commit_idx   = {LSQ_PTR_W{1'b0}};
        for (sci = 0; sci < LSQ_DEPTH; sci = sci + 1) begin
            if (!store_commit_found &&
                e_valid[sci]   && e_is_store[sci] &&
                e_rob_idx[sci] == store_commit_rob_idx &&
                e_state[sci]   == ST_WAIT_COMMIT) begin
                store_commit_found = 1'b1;
                store_commit_idx   = sci[LSQ_PTR_W-1:0];
            end
        end
    end

    // ================================================================
    // HELPERS & ARBITRATION
    // ================================================================
    function automatic [1:0] funct3_to_size;
        input [2:0] f3;
        begin
            case (f3[1:0])
                2'b00:   funct3_to_size = 2'b00;
                2'b01:   funct3_to_size = 2'b01;
                default: funct3_to_size = 2'b10;
            endcase
        end
    endfunction

    function automatic [31:0] extend_load;
        input [31:0] raw;
        input [2:0]  f3;
        begin
            case (f3)
                3'b000:  extend_load = {{24{raw[7]}},  raw[7:0]};
                3'b001:  extend_load = {{16{raw[15]}}, raw[15:0]};
                3'b010:  extend_load = raw;
                3'b100:  extend_load = {24'b0, raw[7:0]};
                3'b101:  extend_load = {16'b0, raw[15:0]};
                default: extend_load = raw;
            endcase
        end
    endfunction

    // Search for committed stores ready to write to memory (ST_MEM_STORE)
    reg                  store_mem_found;
    reg [LSQ_PTR_W-1:0]  store_mem_idx;
    integer smi;
    always @(*) begin
        store_mem_found = 1'b0;
        store_mem_idx   = {LSQ_PTR_W{1'b0}};
        for (smi = 0; smi < LSQ_DEPTH; smi = smi + 1) begin
            if (!store_mem_found &&
                e_valid[smi] && e_is_store[smi] &&
                e_state[smi] == ST_MEM_STORE) begin
                store_mem_found = 1'b1;
                store_mem_idx   = smi[LSQ_PTR_W-1:0];
            end
        end
    end

    wire store_mem_go = store_mem_found;

    wire load_mem_go  = load_issue_valid && !load_fwd_hit && !load_conflict;

    always @(*) begin
        mem_req_valid   = 1'b0;
        mem_req_we      = 1'b0;
        mem_req_addr    = 32'b0;
        mem_req_wdata   = 32'b0;
        mem_req_size    = 2'b10;
        mem_req_lsq_idx = {LSQ_PTR_W{1'b0}};

        if (store_mem_go) begin
            mem_req_valid   = 1'b1;
            mem_req_we      = 1'b1;
            mem_req_addr    = e_addr [store_mem_idx];
            mem_req_wdata   = e_data [store_mem_idx];
            mem_req_size    = funct3_to_size(e_funct3[store_mem_idx]);
            mem_req_lsq_idx = store_mem_idx;
        end else if (load_mem_go) begin
            mem_req_valid   = 1'b1;
            mem_req_we      = 1'b0;
            mem_req_addr    = e_addr [load_issue_idx];
            mem_req_size    = funct3_to_size(e_funct3[load_issue_idx]);
            mem_req_lsq_idx = load_issue_idx;
        end
    end

    // ================================================================
    // MAIN SEQUENTIAL BLOCK
    // ================================================================
    integer k;

    always @(posedge clk or posedge rst) begin : LSQ_SEQ
        reg [LSQ_PTR_W:0]   nc;
        reg [LSQ_PTR_W-1:0] new_tail;
        reg [LSQ_PTR_W:0]   new_count;
        reg                 free_head;
        reg [LSQ_PTR_W-1:0] slot;
        reg                 did_aq_pop;   
        integer             m;

        if (rst) begin
            head       <= {LSQ_PTR_W{1'b0}};
            tail       <= {LSQ_PTR_W{1'b0}};
            count      <= {(LSQ_PTR_W+1){1'b0}};
            aq_head_r  <= {AQ_PTR_W{1'b0}};
            aq_tail_r  <= {AQ_PTR_W{1'b0}};
            aq_count_r <= {(AQ_PTR_W+1){1'b0}};
            cdb_valid  <= 1'b0;
            
            for (k = 0; k < LSQ_DEPTH; k = k + 1) begin
                e_valid     [k] <= 1'b0;
                e_state     [k] <= ST_IDLE;
                e_addr_valid[k] <= 1'b0;
                e_data_valid[k] <= 1'b0;
            end

        end else begin

            cdb_valid    <= 1'b0;
            did_aq_pop   = 1'b0;

            // 1. FLUSH
            if (flush) begin
                new_tail  = head;
                new_count = {(LSQ_PTR_W+1){1'b0}};

                for (m = 0; m < LSQ_DEPTH; m = m + 1) begin : FLUSH_WALK
                    slot = head + m[LSQ_PTR_W-1:0];
                    if (e_valid[slot]) begin
                        if (e_seq_num[slot] == flush_seq_num ||
                            older_than(e_seq_num[slot], flush_seq_num)) begin
                            new_count = new_count + 1;
                            new_tail  = slot + 1;
                        end else begin
                            e_valid[slot] <= 1'b0;
                            e_state[slot] <= ST_IDLE;
                        end
                    end
                end

                tail       <= new_tail;
                count      <= new_count;
                aq_head_r  <= {AQ_PTR_W{1'b0}};
                aq_tail_r  <= {AQ_PTR_W{1'b0}};
                aq_count_r <= {(AQ_PTR_W+1){1'b0}};

            end else begin

                free_head = 1'b0;

                // 2. DISPATCH (4-Wide Processor mapped to pre-computed indices)
                if (|is_mem_op && !lsq_full) begin
                    // Slot 0
                    if (is_mem_op[0]) begin
                        e_valid     [next_idx0] <= 1'b1;
                        e_is_load   [next_idx0] <= dispatch_is_load[0];
                        e_is_store  [next_idx0] <= dispatch_is_store[0];
                        e_seq_num   [next_idx0] <= {2'b0, d_rob[0]};
                        e_rob_idx   [next_idx0] <= d_rob[0];
                        e_phys_rd   [next_idx0] <= d_rd[0];
                        e_phys_rs1  [next_idx0] <= d_rs1[0];
                        e_phys_rs2  [next_idx0] <= d_rs2[0];
                        e_imm       [next_idx0] <= d_imm[0];
                        e_funct3    [next_idx0] <= d_fn3[0];
                        e_addr_valid[next_idx0] <= 1'b0;
                        e_data_valid[next_idx0] <= dispatch_is_load[0];
                        e_state     [next_idx0] <= ST_WAIT_ADDR;
                        aq_data     [next_aq0]  <= next_idx0;
                    end
                    // Slot 1
                    if (is_mem_op[1]) begin
                        e_valid     [next_idx1] <= 1'b1;
                        e_is_load   [next_idx1] <= dispatch_is_load[1];
                        e_is_store  [next_idx1] <= dispatch_is_store[1];
                        e_seq_num   [next_idx1] <= {2'b0, d_rob[1]};
                        e_rob_idx   [next_idx1] <= d_rob[1];
                        e_phys_rd   [next_idx1] <= d_rd[1];
                        e_phys_rs1  [next_idx1] <= d_rs1[1];
                        e_phys_rs2  [next_idx1] <= d_rs2[1];
                        e_imm       [next_idx1] <= d_imm[1];
                        e_funct3    [next_idx1] <= d_fn3[1];
                        e_addr_valid[next_idx1] <= 1'b0;
                        e_data_valid[next_idx1] <= dispatch_is_load[1];
                        e_state     [next_idx1] <= ST_WAIT_ADDR;
                        aq_data     [next_aq1]  <= next_idx1;
                    end
                    // Slot 2
                    if (is_mem_op[2]) begin
                        e_valid     [next_idx2] <= 1'b1;
                        e_is_load   [next_idx2] <= dispatch_is_load[2];
                        e_is_store  [next_idx2] <= dispatch_is_store[2];
                        e_seq_num   [next_idx2] <= {2'b0, d_rob[2]};
                        e_rob_idx   [next_idx2] <= d_rob[2];
                        e_phys_rd   [next_idx2] <= d_rd[2];
                        e_phys_rs1  [next_idx2] <= d_rs1[2];
                        e_phys_rs2  [next_idx2] <= d_rs2[2];
                        e_imm       [next_idx2] <= d_imm[2];
                        e_funct3    [next_idx2] <= d_fn3[2];
                        e_addr_valid[next_idx2] <= 1'b0;
                        e_data_valid[next_idx2] <= dispatch_is_load[2];
                        e_state     [next_idx2] <= ST_WAIT_ADDR;
                        aq_data     [next_aq2]  <= next_idx2;
                    end
                    // Slot 3
                    if (is_mem_op[3]) begin
                        e_valid     [next_idx3] <= 1'b1;
                        e_is_load   [next_idx3] <= dispatch_is_load[3];
                        e_is_store  [next_idx3] <= dispatch_is_store[3];
                        e_seq_num   [next_idx3] <= {2'b0, d_rob[3]};
                        e_rob_idx   [next_idx3] <= d_rob[3];
                        e_phys_rd   [next_idx3] <= d_rd[3];
                        e_phys_rs1  [next_idx3] <= d_rs1[3];
                        e_phys_rs2  [next_idx3] <= d_rs2[3];
                        e_imm       [next_idx3] <= d_imm[3];
                        e_funct3    [next_idx3] <= d_fn3[3];
                        e_addr_valid[next_idx3] <= 1'b0;
                        e_data_valid[next_idx3] <= dispatch_is_load[3];
                        e_state     [next_idx3] <= ST_WAIT_ADDR;
                        aq_data     [next_aq3]  <= next_idx3;
                    end

                    tail      <= tail + {{(LSQ_PTR_W-3){1'b0}}, actual_dispatched};
                    aq_tail_r <= aq_tail_r + {{(AQ_PTR_W-3){1'b0}}, actual_dispatched};
                end

                // 3. ADDRESS QUEUE POP
                if (agu_pop && !aq_empty_w) begin
                    aq_head_r <= aq_head_r + 1;
                    did_aq_pop = 1'b1;
                end
    
                // 4. AGU ADDRESS WRITEBACK
                if (agu_wb_valid) begin
                    e_addr      [agu_wb_lsq_idx] <= agu_wb_addr;
                    e_addr_valid[agu_wb_lsq_idx] <= 1'b1;
                    
                     // Capture store data from AGU if available
                    if (e_is_store[agu_wb_lsq_idx] && agu_wb_data_valid && !e_data_valid[agu_wb_lsq_idx]) begin
                        e_data      [agu_wb_lsq_idx] <= agu_wb_store_data;
                        e_data_valid[agu_wb_lsq_idx] <= 1'b1;
                    end

                    
                    if (e_is_store[agu_wb_lsq_idx]) begin
                        if (e_data_valid[agu_wb_lsq_idx] || agu_wb_data_valid) begin
                            e_state[agu_wb_lsq_idx] <= ST_WAIT_COMMIT;
                        end else begin
                            e_state[agu_wb_lsq_idx] <= ST_ADDR_READY;
                        end
                    end else begin
                        e_state[agu_wb_lsq_idx] <= ST_ADDR_READY;
                    end
                end

                // 5. CDB SNOOP - capture store data
                for (k = 0; k < LSQ_DEPTH; k = k + 1) begin
                    if (e_valid[k] && e_is_store[k] && !e_data_valid[k]) begin
                        if (cdb_fu0_valid && cdb_fu0_phys_reg == e_phys_rs2[k]) begin
                            e_data      [k] <= cdb_fu0_result;
                            e_data_valid[k] <= 1'b1;
                            if (e_addr_valid[k]) e_state[k] <= ST_WAIT_COMMIT;
                        end else if (cdb_fu1_valid && cdb_fu1_phys_reg == e_phys_rs2[k]) begin
                            e_data      [k] <= cdb_fu1_result;
                            e_data_valid[k] <= 1'b1;
                            if (e_addr_valid[k]) e_state[k] <= ST_WAIT_COMMIT;
                        end else if (cdb_fu2_valid && cdb_fu2_phys_reg == e_phys_rs2[k]) begin
                            e_data      [k] <= cdb_fu2_result;
                            e_data_valid[k] <= 1'b1;
                            if (e_addr_valid[k]) e_state[k] <= ST_WAIT_COMMIT;
                        end else if (cdb_fu3_valid && cdb_fu3_phys_reg == e_phys_rs2[k]) begin
                            e_data      [k] <= cdb_fu3_result;
                            e_data_valid[k] <= 1'b1;
                            if (e_addr_valid[k]) e_state[k] <= ST_WAIT_COMMIT;
                        end else if (cdb_bpu_valid && cdb_bpu_phys_reg == e_phys_rs2[k]) begin
                            e_data      [k] <= cdb_bpu_result;
                            e_data_valid[k] <= 1'b1;
                            if (e_addr_valid[k]) e_state[k] <= ST_WAIT_COMMIT;
                        end else if (cdb_lsq_snoop_valid && cdb_lsq_snoop_phys_reg == e_phys_rs2[k]) begin
                            e_data      [k] <= cdb_lsq_snoop_result;
                            e_data_valid[k] <= 1'b1;
                            if (e_addr_valid[k]) e_state[k] <= ST_WAIT_COMMIT;
                        end
                    end
                end

                // 6. LOAD ISSUE
                if (load_issue_valid) begin
                    if (load_fwd_hit && !mem_resp_valid) begin
                        e_state     [load_issue_idx] <= ST_FWD_DONE;
                        cdb_valid    <= 1'b1;
                        cdb_tag      <= e_seq_num [load_issue_idx];
                        cdb_phys_reg <= e_phys_rd [load_issue_idx];
                        cdb_result   <= extend_load(load_fwd_data, e_funct3[load_issue_idx]);
                    end else if (!load_fwd_hit && load_mem_go && mem_req_ready) begin
                        e_state[load_issue_idx] <= ST_MEM_WAIT;
                    end
                end

                // 7. MEMORY LOAD RESPONSE → CDB
                if (mem_resp_valid) begin
                    if (e_valid [mem_resp_lsq_idx] &&
                        e_is_load[mem_resp_lsq_idx] &&
                        e_state  [mem_resp_lsq_idx] == ST_MEM_WAIT) begin
                        e_state     [mem_resp_lsq_idx] <= ST_DONE;
                        cdb_valid    <= 1'b1;
                        cdb_tag      <= e_seq_num [mem_resp_lsq_idx];
                        cdb_phys_reg <= e_phys_rd [mem_resp_lsq_idx];
                        cdb_result   <= extend_load(mem_resp_data, e_funct3[mem_resp_lsq_idx]);
                    end
                end

                // 8a. STORE COMMIT → ST_MEM_STORE (latch commit)
                if (store_commit_valid && store_commit_found) begin
                    e_state[store_commit_idx] <= ST_MEM_STORE;
                end

                // 8b. ST_MEM_STORE → ST_DONE (memory accepts)
                if (store_mem_go && mem_req_ready) begin
                    e_state[store_mem_idx] <= ST_DONE;
                end

                // 9. FREE HEAD
                if (e_valid[head] &&
                    (e_state[head] == ST_DONE ||
                     e_state[head] == ST_FWD_DONE)) begin
                    e_valid[head] <= 1'b0;
                    e_state[head] <= ST_IDLE;
                    head          <= head + 1;
                    free_head     = 1'b1;
                end

                // --- COUNT UPDATES ---
                begin : AQ_COUNT_UPDATE
                    reg [AQ_PTR_W:0] naq;
                    naq = aq_count_r;
                    naq = naq + {{(AQ_PTR_W-2){1'b0}}, actual_dispatched};
                    if (did_aq_pop)   naq = naq - 1;
                    aq_count_r <= naq;
                end

                nc = count;
                nc = nc + {{(LSQ_PTR_W-2){1'b0}}, actual_dispatched};
                if (free_head)    nc = nc - 1;
                count <= nc;

            end // !flush
        end // !rst
    end // LSQ_SEQ

endmodule