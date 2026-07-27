`define WIDTH 31:0
`define MEMDEPTH 0:8191
`define ZEROWORD 32'h0
`define MEMADDRESS 14:2
// RAM - DATA MEMORY
module data_memory(
    clk, reset, write_enable_in, address_in, data_in, data_out
);

//inputs/outputs from slave bus
input clk, reset, write_enable_in;
input [`WIDTH] data_in, address_in;
output reg [`WIDTH] data_out;

// memory defining
reg [31:0] MEMORY [`MEMDEPTH];

// asynchronous read
always @(*) begin
    if(reset == 1'b1) begin
        data_out = `ZEROWORD;
    end
    else data_out = MEMORY[address_in[`MEMADDRESS]];
end

//synchronous write
always @(posedge clk) begin
    if(write_enable_in == 1'b1) MEMORY[address_in[`MEMADDRESS]] = data_in;
end

endmodule
