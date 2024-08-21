module test_proc();
reg clk1,clk2;
integer k;

my_risc mips(clk1,clk2);

initial begin
    clk1=0;
    clk2=0;
    repeat(60) begin
        #5 clk1=1; #5 clk1=0;
        #5 clk2=1; #5 clk2=0;
    end
end

initial begin
    for(k=0;k<8;k=k+1) begin
        mips.Reg[k]=k;
    end
    for (k=0;k<20;k=k+1) begin
        mips.memd[k]=k;
    end
   mips.memi[0]=16'b0001_011_010_001_000;//add r1=r2+r3=5
	mips.memi[1]=16'b1000_000_000_000_111;//beq to pc+imm=2+7=9
   mips.memi[2]=16'b0001_001_101_100_000; // add r4=r5+r1=10	is skipped since branch 
	mips.Reg[7]=16'hffff;						//to set carryflag just assume R7=FFFF
	 
   mips.memi[10]=16'b0001_001_111_110_000;//add set cy=1 and R6=R1+R7=5+H'FFFF=4
	//instn 11 dependency on instn 10
	mips.memi[11]=16'b0001_011_110_010_010;//add cy=set//not executed r2=R6+R3=4+3=7
	mips.memi[12]=16'b0001_000_000_001_000;// make alu==0 set zeroflag r1=r0+r0=0
	//instn 13 dependency on instn 10 at distance 2
	mips.memi[13]=16'b0001_011_010_001_001;// add if zy=1 r1=r2+r3=10
	mips.memi[14]=16'b0001_011_111_001_100; //r1=~r7+r3=3
   mips.memi[15]=16'b0100_110_000_000000;//LOAD R0 WORKS at R0=M[R6+0]=M[4]=4
	//inst 16 has immediate dependency after load 
	//one stall + forwarding
   mips.memi[16]=16'b0001_000_000_001_000; //add contents R1=R0+R0=4+4=8
   mips.memi[17]=16'b0001_001_101_100_000; // add r4=r5+r1=13
    ////////////////////////////////////////
   mips.memi[18]=16'b0101_000_000_000001;	//store M[R0+1]=M[5]=4
   mips.memi[19]=16'b0101_000_000_000010;//Store M[6]=4
   mips.memi[20]=16'b0101_000_001_000000;//store M[4]=8
	 ////////////////////////////////////////
	mips.memi[21]=16'b0000_000_001_001000; //r1=r0+imm=4+8=12
	//dependency of immediate instn on next instn 22
	mips.memi[22]=16'b0001_001_110_100_000;//r4=r6+r1=12+4=16
	 /////branch less than and less than equal_to
    mips.memi[23]=16'b1001_011_100_000011; //blt R3<R4=true skip pc=24+imm=27
   //mips.memi[23]=16'b1010_000_000_000011;  //ble if 
    //mips.memi[23]=16'b1100_000_000000011;   //jal
    
    //mips.memi[23]=16'b1101_111_000_000000;  //jlr these also branch  to 27th 
   mips.memi[24]=16'b0001_011_010_001_000;
   mips.memi[25]=16'b0001_011_010_001_000;
   mips.memi[26]=16'b0001_011_010_001_000;
   mips.memi[27]=16'b0001_011_010_011_000;//executes this after branch r3=r3+r2=3+7=10
   mips.memi[28]=16'b0001_011_010_001_000;//dependency r1=r3+r2=10+7=17

    //mips.memi[0]=16'b0110_100_111111000;
    //mips.memi[3]=16'b0001_010_011_000100;
    mips.halted=0;
    mips.stall=0;
    mips.pc=0;
	 
    //mips.taken_branch=0;
    
    #280;    
end

initial begin
    #700 $finish;
end
endmodule

