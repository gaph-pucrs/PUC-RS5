/*!\file retire.sv
 * PUCRS-RV VERSION - 1.0 - Public Release
 *
 * Distribution:  September 2021
 *
 * Willian Nunes   <willian.nunes@edu.pucrs.br>
 * Marcos Sartori  <marcos.sartori@acad.pucrs.br>
 * Ney calazans    <ney.calazans@pucrs.br>
 *
 * Research group: GAPH-PUCRS  <>
 *
 * \brief
 * Retire is the last stage of the PUCRS-RV processor.
 *
 * \detailed
 * Retire is the last stage of the PUCRS-RV processor and is reponsible for closing the loops.
 * First compares the instruction_i tag and the internal tag, if they does not match then the 
 * instruction_i is killed and no operation is performed, otherwise it sends the data received 
 * to the designed outputs, they are: 
 * 1) Register bank mem_write_enable_o data and mem_write_enable_o enable
 * 2) Branch address (New_PC)
 * 3) Memory mem_write_enable_o signals (Data, address and mem_write_enable_o enable)
 */

import my_pkg::*;

module retire(
    input   logic           clk,
    input   logic           reset,
    
    input   logic [31:0]    instruction_i,
    input   logic [31:0]    pc_i,
    input   logic [31:0]    results_i [1:0],            // Results array
    input   logic [2:0]     tag_i,                      // Instruction tag to be compared with retire tag
    input   logic [3:0]     mem_write_enable_i,         // Write enable memory
    input   logic           write_enable_i,             // Write enable from Execute(based on instruction_i type)
    input   logic           jump_i,                     // Jump signal from branch unit 
    input   iType_e         instruction_operation_i,
    input   logic           exception_i,

    output  logic           regbank_write_enable_o,     // Write Enable to Register Bank
    output  logic [31:0]    regbank_data_o,             // WriteBack data to Register Bank
    output  logic [31:0]    jump_target_o,              // Branch target to fetch Unit
    output  logic           jump_o,                     // Jump signal to Fetch Unit

    output  logic [31:0]    mem_write_address_o,        // Memory mem_write_enable_o address
    output  logic [3:0]     mem_write_enable_o,         // Memory mem_write_enable_o enable
    output  logic [31:0]    mem_data_o,                 // Memory data to be written
    input   logic [31:0]    mem_data_i,                 // Data from memory

    output  logic [2:0]     current_retire_tag_o,
    output  exceptionCode_e exception_code_o,
    output  logic           raise_exception_o,
    output  logic           machine_return_o,
    output  logic           interrupt_ack_o,
    input   logic           interrupt_pending_i
);

    logic [31:0] memory_data;
    logic [2:0] curr_tag;
    logic killed;
    executionUnit_e execution_unit_selection;

    assign current_retire_tag_o = curr_tag;
    assign execution_unit_selection = executionUnit_e'(instruction_operation_i[5:3]);

//////////////////////////////////////////////////////////////////////////////
// Assign to Register Bank Write Back
//////////////////////////////////////////////////////////////////////////////

    assign regbank_data_o = (execution_unit_selection == MEMORY_UNIT) 
                            ? memory_data 
                            : results_i[0];

//////////////////////////////////////////////////////////////////////////////
// Killed signal generation
//////////////////////////////////////////////////////////////////////////////

    always_comb begin
        if (curr_tag != tag_i) begin
            killed <= 1;
        end
        else begin
            killed <= 0;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// TAG control based on signals Jump and Killed
//////////////////////////////////////////////////////////////////////////////

    always @(posedge clk) begin
        if (reset) begin
            curr_tag <= 0;
        end
        else if (killed == 0 && (jump_o == 1 || raise_exception_o == 1 || machine_return_o == 1 || interrupt_ack_o == 1)) begin
            curr_tag <= curr_tag + 1;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// RegBank Writw Enable Generation
//////////////////////////////////////////////////////////////////////////////

    always_comb begin
        if (killed == 1) begin
          regbank_write_enable_o <= 0;
        end 
        else begin
          regbank_write_enable_o <= write_enable_i;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// PC Flow control signal generation
//////////////////////////////////////////////////////////////////////////////

    always_comb begin
        if (jump_i == 1 && killed == 0) begin
            jump_target_o <= results_i[1];
            jump_o        <= 1;
        end 
        else begin
            jump_target_o <= '0;
            jump_o        <= '0;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// Memory Signal Generation
