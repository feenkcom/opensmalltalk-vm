"
RegisterAllocatingCogit is an optimizing code generator that is specialized in register allocation..

On the contrary to StackToRegisterMappingCogit, RegisterAllocatingCogit keeps at each control flow merge point the state of the simulated stack to merge into and not only an integer fixup. Each branch and jump record the current state of the simulated stack, and each fixup is responsible for merging this state into the saved simulated stack.

"
Class {
	#name : #RegisterAllocatingCogit,
	#superclass : #StackToRegisterMappingCogit,
	#instVars : [
		'numFixups',
		'mergeSimStacksBase',
		'nextFixup'
	],
	#category : #'VMMaker-JIT'
}

{ #category : #'compile abstract instructions' }
RegisterAllocatingCogit >> allocateMergeFixups [
	"Allocate the various arrays needed to allocate the merge fixups, failing if the size
	 needed is considered too high.

	 This *must* be inlined since the arrays are alloca'ed (stack allocated)
	 so that they are freed when compilation is done.

	 N.B. We do one single alloca to save embarrassing C optimizers that
	 generate incorrect code as both gcc and the intel compiler do on x86."
	<inline: true>
	| mergeSimStackBytes |
	mergeSimStackBytes := numFixups * self simStackSlots * (self sizeof: CogSimStackEntry).
	nextFixup := 0.
	self cCode:
		[mergeSimStacksBase := self alloca: mergeSimStackBytes.
		 self b: mergeSimStacksBase zero: mergeSimStackBytes]
]

{ #category : #'simulation only' }
RegisterAllocatingCogit >> bytecodeFixupClass [
	<doNotGenerate>
	^CogRASSBytecodeFixup
]

{ #category : #'compile abstract instructions' }
RegisterAllocatingCogit >> compileEntireFullBlockMethod: numCopied [
	"Compile the abstract instructions for the entire full block method."
	self allocateMergeFixups.
	^super compileEntireFullBlockMethod: numCopied
]

{ #category : #'compile abstract instructions' }
RegisterAllocatingCogit >> compileEntireMethod [
	"Compile the abstract instructions for the entire method, including blocks."
	self allocateMergeFixups.
	^super compileEntireMethod
]

{ #category : #'simulation only' }
RegisterAllocatingCogit >> copySimStack [
	<doNotGenerate>
	^CArrayAccessor on: (simStack object collect: [:stackEntry| stackEntry copy])
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> ensureFixupAt: targetIndex [
	| fixup |	
	<var: #fixup type: #'BytecodeFixup *'>
	fixup := self fixupAt: targetIndex.
	fixup needsFixup 
		ifTrue: [self mergeCurrentSimStackWith: fixup mergeSimStack ]
		ifFalse: 
			[self assert: fixup mergeSimStack isNil.
			self moveSimStackConstantsToRegisters.
			self setMergeSimStackOf: fixup ].
	^super ensureFixupAt: targetIndex.

]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> flushLiveRegistersForCRunTimeCall [
	<inline: true>
	0 to: simStackPtr do:
		[:i| | reg |
		 self assert: (self simStackAt: i) type = (i <= methodOrBlockNumTemps
													ifTrue: [SSBaseOffset]
													ifFalse: [SSSpill]).
		 reg := (self simStackAt: i) liveRegister.
		 (reg ~= NoReg and: [(self isCallerSavedReg: reg)]) ifTrue:
			[(self simStackAt: i) liveRegister: NoReg]]
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> flushLiveRegistersForSend [
	<inline: true>
	0 to: simStackPtr do:
		[:i|
		 self assert: (self simStackAt: i) type = (i <= methodOrBlockNumTemps
													ifTrue: [SSBaseOffset]
													ifFalse: [SSSpill]).
		 (self simStackAt: i) liveRegister: NoReg]
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> genJumpTo: targetBytecodePC [
	"Overriden to avoid the flush because in this cogit stack state is merged at merge point."
	deadCode := true. "can't fall through"
	self Jump: (self ensureFixupAt: targetBytecodePC - initialPC).
	^ 0
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> genMarshalledSend: selectorIndex numArgs: numArgs sendTable: sendTable [
	self flushLiveRegistersForSend.
	^super genMarshalledSend: selectorIndex numArgs: numArgs sendTable: sendTable
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> genStorePop: popBoolean TemporaryVariable: tempIndex [
	"Override so that if a register other than TempReg is allocated, the temp is marked as being live in that register."
	| reg |
	self ssFlushUpThroughTemporaryVariable: tempIndex.
	reg := self ssStorePop: popBoolean toPreferredReg: TempReg.
	self MoveR: reg
		Mw: (self frameOffsetOfTemporary: tempIndex)
		r: FPReg.
	reg ~= TempReg ifTrue:
		[(self simStackAt: tempIndex) liveRegister: reg].
	^0
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> initSimStackForFramefulMethod: startpc [
	super initSimStackForFramefulMethod: startpc.
	simSelf liveRegister: NoReg.
	0 to: simStackPtr do:
		[:i| (self simStackAt: i) liveRegister: NoReg]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> initSimStackForFramelessBlock: startpc [
	super initSimStackForFramelessBlock: startpc.
	simSelf liveRegister: simSelf register.
	0 to: simStackPtr do:
		[:i| (self simStackAt: i) liveRegister: NoReg]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> initSimStackForFramelessMethod: startpc [
	super initSimStackForFramelessMethod: startpc.
	simSelf liveRegister: NoReg.
	0 to: simStackPtr do:
		[:i| | desc |
		desc := self simStackAt: 1.
		desc liveRegister: (desc type = SSRegister ifTrue: [desc register] ifFalse: [NoReg])]
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> mergeCurrentSimStackWith: mergeSimStack [
	<var: #mergeSimStack type: #'SimStackEntry *'>
	<var: #currentSSEntry type: #'SimStackEntry *'>
	<var: #expectedSSEntry type: #'SimStackEntry *'>
	"At merge point the cogit expects the stack to be in the same state as mergeSimStack.
	The logic is very naive, we align the existing state from the current stack to the merge stack
	from simStackPtr to methodOrBlockNumTemps, and if a conflict happen, we flush what remains
	to be merged."
	self flag: #TODO. "we could have a better algorithm with the current set of live registers to avoid flushing"
	simStackPtr to: methodOrBlockNumTemps by: -1 do:
		[:i|
			| currentSSEntry expectedSSEntry |
			currentSSEntry := self simStackAt: i.
			expectedSSEntry := self simStack: mergeSimStack at: i.
			expectedSSEntry type
				caseOf: {
					[SSBaseOffset]	-> [ self assert: (expectedSSEntry register = ReceiverResultReg or: [ expectedSSEntry register = FPReg ]).
										(expectedSSEntry register = ReceiverResultReg and: [needsFrame]) ifTrue: 
											[optStatus isReceiverResultRegLive ifFalse: 
												[self ssFlushFrom: i - 1 upThroughRegister: ReceiverResultReg.
											 	 self putSelfInReceiverResultReg ].
											 optStatus isReceiverResultRegLive: true].  ].
					[SSSpill]		-> [currentSSEntry ensureSpilledAt: (self frameOffsetOfTemporary: i) from: FPReg].
					[SSConstant]	-> [self assert: expectedSSEntry liveRegister notNil. 
										currentSSEntry storeToReg: expectedSSEntry liveRegister ].
					[SSRegister]	-> [(currentSSEntry type = SSRegister and: [currentSSEntry register = expectedSSEntry register])
											ifFalse: 
												[ self ssFlushFrom: i - 1 upThroughRegister: expectedSSEntry register.
												currentSSEntry storeToReg: expectedSSEntry register ] ]}.
			 ]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> mergeWithFixupIfRequired: fixup [
	"If this bytecode has a fixup, some kind of merge needs to be done. There are 4 cases:
		1) the bytecode has no fixup (fixup isNotAFixup)
			do nothing
		2) the bytecode has a non merge fixup
			the fixup has needsNonMergeFixup.
			The code generating non merge fixup (currently only special selector code) is responsible
				for the merge so no need to do it.
			We set deadCode to false as the instruction can be reached from jumps.
		3) the bytecode has a merge fixup, but execution flow *cannot* fall through to the merge point.
			the fixup has needsMergeFixup and deadCode = true.
			ignores the current simStack as it does not mean anything 
			restores the simStack to the state the jumps to the merge point expects it to be.
		4) the bytecode has a merge fixup and execution flow *can* fall through to the merge point.
			the fixup has needsMergeFixup and deadCode = false.
			flushes the stack to the stack pointer so the fall through execution path simStack is 
				in the state the merge point expects it to be. 
			restores the simStack to the state the jumps to the merge point expects it to be.
			
	In addition, if this is a backjump merge point, we patch the fixup to hold the current simStackPtr 
	for later assertions."
	
	<var: #fixup type: #'BytecodeFixup *'>
	"case 1"
	fixup notAFixup ifTrue: [^ 0].

	"case 2"
	fixup isNonMergeFixup ifTrue: [deadCode := false. ^ 0 ].

	"cases 3 and 4"
	self assert: fixup isMergeFixup.
	self traceMerge: fixup.
	deadCode 
		ifTrue: [simStackPtr := fixup simStackPtr] "case 3"
		ifFalse: [self mergeCurrentSimStackWith: fixup mergeSimStack]. "case 4"
	"cases 3 and 4"
	deadCode := false.
	fixup isBackwardBranchFixup ifTrue: [fixup simStackPtr: simStackPtr].
	fixup targetInstruction: self Label.
	self assert: simStackPtr = fixup simStackPtr.
	self cCode: '' inSmalltalk:
		[self assert: fixup simStackPtr = (self debugStackPointerFor: bytecodePC)].
	self restoreSimStackAtMergePoint: fixup.
	
	^0
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> moveSimStackConstantsToRegisters [
	<inline: true>
	(simSpillBase max: 0) to: simStackPtr do: 
		[:i|
			| desc |
			desc := self simStackAt: i.
			(desc type = SSConstant and: [desc liveRegister = NoReg])
				ifTrue: [ desc storeToReg: (self allocateRegNotConflictingWith: 0) ] ]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> restoreSimStackAtMergePoint: fixup [
	<inline: true>
	"All the execution paths reaching a merge point expect everything to be
	spilled on stack and the optStatus is unknown. Throw away all simStack and 
	optStatus optimization state."
	simSpillBase := methodOrBlockNumTemps.
	optStatus isReceiverResultRegLive: false.
	0 to: simStackPtr do:
		[:i|
		self cCode: [simStack at: i put: (fixup mergeSimStack at: i)]
			inSmalltalk: [(simStack at: i) copyFrom: (fixup mergeSimStack at: i)]].
	^ 0
]

{ #category : #'compile abstract instructions' }
RegisterAllocatingCogit >> scanMethod [
	"Overrides to count the number of fixups."
	"Scan the method (and all embedded blocks) to determine
		- what the last bytecode is; extra bytes at the end of a method are used to encode things like source pointers or temp names
		- if the method needs a frame or not
		- what are the targets of any backward branches.
		- how many blocks it creates
	 Answer the block count or on error a negative error code"
	| latestContinuation nExts descriptor pc numBlocks distance targetPC framelessStackDelta |
	<var: #descriptor type: #'BytecodeDescriptor *'>
	needsFrame := false.
	numFixups := 0.
	prevBCDescriptor := nil.
	NewspeakVM ifTrue:
		[numIRCs := 0].
	(primitiveIndex > 0
	 and: [coInterpreter isQuickPrimitiveIndex: primitiveIndex]) ifTrue:
		[^0].
	pc := latestContinuation := initialPC.
	numBlocks := framelessStackDelta := nExts := extA := extB := 0.
	[pc <= endPC] whileTrue:
		[byte0 := (objectMemory fetchByte: pc ofObject: methodObj) + bytecodeSetOffset.
		 descriptor := self generatorAt: byte0.
		 descriptor isExtension ifTrue:
			[descriptor opcode = Nop ifTrue: "unknown bytecode tag; see Cogit class>>#generatorTableFrom:"
				[^EncounteredUnknownBytecode].
			 self loadSubsequentBytesForDescriptor: descriptor at: pc.
			 self perform: descriptor generator].
		 (descriptor isReturn
		  and: [pc >= latestContinuation]) ifTrue:
			[endPC := pc].
		 needsFrame ifFalse:
			[(descriptor needsFrameFunction isNil
			  or: [self perform: descriptor needsFrameFunction with: framelessStackDelta])
				ifTrue: [needsFrame := true]
				ifFalse: [framelessStackDelta := framelessStackDelta + descriptor stackDelta]].
		 descriptor isBranch ifTrue:
			[distance := self spanFor: descriptor at: pc exts: nExts in: methodObj.
			 targetPC := pc + descriptor numBytes + distance.
			 (self isBackwardBranch: descriptor at: pc exts: nExts in: methodObj)
				ifTrue: [self initializeFixupAt: targetPC - initialPC]
				ifFalse: 
					[latestContinuation := latestContinuation max: targetPC.
					numFixups := numFixups + 1]].
		 descriptor isBlockCreation ifTrue:
			[numBlocks := numBlocks + 1.
			 distance := self spanFor: descriptor at: pc exts: nExts in: methodObj.
			 targetPC := pc + descriptor numBytes + distance.
			 latestContinuation := latestContinuation max: targetPC.
			 numFixups := numFixups + 1].
		 NewspeakVM ifTrue:
			[descriptor hasIRC ifTrue:
				[numIRCs := numIRCs + 1]].
		 pc := pc + descriptor numBytes.
		 descriptor isExtension
			ifTrue: [nExts := nExts + 1]
			ifFalse: [nExts := extA := extB := 0].
		 prevBCDescriptor := descriptor].
	^numBlocks
]

{ #category : #'bytecode generator support' }
RegisterAllocatingCogit >> setMergeSimStackOf: fixup [
	<var: #fixup type: #'BytecodeFixup *'>
	self assert: nextFixup < numFixups.
	self moveSimStackConstantsToRegisters.
	self cCode: [fixup mergeSimStack: mergeSimStacksBase + (nextFixup * self simStackSlots * (self sizeof: CogSimStackEntry))].
	nextFixup := nextFixup + 1.
	self cCode: [self mem: fixup mergeSimStack cp: self simStackSlots * (self sizeof: CogSimStackEntry) y: simStack]
		inSmalltalk: [fixup mergeSimStack: self copySimStack]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> simStack: stack at: index [
	<cmacro: '(stack,index) ((stack) + (index))'>
	<returnTypeC: #'CogSimStackEntry *'>
	^self addressOf: (stack at: index)
]

{ #category : #initialization }
RegisterAllocatingCogit >> simStackEntryClass [
	<doNotGenerate>
	^CogRegisterAllocatingSimStackEntry
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssFlushFrom: start upThrough: unaryBlock [
	"Any occurrences on the stack of the value being stored (which is the top of stack)
	 must be flushed, and hence any values colder than them stack."
	<inline: true>
	start to: (simSpillBase max: 0) by: -1 do:
		[ :index |
		(unaryBlock value: (self simStackAt: index)) ifTrue: [ ^ self ssFlushTo: index ] ]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssFlushFrom: start upThroughRegister: reg [
	"Any occurrences on the stack of the register must be
	 flushed, and hence any values colder than them stack."
	<var: #desc type: #'CogSimStackEntry *'>
	self ssFlushFrom: start upThrough: [ :desc | desc type = SSRegister and: [ desc register = reg ] ]
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssPushAnnotatedConstant: literal [
	super ssPushAnnotatedConstant: literal.
	self ssTop liveRegister: NoReg.
	^0
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssPushBase: reg offset: offset [
	super ssPushBase: reg offset: offset.
	self ssTop liveRegister: NoReg.
	^0
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssPushConstant: literal [
	super ssPushConstant: literal.
	self ssTop liveRegister: NoReg.
	^0
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssPushRegister: reg [
	super ssPushRegister: reg.
	self ssTop liveRegister: NoReg.
	^0
]

{ #category : #'simulation stack' }
RegisterAllocatingCogit >> ssStorePop: popBoolean toPreferredReg: preferredReg [
	"Store or pop the top simulated stack entry to a register.
	 Use preferredReg if the entry is not itself a register.
	 Answer the actual register the result ends up in."
	| actualReg |
	actualReg := preferredReg.
	self ssTop type = SSRegister ifTrue: 
		[self assert: self ssTop liveRegister = self ssTop register.
		self assert: self ssTop spilled not].
	self ssTop liveRegister ~= NoReg ifTrue:
		[actualReg := self ssTop liveRegister].
	self ssStorePop: popBoolean toReg: actualReg. "generates nothing if ssTop is already in actualReg"
	^ actualReg
]