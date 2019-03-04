//===-- LLVMOps.td - LLVM IR dialect op definition file ----*- tablegen -*-===//
//
// Copyright 2019 The MLIR Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// =============================================================================
//
// This is the LLVM IR operation definition file.
//
//===----------------------------------------------------------------------===//

#ifdef LLVMIR_OPS
#else
#define LLVMIR_OPS

#ifdef OP_BASE
#else
include "mlir/IR/OpBase.td"
#endif // OP_BASE

// LLVM IR type wrapped in MLIR.
def LLVM_Type : Type<CPred<"{0}.isa<::mlir::LLVM::LLVMType>()">,
                     "LLVM dialect type">;

// Base class for LLVM operations.  All operations get an "llvm." prefix in
// their name automatically.  LLVM operations have either zero or one result,
// this class is specialized below for both cases and should not be used
// directly.
class LLVM_Op<string mnemonic, list<OpTrait> traits = []> :
    Op<!strconcat("llvm.", mnemonic), traits>;

def LLVM_OneResultOpBuilder {
  code builder = [{
      static void build(Builder *, OperationState *result,
                        Type resultType, ArrayRef<Value *> operands,
                        ArrayRef<NamedAttribute> attributes = {}) {
      if (resultType) result->addTypes(resultType);
      result->addOperands(operands);
      for (auto namedAttr : attributes) {
        result->addAttribute(namedAttr.first, namedAttr.second);
      }
    }
  }];
}

def LLVM_ZeroResultOpBuilder {
  code builder = [{
    static void build(Builder *, OperationState *result,
                      ArrayRef<Value *> operands,
                      ArrayRef<NamedAttribute> attributes = {}) {
      result->addOperands(operands);
      for (auto namedAttr : attributes) {
        result->addAttribute(namedAttr.first, namedAttr.second);
      }
    }
  }];
}

class LLVM_TwoBuilders<code b1, code b2> {
  code builder = !cast<code>(!strconcat(!cast<string>(b1), !cast<string>(b2)));
}

// Base class for LLVM operations with one result.
class LLVM_OneResultOp<string mnemonic, list<OpTrait> traits = []> :
    LLVM_Op<mnemonic, traits>, Results<(outs LLVM_Type)> {
  let builder = LLVM_OneResultOpBuilder.builder;
}

// Base class for LLVM operations with zero results.
class LLVM_ZeroResultOp<string mnemonic, list<OpTrait> traits = []> :
    LLVM_Op<mnemonic, traits>, Results<(outs)> {
  let builder = LLVM_TwoBuilders<[{
    // Compatibility builder that takes an instance of wrapped llvm::VoidType
    // to indicate no result.
    static void build(Builder *builder, OperationState *result, Type resultType,
                      ArrayRef<Value *> operands,
                      ArrayRef<NamedAttribute> attributes = {}) {
      auto llvmType = resultType.dyn_cast<LLVM::LLVMType>();
      assert(llvmType && "result must be an LLVM type");
      assert(llvmType.getUnderlyingType() &&
             llvmType.getUnderlyingType()->isVoidTy() &&
             "for zero-result operands, only 'void' is accepted as result type");
      build(builder, result, operands, attributes);
    }
  }],
  LLVM_ZeroResultOpBuilder.builder>.builder;
}

// Base class for LLVM terminator operations.  All terminator operations have
// zero results and an optional list of successors.
class LLVM_TerminatorOp<string mnemonic, list<OpTrait> traits = []> :
    LLVM_Op<mnemonic, !listconcat(traits, [Terminator])>,
    Arguments<(ins Variadic<LLVM_Type>)>, Results<(outs)> {
  let builder = [{
      static void build(Builder *builder, OperationState *result,
                        ArrayRef<Value *> properOperands,
                        ArrayRef<Block *> destinations,
                        ArrayRef<ArrayRef<Value *>> operands = {},
                        ArrayRef<NamedAttribute> attributes = {}) {
      (void) builder;
      result->addOperands(properOperands);
      for (auto kvp : llvm::zip(destinations, operands)) {
        result->addSuccessor(std::get<0>(kvp), std::get<1>(kvp));
      }
      for (auto namedAttr : attributes) {
        result->addAttribute(namedAttr.first, namedAttr.second);
      }
    }
  }];
}

// Class for arithmetic binary instructions.
class LLVM_ArithmeticOp<string mnemonic, list<OpTrait> traits = []> :
    LLVM_OneResultOp<mnemonic,
           !listconcat([NoSideEffect, SameValueType], traits)>,
    Arguments<(ins LLVM_Type:$lhs, LLVM_Type:$rhs)>;

// Class for variadic instructions.
class LLVM_VariadicOneResultOp<string mnemonic, list<OpTrait> traits = []> :
    LLVM_OneResultOp<mnemonic, traits>, Arguments<(ins Variadic<LLVM_Type>)>;

// Integer binary instructions.
def LLVM_AddOp : LLVM_ArithmeticOp<"add", [Commutative]>;
def LLVM_SubOp : LLVM_ArithmeticOp<"sub">;
def LLVM_MulOp : LLVM_ArithmeticOp<"mul", [Commutative]>;
def LLVM_UDivOp : LLVM_ArithmeticOp<"udiv">;
def LLVM_SDivOp : LLVM_ArithmeticOp<"sdiv">;
def LLVM_URemOp : LLVM_ArithmeticOp<"urem">;
def LLVM_SRemOp : LLVM_ArithmeticOp<"srem">;

// Other integer instructions.
def LLVM_ICmpOp : LLVM_OneResultOp<"icmp", [NoSideEffect]>,
                  Arguments<(ins LLVM_Type:$lhs, LLVM_Type:$rhs)>;

// Floating point binary instructions.
def LLVM_FAddOp : LLVM_ArithmeticOp<"fadd">;
def LLVM_FSubOp : LLVM_ArithmeticOp<"fsub">;
def LLVM_FMulOp : LLVM_ArithmeticOp<"fmul">;
def LLVM_FDivOp : LLVM_ArithmeticOp<"fdiv">;
def LLVM_FRemOp : LLVM_ArithmeticOp<"frem">;

// Memory-related instructions.
def LLVM_AllocaOp : LLVM_OneResultOp<"alloca">,
                    Arguments<(ins LLVM_Type:$arraySize)>;
def LLVM_GEPOp : LLVM_VariadicOneResultOp<"getelementptr", [NoSideEffect]>;
def LLVM_LoadOp : LLVM_OneResultOp<"load">, Arguments<(ins LLVM_Type:$addr)>;
def LLVM_StoreOp : LLVM_ZeroResultOp<"store">,
                   Arguments<(ins LLVM_Type:$value, LLVM_Type:$addr)>;
def LLVM_BitcastOp : LLVM_OneResultOp<"bitcast", [NoSideEffect]>,
                     Arguments<(ins LLVM_Type)>;


// Call-related instructions.
def LLVM_CallOp : LLVM_Op<"call">, Arguments<(ins Variadic<LLVM_Type>)>,
                     Results<(outs Variadic<LLVM_Type>)> {
  let builder = LLVM_TwoBuilders<
    LLVM_OneResultOpBuilder.builder,
    LLVM_ZeroResultOpBuilder.builder
  >.builder;

  let verifier = [{
    if (getNumResults() > 1)
      return emitOpError("must have 0 or 1 result");
    return false;
  }];
}
def LLVM_ExtractValueOp : LLVM_OneResultOp<"extractvalue", [NoSideEffect]>,
                          Arguments<(ins LLVM_Type)>;
def LLVM_InsertValueOp : LLVM_OneResultOp<"insertvalue", [NoSideEffect]>,
                         Arguments<(ins LLVM_Type, LLVM_Type)>;

// Misc instructions.
def LLVM_SelectOp : LLVM_OneResultOp<"select", [NoSideEffect]>,
                    Arguments<(ins LLVM_Type, LLVM_Type, LLVM_Type)>;

// Terminators.
def LLVM_BrOp : LLVM_TerminatorOp<"br", [NoSideEffect]>;
def LLVM_CondBrOp : LLVM_TerminatorOp<"cond_br", [NoSideEffect]> {
  let verifier = [{
    if (getNumSuccessors() != 2)
      return emitOpError("expected exactly two successors");
    if (getSuccessor(0) == getSuccessor(1) &&
        getNumSuccessorOperands(0) != 0)
      return emitOpError(
          "expected successors with arguments to be different blocks");
    return false;
  }];
}
def LLVM_ReturnOp : LLVM_TerminatorOp<"return", [NoSideEffect]>;

// Pseudo-operations (do not appear in LLVM IR but necessary for the dialect to
// work correctly).
def LLVM_UndefOp : LLVM_OneResultOp<"undef", [NoSideEffect]>;
def LLVM_ConstantOp : LLVM_OneResultOp<"constant", [NoSideEffect]>,
                      Arguments<(ins)>;

#endif // LLVMIR_OPS