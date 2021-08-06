//===-- SparcInstrSPARROW.td - Target Description for Sparc SPARROW  ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the Sparc SPARROW instructions in TableGen format.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Instruction format superclass
//===----------------------------------------------------------------------===//

//AI format
class F3_AI<bits<5>sd1Val, bits<3> sd2Val, dag outs, dag ins,
            string asmstr, list<dag> pattern, InstrItinClass itin = NoItinerary>
      : F3<outs, ins, asmstr, pattern, itin>{
      bits<5> rs2;

      let op = 2;
      let op3 = 0b001001;

      let Inst{13} = 0;
      let Inst{12-10} = sd2Val;
      let Inst{9-5} = sd1Val;
      let Inst{4-0} = rs2;
}

//AI format with immediate
class F3_AIimm<bits<5>sd1Val, bits<3> sd2Val, dag outs, dag ins,
            string asmstr, list<dag> pattern, InstrItinClass itin = NoItinerary>
      : F3<outs, ins, asmstr, pattern, itin>{
      bits<5> simm5;

      let op = 2;
      let op3 = 0b001001;

      let Inst{13} = 1;
      let Inst{12-10} = sd2Val;
      let Inst{9-5} = sd1Val;
      let Inst{4-0} = simm5;
}

//===----------------------------------------------------------------------===//
// Instruction Pattern Stuff
//===----------------------------------------------------------------------===//

//5 bit encoded operand for signed AI SPARROW
def simm5Op : Operand<i8> {
  let DecoderMethod = "DecodeSIMM5";
  let EncoderMethod = "getSImm5OpValue";
}

//5 bit encoded operand for unsigned AI SPARROW
def imm5Op : Operand<i8> {
  let DecoderMethod = "DecodeIMM5";
  let EncoderMethod = "getImm5OpValue";
}

//===----------------------------------------------------------------------===//
// Instruction Class Templates
//===----------------------------------------------------------------------===//

//Simd multiclass - Define both Reg+Reg/Reg+Immm patterns in one shot.
multiclass SD_1<string OpcStr, bits<5> sd1Val, bits<3> sd2Val, SDNode OpNode,
                RegisterClass RC, ValueType Ty, Operand immOp,
                InstrItinClass itin = IIC_iu_simd> {

  def rr  : F3_AI<sd1Val, sd2Val, (outs RC:$rd), (ins RC:$rs1, RC:$rs2),
                  !strconcat(OpcStr, " $rs1, $rs2, $rd"),
                  [(set Ty:$rd, (OpNode Ty:$rs1, Ty:$rs2))],
                  itin>;

  def ri  : F3_AIimm<sd1Val, sd2Val, (outs RC:$rd), (ins RC:$rs1, immOp:$simm5),
                  !strconcat(OpcStr, " $rs1, $simm5, $rd"),
                  [(set Ty:$rd, (OpNode Ty:$rs1, (Ty simm5:$simm5)))],
                  itin>;
}

//Simd multiclass - Define all second stages for each first stage
multiclass Simd<string OpcStr, bits<5> sd1Val, SDNode OpNode,
                RegisterClass RC, ValueType Ty, Operand immOp,
                InstrItinClass itin = IIC_iu_instr> {

  defm NOP :  SD_1<OpcStr,                     sd1Val, 0b000, OpNode, RC, Ty,
                    immOp, IIC_iu_instr> ;
  defm SUM :  SD_1<!strconcat(OpcStr, "sum"),  sd1Val, 0b001, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;
  defm MAX :  SD_1<!strconcat(OpcStr, "max"),  sd1Val, 0b010, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;
  defm MIN :  SD_1<!strconcat(OpcStr, "min"),  sd1Val, 0b011, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;
  defm XOR :  SD_1<!strconcat(OpcStr, "xor"),  sd1Val, 0b100, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;
  defm USUM : SD_1<!strconcat(OpcStr, "usum"), sd1Val, 0b101, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;
  defm UMAX : SD_1<!strconcat(OpcStr, "umax"), sd1Val, 0b110, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;
  defm UMIN : SD_1<!strconcat(OpcStr, "umin"), sd1Val, 0b111, OpNode, RC, Ty,
                    immOp, IIC_iu_simd> ;

}

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

