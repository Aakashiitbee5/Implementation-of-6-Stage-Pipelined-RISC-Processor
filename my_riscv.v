module my_risc(clk1,clk2,end_opc);
input clk1,clk2;
output end_opc;
reg [15:0] if_id_ir,id_rd_ir,rd_ex_ir,ex_mem_ir,mem_wb_ir;
reg [15:0] pc,if_id_npc,id_rd_npc,rd_ex_npc,ex_mem_npc,mem_wb_npc;
reg [2:0] id_rd_type,rd_ex_type,ex_mem_type,mem_wb_type;
//rr=register-register instn rm-register-memory instn
parameter rr_alu=3'd0, rm_alu=3'd1,load=3'd2,store=3'd3,branch=3'd4,halt=3'd5; //what is type of instruction
reg halted;
reg [15:0] ex_mem_aluout,mem_wb_aluout,ex_mem_b;
reg ex_mem_cond;
// register bank 
reg [15:0] Reg [0:7];
// data memory ;
reg [15:0] memd [0:1023];
// instn memory
reg [15:0] memi [0:255];
//wb temp reg
reg [15:0] mem_wb_lmd;
reg ex_mem_carry=1'b0,ex_mem_zero=1'b0,mem_wb_carry=1'b0,mem_wb_zero=1'b0;
reg final_carry=1'b0,final_zero=1'b0;
//op-codes declarations
parameter add=4'b0001,addimm=4'b0000,ndu_1=4'b0010,lli=4'b0011,load_i=4'b0100,store_i=4'b0101;
//for add types
parameter ada=3'd0,adc=3'd2,adz=3'd1,awc=3'd3,aca=3'd4,acc=3'd6,acz=3'd5,acw=3'd7;
//for nand types
parameter ndu=3'd0,ndc=3'd2,ndz=3'd1,ncu=3'd4,ncc=3'd6,ncz=3'd5;
parameter nops=4'b1110;
parameter lm1=4'b0110,sm1=4'b0111;
parameter beq=4'b1000,blt=4'b1001,ble=4'b1010;   // branching               
parameter jal=4'b1100,jlr=4'b1101,jri=4'b1111,halt_i=4'bxxxx; //branching instruction
parameter rtype=2'd0,itype=2'd1,jtype=2'd2,t_halt_type=2'd3;
/////////////////////////////////////////////////////////////
reg id_rd_src1en,id_rd_src2,en,id_rd_desten;
reg [15:0] id_rd_imm;
//flag reg modifier
reg [3:0] id_rd_c_cr_z,rd_ex_c_cr_z,ex_mem_c_cr_z,mem_wb_c_cr_z;
reg ex_mem_flag_Z,ex_mem_flag_c;
reg [15:0] rd_ex_A,rd_ex_B,rd_ex_imm;
//stall and forwarding
reg [5:0] stall;
reg data_avl_ex,data_avl_wb,data_avl_mem;//forward this to the operand read stage for data hazards
reg load_dependency=1'b0;
reg clk1_fetch=1'b0,clk1_mem=1'b0,clk1_read=1'b0,clk2_decode=1'b0,clk2_execute=1'b0,clk2_write=1'b0;
integer count_stall=0;
reg start_count=1'b0;


//inst fetch stage
always@(posedge clk1_fetch) begin
    if((halted==0 || stall[0]==0)) begin
        if(((ex_mem_ir[15:12]==beq || ex_mem_ir[15:12]==blt || ex_mem_ir[15:12]==ble || ex_mem_ir[15:12]==jal || ex_mem_ir[15:12]==jlr || ex_mem_ir[15:12]==jri) && ex_mem_cond==1)) begin
            if_id_ir<=#2 memi[ex_mem_aluout];
            if_id_npc<=#2 ex_mem_aluout+1;
            pc<=#2 ex_mem_aluout;
        end
        else begin
            if_id_ir<=#2 memi[pc];
            if_id_npc<=#2 pc+1;
            pc<=#2 pc+1;
        end
    end  

end

// instruction decode stage
always@(posedge clk2_decode) begin
    if((halted==0 || stall[1]==0 )) begin
        //
        id_rd_npc<=#2 if_id_npc;
        if((ex_mem_ir[15:12]==beq || ex_mem_ir[15:12]==blt || ex_mem_ir[15:12]==ble || ex_mem_ir[15:12]==jal || ex_mem_ir[15:12]==jlr || ex_mem_ir[15:12]==jri) && ex_mem_cond==1) begin
            id_rd_ir<=#2 {nops,12'hxxx};
        end
        else begin
            id_rd_ir<=#2 if_id_ir;
        end
        if(if_id_ir[15:12]==4'b0000 || if_id_ir[15:12]==4'b0100 || if_id_ir[15:12]==4'b0101 || if_id_ir[15:12]==4'b1000 || if_id_ir[15:12]==4'b1001 || if_id_ir[15:12]==blt || if_id_ir[15:12]==ble) begin
            id_rd_imm<=#2 {{10{if_id_ir[5]}},{if_id_ir[5:0]}}; //sign extend bits
        end
        else begin
            id_rd_imm<=#2 {{10{if_id_ir[8]}},{if_id_ir[8:0]}}; //sign extend bits #9 imm
        end
        case(if_id_ir[15:12])
            add,ndu_1: begin
							id_rd_c_cr_z<= #2 if_id_ir[2:0];
							id_rd_type<= #2 rr_alu;  //all rtype instn
						end
            addimm:begin
						id_rd_c_cr_z<= #2 2'd0;
                  id_rd_type<=#2 rm_alu;
						end
            load_i:begin
						id_rd_c_cr_z<= #2 2'd0;
						id_rd_type<=#2 load;
						end
            store_i:begin
						id_rd_c_cr_z<= #2 2'd0;
                  id_rd_type<=#2 store;   
						end
			beq,blt: begin
					id_rd_c_cr_z<=#2 2'd0;
                    id_rd_type<=#2 branch;
					end
            ble:begin
                    id_rd_c_cr_z<=#2 2'd0;
                    id_rd_type<=#2 branch;
            end
            jal:begin
                id_rd_c_cr_z<=#2 2'd0;
                id_rd_type<=#2 branch;
            end
            jlr:begin
                id_rd_c_cr_z<=#2 2'd0;
                id_rd_type<=#2 branch;
            end
            jri:begin
                id_rd_c_cr_z<=#2 2'd0;
                id_rd_type<=#2 branch;
            end
            default: id_rd_type<=#2 halt;
        endcase
    end
    
end
// register read stage 
always@(posedge clk1_read) begin
    if((halted==0 || stall[2]==0 ) ) begin
        if((ex_mem_ir[15:12]==beq || ex_mem_ir[15:12]==blt || ex_mem_ir[15:12]==ble || ex_mem_ir[15:12]==jal || ex_mem_ir[15:12]==jlr || ex_mem_ir[15:12]==jri) && ex_mem_cond==1) begin
            rd_ex_ir<=#2 {nops,12'hxxx};
        end
        else begin
            rd_ex_ir<=#2 id_rd_ir;
        end
        rd_ex_c_cr_z<=#2 id_rd_c_cr_z;
        
        rd_ex_npc<=#2 id_rd_npc;
        rd_ex_type<=#2 id_rd_type;
        rd_ex_A<=#2 Reg[id_rd_ir[11:9]];
        rd_ex_B<=#2 Reg[id_rd_ir[8:6]];
        rd_ex_imm<=#2 id_rd_imm;
        //rr_memory-immediate opr inst dependency and forwarding check
        if(id_rd_type==rm_alu && (rd_ex_type==rr_alu || ex_mem_type==rr_alu)) begin
            if(id_rd_ir[11:9]==rd_ex_ir[5:3]) begin
                rd_ex_A<=#2 ex_mem_aluout;
            end
            if(id_rd_ir[11:9]==ex_mem_ir[5:3]) begin
                rd_ex_A<=#2 mem_wb_aluout;
            end
        end
        // check imm withrr dependency
        if(id_rd_type==rr_alu && (rd_ex_type==rm_alu || ex_mem_type==rm_alu)) begin
            if(id_rd_ir[11:9]==rd_ex_ir[8:6]) begin
                rd_ex_A<=#2 ex_mem_aluout;
            end
            else if(id_rd_ir[11:9]==ex_mem_ir[8:6]) begin
                rd_ex_A<=#2 mem_wb_aluout;
            end
            else if(id_rd_ir[8:6]==rd_ex_ir[8:6]) begin
                rd_ex_B<=#2 ex_mem_aluout;
            end
            else if(id_rd_ir[8:6]==ex_mem_ir[8:6]) begin
                rd_ex_B<=#2 mem_wb_aluout;
            end
        end

        //implement R-R forwarding only checking source and destination using IR
        if(id_rd_type==rr_alu && (rd_ex_type==rr_alu || ex_mem_type==rr_alu)) begin
            if(id_rd_ir[11:9]==rd_ex_ir[5:3]) begin
                rd_ex_A<=#2 ex_mem_aluout;
            end
            else if(id_rd_ir[11:9]==ex_mem_ir[5:3]) begin
                rd_ex_A<=#2 mem_wb_aluout;
            end
            else if(id_rd_ir[8:6]==rd_ex_ir[5:3]) begin
                rd_ex_B<=#2 ex_mem_aluout;
            end
            else  if(id_rd_ir[8:6]==ex_mem_ir[5:3]) begin
                rd_ex_B<=#2 mem_wb_aluout;
            end
        end
        //load with stall + forwarding in separate always block comb for immediate dependency
        if(id_rd_type==rr_alu && ex_mem_type==load) begin
            if(id_rd_ir[11:9]==ex_mem_ir[8:6]) begin
                rd_ex_A<=#2 mem_wb_lmd;
            end
            else if(id_rd_ir[8:6]==ex_mem_ir[8:6]) begin
                rd_ex_B<=#2 mem_wb_lmd;
            end
        end
        //load with stall+forwarding rm register_memory 
        if(id_rd_type==rm_alu && ex_mem_type==load) begin
            if(id_rd_ir[11:9]==ex_mem_ir[8:6]) begin
                rd_ex_A<=#2 mem_wb_lmd;
            end

        end

                
    end
    
end

// execute stage 
always@(posedge clk2_execute)
 begin
    if(halted==0 || stall[3]==0) begin
        ex_mem_type<=#2 rd_ex_type;
        ex_mem_ir<=#2 rd_ex_ir;
        ex_mem_c_cr_z<=#2 rd_ex_c_cr_z;
        ex_mem_npc<=#2 rd_ex_npc;
        case(rd_ex_type) 
            rr_alu: begin
                case(rd_ex_ir[15:12]) //decode based on opcode
                add: 
                    case(rd_ex_c_cr_z)
                    ada:begin
                        {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+rd_ex_B;
                        if(rd_ex_A+rd_ex_B==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        end
                    adc: begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+rd_ex_B;
                            if(rd_ex_A+rd_ex_B==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                    end

                    adz:begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+rd_ex_B;
                            if(rd_ex_A+rd_ex_B==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                    end
                    awc:begin
                        {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+rd_ex_B+ex_mem_carry;
                        if(rd_ex_A+rd_ex_B+ex_mem_carry==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        end
                    aca:begin
                        {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+(~rd_ex_B);
                        if(rd_ex_A+(~rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        end
                    acc: begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+(~rd_ex_B);
                            if(rd_ex_A+(~rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                    end
                    acz:begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+(~rd_ex_B);
                            if(rd_ex_A+(~rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                    end
                    acw:begin
                        {ex_mem_carry,ex_mem_aluout}<=#2 rd_ex_A+(~rd_ex_B)+ex_mem_carry;
                        if(rd_ex_A+(~rd_ex_B)+ex_mem_carry==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        end
                    default:ex_mem_aluout<=#2 16'hxxxx;
                    endcase
                //encode remaining also 
                ndu_1:case(rd_ex_c_cr_z)
                      ndu: begin
                            {ex_mem_carry,ex_mem_aluout}<=#2 ~(rd_ex_A&rd_ex_B);
                            if(~(rd_ex_A&rd_ex_B)==0) begin
                                ex_mem_zero<=#2 1'b1;
                            end
                      end
                      ndc: begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 ~(rd_ex_A&rd_ex_B);
                            if(~(rd_ex_A&rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end

                      end
                      ndz:begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 ~(rd_ex_A&rd_ex_B);
                            if(~(rd_ex_A&rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                         end
                      ncu:begin
                        {ex_mem_carry,ex_mem_aluout}<=#2 ~(rd_ex_A&rd_ex_B);
                        if(~(rd_ex_A&rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        end
                      ncc:begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 ~(rd_ex_A&rd_ex_B);
                            if(~(rd_ex_A&rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                        end
                      ncz:begin
                        
                            {ex_mem_carry,ex_mem_aluout}<=#2 ~(rd_ex_A&rd_ex_B);
                            if(~(rd_ex_A&rd_ex_B)==0) begin
                            ex_mem_zero<=#2 1'b1;
                        end
                        
                        end
                      default:ex_mem_aluout<=#2 16'hxxxx;
                endcase
                //ex_mem_aluout<=#2 rd_ex_A & rd_ex_B;


                default: ex_mem_aluout<=#2 16'hxxxx;
                endcase
            end
            rm_alu: begin
                    case(rd_ex_ir[15:12]) 
                    addimm:{ex_mem_flag_c,ex_mem_aluout}<=#2 rd_ex_A+rd_ex_imm;

                    default:ex_mem_aluout<=#2 16'hxxxx;
                    endcase
            end
            load,store: begin
                //calculate the address;
                ex_mem_aluout<=#2 rd_ex_A+rd_ex_imm;
                ex_mem_b<=#2 rd_ex_B;
            end
            branch: begin
                case(rd_ex_ir[15:12])
                beq:begin
                    ex_mem_aluout<=#2 rd_ex_npc+rd_ex_imm;
                    ex_mem_cond<=#2 (rd_ex_A==rd_ex_B);
                end
                blt:begin
                    ex_mem_aluout<=#2 rd_ex_npc+rd_ex_imm;
                    ex_mem_cond<=#2 (rd_ex_A < rd_ex_B);
                end
                ble:begin
                    ex_mem_aluout<=#2 rd_ex_npc+rd_ex_imm;
                    ex_mem_cond<=#2 (rd_ex_A <= rd_ex_B);
                end
                jal:begin
                    ex_mem_aluout<=#2 rd_ex_npc+rd_ex_imm;
                    ex_mem_cond<=#2 1'b1;   //unconditional jump
                end
                jlr:begin
                    ex_mem_aluout<=#2 rd_ex_B;
                    ex_mem_cond<=#2 1'b1;
                end
                jri:begin
                    ex_mem_aluout<=#2 rd_ex_A+rd_ex_npc;
                    ex_mem_cond<=#2 1'b1;
                end
                default:begin
                        ex_mem_aluout<=#2 rd_ex_npc;
                        ex_mem_cond<=#2 1'b0;
						end
                endcase
            end
        endcase

    end 
 end

 //mem stage
 always@(posedge clk1_mem) begin
    if(halted==0 || stall[4]==0) begin
        mem_wb_carry<=#2 ex_mem_carry;
        mem_wb_zero<=#2 ex_mem_zero;
        mem_wb_c_cr_z<=#2 ex_mem_c_cr_z;
        mem_wb_type=#2 ex_mem_type;
        mem_wb_ir<=#2 ex_mem_ir;
        mem_wb_npc<=#2 ex_mem_npc;
        case(ex_mem_type)
        rr_alu,rm_alu: mem_wb_aluout<=#2 ex_mem_aluout;
        load:mem_wb_lmd<=#2 memd[ex_mem_aluout];    //accessed data stored in temporary buffer 
        store: 
                memd[ex_mem_aluout]<=# 2 ex_mem_b;
        branch:mem_wb_aluout<=#2 ex_mem_aluout;
        
        endcase
    end
 end


 //write back stage
 always@(posedge clk2_write) begin
    if(stall[5]==0) begin
        final_carry<=#2 mem_wb_carry;
        final_zero<=#2 mem_wb_zero;


        case(mem_wb_type) 
        rr_alu: 
        case(mem_wb_c_cr_z)
        ada:Reg[mem_wb_ir[5:3]]<=#2 mem_wb_aluout;
        adc,acc:if(final_carry==1)
            Reg[mem_wb_ir[5:3]]<=#2 mem_wb_aluout;
        adz,acz:if(final_zero==1)
            Reg[mem_wb_ir[5:3]]<=#2 mem_wb_aluout;
        default:Reg[mem_wb_ir[5:3]]<=#2 mem_wb_aluout;
        endcase

        rm_alu:Reg[mem_wb_ir[8:6]]<=#2 mem_wb_aluout;
        load: Reg[mem_wb_ir[8:6]]<=#2 mem_wb_lmd;
        branch:case(mem_wb_ir[15:12])
                jal,jlr:begin
                    Reg[mem_wb_ir[11:9]]<=#2 mem_wb_npc;
                end
            endcase
		  halt: halted<=#2 1'b1;
        endcase
    end
 end
 
 assign end_opc= halted;
 //stalls
always@(*) begin
    if(id_rd_type==rr_alu && rd_ex_type==load && count_stall<2) begin
        if(id_rd_ir[11:9]==rd_ex_ir[8:6] ) begin
            load_dependency<= #2 1'b1;
            start_count<=1;
        end
        else if(id_rd_ir[8:6]==rd_ex_ir[8:6]) begin
            load_dependency<=#2 1'b1;
            start_count<=1;
        end
        else begin
            load_dependency<=#2 1'b0;
        end

    end
    else if(id_rd_type==rm_alu && rd_ex_type==load && count_stall<2) begin
        if(id_rd_ir[11:9]==rd_ex_ir[8:6]) begin
            load_dependency<=#2 1'b1;
            start_count<=1;
        end
        else begin
            load_dependency<=#2 1'b0;
        end
    end

    else begin
        start_count<=0;
        load_dependency<=#2 1'b0;

    end


    if(load_dependency==1) begin
        clk1_fetch<=0;
        clk2_decode<=0;
        clk1_read<=0;
        clk2_execute<=clk2;
        clk1_mem<=clk1;
        clk2_write<=clk2;
    end
    else begin
        clk1_fetch<=clk1;
        clk2_decode<=clk2;
        clk1_read<=clk1;
        clk2_execute<=clk2;
        clk1_mem<=clk1;
        clk2_write<=clk2;
    end
end
always@(posedge clk1) begin
    if(start_count==1) begin
        count_stall<=#2 count_stall+1;
    end
    else begin
        count_stall<=#2 0;
    end
end
endmodule





