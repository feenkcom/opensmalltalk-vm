Class {
	#name : #CogOutOfLineLiteralsX64Compiler,
	#superclass : #CogX64Compiler,
	#category : #'VMMaker-JIT'
}

{ #category : #'class initialization' }
CogOutOfLineLiteralsX64Compiler class >> initializeAbstractRegisters [
	"Assign the abstract registers with the identities/indices of the relevant concrete registers."

	super initializeAbstractRegisters.
	Scratch6Reg := R8
]

{ #category : #testing }
CogOutOfLineLiteralsX64Compiler class >> isRISCTempRegister: reg [
	"For tests to filter-out bogus values left in the RISCTempRegister, if any."
	^false
]

{ #category : #testing }
CogOutOfLineLiteralsX64Compiler >> isPCDependent [
	"Answer if the receiver is a pc-dependent instruction.  With out-of-line literals any instruction
	 that refers to a literal depends on the address of the literal, so add them in addition to the jumps."
	^self isJump
	  or: [opcode = AlignmentNops
	  or: [opcode ~= Literal and: [dependent notNil and: [dependent opcode = Literal]]]]
]