//TODO: change sub for sparrow
//SPARROW instructions
let Uses = [SCR] in{
  defm NOP_   : Simd<"nop_",   0b00000, srem, IntRegs, v4i8, simm5Op>;
  defm ADD_   : Simd<"add_",   0b00001, add, IntRegs, v4i8, imm5Op>;
  defm SUB_   : Simd<"sub_",   0b00010, sub, IntRegs, v4i8, imm5Op>;
  defm MUL_   : Simd<"mul_",   0b00011, mul, IntRegs, v4i8, simm5Op>;
  defm MAX_   : Simd<"max_",   0b00101, smax, IntRegs, v4i8, simm5Op>;
  defm MIN_   : Simd<"min_",   0b00110, smin, IntRegs, v4i8, simm5Op>;
  defm AND_   : Simd<"and_",   0b00111, and, IntRegs, v4i8, imm5Op>;
  defm OR_    : Simd<"or_",    0b01000, or, IntRegs, v4i8, imm5Op>;
  defm XOR_   : Simd<"xor_",   0b01001, xor, IntRegs, v4i8, imm5Op>;
  defm NAND_  : Simd<"nand_",  0b01010, srem, IntRegs, v4i8, imm5Op>;
  defm NOR_   : Simd<"nor_",   0b01011, srem, IntRegs, v4i8, imm5Op>;
  defm XNOR_  : Simd<"xnor_",  0b01100, srem, IntRegs, v4i8, imm5Op>;
  defm SADD_  : Simd<"sadd_",  0b01101, srem, IntRegs, v4i8, imm5Op>;
  defm SSUB_  : Simd<"ssub_",  0b01110, srem, IntRegs, v4i8, imm5Op>;
  defm SMUL_  : Simd<"smul_",  0b01111, srem, IntRegs, v4i8, simm5Op>;
  defm MERG_  : Simd<"merg_",  0b10000, srem, IntRegs, v4i8, imm5Op>;
  defm SHFT_  : Simd<"shft_",  0b10001, srem, IntRegs, v4i8, imm5Op>;
  defm UMUL_  : Simd<"umul_",  0b10011, srem, IntRegs, v4i8, imm5Op>;
  defm UMAX_  : Simd<"umax_",  0b10101, umax, IntRegs, v4i8, imm5Op>;
  defm UMIN_  : Simd<"umin_",  0b10110, umin, IntRegs, v4i8, imm5Op>;
  defm SSHFT_ : Simd<"sshft_", 0b11001, srem, IntRegs, v4i8, imm5Op>;
  defm USADD_ : Simd<"usadd_", 0b11101, srem, IntRegs, v4i8, imm5Op>;
  defm USSUB_ : Simd<"ussub_", 0b11110, srem, IntRegs, v4i8, imm5Op>;
  defm USMUL_ : Simd<"usmul_", 0b11111, srem, IntRegs, v4i8, imm5Op>;
}

//READ and WRITE for the %SCR
let rs2 = 0, rs1 = 0, Uses=[SCR] in
    def RDSCR : F3_1<2, 0b101100,
             (outs IntRegs:$rd), (ins),
             "rd %scr, $rd", []>;

let Defs = [SCR], rd=0 in {
    def WRSCRrr : F3_1<2, 0b011001,
             (outs), (ins IntRegs:$rs1, IntRegs:$rs2),
             "wr $rs1, $rs2, %scr", []>;
    def WRSCRri : F3_2<2, 0b011001,
             (outs), (ins IntRegs:$rs1, simm13Op:$simm13),
             "wr $rs1, $simm13, %scr", []>;
}

