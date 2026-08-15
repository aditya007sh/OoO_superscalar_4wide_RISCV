/*module ROB #(
    parameter ROB_DEPTH  = 64,
    parameter ROB_PTR_W  = 6,
    parameter LSQ_PTR_W  = 5
)(
    input  wire clk,
    input  wire rst,

    // PORT A - DISPATCH
    input  wire [3:0]   dispatch_valid,
    input  wire [3:0]   dispatch_is_alu,
    input  wire [3:0]   dispatch_is_load,
    input  wire [3:0]   dispatch_is_store,
    input  wire [3:0]   dispatch_is_branch,
    input  wire [3:0]   dispatch_is_jal,
    input  wire [3:0]   dispatch_is_jalr,
    input  wire [23:0]  dispatch_phys_rd,
    input  wire [23:0]  dispatch_old_phys_rd,
    input  wire [3:0]   dispatch_rd_valid,
    input  wire [31:0]  dispatch_pc0,
    input  wire [31:0]  dispatch_pc1,
    input  wire [31:0]  dispatch_pc2,
    input  wire [31:0]  dispatch_pc3,
    input  wire [19:0]  dispatch_arch_rd,

    output wire [ROB_PTR_W-1:0] rob_idx_out0,
    output wire [ROB_PTR_W-1:0] rob_idx_out1,
    output wire [ROB_PTR_W-1:0] rob_idx_out2,
    output wire [ROB_PTR_W-1:0] rob_idx_out3,
    output wire         rob_full,

    // PORT B - CDB WRITEBACK
    input  wire         cdb_fu0_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu0_rob_idx,
    input  wire [31:0]  cdb_fu0_result,

    input  wire         cdb_fu1_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu1_rob_idx,
    input  wire [31:0]  cdb_fu1_result,

    input  wire         cdb_fu2_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu2_rob_idx,
    input  wire [31:0]  cdb_fu2_result,

    input  wire         cdb_fu3_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu3_rob_idx,
    input  wire [31:0]  cdb_fu3_result,

    input  wire         cdb_bpu_valid,
    input  wire [ROB_PTR_W-1:0] cdb_bpu_rob_idx,
    input  wire [31:0]  cdb_bpu_result,
    input  wire         cdb_bpu_mispredict,
    input  wire [31:0]  cdb_bpu_correct_pc,

    input  wire         cdb_lsq_valid,
    input  wire [ROB_PTR_W-1:0] cdb_lsq_rob_idx,
    input  wire [31:0]  cdb_lsq_result,

    // PORT C - COMMIT (4-wide)
    output reg  [3:0]   commit_valid,
    output reg  [19:0]  commit_arch_rd,
    output reg  [23:0]  commit_phys_rd,
    output reg  [127:0] commit_result,
    output reg  [3:0]   commit_rd_valid,
    output reg  [3:0]   commit_free_valid,
    output reg  [23:0]  commit_old_phys_rd,
    output reg  [3:0]   commit_store_valid,
    output reg  [4*ROB_PTR_W-1:0] commit_store_rob_idx,

    // PORT D - FLUSH
    output reg          flush,
    output reg  [7:0]   flush_seq_num,
    output reg  [31:0]  flush_correct_pc,
    output reg  [3:0]   flush_free_valid,
    output reg  [23:0]  flush_free_phys_rd,

    // New ROB input:
    input  wire        store_done_valid,
    input  wire [ROB_PTR_W-1:0] store_done_rob_idx,

    // PORT E - DEBUG
    output wire [ROB_PTR_W-1:0] dbg_head,
    output wire [ROB_PTR_W-1:0] dbg_tail,
    output wire [ROB_PTR_W:0]   dbg_count
);

    localparam ST_IDLE     = 2'd0;
    localparam ST_BUSY     = 2'd1;
    localparam ST_COMPLETE = 2'd2;
    localparam ST_COMMIT   = 2'd3;

    reg [1:0]  r_state       [0:ROB_DEPTH-1];
    reg        r_valid       [0:ROB_DEPTH-1];
    reg        r_is_alu      [0:ROB_DEPTH-1];
    reg        r_is_load     [0:ROB_DEPTH-1];
    reg        r_is_store    [0:ROB_DEPTH-1];
    reg        r_is_branch   [0:ROB_DEPTH-1];
    reg        r_is_jal      [0:ROB_DEPTH-1];
    reg        r_is_jalr     [0:ROB_DEPTH-1];
    reg [4:0]  r_arch_rd     [0:ROB_DEPTH-1];
    reg [5:0]  r_phys_rd     [0:ROB_DEPTH-1];
    reg [5:0]  r_old_phys_rd [0:ROB_DEPTH-1];
    reg        r_rd_valid    [0:ROB_DEPTH-1];
    reg [31:0] r_result      [0:ROB_DEPTH-1];
    reg        r_mispredict  [0:ROB_DEPTH-1];
    reg [31:0] r_correct_pc  [0:ROB_DEPTH-1];
    reg [31:0] r_pc          [0:ROB_DEPTH-1];

    reg [ROB_PTR_W-1:0] head;
    reg [ROB_PTR_W-1:0] tail;
    reg [ROB_PTR_W:0]   count;

    assign dbg_head  = head;
    assign dbg_tail  = tail;
    assign dbg_count = count;

    // Dispatch slot indices
    wire [ROB_PTR_W-1:0] slot0 = tail;
    wire [ROB_PTR_W-1:0] slot1 = tail + {{(ROB_PTR_W-1){1'b0}}, dispatch_valid[0]};
    wire [ROB_PTR_W-1:0] slot2 = slot1 + {{(ROB_PTR_W-1){1'b0}}, dispatch_valid[1]};
    wire [ROB_PTR_W-1:0] slot3 = slot2 + {{(ROB_PTR_W-1){1'b0}}, dispatch_valid[2]};

    assign rob_idx_out0 = slot0;
    assign rob_idx_out1 = slot1;
    assign rob_idx_out2 = slot2;
    assign rob_idx_out3 = slot3;

    // Commit readiness check for up to 4 entries from head
    wire [ROB_PTR_W-1:0] h0 = head;
    wire [ROB_PTR_W-1:0] h1 = head + 1;
    wire [ROB_PTR_W-1:0] h2 = head + 2;
    wire [ROB_PTR_W-1:0] h3 = head + 3;

    wire c0_ready = r_valid[h0] && (r_state[h0] == ST_COMPLETE);
    wire c1_ready = r_valid[h1] && (r_state[h1] == ST_COMPLETE);
    wire c2_ready = r_valid[h2] && (r_state[h2] == ST_COMPLETE);
    wire c3_ready = r_valid[h3] && (r_state[h3] == ST_COMPLETE);

    // Stop conditions: store or mispredict (commit that entry, then stop)
    wire c0_stop = r_is_store[h0] || r_mispredict[h0];
    wire c1_stop = r_is_store[h1] || r_mispredict[h1];
    wire c2_stop = r_is_store[h2] || r_mispredict[h2];

    // How many to commit (greedy, consecutive, stop after store/mispredict)
    wire [2:0] commit_count_comb;
    assign commit_count_comb = !c0_ready          ? 3'd0 :
                               c0_stop            ? 3'd1 :
                               !c1_ready          ? 3'd1 :
                               c1_stop            ? 3'd2 :
                               !c2_ready          ? 3'd2 :
                               c2_stop            ? 3'd3 :
                               !c3_ready          ? 3'd3 :
                                                    3'd4;

    wire head_commits = (commit_count_comb != 3'd0);
    assign rob_full = (count >= ROB_DEPTH - 4);

    // Will flush if any committing entry has mispredict
    wire will_flush = (commit_count_comb >= 3'd1 && r_mispredict[h0]) ||
                      (commit_count_comb >= 3'd2 && r_mispredict[h1]) ||
                      (commit_count_comb >= 3'd3 && r_mispredict[h2]) ||
                      (commit_count_comb >= 3'd4 && r_mispredict[h3]);

    // Unpack dispatch inputs
    wire [5:0] d_phys_rd     [0:3];
    wire [5:0] d_old_phys_rd [0:3];
    wire [4:0] d_arch_rd     [0:3];
    wire [2:0] dispatch_count = {2'b0, dispatch_valid[0]}
                               + {2'b0, dispatch_valid[1]}
                               + {2'b0, dispatch_valid[2]}
                               + {2'b0, dispatch_valid[3]};

    assign d_phys_rd[0]     = dispatch_phys_rd[5:0];
    assign d_phys_rd[1]     = dispatch_phys_rd[11:6];
    assign d_phys_rd[2]     = dispatch_phys_rd[17:12];
    assign d_phys_rd[3]     = dispatch_phys_rd[23:18];

    assign d_old_phys_rd[0] = dispatch_old_phys_rd[5:0];
    assign d_old_phys_rd[1] = dispatch_old_phys_rd[11:6];
    assign d_old_phys_rd[2] = dispatch_old_phys_rd[17:12];
    assign d_old_phys_rd[3] = dispatch_old_phys_rd[23:18];

    assign d_arch_rd[0] = dispatch_arch_rd[4:0];
    assign d_arch_rd[1] = dispatch_arch_rd[9:5];
    assign d_arch_rd[2] = dispatch_arch_rd[14:10];
    assign d_arch_rd[3] = dispatch_arch_rd[19:15];

    // Drain FSM storage
    reg [5:0] drain_prf    [0:ROB_DEPTH-2];
    reg [5:0] drain_head_r;
    reg [5:0] drain_count_r;
    reg       drain_active;

    integer i;

    always @(posedge clk or posedge rst) begin : ROB_SEQ

        reg [ROB_PTR_W-1:0] flush_walk_idx;
        reg [2:0]           flush_slot;
        integer             fw;

        if (rst) begin
            head  <= {ROB_PTR_W{1'b0}};
            tail  <= {ROB_PTR_W{1'b0}};
            count <= {(ROB_PTR_W+1){1'b0}};

            commit_valid        <= 4'b0;
            commit_free_valid   <= 4'b0;
            commit_store_valid  <= 4'b0;
            commit_rd_valid     <= 4'b0;
            commit_arch_rd      <= 20'b0;
            commit_phys_rd      <= 24'b0;
            commit_result       <= 128'b0;
            commit_old_phys_rd  <= 24'b0;
            commit_store_rob_idx <= {4*ROB_PTR_W{1'b0}};
            flush               <= 1'b0;
            flush_free_valid    <= 4'b0;
            drain_active        <= 1'b0;
            drain_head_r        <= 6'b0;
            drain_count_r       <= 6'b0;

            for (i = 0; i < ROB_DEPTH; i = i + 1) begin
                r_valid    [i] <= 1'b0;
                r_state    [i] <= ST_IDLE;
                r_mispredict[i]<= 1'b0;
            end

        end else begin

            flush              <= 1'b0;
            flush_free_valid   <= 4'b0;

            // 1. CDB WRITEBACK
            if (cdb_lsq_valid && r_valid[cdb_lsq_rob_idx]) begin
                r_state [cdb_lsq_rob_idx] <= ST_COMPLETE;
                r_result[cdb_lsq_rob_idx] <= cdb_lsq_result;
            end
            if (cdb_fu0_valid && r_valid[cdb_fu0_rob_idx]) begin
                r_state [cdb_fu0_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu0_rob_idx] <= cdb_fu0_result;
            end
            if (cdb_fu1_valid && r_valid[cdb_fu1_rob_idx]) begin
                r_state [cdb_fu1_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu1_rob_idx] <= cdb_fu1_result;
            end
            if (cdb_fu2_valid && r_valid[cdb_fu2_rob_idx]) begin
                r_state [cdb_fu2_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu2_rob_idx] <= cdb_fu2_result;
            end
            if (cdb_fu3_valid && r_valid[cdb_fu3_rob_idx]) begin
                r_state [cdb_fu3_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu3_rob_idx] <= cdb_fu3_result;
            end
            if (cdb_bpu_valid && r_valid[cdb_bpu_rob_idx]) begin
                r_state      [cdb_bpu_rob_idx] <= ST_COMPLETE;
                r_result     [cdb_bpu_rob_idx] <= cdb_bpu_result;
                r_mispredict [cdb_bpu_rob_idx] <= cdb_bpu_mispredict;
                r_correct_pc [cdb_bpu_rob_idx] <= cdb_bpu_correct_pc;
            end
            if (store_done_valid && r_valid[store_done_rob_idx]) begin
                r_state[store_done_rob_idx] <= ST_COMPLETE;
            end

            // 2. DISPATCH - gated with !will_flush
            if (!rob_full && !will_flush && !flush) begin

                if (dispatch_valid[0]) begin
                    r_valid      [slot0] <= 1'b1;
                    r_state      [slot0] <= ST_BUSY;
                    r_is_alu     [slot0] <= dispatch_is_alu[0];
                    r_is_load    [slot0] <= dispatch_is_load[0];
                    r_is_store   [slot0] <= dispatch_is_store[0];
                    r_is_branch  [slot0] <= dispatch_is_branch[0];
                    r_is_jal     [slot0] <= dispatch_is_jal[0];
                    r_is_jalr    [slot0] <= dispatch_is_jalr[0];
                    r_arch_rd    [slot0] <= d_arch_rd[0];
                    r_phys_rd    [slot0] <= d_phys_rd[0];
                    r_old_phys_rd[slot0] <= d_old_phys_rd[0];
                    r_rd_valid   [slot0] <= dispatch_rd_valid[0];
                    r_pc         [slot0] <= dispatch_pc0;
                    r_mispredict [slot0] <= 1'b0;
                    r_result     [slot0] <= 32'b0;
                end

                if (dispatch_valid[1]) begin
                    r_valid      [slot1] <= 1'b1;
                    r_state      [slot1] <= ST_BUSY;
                    r_is_alu     [slot1] <= dispatch_is_alu[1];
                    r_is_load    [slot1] <= dispatch_is_load[1];
                    r_is_store   [slot1] <= dispatch_is_store[1];
                    r_is_branch  [slot1] <= dispatch_is_branch[1];
                    r_is_jal     [slot1] <= dispatch_is_jal[1];
                    r_is_jalr    [slot1] <= dispatch_is_jalr[1];
                    r_arch_rd    [slot1] <= d_arch_rd[1];
                    r_phys_rd    [slot1] <= d_phys_rd[1];
                    r_old_phys_rd[slot1] <= d_old_phys_rd[1];
                    r_rd_valid   [slot1] <= dispatch_rd_valid[1];
                    r_pc         [slot1] <= dispatch_pc1;
                    r_mispredict [slot1] <= 1'b0;
                    r_result     [slot1] <= 32'b0;
                end

                if (dispatch_valid[2]) begin
                    r_valid      [slot2] <= 1'b1;
                    r_state      [slot2] <= ST_BUSY;
                    r_is_alu     [slot2] <= dispatch_is_alu[2];
                    r_is_load    [slot2] <= dispatch_is_load[2];
                    r_is_store   [slot2] <= dispatch_is_store[2];
                    r_is_branch  [slot2] <= dispatch_is_branch[2];
                    r_is_jal     [slot2] <= dispatch_is_jal[2];
                    r_is_jalr    [slot2] <= dispatch_is_jalr[2];
                    r_arch_rd    [slot2] <= d_arch_rd[2];
                    r_phys_rd    [slot2] <= d_phys_rd[2];
                    r_old_phys_rd[slot2] <= d_old_phys_rd[2];
                    r_rd_valid   [slot2] <= dispatch_rd_valid[2];
                    r_pc         [slot2] <= dispatch_pc2;
                    r_mispredict [slot2] <= 1'b0;
                    r_result     [slot2] <= 32'b0;
                end

                if (dispatch_valid[3]) begin
                    r_valid      [slot3] <= 1'b1;
                    r_state      [slot3] <= ST_BUSY;
                    r_is_alu     [slot3] <= dispatch_is_alu[3];
                    r_is_load    [slot3] <= dispatch_is_load[3];
                    r_is_store   [slot3] <= dispatch_is_store[3];
                    r_is_branch  [slot3] <= dispatch_is_branch[3];
                    r_is_jal     [slot3] <= dispatch_is_jal[3];
                    r_is_jalr    [slot3] <= dispatch_is_jalr[3];
                    r_arch_rd    [slot3] <= d_arch_rd[3];
                    r_phys_rd    [slot3] <= d_phys_rd[3];
                    r_old_phys_rd[slot3] <= d_old_phys_rd[3];
                    r_rd_valid   [slot3] <= dispatch_rd_valid[3];
                    r_pc         [slot3] <= dispatch_pc3;
                    r_mispredict [slot3] <= 1'b0;
                    r_result     [slot3] <= 32'b0;
                end

                tail <= tail + {{(ROB_PTR_W-3){1'b0}}, dispatch_count};
            end

            // 3. COMMIT (4-wide) - use temp vars to avoid full-width vs bit-select NBA
            begin : COMMIT_BLOCK
                reg [3:0]   t_cv, t_cfv, t_csv, t_crdv;
                reg [19:0]  t_car;
                reg [23:0]  t_cpr, t_copr;
                reg [127:0] t_cres;
                reg [4*ROB_PTR_W-1:0] t_csri;

                // Default: all zeros
                t_cv   = 4'b0;
                t_cfv  = 4'b0;
                t_csv  = 4'b0;
                t_crdv = 4'b0;
                t_car  = 20'b0;
                t_cpr  = 24'b0;
                t_copr = 24'b0;
                t_cres = 128'b0;
                t_csri = {4*ROB_PTR_W{1'b0}};

                if (commit_count_comb >= 3'd1) begin
                    r_valid[h0] <= 1'b0;
                    r_state[h0] <= ST_IDLE;
                    t_cv[0]          = 1'b1;
                    t_car[4:0]       = r_arch_rd[h0];
                    t_cpr[5:0]       = r_phys_rd[h0];
                    t_cres[31:0]     = r_result[h0];
                    t_crdv[0]        = r_rd_valid[h0];
                    if (r_rd_valid[h0] && r_old_phys_rd[h0] != 6'b0) begin
                        t_cfv[0]     = 1'b1;
                        t_copr[5:0]  = r_old_phys_rd[h0];
                    end
                    if (r_is_store[h0]) begin
                        t_csv[0]     = 1'b1;
                        t_csri[ROB_PTR_W-1:0] = h0;
                    end
                end

                if (commit_count_comb >= 3'd2) begin
                    r_valid[h1] <= 1'b0;
                    r_state[h1] <= ST_IDLE;
                    t_cv[1]           = 1'b1;
                    t_car[9:5]        = r_arch_rd[h1];
                    t_cpr[11:6]       = r_phys_rd[h1];
                    t_cres[63:32]     = r_result[h1];
                    t_crdv[1]         = r_rd_valid[h1];
                    if (r_rd_valid[h1] && r_old_phys_rd[h1] != 6'b0) begin
                        t_cfv[1]      = 1'b1;
                        t_copr[11:6]  = r_old_phys_rd[h1];
                    end
                    if (r_is_store[h1]) begin
                        t_csv[1]      = 1'b1;
                        t_csri[2*ROB_PTR_W-1:ROB_PTR_W] = h1;
                    end
                end

                if (commit_count_comb >= 3'd3) begin
                    r_valid[h2] <= 1'b0;
                    r_state[h2] <= ST_IDLE;
                    t_cv[2]            = 1'b1;
                    t_car[14:10]       = r_arch_rd[h2];
                    t_cpr[17:12]       = r_phys_rd[h2];
                    t_cres[95:64]      = r_result[h2];
                    t_crdv[2]          = r_rd_valid[h2];
                    if (r_rd_valid[h2] && r_old_phys_rd[h2] != 6'b0) begin
                        t_cfv[2]       = 1'b1;
                        t_copr[17:12]  = r_old_phys_rd[h2];
                    end
                    if (r_is_store[h2]) begin
                        t_csv[2]       = 1'b1;
                        t_csri[3*ROB_PTR_W-1:2*ROB_PTR_W] = h2;
                    end
                end

                if (commit_count_comb >= 3'd4) begin
                    r_valid[h3] <= 1'b0;
                    r_state[h3] <= ST_IDLE;
                    t_cv[3]             = 1'b1;
                    t_car[19:15]        = r_arch_rd[h3];
                    t_cpr[23:18]        = r_phys_rd[h3];
                    t_cres[127:96]      = r_result[h3];
                    t_crdv[3]           = r_rd_valid[h3];
                    if (r_rd_valid[h3] && r_old_phys_rd[h3] != 6'b0) begin
                        t_cfv[3]        = 1'b1;
                        t_copr[23:18]   = r_old_phys_rd[h3];
                    end
                    if (r_is_store[h3]) begin
                        t_csv[3]        = 1'b1;
                        t_csri[4*ROB_PTR_W-1:3*ROB_PTR_W] = h3;
                    end
                end

                // Single full-width NBA - no conflict
                commit_valid         <= t_cv;
                commit_arch_rd       <= t_car;
                commit_phys_rd       <= t_cpr;
                commit_result        <= t_cres;
                commit_rd_valid      <= t_crdv;
                commit_free_valid    <= t_cfv;
                commit_old_phys_rd   <= t_copr;
                commit_store_valid   <= t_csv;
                commit_store_rob_idx <= t_csri;

                // --- FLUSH on mispredict ---
                if (will_flush) begin
                    flush <= 1'b1;
                    if (r_mispredict[h0]) begin
                        flush_seq_num    <= {2'b0, h0};
                        flush_correct_pc <= r_correct_pc[h0];
                    end else if (r_mispredict[h1]) begin
                        flush_seq_num    <= {2'b0, h1};
                        flush_correct_pc <= r_correct_pc[h1];
                    end else if (r_mispredict[h2]) begin
                        flush_seq_num    <= {2'b0, h2};
                        flush_correct_pc <= r_correct_pc[h2];
                    end else begin
                        flush_seq_num    <= {2'b0, h3};
                        flush_correct_pc <= r_correct_pc[h3];
                    end

                    flush_slot         = 3'd0;
                    flush_free_valid  <= 4'b0;
                    flush_free_phys_rd <= 24'b0;
                    drain_active      <= 1'b0;
                    drain_head_r      <= 6'b0;
                    drain_count_r     <= 6'b0;

                    begin : FLUSH_LOOP
                        reg [5:0] drain_cnt_tmp;
                        reg [ROB_PTR_W-1:0] flush_start;
                        drain_cnt_tmp = 6'd0;
                        flush_start = head + {{(ROB_PTR_W-3){1'b0}}, commit_count_comb};

                        for (fw = 0; fw < ROB_DEPTH; fw = fw + 1) begin
                            flush_walk_idx = flush_start + fw[ROB_PTR_W-1:0];

                            if (flush_walk_idx == tail)
                                disable FLUSH_LOOP;

                            if (r_valid[flush_walk_idx]) begin
                                r_valid[flush_walk_idx] <= 1'b0;
                                r_state[flush_walk_idx] <= ST_IDLE;

                                if (r_rd_valid[flush_walk_idx] &&
                                    r_phys_rd[flush_walk_idx] != 6'b0) begin

                                    if (flush_slot <= 3'd3) begin
                                        case (flush_slot)
                                            3'd0: begin
                                                flush_free_phys_rd[5:0]   <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[0]       <= 1'b1;
                                            end
                                            3'd1: begin
                                                flush_free_phys_rd[11:6]  <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[1]       <= 1'b1;
                                            end
                                            3'd2: begin
                                                flush_free_phys_rd[17:12] <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[2]       <= 1'b1;
                                            end
                                            3'd3: begin
                                                flush_free_phys_rd[23:18] <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[3]       <= 1'b1;
                                            end
                                        endcase
                                        flush_slot = flush_slot + 1;
                                    end else begin
                                        drain_prf[drain_cnt_tmp] <= r_phys_rd[flush_walk_idx];
                                        drain_cnt_tmp = drain_cnt_tmp + 1;
                                        drain_active  <= 1'b1;
                                    end
                                end
                            end
                        end
                        drain_count_r <= drain_cnt_tmp;
                    end // FLUSH_LOOP

                    tail <= head + {{(ROB_PTR_W-3){1'b0}}, commit_count_comb};
                end

                if (commit_count_comb != 3'd0)
                    head <= head + {{(ROB_PTR_W-3){1'b0}}, commit_count_comb};
            end // COMMIT_BLOCK

            // Drain FSM
            if (drain_active && !flush) begin
                flush_free_valid   <= 4'b0;
                flush_free_phys_rd <= 24'b0;

                if (drain_count_r >= 6'd1) begin
                    flush_free_phys_rd[5:0]  <= drain_prf[drain_head_r];
                    flush_free_valid[0]      <= 1'b1;
                end
                if (drain_count_r >= 6'd2) begin
                    flush_free_phys_rd[11:6] <= drain_prf[drain_head_r + 1];
                    flush_free_valid[1]      <= 1'b1;
                end
                if (drain_count_r >= 6'd3) begin
                    flush_free_phys_rd[17:12]<= drain_prf[drain_head_r + 2];
                    flush_free_valid[2]      <= 1'b1;
                end
                if (drain_count_r >= 6'd4) begin
                    flush_free_phys_rd[23:18]<= drain_prf[drain_head_r + 3];
                    flush_free_valid[3]      <= 1'b1;
                end

                begin : DRAIN_ADVANCE
                    reg [5:0] sent;
                    sent = (drain_count_r >= 6'd4) ? 6'd4 : drain_count_r;
                    drain_head_r  <= drain_head_r  + sent;
                    drain_count_r <= drain_count_r - sent;
                    if (drain_count_r <= sent)
                        drain_active <= 1'b0;
                end
            end

            // 4. COUNT UPDATE
            begin : COUNT_UPDATE
                reg [ROB_PTR_W:0] nc;

                if (will_flush) begin
                    nc = {(ROB_PTR_W+1){1'b0}};
                end else begin
                    nc = count;
                    if (!rob_full && !will_flush && !flush)
                        nc = nc + {4'b0, dispatch_count};
                    nc = nc - {4'b0, commit_count_comb};
                end
                count <= nc;
            end

        end // !rst
    end // ROB_SEQ

endmodule*/
module ROB #(
    parameter ROB_DEPTH  = 64,
    parameter ROB_PTR_W  = 6,
    parameter LSQ_PTR_W  = 5
)(
    input  wire clk,
    input  wire rst,

    // PORT A - DISPATCH
    input  wire [3:0]   dispatch_valid,
    input  wire [3:0]   dispatch_is_alu,
    input  wire [3:0]   dispatch_is_mul,
    input  wire [3:0]   dispatch_is_load,
    input  wire [3:0]   dispatch_is_store,
    input  wire [3:0]   dispatch_is_branch,
    input  wire [3:0]   dispatch_is_jal,
    input  wire [3:0]   dispatch_is_jalr,
    input  wire [23:0]  dispatch_phys_rd,
    input  wire [23:0]  dispatch_old_phys_rd,
    input  wire [3:0]   dispatch_rd_valid,
    input  wire [31:0]  dispatch_pc0,
    input  wire [31:0]  dispatch_pc1,
    input  wire [31:0]  dispatch_pc2,
    input  wire [31:0]  dispatch_pc3,
    input  wire [19:0]  dispatch_arch_rd,

    output wire [ROB_PTR_W-1:0] rob_idx_out0,
    output wire [ROB_PTR_W-1:0] rob_idx_out1,
    output wire [ROB_PTR_W-1:0] rob_idx_out2,
    output wire [ROB_PTR_W-1:0] rob_idx_out3,
    output wire         rob_full,

    // PORT B - CDB WRITEBACK
    input  wire         cdb_fu0_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu0_rob_idx,
    input  wire [31:0]  cdb_fu0_result,

    input  wire         cdb_fu1_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu1_rob_idx,
    input  wire [31:0]  cdb_fu1_result,

    input  wire         cdb_fu2_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu2_rob_idx,
    input  wire [31:0]  cdb_fu2_result,

    input  wire         cdb_fu3_valid,
    input  wire [ROB_PTR_W-1:0] cdb_fu3_rob_idx,
    input  wire [31:0]  cdb_fu3_result,

    input  wire         cdb_bpu_valid,
    input  wire [ROB_PTR_W-1:0] cdb_bpu_rob_idx,
    input  wire [31:0]  cdb_bpu_result,
    input  wire         cdb_bpu_mispredict,
    input  wire [31:0]  cdb_bpu_correct_pc,

    input  wire         cdb_lsq_valid,
    input  wire [ROB_PTR_W-1:0] cdb_lsq_rob_idx,
    input  wire [31:0]  cdb_lsq_result,

    input  wire         cdb_mul_valid,
    input  wire [ROB_PTR_W-1:0] cdb_mul_rob_idx,
    input  wire [31:0]  cdb_mul_result,

    // PORT C - COMMIT (4-wide)
    output reg  [3:0]   commit_valid,
    output reg  [19:0]  commit_arch_rd,
    output reg  [23:0]  commit_phys_rd,
    output reg  [127:0] commit_result,
    output reg  [3:0]   commit_rd_valid,
    output reg  [3:0]   commit_free_valid,
    output reg  [23:0]  commit_old_phys_rd,
    output reg  [3:0]   commit_store_valid,
    output reg  [4*ROB_PTR_W-1:0] commit_store_rob_idx,

    // PORT D - FLUSH
    output reg          flush,
    output reg  [7:0]   flush_seq_num,
    output reg  [31:0]  flush_correct_pc,
    output reg  [3:0]   flush_free_valid,
    output reg  [23:0]  flush_free_phys_rd,

    // New ROB input:
    input  wire        store_done_valid,
    input  wire [ROB_PTR_W-1:0] store_done_rob_idx,

    // PORT E - DEBUG
    output wire [ROB_PTR_W-1:0] dbg_head,
    output wire [ROB_PTR_W-1:0] dbg_tail,
    output wire [ROB_PTR_W:0]   dbg_count
);

    localparam ST_IDLE     = 2'd0;
    localparam ST_BUSY     = 2'd1;
    localparam ST_COMPLETE = 2'd2;
    localparam ST_COMMIT   = 2'd3;

    reg [1:0]  r_state       [0:ROB_DEPTH-1];
    reg        r_valid       [0:ROB_DEPTH-1];
    reg        r_is_alu      [0:ROB_DEPTH-1];
    reg        r_is_load     [0:ROB_DEPTH-1];
    reg        r_is_store    [0:ROB_DEPTH-1];
    reg        r_is_branch   [0:ROB_DEPTH-1];
    reg        r_is_jal      [0:ROB_DEPTH-1];
    reg        r_is_jalr     [0:ROB_DEPTH-1];
    reg [4:0]  r_arch_rd     [0:ROB_DEPTH-1];
    reg [5:0]  r_phys_rd     [0:ROB_DEPTH-1];
    reg [5:0]  r_old_phys_rd [0:ROB_DEPTH-1];
    reg        r_rd_valid    [0:ROB_DEPTH-1];
    reg [31:0] r_result      [0:ROB_DEPTH-1];
    reg        r_mispredict  [0:ROB_DEPTH-1];
    reg [31:0] r_correct_pc  [0:ROB_DEPTH-1];
    reg [31:0] r_pc          [0:ROB_DEPTH-1];

    reg [ROB_PTR_W-1:0] head;
    reg [ROB_PTR_W-1:0] tail;
    reg [ROB_PTR_W:0]   count;

    assign dbg_head  = head;
    assign dbg_tail  = tail;
    assign dbg_count = count;

    // Dispatch slot indices
    wire [ROB_PTR_W-1:0] slot0 = tail;
    wire [ROB_PTR_W-1:0] slot1 = tail + {{(ROB_PTR_W-1){1'b0}}, dispatch_valid[0]};
    wire [ROB_PTR_W-1:0] slot2 = slot1 + {{(ROB_PTR_W-1){1'b0}}, dispatch_valid[1]};
    wire [ROB_PTR_W-1:0] slot3 = slot2 + {{(ROB_PTR_W-1){1'b0}}, dispatch_valid[2]};

    assign rob_idx_out0 = slot0;
    assign rob_idx_out1 = slot1;
    assign rob_idx_out2 = slot2;
    assign rob_idx_out3 = slot3;

    // Commit readiness check for up to 4 entries from head
    wire [ROB_PTR_W-1:0] h0 = head;
    wire [ROB_PTR_W-1:0] h1 = head + 1;
    wire [ROB_PTR_W-1:0] h2 = head + 2;
    wire [ROB_PTR_W-1:0] h3 = head + 3;

    wire c0_ready = r_valid[h0] && (r_state[h0] == ST_COMPLETE);
    wire c1_ready = r_valid[h1] && (r_state[h1] == ST_COMPLETE);
    wire c2_ready = r_valid[h2] && (r_state[h2] == ST_COMPLETE);
    wire c3_ready = r_valid[h3] && (r_state[h3] == ST_COMPLETE);

    // Stop conditions: store or mispredict (commit that entry, then stop)
    wire c0_stop = r_is_store[h0] || r_mispredict[h0];
    wire c1_stop = r_is_store[h1] || r_mispredict[h1];
    wire c2_stop = r_is_store[h2] || r_mispredict[h2];

    // How many to commit (greedy, consecutive, stop after store/mispredict)
    wire [2:0] commit_count_comb;
    assign commit_count_comb = !c0_ready          ? 3'd0 :
                               c0_stop            ? 3'd1 :
                               !c1_ready          ? 3'd1 :
                               c1_stop            ? 3'd2 :
                               !c2_ready          ? 3'd2 :
                               c2_stop            ? 3'd3 :
                               !c3_ready          ? 3'd3 :
                                                    3'd4;

    wire head_commits = (commit_count_comb != 3'd0);
    assign rob_full = (count >= ROB_DEPTH - 4);

    // Will flush if any committing entry has mispredict
    wire will_flush = (commit_count_comb >= 3'd1 && r_mispredict[h0]) ||
                      (commit_count_comb >= 3'd2 && r_mispredict[h1]) ||
                      (commit_count_comb >= 3'd3 && r_mispredict[h2]) ||
                      (commit_count_comb >= 3'd4 && r_mispredict[h3]);

    // Unpack dispatch inputs
    wire [5:0] d_phys_rd     [0:3];
    wire [5:0] d_old_phys_rd [0:3];
    wire [4:0] d_arch_rd     [0:3];
    wire [2:0] dispatch_count = {2'b0, dispatch_valid[0]}
                               + {2'b0, dispatch_valid[1]}
                               + {2'b0, dispatch_valid[2]}
                               + {2'b0, dispatch_valid[3]};

    assign d_phys_rd[0]     = dispatch_phys_rd[5:0];
    assign d_phys_rd[1]     = dispatch_phys_rd[11:6];
    assign d_phys_rd[2]     = dispatch_phys_rd[17:12];
    assign d_phys_rd[3]     = dispatch_phys_rd[23:18];

    assign d_old_phys_rd[0] = dispatch_old_phys_rd[5:0];
    assign d_old_phys_rd[1] = dispatch_old_phys_rd[11:6];
    assign d_old_phys_rd[2] = dispatch_old_phys_rd[17:12];
    assign d_old_phys_rd[3] = dispatch_old_phys_rd[23:18];

    assign d_arch_rd[0] = dispatch_arch_rd[4:0];
    assign d_arch_rd[1] = dispatch_arch_rd[9:5];
    assign d_arch_rd[2] = dispatch_arch_rd[14:10];
    assign d_arch_rd[3] = dispatch_arch_rd[19:15];

    // Drain FSM storage
    reg [5:0] drain_prf    [0:ROB_DEPTH-2];
    reg [5:0] drain_head_r;
    reg [5:0] drain_count_r;
    reg       drain_active;

    integer i;

    always @(posedge clk or posedge rst) begin : ROB_SEQ

        reg [ROB_PTR_W-1:0] flush_walk_idx;
        reg [2:0]           flush_slot;
        integer             fw;

        if (rst) begin
            head  <= {ROB_PTR_W{1'b0}};
            tail  <= {ROB_PTR_W{1'b0}};
            count <= {(ROB_PTR_W+1){1'b0}};

            commit_valid        <= 4'b0;
            commit_free_valid   <= 4'b0;
            commit_store_valid  <= 4'b0;
            commit_rd_valid     <= 4'b0;
            commit_arch_rd      <= 20'b0;
            commit_phys_rd      <= 24'b0;
            commit_result       <= 128'b0;
            commit_old_phys_rd  <= 24'b0;
            commit_store_rob_idx <= {4*ROB_PTR_W{1'b0}};
            flush               <= 1'b0;
            flush_free_valid    <= 4'b0;
            drain_active        <= 1'b0;
            drain_head_r        <= 6'b0;
            drain_count_r       <= 6'b0;

            for (i = 0; i < ROB_DEPTH; i = i + 1) begin
                r_valid    [i] <= 1'b0;
                r_state    [i] <= ST_IDLE;
                r_mispredict[i]<= 1'b0;
            end

        end else begin

            flush              <= 1'b0;
            flush_free_valid   <= 4'b0;

            // 1. CDB WRITEBACK
            if (cdb_lsq_valid && r_valid[cdb_lsq_rob_idx]) begin
                r_state [cdb_lsq_rob_idx] <= ST_COMPLETE;
                r_result[cdb_lsq_rob_idx] <= cdb_lsq_result;
            end
            if (cdb_fu0_valid && r_valid[cdb_fu0_rob_idx]) begin
                r_state [cdb_fu0_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu0_rob_idx] <= cdb_fu0_result;
            end
            if (cdb_fu1_valid && r_valid[cdb_fu1_rob_idx]) begin
                r_state [cdb_fu1_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu1_rob_idx] <= cdb_fu1_result;
            end
            if (cdb_fu2_valid && r_valid[cdb_fu2_rob_idx]) begin
                r_state [cdb_fu2_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu2_rob_idx] <= cdb_fu2_result;
            end
            if (cdb_fu3_valid && r_valid[cdb_fu3_rob_idx]) begin
                r_state [cdb_fu3_rob_idx] <= ST_COMPLETE;
                r_result[cdb_fu3_rob_idx] <= cdb_fu3_result;
            end
            if (cdb_bpu_valid && r_valid[cdb_bpu_rob_idx]) begin
                r_state      [cdb_bpu_rob_idx] <= ST_COMPLETE;
                r_result     [cdb_bpu_rob_idx] <= cdb_bpu_result;
                r_mispredict [cdb_bpu_rob_idx] <= cdb_bpu_mispredict;
                r_correct_pc [cdb_bpu_rob_idx] <= cdb_bpu_correct_pc;
            end
            if (store_done_valid && r_valid[store_done_rob_idx]) begin
                r_state[store_done_rob_idx] <= ST_COMPLETE;
            end
            if (cdb_mul_valid && r_valid[cdb_mul_rob_idx]) begin
                r_state [cdb_mul_rob_idx] <= ST_COMPLETE;
                r_result[cdb_mul_rob_idx] <= cdb_mul_result;
            end

            // 2. DISPATCH - gated with !will_flush
            if (!rob_full && !will_flush && !flush) begin

                if (dispatch_valid[0]) begin
                    r_valid      [slot0] <= 1'b1;
                    r_state      [slot0] <= ST_BUSY;
                    r_is_alu     [slot0] <= dispatch_is_alu[0];
                    r_is_load    [slot0] <= dispatch_is_load[0];
                    r_is_store   [slot0] <= dispatch_is_store[0];
                    r_is_branch  [slot0] <= dispatch_is_branch[0];
                    r_is_jal     [slot0] <= dispatch_is_jal[0];
                    r_is_jalr    [slot0] <= dispatch_is_jalr[0];
                    r_arch_rd    [slot0] <= d_arch_rd[0];
                    r_phys_rd    [slot0] <= d_phys_rd[0];
                    r_old_phys_rd[slot0] <= d_old_phys_rd[0];
                    r_rd_valid   [slot0] <= dispatch_rd_valid[0];
                    r_pc         [slot0] <= dispatch_pc0;
                    r_mispredict [slot0] <= 1'b0;
                    r_result     [slot0] <= 32'b0;
                end

                if (dispatch_valid[1]) begin
                    r_valid      [slot1] <= 1'b1;
                    r_state      [slot1] <= ST_BUSY;
                    r_is_alu     [slot1] <= dispatch_is_alu[1];
                    r_is_load    [slot1] <= dispatch_is_load[1];
                    r_is_store   [slot1] <= dispatch_is_store[1];
                    r_is_branch  [slot1] <= dispatch_is_branch[1];
                    r_is_jal     [slot1] <= dispatch_is_jal[1];
                    r_is_jalr    [slot1] <= dispatch_is_jalr[1];
                    r_arch_rd    [slot1] <= d_arch_rd[1];
                    r_phys_rd    [slot1] <= d_phys_rd[1];
                    r_old_phys_rd[slot1] <= d_old_phys_rd[1];
                    r_rd_valid   [slot1] <= dispatch_rd_valid[1];
                    r_pc         [slot1] <= dispatch_pc1;
                    r_mispredict [slot1] <= 1'b0;
                    r_result     [slot1] <= 32'b0;
                end

                if (dispatch_valid[2]) begin
                    r_valid      [slot2] <= 1'b1;
                    r_state      [slot2] <= ST_BUSY;
                    r_is_alu     [slot2] <= dispatch_is_alu[2];
                    r_is_load    [slot2] <= dispatch_is_load[2];
                    r_is_store   [slot2] <= dispatch_is_store[2];
                    r_is_branch  [slot2] <= dispatch_is_branch[2];
                    r_is_jal     [slot2] <= dispatch_is_jal[2];
                    r_is_jalr    [slot2] <= dispatch_is_jalr[2];
                    r_arch_rd    [slot2] <= d_arch_rd[2];
                    r_phys_rd    [slot2] <= d_phys_rd[2];
                    r_old_phys_rd[slot2] <= d_old_phys_rd[2];
                    r_rd_valid   [slot2] <= dispatch_rd_valid[2];
                    r_pc         [slot2] <= dispatch_pc2;
                    r_mispredict [slot2] <= 1'b0;
                    r_result     [slot2] <= 32'b0;
                end

                if (dispatch_valid[3]) begin
                    r_valid      [slot3] <= 1'b1;
                    r_state      [slot3] <= ST_BUSY;
                    r_is_alu     [slot3] <= dispatch_is_alu[3];
                    r_is_load    [slot3] <= dispatch_is_load[3];
                    r_is_store   [slot3] <= dispatch_is_store[3];
                    r_is_branch  [slot3] <= dispatch_is_branch[3];
                    r_is_jal     [slot3] <= dispatch_is_jal[3];
                    r_is_jalr    [slot3] <= dispatch_is_jalr[3];
                    r_arch_rd    [slot3] <= d_arch_rd[3];
                    r_phys_rd    [slot3] <= d_phys_rd[3];
                    r_old_phys_rd[slot3] <= d_old_phys_rd[3];
                    r_rd_valid   [slot3] <= dispatch_rd_valid[3];
                    r_pc         [slot3] <= dispatch_pc3;
                    r_mispredict [slot3] <= 1'b0;
                    r_result     [slot3] <= 32'b0;
                end

                tail <= tail + {{(ROB_PTR_W-3){1'b0}}, dispatch_count};
            end

            // 3. COMMIT (4-wide) - use temp vars to avoid full-width vs bit-select NBA
            begin : COMMIT_BLOCK
                reg [3:0]   t_cv, t_cfv, t_csv, t_crdv;
                reg [19:0]  t_car;
                reg [23:0]  t_cpr, t_copr;
                reg [127:0] t_cres;
                reg [4*ROB_PTR_W-1:0] t_csri;

                // Default: all zeros
                t_cv   = 4'b0;
                t_cfv  = 4'b0;
                t_csv  = 4'b0;
                t_crdv = 4'b0;
                t_car  = 20'b0;
                t_cpr  = 24'b0;
                t_copr = 24'b0;
                t_cres = 128'b0;
                t_csri = {4*ROB_PTR_W{1'b0}};

                if (commit_count_comb >= 3'd1) begin
                    r_valid[h0] <= 1'b0;
                    r_state[h0] <= ST_IDLE;
                    t_cv[0]          = 1'b1;
                    t_car[4:0]       = r_arch_rd[h0];
                    t_cpr[5:0]       = r_phys_rd[h0];
                    t_cres[31:0]     = r_result[h0];
                    t_crdv[0]        = r_rd_valid[h0];
                    if (r_rd_valid[h0] && r_old_phys_rd[h0] != 6'b0) begin
                        t_cfv[0]     = 1'b1;
                        t_copr[5:0]  = r_old_phys_rd[h0];
                    end
                    if (r_is_store[h0]) begin
                        t_csv[0]     = 1'b1;
                        t_csri[ROB_PTR_W-1:0] = h0;
                    end
                end

                if (commit_count_comb >= 3'd2) begin
                    r_valid[h1] <= 1'b0;
                    r_state[h1] <= ST_IDLE;
                    t_cv[1]           = 1'b1;
                    t_car[9:5]        = r_arch_rd[h1];
                    t_cpr[11:6]       = r_phys_rd[h1];
                    t_cres[63:32]     = r_result[h1];
                    t_crdv[1]         = r_rd_valid[h1];
                    if (r_rd_valid[h1] && r_old_phys_rd[h1] != 6'b0) begin
                        t_cfv[1]      = 1'b1;
                        t_copr[11:6]  = r_old_phys_rd[h1];
                    end
                    if (r_is_store[h1]) begin
                        t_csv[1]      = 1'b1;
                        t_csri[2*ROB_PTR_W-1:ROB_PTR_W] = h1;
                    end
                end

                if (commit_count_comb >= 3'd3) begin
                    r_valid[h2] <= 1'b0;
                    r_state[h2] <= ST_IDLE;
                    t_cv[2]            = 1'b1;
                    t_car[14:10]       = r_arch_rd[h2];
                    t_cpr[17:12]       = r_phys_rd[h2];
                    t_cres[95:64]      = r_result[h2];
                    t_crdv[2]          = r_rd_valid[h2];
                    if (r_rd_valid[h2] && r_old_phys_rd[h2] != 6'b0) begin
                        t_cfv[2]       = 1'b1;
                        t_copr[17:12]  = r_old_phys_rd[h2];
                    end
                    if (r_is_store[h2]) begin
                        t_csv[2]       = 1'b1;
                        t_csri[3*ROB_PTR_W-1:2*ROB_PTR_W] = h2;
                    end
                end

                if (commit_count_comb >= 3'd4) begin
                    r_valid[h3] <= 1'b0;
                    r_state[h3] <= ST_IDLE;
                    t_cv[3]             = 1'b1;
                    t_car[19:15]        = r_arch_rd[h3];
                    t_cpr[23:18]        = r_phys_rd[h3];
                    t_cres[127:96]      = r_result[h3];
                    t_crdv[3]           = r_rd_valid[h3];
                    if (r_rd_valid[h3] && r_old_phys_rd[h3] != 6'b0) begin
                        t_cfv[3]        = 1'b1;
                        t_copr[23:18]   = r_old_phys_rd[h3];
                    end
                    if (r_is_store[h3]) begin
                        t_csv[3]        = 1'b1;
                        t_csri[4*ROB_PTR_W-1:3*ROB_PTR_W] = h3;
                    end
                end

                // Single full-width NBA - no conflict
                commit_valid         <= t_cv;
                commit_arch_rd       <= t_car;
                commit_phys_rd       <= t_cpr;
                commit_result        <= t_cres;
                commit_rd_valid      <= t_crdv;
                commit_free_valid    <= t_cfv;
                commit_old_phys_rd   <= t_copr;
                commit_store_valid   <= t_csv;
                commit_store_rob_idx <= t_csri;

                // --- FLUSH on mispredict ---
                if (will_flush) begin
                    flush <= 1'b1;
                    if (r_mispredict[h0]) begin
                        flush_seq_num    <= {2'b0, h0};
                        flush_correct_pc <= r_correct_pc[h0];
                    end else if (r_mispredict[h1]) begin
                        flush_seq_num    <= {2'b0, h1};
                        flush_correct_pc <= r_correct_pc[h1];
                    end else if (r_mispredict[h2]) begin
                        flush_seq_num    <= {2'b0, h2};
                        flush_correct_pc <= r_correct_pc[h2];
                    end else begin
                        flush_seq_num    <= {2'b0, h3};
                        flush_correct_pc <= r_correct_pc[h3];
                    end

                    flush_slot         = 3'd0;
                    flush_free_valid  <= 4'b0;
                    flush_free_phys_rd <= 24'b0;
                    drain_active      <= 1'b0;
                    drain_head_r      <= 6'b0;
                    drain_count_r     <= 6'b0;

                    begin : FLUSH_LOOP
                        reg [5:0] drain_cnt_tmp;
                        reg [ROB_PTR_W-1:0] flush_start;
                        drain_cnt_tmp = 6'd0;
                        flush_start = head + {{(ROB_PTR_W-3){1'b0}}, commit_count_comb};

                        for (fw = 0; fw < ROB_DEPTH; fw = fw + 1) begin
                            flush_walk_idx = flush_start + fw[ROB_PTR_W-1:0];

                            if (flush_walk_idx == tail)
                                disable FLUSH_LOOP;

                            if (r_valid[flush_walk_idx]) begin
                                r_valid[flush_walk_idx] <= 1'b0;
                                r_state[flush_walk_idx] <= ST_IDLE;

                                if (r_rd_valid[flush_walk_idx] &&
                                    r_phys_rd[flush_walk_idx] != 6'b0) begin

                                    if (flush_slot <= 3'd3) begin
                                        case (flush_slot)
                                            3'd0: begin
                                                flush_free_phys_rd[5:0]   <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[0]       <= 1'b1;
                                            end
                                            3'd1: begin
                                                flush_free_phys_rd[11:6]  <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[1]       <= 1'b1;
                                            end
                                            3'd2: begin
                                                flush_free_phys_rd[17:12] <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[2]       <= 1'b1;
                                            end
                                            3'd3: begin
                                                flush_free_phys_rd[23:18] <= r_phys_rd[flush_walk_idx];
                                                flush_free_valid[3]       <= 1'b1;
                                            end
                                        endcase
                                        flush_slot = flush_slot + 1;
                                    end else begin
                                        drain_prf[drain_cnt_tmp] <= r_phys_rd[flush_walk_idx];
                                        drain_cnt_tmp = drain_cnt_tmp + 1;
                                        drain_active  <= 1'b1;
                                    end
                                end
                            end
                        end
                        drain_count_r <= drain_cnt_tmp;
                    end // FLUSH_LOOP

                    tail <= head + {{(ROB_PTR_W-3){1'b0}}, commit_count_comb};
                end

                if (commit_count_comb != 3'd0)
                    head <= head + {{(ROB_PTR_W-3){1'b0}}, commit_count_comb};
            end // COMMIT_BLOCK

            // Drain FSM
            if (drain_active && !flush) begin
                flush_free_valid   <= 4'b0;
                flush_free_phys_rd <= 24'b0;

                if (drain_count_r >= 6'd1) begin
                    flush_free_phys_rd[5:0]  <= drain_prf[drain_head_r];
                    flush_free_valid[0]      <= 1'b1;
                end
                if (drain_count_r >= 6'd2) begin
                    flush_free_phys_rd[11:6] <= drain_prf[drain_head_r + 1];
                    flush_free_valid[1]      <= 1'b1;
                end
                if (drain_count_r >= 6'd3) begin
                    flush_free_phys_rd[17:12]<= drain_prf[drain_head_r + 2];
                    flush_free_valid[2]      <= 1'b1;
                end
                if (drain_count_r >= 6'd4) begin
                    flush_free_phys_rd[23:18]<= drain_prf[drain_head_r + 3];
                    flush_free_valid[3]      <= 1'b1;
                end

                begin : DRAIN_ADVANCE
                    reg [5:0] sent;
                    sent = (drain_count_r >= 6'd4) ? 6'd4 : drain_count_r;
                    drain_head_r  <= drain_head_r  + sent;
                    drain_count_r <= drain_count_r - sent;
                    if (drain_count_r <= sent)
                        drain_active <= 1'b0;
                end
            end

            // 4. COUNT UPDATE
            begin : COUNT_UPDATE
                reg [ROB_PTR_W:0] nc;

                if (will_flush) begin
                    nc = {(ROB_PTR_W+1){1'b0}};
                end else begin
                    nc = count;
                    if (!rob_full && !will_flush && !flush)
                        nc = nc + {4'b0, dispatch_count};
                    nc = nc - {4'b0, commit_count_comb};
                end
                count <= nc;
            end

        end // !rst
    end // ROB_SEQ

endmodule

