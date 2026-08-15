module Main_Memory #(
    parameter DEPTH      = 256,        // number of 32-bit words  → 1 KB
    parameter ADDR_W     = 32,         // byte address width
    parameter LSQ_PTR_W  = 5,          // must match LSQ parameter
    parameter INIT_FILE  = ""          // optional hex init file path
)(
    input  wire                   clk,
    input  wire                   rst,

    // ================================================================
    // REQUEST PORT  (from LSQ)
    // ================================================================
    input  wire                   mem_req_valid,
    input  wire                   mem_req_we,        // 1=store  0=load
    input  wire [ADDR_W-1:0]      mem_req_addr,      // byte address
    input  wire [31:0]            mem_req_wdata,     // store data
    input  wire [1:0]             mem_req_size,      // 00=B 01=H 10=W
    input  wire [LSQ_PTR_W-1:0]  mem_req_lsq_idx,   // tag - echoed in response
    output wire                   mem_req_ready,     // can accept request

    // ================================================================
    // RESPONSE PORT  (to LSQ)
    // ================================================================
    output reg                    mem_resp_valid,    // load data ready
    output reg  [31:0]            mem_resp_data,     // load result (zero-ext)
    output reg  [LSQ_PTR_W-1:0]  mem_resp_lsq_idx   // echoed tag
);

    // ================================================================
    // MEMORY ARRAY
    // 256 words × 32 bits = 1 KB
    // Addressed by word index = byte_addr[9:2]
    // ================================================================
    reg [31:0] mem [0:DEPTH-1];

    // Word index from byte address (ignore bottom 2 bits)
    wire [7:0] word_idx = mem_req_addr[9:2];

    // ================================================================
    // READY LOGIC
    // mem_req_ready is high when the pipeline stage 1 register is empty.
    // We implement a 1-deep request pipeline:
    //   stage1_valid : a request was accepted last cycle, now executing
    // Ready deasserts for exactly 1 cycle after accepting a request so
    // the pipeline doesn't overflow.
    // This gives a throughput of 1 request every 2 cycles - sufficient
    // for a single-issue LSQ.
    // ================================================================
    reg        stage1_valid;    // stage 1 occupied
    reg        stage1_we;
    reg [7:0]  stage1_word_idx;
    reg [31:0] stage1_wdata;
    reg [1:0]  stage1_size;
    reg [LSQ_PTR_W-1:0] stage1_lsq_idx;
    reg        stage1_is_load;

    // Ready: accept new request only when stage1 is free
    assign mem_req_ready = !stage1_valid;

    // ================================================================
    // BYTE ENABLE GENERATION
    // Given a word-aligned base and a size, produce 4-bit byte enable.
    // Also produce a byte-lane-shifted write data.
    // ================================================================
    // Byte offset within the word from the 2 LSBs of byte address
    wire [1:0] byte_off = mem_req_addr[1:0];

    // Generate byte enables for the incoming request
    // (used at stage1 → stage2 transition for stores)
    function automatic [3:0] gen_be;
        input [1:0] size;
        input [1:0] offset;
        begin
            case (size)
                2'b00: begin  // byte
                    case (offset)
                        2'b00: gen_be = 4'b0001;
                        2'b01: gen_be = 4'b0010;
                        2'b10: gen_be = 4'b0100;
                        2'b11: gen_be = 4'b1000;
                        default: gen_be = 4'b0000;
                    endcase
                end
                2'b01: begin  // halfword (must be 2-byte aligned)
                    case (offset[1])
                        1'b0:   gen_be = 4'b0011;  // lower half
                        1'b1:   gen_be = 4'b1100;  // upper half
                        default: gen_be = 4'b0000;
                    endcase
                end
                default: gen_be = 4'b1111;  // word
            endcase
        end
    endfunction

    // Shift write data into the correct byte lane
    function automatic [31:0] shift_wdata;
        input [31:0] data;
        input [1:0]  size;
        input [1:0]  offset;
        begin
            case (size)
                2'b00:   shift_wdata = data[7:0]  << (offset * 8);
                2'b01:   shift_wdata = data[15:0] << (offset[1] ? 16 : 0);
                default: shift_wdata = data;
            endcase
        end
    endfunction

    // Extract the relevant byte lane from a read word
    function automatic [31:0] extract_rdata;
        input [31:0] word;
        input [1:0]  size;
        input [1:0]  offset;
        begin
            case (size)
                2'b00: begin  // byte - zero extend
                    case (offset)
                        2'b00: extract_rdata = {24'b0, word[7:0]};
                        2'b01: extract_rdata = {24'b0, word[15:8]};
                        2'b10: extract_rdata = {24'b0, word[23:16]};
                        2'b11: extract_rdata = {24'b0, word[31:24]};
                        default: extract_rdata = 32'b0;
                    endcase
                end
                2'b01: begin  // halfword - zero extend
                    case (offset[1])
                        1'b0:   extract_rdata = {16'b0, word[15:0]};
                        1'b1:   extract_rdata = {16'b0, word[31:16]};
                        default: extract_rdata = 32'b0;
                    endcase
                end
                default: extract_rdata = word;  // word - full
            endcase
        end
    endfunction

    // ================================================================
    // STAGE 1 REGISTER - capture accepted request
    // ================================================================
    // Store the byte offset too for extract/shift
    reg [1:0] stage1_byte_off;

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage1_valid    <= 1'b0;
            stage1_we       <= 1'b0;
            stage1_word_idx <= 8'b0;
            stage1_wdata    <= 32'b0;
            stage1_size     <= 2'b10;
            stage1_lsq_idx  <= {LSQ_PTR_W{1'b0}};
            stage1_is_load  <= 1'b0;
            stage1_byte_off <= 2'b0;
        end else begin
            // Stage 1 clears every cycle (1-cycle pipeline stage)
            stage1_valid <= 1'b0;

            if (mem_req_valid && mem_req_ready) begin
                // Accept request - latch into stage 1
                stage1_valid    <= 1'b1;
                stage1_we       <= mem_req_we;
                stage1_word_idx <= word_idx;
                stage1_wdata    <= shift_wdata(mem_req_wdata,
                                               mem_req_size,
                                               byte_off);
                stage1_size     <= mem_req_size;
                stage1_lsq_idx  <= mem_req_lsq_idx;
                stage1_is_load  <= !mem_req_we;
                stage1_byte_off <= byte_off;
            end
        end
    end

    // ================================================================
    // STAGE 2 - MEMORY ACCESS + RESPONSE
    // Execute the latched request and produce the response.
    // ================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_resp_valid   <= 1'b0;
            mem_resp_data    <= 32'b0;
            mem_resp_lsq_idx <= {LSQ_PTR_W{1'b0}};

            // Zero-initialise memory
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 32'b0;

        end else begin
            // Default: no response
            mem_resp_valid <= 1'b0;

            if (stage1_valid) begin
                if (stage1_we) begin
                    // ---- STORE ----
                    // Write only the enabled byte lanes; preserve others.
                    begin : STORE_EXEC
                        reg [3:0]  be;
                        reg [31:0] old_word, new_word;
                        be       = gen_be(stage1_size, stage1_byte_off);
                        old_word = mem[stage1_word_idx];
                        new_word[7:0]   = be[0] ? stage1_wdata[7:0]   : old_word[7:0];
                        new_word[15:8]  = be[1] ? stage1_wdata[15:8]  : old_word[15:8];
                        new_word[23:16] = be[2] ? stage1_wdata[23:16] : old_word[23:16];
                        new_word[31:24] = be[3] ? stage1_wdata[31:24] : old_word[31:24];
                        mem[stage1_word_idx] <= new_word;
                    end
                    // Stores do NOT produce a CDB response
                    mem_resp_valid <= 1'b0;

                end else begin
                    // ---- LOAD ----
                    begin : LOAD_EXEC
                        reg [31:0] raw_word;
                        raw_word = mem[stage1_word_idx];
                        mem_resp_data <= extract_rdata(raw_word,
                                                       stage1_size,
                                                       stage1_byte_off);
                    end
                    mem_resp_valid   <= 1'b1;
                    mem_resp_lsq_idx <= stage1_lsq_idx;
                end
            end
        end
    end

    // ================================================================
    // OPTIONAL: pre-load memory from hex file at simulation start
    // Set INIT_FILE parameter to a path string to use this.
    // ================================================================
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule