//===-- SparcMCCodeEmitter.cpp - Convert Sparc code to machine code -------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the SparcMCCodeEmitter class.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/SparcFixupKinds.h"
#include "SparcMCExpr.h"
#include "SparcMCTargetDesc.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectFileInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/SubtargetFeature.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"
#include <cassert>
#include <cstdint>

using namespace llvm;

#define DEBUG_TYPE "mccodeemitter"

STATISTIC(MCNumEmitted, "Number of MC instructions emitted");

namespace {

class SparcMCCodeEmitter : public MCCodeEmitter {
  const MCInstrInfo &MCII;
  MCContext &Ctx;

public:
  SparcMCCodeEmitter(const MCInstrInfo &mcii, MCContext &ctx)
      : MCII(mcii), Ctx(ctx) {}
  SparcMCCodeEmitter(const SparcMCCodeEmitter &) = delete;
  SparcMCCodeEmitter &operator=(const SparcMCCodeEmitter &) = delete;
  ~SparcMCCodeEmitter() override = default;

  void encodeInstruction(const MCInst &MI, raw_ostream &OS,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override;

  // getBinaryCodeForInstr - TableGen'erated function for getting the
  // binary encoding for an instruction.
  uint64_t getBinaryCodeForInstr(const MCInst &MI,
                                 SmallVectorImpl<MCFixup> &Fixups,
                                 const MCSubtargetInfo &STI) const;

  /// getMachineOpValue - Return binary encoding of operand. If the machine
  /// operand requires relocation, record the relocation and return zero.
  unsigned getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;
  unsigned getCallTargetOpValue(const MCInst &MI, unsigned OpNo,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;
  unsigned getBranchTargetOpValue(const MCInst &MI, unsigned OpNo,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;
  unsigned getSImm13OpValue(const MCInst &MI, unsigned OpNo,
                            SmallVectorImpl<MCFixup> &Fixups,
                            const MCSubtargetInfo &STI) const;
  //marcmod
  unsigned imm5OpEncoder(const int64_t imm) const;
  //marcmod
  unsigned getImm5OpValue(const MCInst &MI, unsigned OpNo,
                            SmallVectorImpl<MCFixup> &Fixups,
                            const MCSubtargetInfo &STI) const;
  //marcmod
  unsigned sImm5OpEncoder(const int64_t imm) const;
  //marcmod
  unsigned getSImm5OpValue(const MCInst &MI, unsigned OpNo,
                            SmallVectorImpl<MCFixup> &Fixups,
                            const MCSubtargetInfo &STI) const;
  unsigned getBranchPredTargetOpValue(const MCInst &MI, unsigned OpNo,
                                      SmallVectorImpl<MCFixup> &Fixups,
                                      const MCSubtargetInfo &STI) const;
  unsigned getBranchOnRegTargetOpValue(const MCInst &MI, unsigned OpNo,
                                       SmallVectorImpl<MCFixup> &Fixups,
                                       const MCSubtargetInfo &STI) const;

private:
  FeatureBitset computeAvailableFeatures(const FeatureBitset &FB) const;
  void
  verifyInstructionPredicates(const MCInst &MI,
                              const FeatureBitset &AvailableFeatures) const;
};

} // end anonymous namespace

void SparcMCCodeEmitter::encodeInstruction(const MCInst &MI, raw_ostream &OS,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
  verifyInstructionPredicates(MI,
                              computeAvailableFeatures(STI.getFeatureBits()));

  unsigned Bits = getBinaryCodeForInstr(MI, Fixups, STI);
  support::endian::write(OS, Bits,
                         Ctx.getAsmInfo()->isLittleEndian() ? support::little
                                                            : support::big);
  unsigned tlsOpNo = 0;
  switch (MI.getOpcode()) {
  default: break;
  case SP::TLS_CALL:   tlsOpNo = 1; break;
  case SP::TLS_ADDrr:
  case SP::TLS_ADDXrr:
  case SP::TLS_LDrr:
  case SP::TLS_LDXrr:  tlsOpNo = 3; break;
  }
  if (tlsOpNo != 0) {
    const MCOperand &MO = MI.getOperand(tlsOpNo);
    uint64_t op = getMachineOpValue(MI, MO, Fixups, STI);
    assert(op == 0 && "Unexpected operand value!");
    (void)op; // suppress warning.
  }

  ++MCNumEmitted;  // Keep track of the # of mi's emitted.
}

unsigned SparcMCCodeEmitter::
getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                  SmallVectorImpl<MCFixup> &Fixups,
                  const MCSubtargetInfo &STI) const {
  if (MO.isReg())
    return Ctx.getRegisterInfo()->getEncodingValue(MO.getReg());

  if (MO.isImm())
    return MO.getImm();

  assert(MO.isExpr());
  const MCExpr *Expr = MO.getExpr();
  if (const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(Expr)) {
    MCFixupKind Kind = (MCFixupKind)SExpr->getFixupKind();
    Fixups.push_back(MCFixup::create(0, Expr, Kind));
    return 0;
  }

  int64_t Res;
  if (Expr->evaluateAsAbsolute(Res))
    return Res;

  llvm_unreachable("Unhandled expression!");
  return 0;
}

unsigned
SparcMCCodeEmitter::getSImm13OpValue(const MCInst &MI, unsigned OpNo,
                                     SmallVectorImpl<MCFixup> &Fixups,
                                     const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);

  if (MO.isImm())
    return MO.getImm();

  assert(MO.isExpr() &&
         "getSImm13OpValue expects only expressions or an immediate");

  const MCExpr *Expr = MO.getExpr();

  // Constant value, no fixup is needed
  if (const MCConstantExpr *CE = dyn_cast<MCConstantExpr>(Expr))
    return CE->getValue();

  MCFixupKind Kind;
  if (const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(Expr)) {
    Kind = MCFixupKind(SExpr->getFixupKind());
  } else {
    bool IsPic = Ctx.getObjectFileInfo()->isPositionIndependent();
    Kind = IsPic ? MCFixupKind(Sparc::fixup_sparc_got13)
                 : MCFixupKind(Sparc::fixup_sparc_13);
  }

  Fixups.push_back(MCFixup::create(0, Expr, Kind));
  return 0;
}
//marcmod 
unsigned 
SparcMCCodeEmitter::imm5OpEncoder(const int64_t imm) const{
    int64_t value = imm;
    if (value == 0) return 0b00001;
    if (value > 255 || value < 0) 
        report_fatal_error("Invalid value for ImmOp5: Value must be within [0, 255] range");
    unsigned result = 0;
    if (value%2 == 1) {
        value++;
        result |= 1;
    }
    if ((value&2)==2 && value>2) {
        value -= 2;
        result |= 0b10000;
    }
    result |= __builtin_ctz(value)<<1;
    //verification
    unsigned plus = (result>>3)&2;
    unsigned sub = result&1;
    unsigned exp = 1<<((result>>1)&0b111);
    unsigned tgt = exp+plus-sub;
    if (tgt != imm) 
        report_fatal_error("Invalid value for SImmOp5: Value must be representable by immediate{4}*2+2^(immediate{3-1})-immediate{0}");

    return result;
}

//marcmod 
unsigned 
SparcMCCodeEmitter::sImm5OpEncoder(const int64_t imm) const{
    int64_t value = imm;
    if (value == 0) return 0b00001;
    if (value>127 || value < -128) 
        report_fatal_error("Invalid value for SImmOp5: Value must be within [127, -128] range");
    unsigned result = 0;
    if (value <0){
        result = 0b10000;
        value = -value;
    }
    if (value%2 == 1) {
        value++;
        result |= 1;
    }
    result |= __builtin_ctz(value)<<1;
    //verification
    signed sign = (result>>4)? -1:1;
    unsigned sub = result&1;
    unsigned exp = 1<<((result>>1)&0b111);
    signed tgt = sign * (exp - sub);
    if (tgt != imm) 
        report_fatal_error("Invalid value for SImmOp5: Value must be representable by immediate{4}?-1:1*(2^(immediate{3-1})-immediate{0})");
    return result;
}

//marcmod
unsigned
SparcMCCodeEmitter::getImm5OpValue(const MCInst &MI, unsigned OpNo,
                                     SmallVectorImpl<MCFixup> &Fixups,
                                     const MCSubtargetInfo &STI) const {
    const MCOperand &MO = MI.getOperand(OpNo);

    if (MO.isImm())
        return imm5OpEncoder(MO.getImm());

    assert(MO.isExpr() &&
            "getSImm5OpValue expects only expressions or an immediate");

    const MCExpr *Expr = MO.getExpr();

    // Constant value, no fixup is needed
    if (const MCConstantExpr *CE = dyn_cast<MCConstantExpr>(Expr))
        return imm5OpEncoder(CE->getValue());

    MCFixupKind Kind;
    if (const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(Expr)) {
        Kind = MCFixupKind(SExpr->getFixupKind());
    } else {
        bool IsPic = Ctx.getObjectFileInfo()->isPositionIndependent();
        Kind = IsPic ? MCFixupKind(Sparc::fixup_sparc_got5)
            : MCFixupKind(Sparc::fixup_sparc_5);
    }

    Fixups.push_back(MCFixup::create(0, Expr, Kind));
    return 0;
}

//marcmod
unsigned
SparcMCCodeEmitter::getSImm5OpValue(const MCInst &MI, unsigned OpNo,
                                     SmallVectorImpl<MCFixup> &Fixups,
                                     const MCSubtargetInfo &STI) const {
    const MCOperand &MO = MI.getOperand(OpNo);

    if (MO.isImm())
        return sImm5OpEncoder(MO.getImm());

    assert(MO.isExpr() &&
            "getSImm5OpValue expects only expressions or an immediate");

    const MCExpr *Expr = MO.getExpr();

    // Constant value, no fixup is needed
    if (const MCConstantExpr *CE = dyn_cast<MCConstantExpr>(Expr))
        return sImm5OpEncoder(CE->getValue());

    MCFixupKind Kind;
    if (const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(Expr)) {
        Kind = MCFixupKind(SExpr->getFixupKind());
    } else {
        bool IsPic = Ctx.getObjectFileInfo()->isPositionIndependent();
        Kind = IsPic ? MCFixupKind(Sparc::fixup_sparc_got5)
            : MCFixupKind(Sparc::fixup_sparc_5);
    }

    Fixups.push_back(MCFixup::create(0, Expr, Kind));
    return 0;
}

unsigned SparcMCCodeEmitter::
getCallTargetOpValue(const MCInst &MI, unsigned OpNo,
                     SmallVectorImpl<MCFixup> &Fixups,
                     const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  const MCExpr *Expr = MO.getExpr();
  const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(Expr);

  if (MI.getOpcode() == SP::TLS_CALL) {
    // No fixups for __tls_get_addr. Will emit for fixups for tls_symbol in
    // encodeInstruction.
#ifndef NDEBUG
    // Verify that the callee is actually __tls_get_addr.
    assert(SExpr && SExpr->getSubExpr()->getKind() == MCExpr::SymbolRef &&
           "Unexpected expression in TLS_CALL");
    const MCSymbolRefExpr *SymExpr = cast<MCSymbolRefExpr>(SExpr->getSubExpr());
    assert(SymExpr->getSymbol().getName() == "__tls_get_addr" &&
           "Unexpected function for TLS_CALL");
#endif
    return 0;
  }

  MCFixupKind Kind = MCFixupKind(SExpr->getFixupKind());
  Fixups.push_back(MCFixup::create(0, Expr, Kind));
  return 0;
}

unsigned SparcMCCodeEmitter::
getBranchTargetOpValue(const MCInst &MI, unsigned OpNo,
                  SmallVectorImpl<MCFixup> &Fixups,
                  const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isReg() || MO.isImm())
    return getMachineOpValue(MI, MO, Fixups, STI);

  Fixups.push_back(MCFixup::create(0, MO.getExpr(),
                                   (MCFixupKind)Sparc::fixup_sparc_br22));
  return 0;
}

unsigned SparcMCCodeEmitter::
getBranchPredTargetOpValue(const MCInst &MI, unsigned OpNo,
                           SmallVectorImpl<MCFixup> &Fixups,
                           const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isReg() || MO.isImm())
    return getMachineOpValue(MI, MO, Fixups, STI);

  Fixups.push_back(MCFixup::create(0, MO.getExpr(),
                                   (MCFixupKind)Sparc::fixup_sparc_br19));
  return 0;
}

unsigned SparcMCCodeEmitter::
getBranchOnRegTargetOpValue(const MCInst &MI, unsigned OpNo,
                           SmallVectorImpl<MCFixup> &Fixups,
                           const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isReg() || MO.isImm())
    return getMachineOpValue(MI, MO, Fixups, STI);

  Fixups.push_back(MCFixup::create(0, MO.getExpr(),
                                   (MCFixupKind)Sparc::fixup_sparc_br16_2));
  Fixups.push_back(MCFixup::create(0, MO.getExpr(),
                                   (MCFixupKind)Sparc::fixup_sparc_br16_14));

  return 0;
}

#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "SparcGenMCCodeEmitter.inc"

MCCodeEmitter *llvm::createSparcMCCodeEmitter(const MCInstrInfo &MCII,
                                              const MCRegisterInfo &MRI,
                                              MCContext &Ctx) {
  return new SparcMCCodeEmitter(MCII, Ctx);
}
