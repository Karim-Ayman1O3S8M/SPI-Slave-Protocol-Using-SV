// Second Lower Module (SPI Slave Interface)

module SPI_Slave_GOLD (SLAVE_if.gold_inst s_if);

// Parameters State Declaration
parameter IDLE = 3'b000;
parameter CHK_CMD = 3'b001;
parameter WRITE = 3'b010;
parameter READ_ADD = 3'b011;
parameter READ_DATA = 3'b100;

// s_if.rst_n -> Active Low ASYNC (Make The RAM in Device Implementation as A Group of Flip-Flops)
// s_if.rst_n -> Active Low SYNC (Make The RAM in Device Implementation as A RAM BLOCK)
// So We Choose s_if.rst_n to be Active Low SYNC

reg [2:0] cs, ns; // cs -> Current State , ns -> Next State
reg[3:0] counter; // Counter to track Serial to Parallel conversion and Parallel to Serial
// To Check that the Read Address Comes First and Read Data Comes Second
reg rd_addr_recieved; // Signal to track if read adress is recieved. Initially no read address is received

// State Memory Logic
always @(posedge s_if.clk) begin
    if (~s_if.rst_n)
        cs <= IDLE;
    else
        cs <= ns;
end

// Next State Logic
always @(*) begin
    case (cs)
        IDLE : 
            begin
                if (s_if.SS_n)
                    ns = IDLE;
                else
                    ns = CHK_CMD;
            end
        CHK_CMD : 
            begin
                if (s_if.SS_n)
                    ns = IDLE;
                else
                if (~s_if.MOSI)
                    ns = WRITE;
                else
                if (~rd_addr_recieved)
                    ns = READ_ADD;
                else
                    ns = READ_DATA;
            end
        WRITE : 
            begin
                if (s_if.SS_n)
                    ns = IDLE;
                else
                    ns = WRITE;
            end
        READ_ADD : 
            begin
                if (s_if.SS_n)
                    ns = IDLE;
                else
                    ns = READ_ADD;
            end
        READ_DATA : 
            begin
                if (s_if.SS_n)
                    ns = IDLE;
                else
                    ns = READ_DATA;
            end
        default : ns = IDLE; // To Avoid Latches for the uncovered state encoding cases
    endcase
end

// Output Logic Convert s_if.MOSI From Serial to Parallel For Communication
// Output Logic Convert s_if.MISO From Parallel to Serial For Communication

always @(posedge s_if.clk) begin
    if (~s_if.rst_n) begin
        s_if.rx_data <= 0;
        s_if.rx_valid <= 0;
        rd_addr_recieved <= 0;
        s_if.MISO <= 0;
        counter <= 0;
    end
    else begin
        case (cs)
            IDLE :
                begin
                    counter <= 0;
                    s_if.rx_valid <= 0;
                    s_if.MISO <= 0;
                end
            CHK_CMD :
                begin
                    counter <= 0;
                    s_if.rx_valid <= 0;
                end
            WRITE :
                begin
                    if (counter <= 9) begin
                        s_if.rx_data <= {s_if.rx_data[8:0],s_if.MOSI};
                        s_if.rx_valid <= 0;
                        counter <= counter + 1;
                    end
                    if (counter >= 9) begin
                        s_if.rx_valid <= 1;
                    end
                end
            READ_ADD :
                begin
                    if (counter <= 9) begin
                        s_if.rx_data <= {s_if.rx_data[8:0],s_if.MOSI};
                        s_if.rx_valid <= 0;
                        rd_addr_recieved <= 1;
                        counter <= counter + 1;
                    end
                    if (counter >= 9)
                        s_if.rx_valid <= 1;
                end
            READ_DATA :
                begin
                    if(s_if.tx_valid && counter >= 3) begin
                        s_if.MISO <= s_if.tx_data[counter - 3];
                        counter <= counter - 1;
                    end
                    else 
                    if(counter <= 9) begin
                        s_if.rx_data <= {s_if.rx_data[8:0],s_if.MOSI}; // recieved bits are MSB TO LSB
                        s_if.rx_valid <= 0;
                        counter <= counter + 1;
                    end
                    // After the Conversion of last bit instantly Rasie s_if.rx_valid to High
                    if(counter >= 9) begin
                        s_if.rx_valid <= 1;
                        rd_addr_recieved <= 0;
                    end
                end
        endcase
    end
end
endmodule

// When The SPI_Wrapper Tell SPI_Slave_Interface To Begin Communication -> s_if.SS_n = 0
// First Detect First Bit From s_if.MOSI "din[9]" = 0 To Implement Write Commands or "din[9]" = 1 To Implement Read Commands
// Then SPI_Slave_Interface Expects to receive 10 Bits On 10 s_if.clk Cycles
// First 2 Cycles we Recieve "00" or "01" or "10" or "11" & then Write Address or Write Data or Read Address or Read Data Respectively Will be Sent on 8 More s_if.clk Cycles
// To Convert Serial to Parallel and Save it in s_if.rx_data
// Then We Will Make s_if.rx_valid -> High To Make The RAM Checks on din[9:8] and Find That it Hold "00" or "01" or "10" or "11"
// Then RAM Save the din[7:0] as A Write Address or Write Data or Read Address or Read Data Respectively in The address Internal Signals or Data Internal Signal
// SPI Slave FSM Transitions in Write Address & Write Data & Read Address & Read Data Commands