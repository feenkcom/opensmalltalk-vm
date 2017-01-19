Class {
	#name : #SpurPlanningCompactorTestsImageResource,
	#superclass : #TestResource,
	#instVars : [
		'emptyVM'
	],
	#category : #'VMMaker-Tests'
}

{ #category : #accessing }
SpurPlanningCompactorTestsImageResource >> emptyVM [
	^emptyVM ifNil:
		[emptyVM := StackInterpreterSimulator newWithOptions: #(ObjectMemory Spur32BitMemoryManager
																	  compactorClass SpurPlanningCompactor)]
]