//////////////////////////////////////////////////////////////////////////////

    always_comb begin
        if (instruction_operation_i == LB || instruction_operation_i == LBU) begin
            case (results_i[1][1:0])
                2'b11:   begin 
                            memory_data[7:0] <= mem_data_i[31:24]; 
                            memory_data[31:8] <= (mem_data_i[31] == 1 && instruction_operation_i == LB) 
                                                ? '1 
                                                : '0;
                        end
                2'b10:   begin 
                            memory_data[7:0] <= mem_data_i[23:16]; 
                            memory_data[31:8] <= (mem_data_i[23] == 1 && instruction_operation_i == LB) 
                                                ? '1 
                                                : '0; 
                        end
                2'b01:   begin 
                            memory_data[7:0] <= mem_data_i[15:8];
                            memory_data[31:8] <= (mem_data_i[15] == 1 && instruction_operation_i == LB) 
                                                ? '1 
                                                : '0; 
                        end
                default: begin 
                            memory_data[7:0]  <= mem_data_i[7:0]; 
                            memory_data[31:8] <= (mem_data_i[7]  == 1 && instruction_operation_i == LB) 
                                                ? '1 
                                                : '0; 
                        end
            endcase
        end
        else if (instruction_operation_i == LH || instruction_operation_i == LHU) begin
            case (results_i[1][1])
                1'b1:    begin 
                            memory_data[15:0]  <= mem_data_i[31:16]; 
                            memory_data[31:16] <= (mem_data_i[31] == 1 && instruction_operation_i == LH) 
                                                ? '1 
                                                : '0; 
                        end
                default: begin  
                            memory_data[15:0]  <= mem_data_i[15:0]; 
                            memory_data[31:16] <= (mem_data_i[15] == 1 && instruction_operation_i == LH) 
                                                ? '1 
                                                : '0; 
                        end
            endcase

        end 
        else begin
            memory_data <= mem_data_i;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// Memory mem_write_enable_o control
//////////////////////////////////////////////////////////////////////////////

    always_comb begin
        if (mem_write_enable_i != 0 && killed == 0) begin
            mem_write_enable_o    <= mem_write_enable_i;
            mem_write_address_o <= results_i[1];
            mem_data_o          <= results_i[0];
        end 
        else begin
            mem_write_enable_o    <= '0;
            mem_write_address_o <= '0;
            mem_data_o          <= '0;
        end
    end

//////////////////////////////////////////////////////////////////////////////
// Privileged Architecture Control
//////////////////////////////////////////////////////////////////////////////

    always_comb begin
        if (killed == 0) begin
            if (exception_i == 1) begin
                raise_exception_o <= 1;
                exception_code_o  <= ILLEGAL_INSTRUCTION;
                machine_return_o  <= 0;
                interrupt_ack_o   <= 0;
                $write("[%0d] EXCEPTION - ILLEGAL INSTRUCTION: %8h %8h\n", $time, pc_i, instruction_i);
            end 
            else if (instruction_operation_i == ECALL) begin
                raise_exception_o <= 1;
                exception_code_o  <= ECALL_FROM_MMODE;
                machine_return_o  <= 0;
                interrupt_ack_o   <= 0;
                $write("[%0d] EXCEPTION - ECALL_FROM_MMODE: %8h %8h\n", $time, pc_i, instruction_i);
            end 
            else if (instruction_operation_i == EBREAK) begin
                raise_exception_o <= 1;
                exception_code_o  <= BREAKPOINT;
                machine_return_o  <= 0;
                interrupt_ack_o   <= 0;
                $write("[%0d] EXCEPTION - EBREAK: %8h %8h\n", $time, pc_i, instruction_i);
            end 
            else if (instruction_operation_i == MRET) begin
                raise_exception_o <= 0;
                exception_code_o  <= NE;
                machine_return_o  <= 1;
                interrupt_ack_o   <= 0;
                $write("[%0d] MRET: %8h %8h\n", $time, pc_i, instruction_i);
            end 
            else if (interrupt_pending_i == 1 && jump_i == 0) begin
                raise_exception_o <= 0;
                exception_code_o  <= NE;
                machine_return_o  <= 0;
                interrupt_ack_o   <= 1;
                $write("[%0d] Interrupt Acked\n", $time);
            end 
            else begin
                raise_exception_o <= 0;
                exception_code_o  <= NE;
                machine_return_o  <= 0;
                interrupt_ack_o   <= 0;
            end
        end
        else begin
            raise_exception_o <= 0;
            exception_code_o  <= NE;
            machine_return_o  <= 0;
            interrupt_ack_o   <= 0;
        end
    end

endmodule
