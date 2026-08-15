module instruction_queue(
input clk,rst,
input flush,
input [31:0] ins0,ins1,ins2,ins3,
input [31:0] pc_in,            // ← NEW: base PC of the bundle
input [3:0] valid,//valid insts
input push,pop,// write n read when
output reg [31:0] ins0_out,ins1_out,ins2_out,ins3_out,
output reg [31:0] pc_out,      // ← NEW: base PC of the popped bundle
output reg [3:0] valid_out,
output wire full,empty
);

reg [31:0] mem0 [0:7];//block of 4 reserved for each set
reg [31:0] mem1 [0:7];
reg [31:0] mem2 [0:7];
reg [31:0] mem3 [0:7];
reg [3:0]  mem_valid [0:7];// stores valid bit of all insts
reg [31:0] mem_pc [0:7];   // ← NEW: stores PC per bundle

reg [2:0] write_ptr,read_ptr;// read and write where
reg [3:0] count;// count of insts

assign full  = (count == 4'd8);
assign empty = (count == 4'd0);

always@(posedge clk or posedge rst)begin

if(rst || flush) 
write_ptr <= 3'b000;

else if(push && !full)
begin
mem0[write_ptr] <= ins0;
mem1[write_ptr] <= ins1;
mem2[write_ptr] <= ins2;
mem3[write_ptr] <= ins3;
mem_valid[write_ptr] <= valid;
mem_pc[write_ptr] <= pc_in;   // ← NEW: store PC
write_ptr <= write_ptr + 1;
end
end

always@(posedge clk or posedge rst)begin

if(rst || flush) 
begin
read_ptr <= 3'b000;
ins0_out <= 32'd0;
ins1_out <= 32'd0;
ins2_out <= 32'd0;
ins3_out <= 32'd0;
pc_out   <= 32'd0;            // ← NEW: reset PC
valid_out <= 4'd0;
end

else if(pop && !empty)
begin
ins0_out <= mem0[read_ptr];
ins1_out <= mem1[read_ptr];
ins2_out <= mem2[read_ptr];
ins3_out <= mem3[read_ptr];
pc_out   <= mem_pc[read_ptr]; // ← NEW: output PC
valid_out <= mem_valid[read_ptr];

read_ptr <= read_ptr + 3'd1;
end
end

always@(posedge clk or posedge rst)
begin
if(rst || flush) count <= 4'b0000;

else 
begin
case({push && !full, pop && !empty})
2'b00: count <= count;
2'b01: count <= count - 4'd1;
2'b10: count <= count + 4'd1;
2'b11: count <= count;
default: count <= count;
endcase

end
end

endmodule