//===----------------------------------------------------------------------===//
// Patterns for type compatibility
//===----------------------------------------------------------------------===//

def : Pat<(v4i8 (load ADDRrr:$addr)), (LDrr ADDRrr:$addr)>;
def : Pat<(v4i8 (load ADDRri:$addr)), (LDri ADDRri:$addr)>;
def : Pat<(store  v4i8:$src, ADDRrr:$addr), (STrr ADDRrr:$addr, $src)>;
def : Pat<(store  v4i8:$src, ADDRri:$addr), (STri ADDRri:$addr, $src)>;

//===----------------------------------------------------------------------===//
// Aliases
//===----------------------------------------------------------------------===//

//dot alias
def : InstAlias<"dot $rs1, $rs2, $rd", (MUL_SUMrr IntRegs:$rd, IntRegs:$rs1,
                                                             IntRegs:$rs2), 0>;
def : InstAlias<"dot $rs1, $simm5, $rd", (MUL_SUMri IntRegs:$rd, IntRegs:$rs1,
                                                             i8imm:$simm5), 0>;

//udot alias
def : InstAlias<"udot $rs1, $rs2, $rd", (UMUL_USUMrr IntRegs:$rd,
                IntRegs:$rs1, IntRegs:$rs2), 0>;
def : InstAlias<"udot $rs1, $simm5, $rd", (UMUL_USUMri IntRegs:$rd,
                IntRegs:$rs1, i8imm:$simm5), 0>;

//sdot alias
def : InstAlias<"sdot $rs1, $rs2, $rd", (SMUL_SUMrr IntRegs:$rd,
                IntRegs:$rs1, IntRegs:$rs2), 0>;
def : InstAlias<"sdot $rs1, $simm5, $rd", (SMUL_SUMri IntRegs:$rd,
                IntRegs:$rs1, i8imm:$simm5), 0>;

//usdot alias
def : InstAlias<"usdot $rs1, $rs2, $rd", (USMUL_USUMrr IntRegs:$rd,
                IntRegs:$rs1, IntRegs:$rs2), 0>;
def : InstAlias<"usdot $rs1, $simm5, $rd", (USMUL_USUMri IntRegs:$rd,
                IntRegs:$rs1, i8imm:$simm5), 0>;

//nop alias nop_ -> nop %g0, %g0, %g0
def : InstAlias<"nop_", (NOP_NOPrr G0, G0, G0), 0>;

//nop alias nop_x rs1, rd -> nop_x rs1, %g0, rd
def : InstAlias<"nop_ $rs1, $rd", (NOP_NOPrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"pass_ $rs1, $rd", (NOP_NOPrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_sum $rs1, $rd", (NOP_SUMrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_max $rs1, $rd", (NOP_MAXrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_min $rs1, $rd", (NOP_MINrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_xor $rs1, $rd", (NOP_XORrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_usum $rs1, $rd", (NOP_USUMrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_umax $rs1, $rd", (NOP_UMAXrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;
def : InstAlias<"nop_umin $rs1, $rd", (NOP_UMINrr IntRegs:$rd,
                                       IntRegs:$rs1, G0), 0>;

// mov %scr, rd -> rd %scr, rd
def : InstAlias<"mov %scr, $rd", (RDSCR IntRegs:$rd), 0>;

// mov reg_or_imm, %scr -> wr %g0, reg_or_imm, %scr
def : InstAlias<"mov $rs2, %scr", (WRSCRrr G0, IntRegs:$rs2), 0>;
def : InstAlias<"mov $simm13, %scr", (WRSCRri G0, i32imm:$simm13), 0>;

// wr reg_or_imm, %scr -> wr %g0, reg_or_imm, %scr
def : InstAlias<"wr $rs2, %scr", (WRSCRrr G0, IntRegs:$rs2), 0>;
def : InstAlias<"wr $simm13, %scr", (WRSCRri G0, i32imm:$simm13), 0>;
