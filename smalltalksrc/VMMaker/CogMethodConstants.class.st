Class {
	#name : #CogMethodConstants,
	#superclass : #SharedPool,
	#classVars : [
		'CMBlock',
		'CMClosedPIC',
		'CMFree',
		'CMMaxUsageCount',
		'CMMethod',
		'CMOpenPIC',
		'CheckAllocationFillerAfterPrimCall',
		'CompletePrimitive',
		'EncounteredUnknownBytecode',
		'InsufficientCodeSpace',
		'MaxLiteralCountForCompile',
		'MaxMethodSize',
		'MaxNegativeErrorCode',
		'MaxNumArgs',
		'MaxStackCheckOffset',
		'MethodTooBig',
		'NotFullyInitialized',
		'PrimCallCollectsProfileSamples',
		'PrimCallDoNotJIT',
		'PrimCallMayCallBack',
		'PrimCallNeedsNewMethod',
		'PrimCallNeedsPrimitiveFunction',
		'ShouldNotJIT',
		'UnfailingPrimitive',
		'UnimplementedPrimitive',
		'YoungSelectorInPIC'
	],
	#category : #'VMMaker-JIT'
}