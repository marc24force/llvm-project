//===-- RISCVInstrSPARROW.td - Target Description for RISCV SPARROW  ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISCV SPARROW instructions in TableGen format.
//
//===----------------------------------------------------------------------===//

// Define SCR (Simd Control register)
def SCR    : RISCVReg<0, "SCR">;

//===----------------------------------------------------------------------===//
// Instruction format superclass
//===----------------------------------------------------------------------===//

//AI format
class RV_AI<bits<5>sd1Val, bits<3> sd2Val, dag outs, dag ins,
            string opcodestr, string argstr>
      : RVInst<outs, ins, opcodestr, argstr, [], InstFormatR> {
      bits<5> rs2;
      bits<5> rs1;
      bits<5> rd;

      let Inst{31} = 0;
      let Inst{30-26} = sd1Val;
      let Inst{25} = 0;
      let Inst{24-20} = rs2;
      let Inst{19-15} = rs1;
      let Inst{14-12} = sd2Val;
      let Inst{11-7} = rd;
      let Opcode = 0b0001011;
}

//AI format with immediate
class RV_AIimm<bits<5>sd1Val, bits<3> sd2Val, dag outs, dag ins,
            string opcodestr, string argstr>
      : RVInst<outs, ins, opcodestr, argstr, [], InstFormatR> {
      bits<5> simm5;
      bits<5> rs1;
      bits<5> rd;

      let Inst{31} = 1;
      let Inst{30-26} = sd1Val;
      let Inst{25} = 0;
      let Inst{24-20} = simm5;
      let Inst{19-15} = rs1;
      let Inst{14-12} = sd2Val;
      let Inst{11-7} = rd;
      let Opcode = 0b0001011;
}


//===----------------------------------------------------------------------===//
// Instruction Pattern Stuff
//===----------------------------------------------------------------------===//

////5 bit encoded operand for signed AI SPARROW
//def simm5Op : Operand<i8> {
//  let DecoderMethod = "DecodeSIMM5";
//  let EncoderMethod = "getSImm5OpValue";
//}
//
////5 bit encoded operand for unsigned AI SPARROW
//def imm5Op : Operand<i8> {
//  let DecoderMethod = "DecodeIMM5";
//  let EncoderMethod = "getImm5OpValue";
//}

//===----------------------------------------------------------------------===//
// Instruction Class Templates
//===----------------------------------------------------------------------===//

//Simd multiclass - Define both Reg+Reg/Reg+Immm patterns in one shot.
multiclass SD_1<string OpcStr, bits<5> sd1Val, bits<3> sd2Val, SDNode OpNode,
                RegisterClass RC, ValueType Ty, Operand immOp> {

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {
  def rr  : RV_AI<sd1Val, sd2Val, (outs RC:$rd), (ins RC:$rs1, RC:$rs2),
                  OpcStr, "$rd, $rs1, $rs2">;

  def ri  : RV_AIimm<sd1Val, sd2Val, (outs RC:$rd), (ins RC:$rs1, immOp:$simm5),
                  OpcStr, "$rd, $rs1, $simm5">;
}
}

//Simd multiclass - Define all second stages for each first stage
multiclass Simd<string OpcStr, bits<5> sd1Val, SDNode OpNode,
                RegisterClass RC, ValueType Ty, Operand immOp> {

  defm NOP :  SD_1<OpcStr,                     sd1Val, 0b000, OpNode, RC, Ty,
                    immOp> ;
  defm SUM :  SD_1<!strconcat(OpcStr, "sum"),  sd1Val, 0b001, OpNode, RC, Ty,
                    immOp> ;
  defm MAX :  SD_1<!strconcat(OpcStr, "max"),  sd1Val, 0b010, OpNode, RC, Ty,
                    immOp> ;
  defm MIN :  SD_1<!strconcat(OpcStr, "min"),  sd1Val, 0b011, OpNode, RC, Ty,
                    immOp> ;
  defm XOR :  SD_1<!strconcat(OpcStr, "xor"),  sd1Val, 0b100, OpNode, RC, Ty,
                    immOp> ;
  defm USUM : SD_1<!strconcat(OpcStr, "usum"), sd1Val, 0b101, OpNode, RC, Ty,
                    immOp> ;
  defm UMAX : SD_1<!strconcat(OpcStr, "umax"), sd1Val, 0b110, OpNode, RC, Ty,
                    immOp> ;
  defm UMIN : SD_1<!strconcat(OpcStr, "umin"), sd1Val, 0b111, OpNode, RC, Ty,
                    immOp> ;

}

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

