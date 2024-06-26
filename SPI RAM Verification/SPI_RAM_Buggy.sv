// SPI RAM RTL Code Before Bug Fixing
module project_ram(din, rx_valid, dout, tx_valid, clk, rst_n);
parameter MEM_DEPTH = 256;
parameter ADDR_SIZE = 8;
input rx_valid, clk, rst_n;
input [9:0] din;
output reg tx_valid;
output reg [7:0] dout;
reg [ADDR_SIZE-1:0] addr_rd, addr_wr;
reg [7:0] mem [MEM_DEPTH-1:0];
integer i = 0;
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		for (i = 0; i < MEM_DEPTH; i=i+1) begin
			mem [i] <= 1'b0;
			dout <= 8'b0;
			tx_valid <= 1'b0;
		end
	end
	else if (rx_valid) begin
		if (din[9:8] == 2'b00) begin
			addr_wr <= din[7:0];
			tx_valid <= 0;
		end
		else if (din[9:8] == 2'b01) begin
			mem [addr_wr] <= din[7:0];
			tx_valid <= 0;
		end
		else if (din[9:8] == 2'b10) begin
			addr_rd <= din[7:0];
			tx_valid <= 0;
		end
		else if (din[9:8] == 2'b11) begin
			dout <= mem[addr_rd];
			tx_valid <= 1;
		end
	end 
end
endmodule
