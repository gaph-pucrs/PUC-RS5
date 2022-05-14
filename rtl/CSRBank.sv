import my_pkg::*;

module CSRBank (
    input logic clk,
    input logic reset,
    input logic rd_en,
    input logic wr_en,
    input csr_ops csr_op,
    input logic [11:0] addr,
    input logic [31:0] data,
    output logic [31:0] out,

    input logic RAISE_EXCEPTION,
    input logic [30:0] CODE,
    input Privilege privilege,
    input logic [31:0] PC,
    input logic [31:0] instruction
    );

    CSRs CSR = addr;
    logic [31:0] mstatus, misa, mie, mtvec, mcounteren, mstatush, mscratch, mepc, mcause, mtval, mip, mtinst, mtval2;
    logic [31:0] wr_data, wmask, current_val;
    //logic [31:0] medeleg, mideleg; // NOT IMPLEMENTED YET (REQUIRED ONLY WHEN SYSTEM HAVE S-MODE)

    always_comb begin
        wmask <= '1;
        case (csr_add)
            // RW REGS
            MSTATUS:    begin current_val <= mstatus;   wmask <= 32'h007E19AA; end
            MISA:       begin current_val <= misa;      wmask <= 32'h3C000000; end
            //MEDELEG:    begin current_val <= medeleg;   wmask <= '1; end
            //MIDELEG:    begin current_val <= mideleg;   wmask <= '1; end
            MIE:        begin current_val <= mie;       wmask <= 32'h00000888; end
            MTVEC:      begin current_val <= mtvec;     wmask <= 32'hFFFFFFFC; end
            //MCOUNTEREN: begin current_val <= mcounteren;wmask <= '1; end
            //MSTATUSH:   begin current_val <= mstatush;  wmask <= '1; end
            MSCRATCH:   begin current_val <= mscratch;  wmask <= 32'hFFFFFFFF; end
            MEPC:       begin current_val <= mepc;      wmask <= 32'hFFFFFFFC; end
            MCAUSE:     begin current_val <= mcause;    wmask <= 32'hFFFFFFFF; end
            MTVAL:      begin current_val <= mtval;     wmask <= 32'hFFFFFFFF; end
            MIP:        begin current_val <= mip;       wmask <= 32'h00000000; end

            default:    begin current_val <= '0;        wmask <= 32'h00000000; end
        endcase
    end

    always_comb
        if(csr_op==write)
            wr_data <= data & wmask;
        else if(csr_op==set)
            wr_data <= (current_val | data) & wmask;
        else if(csr_op==clear)
            wr_data <= (current_val & !data) & wmask;
        else
            wr_data <= 'Z;

    always @(negedge reset or posedge clk) begin
        if(!reset) begin
            mstatus <= '0;
            mstatus[3] <= 0;        // MIE  = 0
            mstatus[17] <= 0;       // MPRV = 0
            misa <= 32'h40000100;   // 32 - I
            //medeleg <= '0;
            //mideleg <= '0;
            mie <= '0;
            mtvec <= '0;
            //mcounteren <= '0;
            //mstatush <= '0;
            mscratch <= '0;
            mepc <= '0;
            mcause <= '0;
            mtval <= '0;
            mip <= '0;

        end else if(RAISE_EXCEPTION) begin

            mcause          <= 0 & CODE;
            mstatus[12:11]  <= privilege;           // MPP previous privilege
            mstatus[7]      <= mstatus[3];          // MPIE = MIE
            mstatus[3]      <= 0;                   // MIE = 0
            mepc            <= PC+4;                // Return address
            mtval           <= (CODE==ILLEGAL_INSTRUCTION) ? instruction : PC;
        
        end else if(wr_en) begin
            case(CSR)
                MSTATUS:    mstatus     <= wr_data;
                MISA:       misa        <= wr_data;
                //MEDELEG:    medeleg     <= wr_data;
                //MIDELEG:    mideleg     <= wr_data;
                MIE:        mie         <= wr_data;
                MTVEC:      mtvec       <= wr_data;
                //MCOUNTEREN: mcounteren  <= wr_data;
                //MSTATUSH:   mstatush    <= wr_data;
                MSCRATCH:   mscratch    <= wr_data;
                MEPC:       mepc        <= wr_data;
                MCAUSE:     mcause      <= wr_data;
                MTVAL:      mtval       <= wr_data;
                MIP:        mip         <= wr_data;
            endcase
        end
    end

    always_comb
        if(rd_en)
            case(CSR)
                MVENDORID:  out <= '0;
                MARCHID:    out <= '0;
                MIMPID:     out <= '0;
                MHARTID:    out <= '0;
                MCONFIGPTR: out <= '0;

                MSTATUS:    out <= mstatus;
                MISA:       out <= misa;
                //MEDELEG:    out <= medeleg;
                //MIDELEG:    out <= mideleg;
                MIE:        out <= mie;
                MTVEC:      out <= mtvec;
                //MCOUNTEREN: out <= mcounteren;
                //MSTATUSH:   out <= mstatush;
                MSCRATCH:   out <= mscratch;
                MEPC:       out <= mepc;
                MCAUSE:     out <= mcause;
                MTVAL:      out <= mtval;
                MIP:        out <= mip;
            endcase
        else
            out <= '0;

endmodule;