//TODO: change sub for sparrow
//SPARROW instructions
let Uses = [SCR] in{
  defm NOP_   : Simd<"nop_",   0b00000, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm ADD_   : Simd<"add_",   0b00001, add, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm SUB_   : Simd<"sub_",   0b00010, sub, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm MUL_   : Simd<"mul_",   0b00011, mul, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm MAX_   : Simd<"max_",   0b00101, smax, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm MIN_   : Simd<"min_",   0b00110, smin, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm AND_   : Simd<"and_",   0b00111, and, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm OR_    : Simd<"or_",    0b01000, or, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm XOR_   : Simd<"xor_",   0b01001, xor, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm NAND_  : Simd<"nand_",  0b01010, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm NOR_   : Simd<"nor_",   0b01011, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm XNOR_  : Simd<"xnor_",  0b01100, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm SADD_  : Simd<"sadd_",  0b01101, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm SSUB_  : Simd<"ssub_",  0b01110, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm SMUL_  : Simd<"smul_",  0b01111, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm MERG_  : Simd<"merg_",  0b10000, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm SHFT_  : Simd<"shft_",  0b10001, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm UMUL_  : Simd<"umul_",  0b10011, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm UMAX_  : Simd<"umax_",  0b10101, umax, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm UMIN_  : Simd<"umin_",  0b10110, umin, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm SSHFT_ : Simd<"sshft_", 0b11001, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm USADD_ : Simd<"usadd_", 0b11101, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm USSUB_ : Simd<"ussub_", 0b11110, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
  defm USMUL_ : Simd<"usmul_", 0b11111, srem, GPR, v4i8, uimm5>,
                Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;

}

////READ and WRITE for the %SCR
let rs2 = 0, rs1 = 0, hasSideEffects = 0,
    mayLoad = 0, mayStore = 0, Uses=[SCR] in
      def RDSCR : RVInstR<0, 0, RISCVOpcode<0b0011111>,
                  (outs GPR:$rd), (ins), "scrrd", "$rd">,
          Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;
let Defs = [SCR], rd=0, hasSideEffects = 1,
    mayLoad = 0, mayStore = 0 in {
      def WRSCRrr : RVInstR<0, 1, RISCVOpcode<0b0011111>,
                  (outs), (ins GPR:$rs1, GPR:$rs2), "scrwr", "$rs1, $rs2">,
          Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;

      def WRSCRri : RVInstI<3, RISCVOpcode<0b0011111>, (outs),
                  (ins GPR:$rs1, simm12:$imm12), "scrwr", "$rs1, $imm12">,
          Sched<[WriteIALU32, ReadIALU32, ReadIALU32]>;

}

//===----------------------------------------------------------------------===//
// Patterns for type compatibility
//===----------------------------------------------------------------------===//

//def : Pat<(v4i8 (load ADDRrr:$addr)), (LDrr ADDRrr:$addr)>;
//def : Pat<(v4i8 (load ADDRri:$addr)), (LDri ADDRri:$addr)>;
//def : Pat<(store  v4i8:$src, ADDRrr:$addr), (STrr ADDRrr:$addr, $src)>;
//def : Pat<(store  v4i8:$src, ADDRri:$addr), (STri ADDRri:$addr, $src)>;

//===----------------------------------------------------------------------===//
// Aliases
//===----------------------------------------------------------------------===//

//dot alias
def : InstAlias<"dot $rd, $rs1, $rs2", (MUL_SUMrr GPR:$rd, GPR:$rs1,
                                                             GPR:$rs2), 0>;
def : InstAlias<"dot $rd, $rs1, $simm5", (MUL_SUMri GPR:$rd, GPR:$rs1,
                                                             uimm5:$simm5), 0>;

//udot alias
def : InstAlias<"udot $rd, $rs1, $rs2", (UMUL_USUMrr GPR:$rd,
                GPR:$rs1, GPR:$rs2), 0>;
def : InstAlias<"udot $rd, $rs1, $simm5", (UMUL_USUMri GPR:$rd,
                GPR:$rs1, uimm5:$simm5), 0>;

//sdot alias
def : InstAlias<"sdot $rd, $rs1, $rs2", (SMUL_SUMrr GPR:$rd,
                GPR:$rs1, GPR:$rs2), 0>;
def : InstAlias<"sdot $rd, $rs1, $simm5", (SMUL_SUMri GPR:$rd,
                GPR:$rs1, uimm5:$simm5), 0>;

//usdot alias
def : InstAlias<"usdot $rd, $rs1, $rs2", (USMUL_USUMrr GPR:$rd,
                GPR:$rs1, GPR:$rs2), 0>;
def : InstAlias<"usdot $rd, $rs1, $simm5", (USMUL_USUMri GPR:$rd,
                GPR:$rs1, uimm5:$simm5), 0>;

//nop alias nop_ -> nop %x0, %x0, %x0
def : InstAlias<"nop_", (NOP_NOPrr X0, X0, X0), 0>;

//nop alias nop_x rs1, rd -> nop_x rs1, %x0, rd
def : InstAlias<"nop_ $rd, $rs1", (NOP_NOPrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"pass_ $rd, $rs1", (NOP_NOPrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"nop_sum $rd, $rs1", (NOP_SUMrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"nop_max $rd, $rs1", (NOP_MAXrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"nop_min $rd, $rs1", (NOP_MINrr GPR:$rd,
                                      GPR:$rs1, X0), 0>;
def : InstAlias<"nop_xor $rd, $rs1", (NOP_XORrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"nop_usum $rd, $rs1", (NOP_USUMrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"nop_umax $rd, $rs1", (NOP_UMAXrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
def : InstAlias<"nop_umin $rd, $rs1", (NOP_UMINrr GPR:$rd,
                                       GPR:$rs1, X0), 0>;
// scrwr reg_or_imm -> scrwr %x0, reg_or_imm
def : InstAlias<"scrwr $rs2", (WRSCRrr X0, GPR:$rs2), 0>;
def : InstAlias<"scrwr $imm12", (WRSCRri X0, simm12:$imm12), 0>;
