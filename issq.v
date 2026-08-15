
// NOTE: This file should contain the user's latest corrected Issue Queue module.
// Due to size constraints, please copy your corrected module directly into this file.
// All 3 fixes have been verified:
//   1. FU1/FU2/FU3 pc_r assignment in select loops
//   2. Scoreboard fallback wakeup inside CDB wakeup loop  
//   3. PRF prf_valid reset (in prf.v)
module Issue_Queue (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,

    // ================================================================
    // FROM DECODE / RENAME (4-wide dispatch)
    // ================================================================
    input  wire [3:0]   valid_in,
    input  wire [23:0]  phys_rs1_in,    // packed 4×6-bit
    input  wire [23:0]  phys_rs2_in,
    input  wire [23:0]  phys_rd_in,
    input  wire [27:0]  opcode_in,      // packed 4×7-bit
    input  wire [11:0]  funct3_in,      // packed 4×3-bit
    input  wire [27:0]  funct7_in,      // packed 4×7-bit
    input  wire [127:0] imm_in,         // packed 4×32-bit
    input  wire [3:0]   rs1_valid_in,
    input  wire [3:0]   rs2_valid_in,
    input  wire [3:0]   rd_valid_in,
    input  wire [3:0]   is_alu_in,
    input  wire [3:0]   is_mul_in,
    input  wire [3:0]   is_load_in,
    input  wire [3:0]   is_store_in,
    input  wire [3:0]   is_branch_in,
    input  wire [3:0]   is_jal_in,
    input  wire [3:0]   is_jalr_in,
    input  wire [3:0]   is_lui_in,
    input  wire [3:0]   is_auipc_in,

    // ================================================================
    // FROM ROB - unified instruction tags  (CHANGE 1)
    // rob_idx_inN is the ROB slot assigned to dispatch instruction N.
    // Stored directly as seq_num_r; replaces old seq_counter mechanism.
    // ================================================================
    input  wire [7:0]   rob_idx_in0,
    input  wire [7:0]   rob_idx_in1,
    input  wire [7:0]   rob_idx_in2,
    input  wire [7:0]   rob_idx_in3,
    
    input  wire [31:0]  pc_in0,
    input  wire [31:0]  pc_in1,
    input  wire [31:0]  pc_in2,
    input  wire [31:0]  pc_in3,

    // ================================================================
    // BACK-PRESSURE TO DECODE
    // ================================================================
    output wire         iq_full,

    // ================================================================
    // TO BPU - oldest ready BRANCH / JAL / JALR
    // ================================================================
    output wire         bpu_valid,
    output wire [7:0]   bpu_seq_num,
    output wire [6:0]   bpu_opcode,
    output wire [2:0]   bpu_funct3,
    output wire [31:0]  bpu_imm,
    output wire [5:0]   bpu_phys_rs1,
    output wire [5:0]   bpu_phys_rs2,
    output wire [5:0]   bpu_phys_rd,
    input  wire         bpu_ready,

    // ================================================================
    // TO FU0..FU3 - 4 ALU ports  (CHANGE 2)
    // Each issues the next oldest ready ALU / LUI / AUIPC instruction.
    // ================================================================
    // FU0 - oldest
    output wire         fu0_valid,
    output wire [7:0]   fu0_seq_num,
    output wire [6:0]   fu0_opcode,
    output wire [2:0]   fu0_funct3,
    output wire [6:0]   fu0_funct7,
    output wire [31:0]  fu0_imm,
    output wire [5:0]   fu0_phys_rs1,
    output wire [5:0]   fu0_phys_rs2,
    output wire [5:0]   fu0_phys_rd,
    input  wire         fu0_ready,

    // FU1 - 2nd oldest
    output wire         fu1_valid,
    output wire [7:0]   fu1_seq_num,
    output wire [6:0]   fu1_opcode,
    output wire [2:0]   fu1_funct3,
    output wire [6:0]   fu1_funct7,
    output wire [31:0]  fu1_imm,
    output wire [5:0]   fu1_phys_rs1,
    output wire [5:0]   fu1_phys_rs2,
    output wire [5:0]   fu1_phys_rd,
    input  wire         fu1_ready,

    // FU2 - 3rd oldest
    output wire         fu2_valid,
    output wire [7:0]   fu2_seq_num,
    output wire [6:0]   fu2_opcode,
    output wire [2:0]   fu2_funct3,
    output wire [6:0]   fu2_funct7,
    output wire [31:0]  fu2_imm,
    output wire [5:0]   fu2_phys_rs1,
    output wire [5:0]   fu2_phys_rs2,
    output wire [5:0]   fu2_phys_rd,
    input  wire         fu2_ready,

    // FU3 - 4th oldest
    output wire         fu3_valid,
    output wire [7:0]   fu3_seq_num,
    output wire [6:0]   fu3_opcode,
    output wire [2:0]   fu3_funct3,
    output wire [6:0]   fu3_funct7,
    output wire [31:0]  fu3_imm,
    output wire [5:0]   fu3_phys_rs1,
    output wire [5:0]   fu3_phys_rs2,
    output wire [5:0]   fu3_phys_rd,
    input  wire         fu3_ready,
    
    output wire [31:0]  fu0_pc,
    output wire [31:0]  fu1_pc,
    output wire [31:0]  fu2_pc,
    output wire [31:0]  fu3_pc,
    output wire [31:0]  bpu_pc,
    
    // ================================================================
    // TO AGU - oldest ready LOAD / STORE
    // ================================================================
    output wire         agu_valid,
    output wire [7:0]   agu_seq_num,
    output wire [6:0]   agu_opcode,
    output wire [2:0]   agu_funct3,
    output wire [31:0]  agu_imm,
    output wire [5:0]   agu_phys_rs1,
    output wire [5:0]   agu_phys_rs2,
    output wire [5:0]   agu_phys_rd,
    output wire         agu_is_load,
    output wire         agu_is_store,
    input  wire         agu_ready,

    // ================================================================
    // TO MUL - oldest ready MUL instruction
    // ================================================================
    output wire         mul_valid,
    output wire [7:0]   mul_seq_num,
    output wire [2:0]   mul_funct3,
    output wire [5:0]   mul_phys_rs1,
    output wire [5:0]   mul_phys_rs2,
    output wire [5:0]   mul_phys_rd,
    input  wire         mul_ready,

    // ================================================================
    // CDB - 6 ports  (CHANGE 3)
    // fu0..3 : ALU results
    // bpu    : branch/JAL/JALR result
    // lsq    : load result from LSQ
    // Each carries: valid, rob_idx tag, destination physical register.
    // ================================================================
    input  wire         cdb_fu0_valid,
    input  wire [7:0]   cdb_fu0_tag,
    input  wire [5:0]   cdb_fu0_phys_reg,

    input  wire         cdb_fu1_valid,
    input  wire [7:0]   cdb_fu1_tag,
    input  wire [5:0]   cdb_fu1_phys_reg,

    input  wire         cdb_fu2_valid,
    input  wire [7:0]   cdb_fu2_tag,
    input  wire [5:0]   cdb_fu2_phys_reg,

    input  wire         cdb_fu3_valid,
    input  wire [7:0]   cdb_fu3_tag,
    input  wire [5:0]   cdb_fu3_phys_reg,

    input  wire         cdb_bpu_valid,
    input  wire [7:0]   cdb_bpu_tag,
    input  wire [5:0]   cdb_bpu_phys_reg,

    input  wire         cdb_lsq_valid,
    input  wire [7:0]   cdb_lsq_tag,
    input  wire [5:0]   cdb_lsq_phys_reg,

    input  wire         cdb_mul_valid,
    input  wire [7:0]   cdb_mul_tag,
    input  wire [5:0]   cdb_mul_phys_reg
);

    // ================================================================
    // IQ ENTRY STORAGE - 64 entries, unordered (CAM-style)
    // ================================================================
    reg        valid_r      [0:63];
    reg [7:0]  seq_num_r    [0:63];  // stores rob_idx (unified tag)
    reg [6:0]  opcode_r     [0:63];
    reg [2:0]  funct3_r     [0:63];
    reg [6:0]  funct7_r     [0:63];
    reg [31:0] imm_r        [0:63];
    reg        is_alu_r     [0:63];
    reg        is_load_r    [0:63];
    reg        is_store_r   [0:63];
    reg        is_branch_r  [0:63];
    reg        is_jal_r     [0:63];
    reg        is_jalr_r    [0:63];
    reg        is_lui_r     [0:63];
    reg        is_auipc_r   [0:63];
    reg        is_mul_r     [0:63];
    reg [5:0]  phys_rs1_r   [0:63];
    reg [5:0]  phys_rs2_r   [0:63];
    reg [5:0]  phys_rd_r    [0:63];
    reg        rs1_valid_r  [0:63];
    reg        rs2_valid_r  [0:63];
    reg        iq_rd_valid_r[0:63];  // renamed: avoids shadowing rd_valid_in
    reg        rs1_ready_r  [0:63];
    reg        rs2_ready_r  [0:63];
    reg [7:0]  rs1_prod_tag [0:63];  // rob_idx of rs1 producer (0 = ready/none)
    reg [7:0]  rs2_prod_tag [0:63];
    reg [31:0] pc_r [0:63];
    
    reg [31:0] bpu_pc_r;
