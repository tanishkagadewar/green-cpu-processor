// Unchanged modules from M2/M3, compacted for M4

// ---- PC Register with Enable (modified for stall support) ----
module pc_register (
    input wire clk, rst, en,
    input wire [15:0] pc_next,
    output reg [15:0] pc
);
    always @(posedge clk)
        if (rst) pc <= 16'h0000;
        else if (en) pc <= pc_next;
endmodule

// ---- Instruction Memory ----
module instruction_memory #(parameter MEM_DEPTH = 256)(
    input wire [15:0] addr, output wire [15:0] instruction
);
    reg [15:0] mem [0:MEM_DEPTH-1];
    assign instruction = mem[addr[7:0]];
    integer i;
    initial for (i = 0; i < MEM_DEPTH; i = i + 1) mem[i] = 16'h0000;
endmodule

// ---- Register File ----
module register_file (
    input wire clk, rst, reg_write,
    input wire [2:0] rs1_addr, rs2_addr, rd_addr,
    input wire [15:0] write_data,
    output wire [15:0] rs1_data, rs2_data
);
    reg [15:0] registers [0:7];
    integer i;
    // Write-before-read forwarding: if WB writes same register ID reads,
    // return the write data (handles WB→ID forwarding in pipeline)
    assign rs1_data = (rs1_addr == 0) ? 16'h0 :
                      (reg_write && rd_addr == rs1_addr) ? write_data :
                      registers[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 16'h0 :
                      (reg_write && rd_addr == rs2_addr) ? write_data :
                      registers[rs2_addr];
    always @(posedge clk)
        if (rst) for (i = 0; i < 8; i = i + 1) registers[i] <= 16'h0;
        else if (reg_write && rd_addr != 0) registers[rd_addr] <= write_data;
endmodule

// ---- ALU ----
module alu (
    input wire [15:0] a, b, input wire [3:0] alu_control,
    output reg [15:0] result, output wire zero
);
    localparam ALU_ADD=0, ALU_SUB=1, ALU_SLT=2, ALU_OR=3,
               ALU_AND=4, ALU_SRL=5, ALU_SLL=6, ALU_SRA=7;
    assign zero = (result == 0);
    always @(*) case (alu_control)
        ALU_ADD: result = a + b;
        ALU_SUB: result = a - b;
        ALU_SLT: result = ($signed(a) < $signed(b)) ? 16'h1 : 16'h0;
        ALU_OR:  result = a | b;
        ALU_AND: result = a & b;
        ALU_SRL: result = a >> b[3:0];
        ALU_SLL: result = a << b[3:0];
        ALU_SRA: result = $signed(a) >>> b[3:0];
        default: result = 16'h0;
    endcase
endmodule

// ---- Data Memory ----
module data_memory #(parameter MEM_DEPTH = 256)(
    input wire clk, mem_read, mem_write,
    input wire [15:0] addr, write_data,
    output wire [15:0] read_data
);
    reg [15:0] mem [0:MEM_DEPTH-1];
    assign read_data = mem_read ? mem[addr[7:0]] : 16'h0;
    always @(posedge clk) if (mem_write) mem[addr[7:0]] <= write_data;
    integer i;
    initial for (i = 0; i < MEM_DEPTH; i = i + 1) mem[i] = 16'h0;
endmodule