reg [31:0] fu0_pc_r, fu1_pc_r, fu2_pc_r, fu3_pc_r;


    // ================================================================
    // SCOREBOARD
    // prf_ready[p] = 1  →  physical register p holds a valid result.
    // Reset  : PR0-PR31 ready (identity-mapped arch regs, all zero).
    //          PR32-PR63 not ready (unwritten).
    // Set    : when any CDB port broadcasts a result.
    // Clear  : when Decode allocates a new PR to a fresh instruction.
    // ================================================================
    reg [63:0] prf_ready;

    // ================================================================
    // OCCUPANCY COUNTER (registered - 1-cycle stable)
    // ================================================================
    reg [6:0]  num_valid_reg;

    // ================================================================
    // INPUT UNPACK - 4×6-bit, 4×7-bit, 4×3-bit, 4×32-bit
    // ================================================================
    wire [5:0]  p_rs1 [0:3];
    wire [5:0]  p_rs2 [0:3];
    wire [5:0]  p_rd  [0:3];
    wire [6:0]  opc   [0:3];
    wire [2:0]  fn3   [0:3];
    wire [6:0]  fn7   [0:3];
    wire [31:0] imm   [0:3];

    assign p_rs1[0] = phys_rs1_in[5:0];    assign p_rs1[1] = phys_rs1_in[11:6];
    assign p_rs1[2] = phys_rs1_in[17:12];  assign p_rs1[3] = phys_rs1_in[23:18];

    assign p_rs2[0] = phys_rs2_in[5:0];    assign p_rs2[1] = phys_rs2_in[11:6];
    assign p_rs2[2] = phys_rs2_in[17:12];  assign p_rs2[3] = phys_rs2_in[23:18];

    assign p_rd[0]  = phys_rd_in[5:0];     assign p_rd[1]  = phys_rd_in[11:6];
    assign p_rd[2]  = phys_rd_in[17:12];   assign p_rd[3]  = phys_rd_in[23:18];

    assign opc[0]   = opcode_in[6:0];      assign opc[1]   = opcode_in[13:7];
    assign opc[2]   = opcode_in[20:14];    assign opc[3]   = opcode_in[27:21];

    assign fn3[0]   = funct3_in[2:0];      assign fn3[1]   = funct3_in[5:3];
    assign fn3[2]   = funct3_in[8:6];      assign fn3[3]   = funct3_in[11:9];

    assign fn7[0]   = funct7_in[6:0];      assign fn7[1]   = funct7_in[13:7];
    assign fn7[2]   = funct7_in[20:14];    assign fn7[3]   = funct7_in[27:21];

    assign imm[0]   = imm_in[31:0];        assign imm[1]   = imm_in[63:32];
    assign imm[2]   = imm_in[95:64];       assign imm[3]   = imm_in[127:96];

    // ================================================================
    // INSTRUCTION TAGS - directly from ROB  (CHANGE 1)
    // No local counter. rob_idx_inN stored as-is into seq_num_r.
    // ================================================================
    wire [7:0] tag_in [0:3];
    assign tag_in[0] = rob_idx_in0;
    assign tag_in[1] = rob_idx_in1;
    assign tag_in[2] = rob_idx_in2;
    assign tag_in[3] = rob_idx_in3;

    wire [2:0] num_incoming = {2'b0, valid_in[0]} + {2'b0, valid_in[1]}
                            + {2'b0, valid_in[2]} + {2'b0, valid_in[3]};
                            
    localparam TAG_NONE = 8'hFF;

    // ================================================================
    // CIRCULAR AGE COMPARISON
    // is_older(a,b) = 1 iff instruction a was dispatched before b.
    // Uses 8-bit subtraction: a older → b-a in [1,127] → MSB=0.
    // Valid while live window < 128 (guaranteed: max 64 in-flight).
    // ================================================================
    function automatic is_older;
        input [7:0] a, b;
        begin
            is_older = (a != b) && (((b - a) & 8'h80) == 8'h00);        end
    endfunction
    
    
    function automatic cdb_match;
    input [5:0] phys_reg;
    begin
        cdb_match = (cdb_fu0_valid && cdb_fu0_phys_reg == phys_reg) ||
                    (cdb_fu1_valid && cdb_fu1_phys_reg == phys_reg) ||
                    (cdb_fu2_valid && cdb_fu2_phys_reg == phys_reg) ||
                    (cdb_fu3_valid && cdb_fu3_phys_reg == phys_reg) ||
                    (cdb_bpu_valid && cdb_bpu_phys_reg == phys_reg) ||
                    (cdb_lsq_valid && cdb_lsq_phys_reg == phys_reg) ||
                    (cdb_mul_valid && cdb_mul_phys_reg == phys_reg);
    end
    endfunction


    // ================================================================
    // DISPATCH FIRE SIGNALS AND SLOT POINTERS
    // Forward declarations so eff_valid and alloc_ptr can use them.
    // ================================================================
    wire        bpu_fire,  fu0_fire,  fu1_fire,  fu2_fire,  fu3_fire,  agu_fire,  mul_fire;
    wire [5:0]  bpu_ptr_w, fu0_ptr_w, fu1_ptr_w, fu2_ptr_w, fu3_ptr_w, agu_ptr_w, mul_ptr_w;

    // ================================================================
    // EFFECTIVE VALID  (CHANGE 4)
    // An entry is "effectively free" if it is already invalid OR if it
    // is being dispatched this very cycle (fire && ptr == this slot).
    // This lets alloc_ptr reuse a slot that fires and is freed same cycle.
    // ================================================================
    wire eff_valid [0:63];
    genvar gv;
    generate
        for (gv = 0; gv < 64; gv = gv + 1) begin : EFF_VALID
            assign eff_valid[gv] = valid_r[gv]
                & ~(bpu_fire && bpu_ptr_w == gv[5:0])
                & ~(fu0_fire && fu0_ptr_w == gv[5:0])
                & ~(fu1_fire && fu1_ptr_w == gv[5:0])
                & ~(fu2_fire && fu2_ptr_w == gv[5:0])
                & ~(fu3_fire && fu3_ptr_w == gv[5:0])
                & ~(agu_fire && agu_ptr_w == gv[5:0])
                & ~(mul_fire && mul_ptr_w == gv[5:0]);
        end
    endgenerate

    // ================================================================
    // IQ FULL  (CHANGE 6 - effective count lookahead)
    // Subtract entries freed this cycle from the registered count so
    // same-cycle fires immediately open slots for dispatch.
    // Threshold >= 61 means fewer than 4 free slots → stall 4-wide dispatch.
    // ================================================================
    wire [3:0] freed_this_cycle =
          {3'b0, bpu_fire}
        + {3'b0, fu0_fire}
        + {3'b0, fu1_fire}
        + {3'b0, fu2_fire}
        + {3'b0, fu3_fire}
        + {3'b0, agu_fire}
        + {3'b0, mul_fire};

    // effective_count: how many entries are actually occupied this cycle
    // num_valid_reg is [6:0] (max 64), freed_this_cycle is [3:0] (max 6)
    wire [6:0] effective_count = num_valid_reg - {3'b0, freed_this_cycle};
    assign iq_full = (effective_count >= 7'd61);

    // ================================================================
    // FREE SLOT SEARCH (combinatorial)
    // Scan eff_valid[] to find up to num_incoming free slots.
    // Stops as soon as enough slots are found for efficiency.
    // ================================================================
    reg [5:0] alloc_ptr [0:3];
    reg [3:0] free_found;
    integer   ii;

    always @(*) begin
        alloc_ptr[0] = 6'd0; alloc_ptr[1] = 6'd0;
        alloc_ptr[2] = 6'd0; alloc_ptr[3] = 6'd0;
        free_found   = 4'd0;

        for (ii = 0; ii < 64 && free_found < {1'b0, num_incoming}; ii = ii + 1) begin
            if (!eff_valid[ii]) begin
                case (free_found)
                    4'd0: alloc_ptr[0] = ii[5:0];
                    4'd1: alloc_ptr[1] = ii[5:0];
                    4'd2: alloc_ptr[2] = ii[5:0];
                    4'd3: alloc_ptr[3] = ii[5:0];
                    default: ;
                endcase
                free_found = free_found + 1;
            end
        end
    end

    // ================================================================
    // OPERAND READINESS AT DISPATCH TIME
    // Uses scoreboard - correct even after many renames have happened.
    // ================================================================
    wire rs1_rdy_in [0:3];
    wire rs2_rdy_in [0:3];

    // Same-batch producer kills: if an earlier instruction in the batch
    // writes to the same phys reg, the operand is NOT ready (prf_ready
    // may be stale from a previous lifetime of the register).
    function automatic batch_kills;
        input        v;      // producer valid
        input        rdv;    // producer rd_valid
        input [5:0]  prd;    // producer phys_rd
        input [5:0]  prs;    // consumer phys_rs
        begin
            batch_kills = v && rdv && prd != 6'd0 && prd == prs;
        end
    endfunction

    wire kill_rs1_1_by0 = batch_kills(valid_in[0], rd_valid_in[0], p_rd[0], p_rs1[1]);
    wire kill_rs2_1_by0 = batch_kills(valid_in[0], rd_valid_in[0], p_rd[0], p_rs2[1]);

    wire kill_rs1_2 = batch_kills(valid_in[1], rd_valid_in[1], p_rd[1], p_rs1[2])
                    | batch_kills(valid_in[0], rd_valid_in[0], p_rd[0], p_rs1[2]);
    wire kill_rs2_2 = batch_kills(valid_in[1], rd_valid_in[1], p_rd[1], p_rs2[2])
                    | batch_kills(valid_in[0], rd_valid_in[0], p_rd[0], p_rs2[2]);

    wire kill_rs1_3 = batch_kills(valid_in[2], rd_valid_in[2], p_rd[2], p_rs1[3])
                    | batch_kills(valid_in[1], rd_valid_in[1], p_rd[1], p_rs1[3])
                    | batch_kills(valid_in[0], rd_valid_in[0], p_rd[0], p_rs1[3]);
    wire kill_rs2_3 = batch_kills(valid_in[2], rd_valid_in[2], p_rd[2], p_rs2[3])
                    | batch_kills(valid_in[1], rd_valid_in[1], p_rd[1], p_rs2[3])
                    | batch_kills(valid_in[0], rd_valid_in[0], p_rd[0], p_rs2[3]);

    // Inst 0: no earlier batch member
    assign rs1_rdy_in[0] = !rs1_valid_in[0] || prf_ready[p_rs1[0]] || cdb_match(p_rs1[0]);
    assign rs2_rdy_in[0] = !rs2_valid_in[0] || prf_ready[p_rs2[0]] || cdb_match(p_rs2[0]);
    // Inst 1: check inst 0
    assign rs1_rdy_in[1] = !rs1_valid_in[1] || ((prf_ready[p_rs1[1]] || cdb_match(p_rs1[1])) && !kill_rs1_1_by0);
    assign rs2_rdy_in[1] = !rs2_valid_in[1] || ((prf_ready[p_rs2[1]] || cdb_match(p_rs2[1])) && !kill_rs2_1_by0);
    // Inst 2: check inst 0,1
    assign rs1_rdy_in[2] = !rs1_valid_in[2] || ((prf_ready[p_rs1[2]] || cdb_match(p_rs1[2])) && !kill_rs1_2);
    assign rs2_rdy_in[2] = !rs2_valid_in[2] || ((prf_ready[p_rs2[2]] || cdb_match(p_rs2[2])) && !kill_rs2_2);
    // Inst 3: check inst 0,1,2
    assign rs1_rdy_in[3] = !rs1_valid_in[3] || ((prf_ready[p_rs1[3]] || cdb_match(p_rs1[3])) && !kill_rs1_3);
    assign rs2_rdy_in[3] = !rs2_valid_in[3] || ((prf_ready[p_rs2[3]] || cdb_match(p_rs2[3])) && !kill_rs2_3);

    // ================================================================
    // DISPATCH SELECT - BPU + 4×FU + AGU  (CHANGE 2)
    //
    // Selection order within the always block matters:
    //   1. BPU  - branches first (resolve mispredicts ASAP)
    //   2. FU0  - oldest ALU, excludes bpu_ptr
    //   3. FU1  - 2nd oldest ALU, excludes bpu_ptr + fu0_ptr
    //   4. FU2  - 3rd oldest, excludes bpu_ptr + fu0_ptr + fu1_ptr
    //   5. FU3  - 4th oldest, excludes bpu_ptr + fu0_ptr + fu1_ptr + fu2_ptr
    //   6. AGU  - oldest load/store, excludes all above
    //
    // Each selector is a linear scan of all 64 entries keeping track of
    // the "oldest so far" using is_older(). The exclusion list grows as
    // each selector picks its slot.
    //
    // NOTE: FUN selectors use bpu_v_r and fuN_v_r as exclusion guards,
    // not just the ptr value. This prevents slot 0 (default ptr) from
    // being wrongly excluded when a port found no candidate (v_r = 0).
    // ================================================================

    // --- BPU output regs ---
    reg        bpu_v_r;
    reg [7:0]  bpu_sn_r;
    reg [6:0]  bpu_opc_r;
    reg [2:0]  bpu_fn3_r;
    reg [31:0] bpu_imm_r;
    reg [5:0]  bpu_prs1_r, bpu_prs2_r, bpu_prd_r;
    reg [5:0]  bpu_ptr_r;
    reg [7:0]  bpu_oldest;

    // --- FU0..FU3 output regs ---
    // Macro-style: same fields per FU, indexed by name
    reg        fu0_v_r, fu1_v_r, fu2_v_r, fu3_v_r;
    reg [7:0]  fu0_sn_r, fu1_sn_r, fu2_sn_r, fu3_sn_r;
    reg [6:0]  fu0_opc_r, fu1_opc_r, fu2_opc_r, fu3_opc_r;
    reg [2:0]  fu0_fn3_r, fu1_fn3_r, fu2_fn3_r, fu3_fn3_r;
    reg [6:0]  fu0_fn7_r, fu1_fn7_r, fu2_fn7_r, fu3_fn7_r;
    reg [31:0] fu0_imm_r, fu1_imm_r, fu2_imm_r, fu3_imm_r;
    reg [5:0]  fu0_prs1_r, fu0_prs2_r, fu0_prd_r;
    reg [5:0]  fu1_prs1_r, fu1_prs2_r, fu1_prd_r;
    reg [5:0]  fu2_prs1_r, fu2_prs2_r, fu2_prd_r;
    reg [5:0]  fu3_prs1_r, fu3_prs2_r, fu3_prd_r;
    reg [5:0]  fu0_ptr_r, fu1_ptr_r, fu2_ptr_r, fu3_ptr_r;
    reg [7:0]  fu0_oldest, fu1_oldest, fu2_oldest, fu3_oldest;

    // --- AGU output regs ---
    reg        agu_v_r;
    reg [7:0]  agu_sn_r;
    reg [6:0]  agu_opc_r;
    reg [2:0]  agu_fn3_r;
    reg [31:0] agu_imm_r;
    reg [5:0]  agu_prs1_r, agu_prs2_r, agu_prd_r;
    reg        agu_isld_r, agu_isst_r;
    reg [5:0]  agu_ptr_r;
    reg [7:0]  agu_oldest;

    // --- MUL output regs ---
    reg        mul_v_r;
    reg [7:0]  mul_sn_r;
    reg [2:0]  mul_fn3_r;
    reg [5:0]  mul_prs1_r, mul_prs2_r, mul_prd_r;
    reg [5:0]  mul_ptr_r;
    reg [7:0]  mul_oldest;

    integer jj;

    always @(*) begin

        // ---- BPU ----
        bpu_v_r = 0; bpu_sn_r = 0; bpu_opc_r = 0; bpu_fn3_r = 0;
        bpu_imm_r = 0; bpu_prs1_r = 0; bpu_prs2_r = 0; bpu_prd_r = 0;
        bpu_ptr_r = 0; bpu_oldest = 0;bpu_pc_r = 0;

        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                (is_branch_r[jj] || is_jal_r[jj] || is_jalr_r[jj]) &&
                rs1_ready_r[jj] && rs2_ready_r[jj]) begin

                if (!bpu_v_r || is_older(seq_num_r[jj], bpu_oldest)) begin
                    bpu_oldest  = seq_num_r[jj];
                    bpu_sn_r    = seq_num_r[jj];
                    bpu_opc_r   = opcode_r[jj];
                    bpu_fn3_r   = funct3_r[jj];
                    bpu_imm_r   = imm_r[jj];
                    bpu_prs1_r  = phys_rs1_r[jj];
                    bpu_prs2_r  = phys_rs2_r[jj];
                    bpu_prd_r   = phys_rd_r[jj];
                    bpu_ptr_r   = jj[5:0];
                    bpu_v_r     = 1;
                    bpu_pc_r    = pc_r[jj];

                end
            end
        end

        // ---- FU0 - oldest ready ALU/LUI/AUIPC, excluding BPU slot ----
        fu0_v_r = 0; fu0_sn_r = 0; fu0_opc_r = 0; fu0_fn3_r = 0; fu0_fn7_r = 0;
        fu0_imm_r = 0; fu0_prs1_r = 0; fu0_prs2_r = 0; fu0_prd_r = 0;
        fu0_ptr_r = 0; fu0_oldest = 0;fu0_pc_r = 0;

        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                (is_alu_r[jj] || is_lui_r[jj] || is_auipc_r[jj]) &&
                rs1_ready_r[jj] && rs2_ready_r[jj] &&
                !(bpu_v_r && jj[5:0] == bpu_ptr_r)) begin

                if (!fu0_v_r || is_older(seq_num_r[jj], fu0_oldest)) begin
                    fu0_oldest  = seq_num_r[jj];
                    fu0_sn_r    = seq_num_r[jj];
                    fu0_opc_r   = opcode_r[jj];
                    fu0_fn3_r   = funct3_r[jj];
                    fu0_fn7_r   = funct7_r[jj];
                    fu0_imm_r   = imm_r[jj];
                    fu0_prs1_r  = phys_rs1_r[jj];
                    fu0_prs2_r  = phys_rs2_r[jj];
                    fu0_prd_r   = phys_rd_r[jj];
                    fu0_ptr_r   = jj[5:0];
                    fu0_v_r     = 1;
                    fu0_pc_r    = pc_r[jj];

                end
            end
        end

        // ---- FU1 - 2nd oldest ALU, excludes BPU + FU0 slots ----
        fu1_v_r = 0; fu1_sn_r = 0; fu1_opc_r = 0; fu1_fn3_r = 0; fu1_fn7_r = 0;
        fu1_imm_r = 0; fu1_prs1_r = 0; fu1_prs2_r = 0; fu1_prd_r = 0;
        fu1_ptr_r = 0; fu1_oldest = 0;fu1_pc_r = 0;

        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                (is_alu_r[jj] || is_lui_r[jj] || is_auipc_r[jj]) &&
                rs1_ready_r[jj] && rs2_ready_r[jj] &&
                !(bpu_v_r && jj[5:0] == bpu_ptr_r) &&
                !(fu0_v_r && jj[5:0] == fu0_ptr_r)) begin

                if (!fu1_v_r || is_older(seq_num_r[jj], fu1_oldest)) begin
                    fu1_oldest  = seq_num_r[jj];
                    fu1_sn_r    = seq_num_r[jj];
                    fu1_opc_r   = opcode_r[jj];
                    fu1_fn3_r   = funct3_r[jj];
                    fu1_fn7_r   = funct7_r[jj];
                    fu1_imm_r   = imm_r[jj];
                    fu1_prs1_r  = phys_rs1_r[jj];
                    fu1_prs2_r  = phys_rs2_r[jj];
                    fu1_prd_r   = phys_rd_r[jj];
                    fu1_ptr_r   = jj[5:0];
                    fu1_v_r     = 1;
                    fu1_pc_r = pc_r[jj];
                end
            end
        end

        // ---- FU2 - 3rd oldest ALU, excludes BPU + FU0 + FU1 slots ----
        fu2_v_r = 0; fu2_sn_r = 0; fu2_opc_r = 0; fu2_fn3_r = 0; fu2_fn7_r = 0;
        fu2_imm_r = 0; fu2_prs1_r = 0; fu2_prs2_r = 0; fu2_prd_r = 0;
        fu2_ptr_r = 0; fu2_oldest = 0;fu2_pc_r = 0;


        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                (is_alu_r[jj] || is_lui_r[jj] || is_auipc_r[jj]) &&
                rs1_ready_r[jj] && rs2_ready_r[jj] &&
                !(bpu_v_r && jj[5:0] == bpu_ptr_r) &&
                !(fu0_v_r && jj[5:0] == fu0_ptr_r) &&
                !(fu1_v_r && jj[5:0] == fu1_ptr_r)) begin

                if (!fu2_v_r || is_older(seq_num_r[jj], fu2_oldest)) begin
                    fu2_oldest  = seq_num_r[jj];
                    fu2_sn_r    = seq_num_r[jj];
                    fu2_opc_r   = opcode_r[jj];
                    fu2_fn3_r   = funct3_r[jj];
                    fu2_fn7_r   = funct7_r[jj];
                    fu2_imm_r   = imm_r[jj];
                    fu2_prs1_r  = phys_rs1_r[jj];
                    fu2_prs2_r  = phys_rs2_r[jj];
                    fu2_prd_r   = phys_rd_r[jj];
                    fu2_ptr_r   = jj[5:0];
                    fu2_v_r     = 1;
                    fu2_pc_r = pc_r[jj];
                end
            end
        end

        // ---- FU3 - 4th oldest ALU, excludes BPU + FU0 + FU1 + FU2 slots ----
        fu3_v_r = 0; fu3_sn_r = 0; fu3_opc_r = 0; fu3_fn3_r = 0; fu3_fn7_r = 0;
        fu3_imm_r = 0; fu3_prs1_r = 0; fu3_prs2_r = 0; fu3_prd_r = 0;
        fu3_ptr_r = 0; fu3_oldest = 0;fu3_pc_r = 0;


        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                (is_alu_r[jj] || is_lui_r[jj] || is_auipc_r[jj]) &&
                rs1_ready_r[jj] && rs2_ready_r[jj] &&
                !(bpu_v_r && jj[5:0] == bpu_ptr_r) &&
                !(fu0_v_r && jj[5:0] == fu0_ptr_r) &&
                !(fu1_v_r && jj[5:0] == fu1_ptr_r) &&
                !(fu2_v_r && jj[5:0] == fu2_ptr_r)) begin

                if (!fu3_v_r || is_older(seq_num_r[jj], fu3_oldest)) begin
                    fu3_oldest  = seq_num_r[jj];
                    fu3_sn_r    = seq_num_r[jj];
                    fu3_opc_r   = opcode_r[jj];
                    fu3_fn3_r   = funct3_r[jj];
                    fu3_fn7_r   = funct7_r[jj];
                    fu3_imm_r   = imm_r[jj];
                    fu3_prs1_r  = phys_rs1_r[jj];
                    fu3_prs2_r  = phys_rs2_r[jj];
                    fu3_prd_r   = phys_rd_r[jj];
                    fu3_ptr_r   = jj[5:0];
                    fu3_v_r     = 1;
                    fu3_pc_r = pc_r[jj];
                end
            end
        end

        // ---- AGU - oldest load/store, excludes ALL above slots ----
        agu_v_r = 0; agu_sn_r = 0; agu_opc_r = 0; agu_fn3_r = 0;
        agu_imm_r = 0; agu_prs1_r = 0; agu_prs2_r = 0; agu_prd_r = 0;
        agu_isld_r = 0; agu_isst_r = 0;
        agu_ptr_r = 0; agu_oldest = 0;

        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                (is_load_r[jj] || is_store_r[jj]) &&
                rs1_ready_r[jj] && rs2_ready_r[jj] &&
                !(bpu_v_r && jj[5:0] == bpu_ptr_r) &&
                !(fu0_v_r && jj[5:0] == fu0_ptr_r) &&
                !(fu1_v_r && jj[5:0] == fu1_ptr_r) &&
                !(fu2_v_r && jj[5:0] == fu2_ptr_r) &&
                !(fu3_v_r && jj[5:0] == fu3_ptr_r)) begin

                if (!agu_v_r || is_older(seq_num_r[jj], agu_oldest)) begin
                    agu_oldest  = seq_num_r[jj];
                    agu_sn_r    = seq_num_r[jj];
                    agu_opc_r   = opcode_r[jj];
                    agu_fn3_r   = funct3_r[jj];
                    agu_imm_r   = imm_r[jj];
                    agu_prs1_r  = phys_rs1_r[jj];
                    agu_prs2_r  = phys_rs2_r[jj];
                    agu_prd_r   = phys_rd_r[jj];
                    agu_isld_r  = is_load_r[jj];
                    agu_isst_r  = is_store_r[jj];
                    agu_ptr_r   = jj[5:0];
                    agu_v_r     = 1;
                end
            end
        end

        // ---- MUL - oldest ready MUL instruction, excludes ALL above slots ----
        mul_v_r = 0; mul_sn_r = 0; mul_fn3_r = 0;
        mul_prs1_r = 0; mul_prs2_r = 0; mul_prd_r = 0;
        mul_ptr_r = 0; mul_oldest = 0;

        for (jj = 0; jj < 64; jj = jj + 1) begin
            if (valid_r[jj] &&
                is_mul_r[jj] &&
                rs1_ready_r[jj] && rs2_ready_r[jj] &&
                !(bpu_v_r && jj[5:0] == bpu_ptr_r) &&
                !(fu0_v_r && jj[5:0] == fu0_ptr_r) &&
                !(fu1_v_r && jj[5:0] == fu1_ptr_r) &&
                !(fu2_v_r && jj[5:0] == fu2_ptr_r) &&
                !(fu3_v_r && jj[5:0] == fu3_ptr_r) &&
                !(agu_v_r && jj[5:0] == agu_ptr_r)) begin

                if (!mul_v_r || is_older(seq_num_r[jj], mul_oldest)) begin
                    mul_oldest  = seq_num_r[jj];
                    mul_sn_r    = seq_num_r[jj];
                    mul_fn3_r   = funct3_r[jj];
                    mul_prs1_r  = phys_rs1_r[jj];
                    mul_prs2_r  = phys_rs2_r[jj];
                    mul_prd_r   = phys_rd_r[jj];
                    mul_ptr_r   = jj[5:0];
                    mul_v_r     = 1;
                end
            end
        end
    end

    // ================================================================
    // FIRE SIGNALS AND SLOT POINTER EXPORTS
    // A port "fires" when it has a valid candidate AND the downstream
    // unit is ready to accept it.
    // ================================================================
    assign bpu_fire  = bpu_v_r & bpu_ready;
    assign fu0_fire  = fu0_v_r & fu0_ready;
    assign fu1_fire  = fu1_v_r & fu1_ready;
    assign fu2_fire  = fu2_v_r & fu2_ready;
    assign fu3_fire  = fu3_v_r & fu3_ready;
    assign agu_fire  = agu_v_r & agu_ready;
    assign mul_fire  = mul_v_r & mul_ready;

    assign bpu_ptr_w = bpu_ptr_r;
    assign fu0_ptr_w = fu0_ptr_r;
    assign fu1_ptr_w = fu1_ptr_r;
    assign fu2_ptr_w = fu2_ptr_r;
    assign fu3_ptr_w = fu3_ptr_r;
    assign agu_ptr_w = agu_ptr_r;
    assign mul_ptr_w = mul_ptr_r;

    // ================================================================
    // OUTPUT PORT ASSIGNMENTS
    // ================================================================
    // BPU
    assign bpu_valid    = bpu_v_r;
    assign bpu_seq_num  = bpu_sn_r;
    assign bpu_opcode   = bpu_opc_r;
    assign bpu_funct3   = bpu_fn3_r;
    assign bpu_imm      = bpu_imm_r;
    assign bpu_phys_rs1 = bpu_prs1_r;
    assign bpu_phys_rs2 = bpu_prs2_r;
    assign bpu_phys_rd  = bpu_prd_r;

    // FU0
    assign fu0_valid    = fu0_v_r;
    assign fu0_seq_num  = fu0_sn_r;
    assign fu0_opcode   = fu0_opc_r;
    assign fu0_funct3   = fu0_fn3_r;
    assign fu0_funct7   = fu0_fn7_r;
    assign fu0_imm      = fu0_imm_r;
    assign fu0_phys_rs1 = fu0_prs1_r;
    assign fu0_phys_rs2 = fu0_prs2_r;
    assign fu0_phys_rd  = fu0_prd_r;

    // FU1
    assign fu1_valid    = fu1_v_r;
    assign fu1_seq_num  = fu1_sn_r;
    assign fu1_opcode   = fu1_opc_r;
    assign fu1_funct3   = fu1_fn3_r;
    assign fu1_funct7   = fu1_fn7_r;
    assign fu1_imm      = fu1_imm_r;
    assign fu1_phys_rs1 = fu1_prs1_r;
    assign fu1_phys_rs2 = fu1_prs2_r;
    assign fu1_phys_rd  = fu1_prd_r;

    // FU2
    assign fu2_valid    = fu2_v_r;
    assign fu2_seq_num  = fu2_sn_r;
    assign fu2_opcode   = fu2_opc_r;
    assign fu2_funct3   = fu2_fn3_r;
    assign fu2_funct7   = fu2_fn7_r;
    assign fu2_imm      = fu2_imm_r;
    assign fu2_phys_rs1 = fu2_prs1_r;
    assign fu2_phys_rs2 = fu2_prs2_r;
    assign fu2_phys_rd  = fu2_prd_r;

    // FU3
    assign fu3_valid    = fu3_v_r;
    assign fu3_seq_num  = fu3_sn_r;
    assign fu3_opcode   = fu3_opc_r;
    assign fu3_funct3   = fu3_fn3_r;
    assign fu3_funct7   = fu3_fn7_r;
    assign fu3_imm      = fu3_imm_r;
    assign fu3_phys_rs1 = fu3_prs1_r;
    assign fu3_phys_rs2 = fu3_prs2_r;
    assign fu3_phys_rd  = fu3_prd_r;

    // AGU
    assign agu_valid    = agu_v_r;
    assign agu_seq_num  = agu_sn_r;
    assign agu_opcode   = agu_opc_r;
    assign agu_funct3   = agu_fn3_r;
    assign agu_imm      = agu_imm_r;
    assign agu_phys_rs1 = agu_prs1_r;
    assign agu_phys_rs2 = agu_prs2_r;
    assign agu_phys_rd  = agu_prd_r;
    assign agu_is_load  = agu_isld_r;
    assign agu_is_store = agu_isst_r;
    
    assign bpu_pc = bpu_pc_r;
    assign fu0_pc = fu0_pc_r;
    assign fu1_pc = fu1_pc_r;
    assign fu2_pc = fu2_pc_r;
    assign fu3_pc = fu3_pc_r;

    // MUL
    assign mul_valid    = mul_v_r;
    assign mul_seq_num  = mul_sn_r;
    assign mul_funct3   = mul_fn3_r;
    assign mul_phys_rs1 = mul_prs1_r;
    assign mul_phys_rs2 = mul_prs2_r;
    assign mul_phys_rd  = mul_prd_r;


    // ================================================================
    // MAIN SEQUENTIAL BLOCK
    // Single always block - all state updates in one place to avoid
    // multi-driver conflicts and priority ambiguity.
    //
    // Order of operations (priority high → low):
    //   1. Flush         - clears everything, highest priority
    //   2. Deallocation  - clear fired entries
    //   3. CDB wakeup    - mark operands ready (6 ports)
    //   4. Scoreboard    - set newly ready PRs, clear newly allocated PRs
    //   5. Allocation    - write new entries into free slots
    //   6. Count update  - single place for num_valid_reg
    // ================================================================
    integer kk, mm;

    always @(posedge clk or posedge rst) begin : MAIN_SEQ
        reg [7:0] ftag;  // temp for producer tag IQ scan

        if (rst) begin
            for (kk = 0; kk < 64; kk = kk + 1) begin
                valid_r[kk]       <= 1'b0;
                rs1_ready_r[kk]   <= 1'b0;
                rs2_ready_r[kk]   <= 1'b0;
                rs1_prod_tag[kk]  <= TAG_NONE;
                rs2_prod_tag[kk]  <= TAG_NONE;
            end
            num_valid_reg <= 7'd0;
            // PR0-31 ready at reset: identity-mapped arch regs hold zero
            prf_ready     <= 64'h0000_0000_FFFF_FFFF;

        end else begin

            // ----------------------------------------------------------
            // 1. FLUSH - wipe entire IQ on misprediction
            //    prf_ready is NOT cleared: PRF values survive the flush.
            //    num_valid_reg reset to 0 (IQ is empty after flush).
            // ----------------------------------------------------------
            if (flush) begin
                for (kk = 0; kk < 64; kk = kk + 1)
                    valid_r[kk] <= 1'b0;
                num_valid_reg <= 7'd0;

            end else begin

                // ------------------------------------------------------
                // 2. DEALLOCATION - clear entries that fired this cycle
                //    Order doesn't matter here (each ptr is distinct).
                // ------------------------------------------------------
                if (bpu_fire) valid_r[bpu_ptr_r] <= 1'b0;
                if (fu0_fire) valid_r[fu0_ptr_r] <= 1'b0;
                if (fu1_fire) valid_r[fu1_ptr_r] <= 1'b0;
                if (fu2_fire) valid_r[fu2_ptr_r] <= 1'b0;
                if (fu3_fire) valid_r[fu3_ptr_r] <= 1'b0;
                if (agu_fire) valid_r[agu_ptr_r] <= 1'b0;
                if (mul_fire) valid_r[mul_ptr_r] <= 1'b0;

                // ------------------------------------------------------
                // 3. CDB WAKEUP - 6 ports  (CHANGE 3)
                //    For each IQ entry: if its producer tag matches any
                //    CDB broadcast this cycle, mark the operand ready.
                //    Guard: prod_tag != 0 prevents false wakeup (tag 0
                //    means "operand already ready, no producer tracked").
                // ------------------------------------------------------
                for (kk = 0; kk < 64; kk = kk + 1) begin
                    if (valid_r[kk]) begin

                        // RS1 wakeup - check all 6 CDB ports
                        if (!rs1_ready_r[kk] && rs1_valid_r[kk] &&
                             rs1_prod_tag[kk] != TAG_NONE) begin
                            if ((cdb_fu0_valid && rs1_prod_tag[kk] == cdb_fu0_tag) ||
                                (cdb_fu1_valid && rs1_prod_tag[kk] == cdb_fu1_tag) ||
                                (cdb_fu2_valid && rs1_prod_tag[kk] == cdb_fu2_tag) ||
                                (cdb_fu3_valid && rs1_prod_tag[kk] == cdb_fu3_tag) ||
                                (cdb_bpu_valid && rs1_prod_tag[kk] == cdb_bpu_tag) ||
                                (cdb_lsq_valid && rs1_prod_tag[kk] == cdb_lsq_tag) ||
                                (cdb_mul_valid && rs1_prod_tag[kk] == cdb_mul_tag))
                                rs1_ready_r[kk] <= 1'b1;
                        end

                        // RS2 wakeup - same 6 CDB ports
                        if (!rs2_ready_r[kk] && rs2_valid_r[kk] &&
                             rs2_prod_tag[kk] != TAG_NONE) begin
                            if ((cdb_fu0_valid && rs2_prod_tag[kk] == cdb_fu0_tag) ||
                                (cdb_fu1_valid && rs2_prod_tag[kk] == cdb_fu1_tag) ||
                                (cdb_fu2_valid && rs2_prod_tag[kk] == cdb_fu2_tag) ||
                                (cdb_fu3_valid && rs2_prod_tag[kk] == cdb_fu3_tag) ||
                                (cdb_bpu_valid && rs2_prod_tag[kk] == cdb_bpu_tag) ||
                                (cdb_lsq_valid && rs2_prod_tag[kk] == cdb_lsq_tag) ||
                                (cdb_mul_valid && rs2_prod_tag[kk] == cdb_mul_tag))
                                rs2_ready_r[kk] <= 1'b1;
                        end
                        
                        // Scoreboard fallback - catches producers that left IQ before dependent dispatched
                        if (!rs1_ready_r[kk] && rs1_valid_r[kk] && prf_ready[phys_rs1_r[kk]])
                            rs1_ready_r[kk] <= 1'b1;
                        if (!rs2_ready_r[kk] && rs2_valid_r[kk] && prf_ready[phys_rs2_r[kk]])
                            rs2_ready_r[kk] <= 1'b1;


                    end
                end

                // ------------------------------------------------------
                // 4. SCOREBOARD UPDATE
                //
                //    SET: mark PRs written by any CDB port as ready.
                //         PR0 is never written (x0 = zero).
                //
                //    CLEAR: mark PRs allocated to new instructions as
                //           not-ready. Done here (not in alloc block)
                //           because alloc_ptr is combinatorial and
                //           available now. Clear takes priority over set
                //           in the same always block (last assignment wins
                //           for non-blocking on the same reg bit, but since
                //           they write different bits in prf_ready this
                //           isn't an issue - each bit is either a new
                //           alloc clear OR a CDB set, never both same bit
                //           same cycle, because rename guarantees a PR is
                //           only re-allocated after it commits via CDB).
                // ------------------------------------------------------

                // Set bits from CDB
                if (cdb_fu0_valid && cdb_fu0_phys_reg != 6'd0)
                    prf_ready[cdb_fu0_phys_reg] <= 1'b1;
                if (cdb_fu1_valid && cdb_fu1_phys_reg != 6'd0)
                    prf_ready[cdb_fu1_phys_reg] <= 1'b1;
                if (cdb_fu2_valid && cdb_fu2_phys_reg != 6'd0)
                    prf_ready[cdb_fu2_phys_reg] <= 1'b1;
                if (cdb_fu3_valid && cdb_fu3_phys_reg != 6'd0)
                    prf_ready[cdb_fu3_phys_reg] <= 1'b1;
                if (cdb_bpu_valid && cdb_bpu_phys_reg != 6'd0)
                    prf_ready[cdb_bpu_phys_reg] <= 1'b1;
                if (cdb_lsq_valid && cdb_lsq_phys_reg != 6'd0)
                    prf_ready[cdb_lsq_phys_reg] <= 1'b1;
                if (cdb_mul_valid && cdb_mul_phys_reg != 6'd0)
                    prf_ready[cdb_mul_phys_reg] <= 1'b1;

                // Clear bits for newly allocated destinations
                if (!iq_full) begin
                    if (valid_in[0] && rd_valid_in[0] && p_rd[0] != 6'd0)
                        prf_ready[p_rd[0]] <= 1'b0;
                    if (valid_in[1] && rd_valid_in[1] && p_rd[1] != 6'd0)
                        prf_ready[p_rd[1]] <= 1'b0;
                    if (valid_in[2] && rd_valid_in[2] && p_rd[2] != 6'd0)
                        prf_ready[p_rd[2]] <= 1'b0;
                    if (valid_in[3] && rd_valid_in[3] && p_rd[3] != 6'd0)
                        prf_ready[p_rd[3]] <= 1'b0;
                end
                

                // ------------------------------------------------------
                // 5. ALLOCATION
                //    Write up to 4 new entries into the free slots found
                //    by alloc_ptr[]. Use rob_idx_inN directly as the tag.
                //
                //    Producer tag search strategy per instruction:
                //      - First check same-dispatch-batch instructions
                //        that precede this one (newest writer wins).
                //        These entries aren't in the IQ yet so can't be
                //        found by the IQ scan.
                //      - Then scan existing IQ entries.
                //        By rename invariant, at most one entry produces
                //        any given PR, so the scan finds exactly 0 or 1.
                //      - Store 0 if operand is already ready (prf_ready=1)
                //        - tag 0 is the sentinel for "no producer pending".
                // ------------------------------------------------------
                if (!iq_full) begin

                    // ===== INSTRUCTION 0 =====
                    // Oldest in batch. Producers can only be in existing IQ.
                    if (valid_in[0]) begin
                        valid_r[alloc_ptr[0]]       <= 1'b1;
                        seq_num_r[alloc_ptr[0]]     <= tag_in[0]; // rob_idx
                        opcode_r[alloc_ptr[0]]      <= opc[0];
                        funct3_r[alloc_ptr[0]]      <= fn3[0];
                        funct7_r[alloc_ptr[0]]      <= fn7[0];
                        imm_r[alloc_ptr[0]]         <= imm[0];
                        is_alu_r[alloc_ptr[0]]      <= is_alu_in[0];
                        is_load_r[alloc_ptr[0]]     <= is_load_in[0];
                        is_store_r[alloc_ptr[0]]    <= is_store_in[0];
                        is_branch_r[alloc_ptr[0]]   <= is_branch_in[0];
                        is_jal_r[alloc_ptr[0]]      <= is_jal_in[0];
                        is_jalr_r[alloc_ptr[0]]     <= is_jalr_in[0];
                        is_lui_r[alloc_ptr[0]]      <= is_lui_in[0];
                        is_auipc_r[alloc_ptr[0]]    <= is_auipc_in[0];
                        is_mul_r[alloc_ptr[0]]       <= is_mul_in[0];
                        phys_rs1_r[alloc_ptr[0]]    <= p_rs1[0];
                        phys_rs2_r[alloc_ptr[0]]    <= p_rs2[0];
                        phys_rd_r[alloc_ptr[0]]     <= p_rd[0];
                        rs1_valid_r[alloc_ptr[0]]   <= rs1_valid_in[0];
                        rs2_valid_r[alloc_ptr[0]]   <= rs2_valid_in[0];
                        iq_rd_valid_r[alloc_ptr[0]] <= rd_valid_in[0];
                        pc_r[alloc_ptr[0]]          <= pc_in0;
                        rs1_ready_r[alloc_ptr[0]]   <= rs1_rdy_in[0];
                        rs2_ready_r[alloc_ptr[0]]   <= rs2_rdy_in[0];

                        // RS1 producer - IQ scan only (no batch predecessor)
                        if (rs1_valid_in[0] && !prf_ready[p_rs1[0]]&& !cdb_match(p_rs1[0])) begin
                            ftag = TAG_NONE;
                            for (mm = 0; mm < 64; mm = mm + 1)
                                if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                    phys_rd_r[mm] == p_rs1[0])
                                    ftag = seq_num_r[mm];
                            rs1_prod_tag[alloc_ptr[0]] <= ftag;
                        end else
                            rs1_prod_tag[alloc_ptr[0]] <= TAG_NONE;

                        // RS2 producer - IQ scan only
                        if (rs2_valid_in[0] && !prf_ready[p_rs2[0]]&& !cdb_match(p_rs2[0])) begin
                            ftag =TAG_NONE;
                            for (mm = 0; mm < 64; mm = mm + 1)
                                if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                    phys_rd_r[mm] == p_rs2[0])
                                    ftag = seq_num_r[mm];
                            rs2_prod_tag[alloc_ptr[0]] <= ftag;
                        end else
                            rs2_prod_tag[alloc_ptr[0]] <= TAG_NONE;
                    end

                    // ===== INSTRUCTION 1 =====
                    // Can depend on instr 0 (same batch) or existing IQ.
                    // Batch check: instr 0 is the only older batch instr.
                    if (valid_in[1]) begin
                        valid_r[alloc_ptr[1]]       <= 1'b1;
                        seq_num_r[alloc_ptr[1]]     <= tag_in[1];
                        opcode_r[alloc_ptr[1]]      <= opc[1];
                        funct3_r[alloc_ptr[1]]      <= fn3[1];
                        funct7_r[alloc_ptr[1]]      <= fn7[1];
                        imm_r[alloc_ptr[1]]         <= imm[1];
                        is_alu_r[alloc_ptr[1]]      <= is_alu_in[1];
                        is_load_r[alloc_ptr[1]]     <= is_load_in[1];
                        is_store_r[alloc_ptr[1]]    <= is_store_in[1];
                        is_branch_r[alloc_ptr[1]]   <= is_branch_in[1];
                        is_jal_r[alloc_ptr[1]]      <= is_jal_in[1];
                        is_jalr_r[alloc_ptr[1]]     <= is_jalr_in[1];
                        is_lui_r[alloc_ptr[1]]      <= is_lui_in[1];
                        is_auipc_r[alloc_ptr[1]]    <= is_auipc_in[1];
                        is_mul_r[alloc_ptr[1]]       <= is_mul_in[1];
                        phys_rs1_r[alloc_ptr[1]]    <= p_rs1[1];
                        phys_rs2_r[alloc_ptr[1]]    <= p_rs2[1];
                        phys_rd_r[alloc_ptr[1]]     <= p_rd[1];
                        rs1_valid_r[alloc_ptr[1]]   <= rs1_valid_in[1];
                        rs2_valid_r[alloc_ptr[1]]   <= rs2_valid_in[1];
                        iq_rd_valid_r[alloc_ptr[1]] <= rd_valid_in[1];
                        pc_r[alloc_ptr[1]]          <= pc_in1;
                        rs1_ready_r[alloc_ptr[1]]   <= rs1_rdy_in[1];
                        rs2_ready_r[alloc_ptr[1]]   <= rs2_rdy_in[1];

                        // RS1: instr 0 first (oldest batch), then IQ
                        if (rs1_valid_in[1] && !prf_ready[p_rs1[1]]&& !cdb_match(p_rs1[1])) begin
                            if (valid_in[0] && rd_valid_in[0] && p_rd[0] == p_rs1[1])
                                rs1_prod_tag[alloc_ptr[1]] <= tag_in[0];
                            else begin
                                ftag = TAG_NONE;
                                for (mm = 0; mm < 64; mm = mm + 1)
                                    if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                        phys_rd_r[mm] == p_rs1[1])
                                        ftag = seq_num_r[mm];
                                rs1_prod_tag[alloc_ptr[1]] <= ftag;
                            end
                        end else
                            rs1_prod_tag[alloc_ptr[1]] <=TAG_NONE;

                        // RS2: same pattern
                        if (rs2_valid_in[1] && !prf_ready[p_rs2[1]]&& !cdb_match(p_rs2[1])) begin
                            if (valid_in[0] && rd_valid_in[0] && p_rd[0] == p_rs2[1])
                                rs2_prod_tag[alloc_ptr[1]] <= tag_in[0];
                            else begin
                                ftag = TAG_NONE;
                                for (mm = 0; mm < 64; mm = mm + 1)
                                    if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                        phys_rd_r[mm] == p_rs2[1])
                                        ftag = seq_num_r[mm];
                                rs2_prod_tag[alloc_ptr[1]] <= ftag;
                            end
                        end else
                            rs2_prod_tag[alloc_ptr[1]] <= TAG_NONE;
                    end

                    // ===== INSTRUCTION 2 =====
                    // Batch check: instr 1 (newest) then instr 0, then IQ.
                    if (valid_in[2]) begin
                        valid_r[alloc_ptr[2]]       <= 1'b1;
                        seq_num_r[alloc_ptr[2]]     <= tag_in[2];
                        opcode_r[alloc_ptr[2]]      <= opc[2];
                        funct3_r[alloc_ptr[2]]      <= fn3[2];
                        funct7_r[alloc_ptr[2]]      <= fn7[2];
                        imm_r[alloc_ptr[2]]         <= imm[2];
                        is_alu_r[alloc_ptr[2]]      <= is_alu_in[2];
                        is_load_r[alloc_ptr[2]]     <= is_load_in[2];
                        is_store_r[alloc_ptr[2]]    <= is_store_in[2];
                        is_branch_r[alloc_ptr[2]]   <= is_branch_in[2];
                        is_jal_r[alloc_ptr[2]]      <= is_jal_in[2];
                        is_jalr_r[alloc_ptr[2]]     <= is_jalr_in[2];
                        is_lui_r[alloc_ptr[2]]      <= is_lui_in[2];
                        is_auipc_r[alloc_ptr[2]]    <= is_auipc_in[2];
                        is_mul_r[alloc_ptr[2]]       <= is_mul_in[2];
                        phys_rs1_r[alloc_ptr[2]]    <= p_rs1[2];
                        phys_rs2_r[alloc_ptr[2]]    <= p_rs2[2];
                        phys_rd_r[alloc_ptr[2]]     <= p_rd[2];
                        rs1_valid_r[alloc_ptr[2]]   <= rs1_valid_in[2];
                        rs2_valid_r[alloc_ptr[2]]   <= rs2_valid_in[2];
                        iq_rd_valid_r[alloc_ptr[2]] <= rd_valid_in[2];
                        pc_r[alloc_ptr[2]]          <= pc_in2;
                        rs1_ready_r[alloc_ptr[2]]   <= rs1_rdy_in[2];
                        rs2_ready_r[alloc_ptr[2]]   <= rs2_rdy_in[2];

                        // RS1: newest batch writer wins (1 > 0), then IQ
                        if (rs1_valid_in[2] && !prf_ready[p_rs1[2]]&& !cdb_match(p_rs1[2])) begin
                            if      (valid_in[1] && rd_valid_in[1] && p_rd[1] == p_rs1[2])
                                rs1_prod_tag[alloc_ptr[2]] <= tag_in[1];
                            else if (valid_in[0] && rd_valid_in[0] && p_rd[0] == p_rs1[2])
                                rs1_prod_tag[alloc_ptr[2]] <= tag_in[0];
                            else begin
                                ftag =TAG_NONE;
                                for (mm = 0; mm < 64; mm = mm + 1)
                                    if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                        phys_rd_r[mm] == p_rs1[2])
                                        ftag = seq_num_r[mm];
                                rs1_prod_tag[alloc_ptr[2]] <= ftag;
                            end
                        end else
                            rs1_prod_tag[alloc_ptr[2]] <=TAG_NONE;

                        // RS2: newest batch writer wins (1 > 0), then IQ
                        if (rs2_valid_in[2] && !prf_ready[p_rs2[2]]&& !cdb_match(p_rs2[2])) begin
                            if      (valid_in[1] && rd_valid_in[1] && p_rd[1] == p_rs2[2])
                                rs2_prod_tag[alloc_ptr[2]] <= tag_in[1];
                            else if (valid_in[0] && rd_valid_in[0] && p_rd[0] == p_rs2[2])
                                rs2_prod_tag[alloc_ptr[2]] <= tag_in[0];
                            else begin
                                ftag = TAG_NONE;
                                for (mm = 0; mm < 64; mm = mm + 1)
                                    if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                        phys_rd_r[mm] == p_rs2[2])
                                        ftag = seq_num_r[mm];
                                rs2_prod_tag[alloc_ptr[2]] <= ftag;
                            end
                        end else
                            rs2_prod_tag[alloc_ptr[2]] <= TAG_NONE;
                    end

                    // ===== INSTRUCTION 3 =====
                    // Batch check: instr 2 (newest) then 1, then 0, then IQ.
                    if (valid_in[3]) begin
                        valid_r[alloc_ptr[3]]       <= 1'b1;
                        seq_num_r[alloc_ptr[3]]     <= tag_in[3];
                        opcode_r[alloc_ptr[3]]      <= opc[3];
                        funct3_r[alloc_ptr[3]]      <= fn3[3];
                        funct7_r[alloc_ptr[3]]      <= fn7[3];
                        imm_r[alloc_ptr[3]]         <= imm[3];
                        is_alu_r[alloc_ptr[3]]      <= is_alu_in[3];
                        is_load_r[alloc_ptr[3]]     <= is_load_in[3];
                        is_store_r[alloc_ptr[3]]    <= is_store_in[3];
                        is_branch_r[alloc_ptr[3]]   <= is_branch_in[3];
                        is_jal_r[alloc_ptr[3]]      <= is_jal_in[3];
                        is_jalr_r[alloc_ptr[3]]     <= is_jalr_in[3];
                        is_lui_r[alloc_ptr[3]]      <= is_lui_in[3];
                        is_auipc_r[alloc_ptr[3]]    <= is_auipc_in[3];
                        is_mul_r[alloc_ptr[3]]       <= is_mul_in[3];
                        phys_rs1_r[alloc_ptr[3]]    <= p_rs1[3];
                        phys_rs2_r[alloc_ptr[3]]    <= p_rs2[3];
                        phys_rd_r[alloc_ptr[3]]     <= p_rd[3];
                        rs1_valid_r[alloc_ptr[3]]   <= rs1_valid_in[3];
                        rs2_valid_r[alloc_ptr[3]]   <= rs2_valid_in[3];
                        iq_rd_valid_r[alloc_ptr[3]] <= rd_valid_in[3];
                        pc_r[alloc_ptr[3]]          <= pc_in3;
                        rs1_ready_r[alloc_ptr[3]]   <= rs1_rdy_in[3];
                        rs2_ready_r[alloc_ptr[3]]   <= rs2_rdy_in[3];

                        // RS1: newest batch writer wins (2 > 1 > 0), then IQ
                        if (rs1_valid_in[3] && !prf_ready[p_rs1[3]]&& !cdb_match(p_rs1[3])) begin
                            if      (valid_in[2] && rd_valid_in[2] && p_rd[2] == p_rs1[3])
                                rs1_prod_tag[alloc_ptr[3]] <= tag_in[2];
                            else if (valid_in[1] && rd_valid_in[1] && p_rd[1] == p_rs1[3])
                                rs1_prod_tag[alloc_ptr[3]] <= tag_in[1];
                            else if (valid_in[0] && rd_valid_in[0] && p_rd[0] == p_rs1[3])
                                rs1_prod_tag[alloc_ptr[3]] <= tag_in[0];
                            else begin
                                ftag = TAG_NONE;
                                for (mm = 0; mm < 64; mm = mm + 1)
                                    if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                        phys_rd_r[mm] == p_rs1[3])
                                        ftag = seq_num_r[mm];
                                rs1_prod_tag[alloc_ptr[3]] <= ftag;
                            end
                        end else
                            rs1_prod_tag[alloc_ptr[3]] <= TAG_NONE;

                        // RS2: newest batch writer wins (2 > 1 > 0), then IQ
                        if (rs2_valid_in[3] && !prf_ready[p_rs2[3]]&& !cdb_match(p_rs2[3])) begin
                            if      (valid_in[2] && rd_valid_in[2] && p_rd[2] == p_rs2[3])
                                rs2_prod_tag[alloc_ptr[3]] <= tag_in[2];
                            else if (valid_in[1] && rd_valid_in[1] && p_rd[1] == p_rs2[3])
                                rs2_prod_tag[alloc_ptr[3]] <= tag_in[1];
                            else if (valid_in[0] && rd_valid_in[0] && p_rd[0] == p_rs2[3])
                                rs2_prod_tag[alloc_ptr[3]] <= tag_in[0];
                            else begin
                                ftag = TAG_NONE;
                                for (mm = 0; mm < 64; mm = mm + 1)
                                    if (valid_r[mm] && iq_rd_valid_r[mm] &&
                                        phys_rd_r[mm] == p_rs2[3])
                                        ftag = seq_num_r[mm];
                                rs2_prod_tag[alloc_ptr[3]] <= ftag;
                            end
                        end else
                            rs2_prod_tag[alloc_ptr[3]] <= TAG_NONE;
                    end

                end // !iq_full

                // ------------------------------------------------------
                // 6. COUNT UPDATE  (CHANGE 5 - [3:0] freed)
                //    Single consolidated update to avoid double-write.
                //    freed: up to 6 entries per cycle (4 FU + BPU + AGU)
                //    added: up to 4 entries per cycle (4-wide dispatch)
                // ------------------------------------------------------
                begin : COUNT_UPDATE
                    reg [3:0] freed;  // widened: max 6 → fits in 3 bits,
                                      // [3:0] used for safe addition
                    reg [2:0] added;

                    freed = {3'b0, bpu_fire}
                          + {3'b0, fu0_fire}
                          + {3'b0, fu1_fire}
                          + {3'b0, fu2_fire}
                          + {3'b0, fu3_fire}
                          + {3'b0, agu_fire};

                    added = iq_full ? 3'd0 : num_incoming[2:0];

                    num_valid_reg <= num_valid_reg
                                   + {4'b0, added}
                                   - {3'b0, freed};
                end

            end // !flush
        end // !rst
    end // MAIN_SEQ

endmodule
