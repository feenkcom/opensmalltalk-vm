"
Provide access to the host machine file system. Requires both the Cross platform support files from platforms - Cross - plugins - FilePlugin (or some suitable replacement) and the platform specific fils from platforms - {your platform} - plugins - FilePlugin.
"
Class {
	#name : #FilePlugin,
	#superclass : #InterpreterPlugin,
	#instVars : [
		'sCCPfn',
		'sCDPfn',
		'sCGFTfn',
		'sCLPfn',
		'sCSFTfn',
		'sDFAfn',
		'sCDFfn',
		'sCOFfn',
		'sCRFfn',
		'sHFAfn'
	],
	#classVars : [
		'DirBadPath',
		'DirEntryFound',
		'DirNoMoreEntries'
	],
	#category : #'VMMaker-Plugins'
}

{ #category : #translation }
FilePlugin class >> declareCVarsIn: aCCodeGenerator [

	self declareC:  #('sCCPfn' 'sCDFfn' 'sCDPfn' 'sCGFTfn' 'sCLPfn' 'sCOFfn' 'sCRFfn' 'sCSFTfn' 'sDFAfn' 'sHFAfn')
		as: #'void *'
		in: aCCodeGenerator.
	aCCodeGenerator addHeaderFile: '"FilePlugin.h"'
]

{ #category : #translation }
FilePlugin class >> hasHeaderFile [
	"If there is a single intrinsic header file to be associated with the plugin, here is where you want to flag"
	^true
]

{ #category : #'class initialization' }
FilePlugin class >> initialize [
	"FilePlugin initialize"
	DirEntryFound := 0.
	DirNoMoreEntries := 1.
	DirBadPath := 2.
]

{ #category : #translation }
FilePlugin class >> requiresCrossPlatformFiles [
	"this plugin requires cross platform files in order to work"
	^true
]

{ #category : #translation }
FilePlugin class >> requiresPlatformFiles [
	"this plugin requires platform specific files in order to work"
	^true
]

{ #category : #simulation }
FilePlugin class >> simulatorClass [
	^FilePluginSimulator
]

{ #category : #'directory primitives' }
FilePlugin >> asciiDirectoryDelimiter [
	^ self
		cCode: 'dir_Delimitor()'
		inSmalltalk:
			[(Smalltalk classNamed: #FileSystem)
				ifNotNil: [:fileSystem| fileSystem disk delimiter asciiValue]
				ifNil: [FileDirectory pathNameDelimiter asciiValue]]
]

{ #category : #'file primitives' }
FilePlugin >> fileOpenName: nameIndex size: nameSize write: writeFlag secure: secureFlag [
	"Open the named file, possibly checking security. Answer the file oop."
	| file fileOop okToOpen |
	<var: #file type: 'SQFile *'>
	<var: 'nameIndex' type: 'char *'>
	<export: true>
	fileOop := interpreterProxy instantiateClass: interpreterProxy classByteArray indexableSize: self fileRecordSize.
	file := self fileValueOf: fileOop.
	interpreterProxy failed
		ifFalse: [ secureFlag ifTrue: [
				"If the security plugin can be loaded, use it to check for permission.
				If not, assume it's ok"
				sCOFfn ~= 0 
					ifTrue: [okToOpen := self cCode: '((sqInt (*) (char *, sqInt, sqInt)) sCOFfn)(nameIndex, nameSize, writeFlag)' inSmalltalk:[true].
						okToOpen
							ifFalse: [interpreterProxy primitiveFail]]]].
	interpreterProxy failed
		ifFalse: [self cCode: 'sqFileOpen(file, nameIndex, nameSize, writeFlag)' inSmalltalk: [file]].
	^ fileOop
]

{ #category : #'file primitives' }
FilePlugin >> fileRecordSize [
	"Return the size of a Smalltalk file record in bytes."
	<static: false>
	^self sizeof: #SQFile
]

{ #category : #'file primitives' }
FilePlugin >> fileValueOf: objectPointer [
	"Return a pointer to the first byte of of the file record within the given Smalltalk object, or nil if objectPointer is not a file record."
	<returnTypeC: 'SQFile *'>
	<static: false>
	(((interpreterProxy isBytes: objectPointer) and:
		 [(interpreterProxy byteSizeOf: objectPointer) = self fileRecordSize]))
			ifFalse:[interpreterProxy primitiveFail. ^nil].
	^interpreterProxy firstIndexableField: objectPointer
]

{ #category : #'file primitives' }
FilePlugin >> getThisSession [
	"Exported entry point for the VM. Only used by AsynchFilePlugin and needs to be reowrked now we have a VM global session Id capability"
	<export: true> 
	^self cCode: 'sqFileThisSession()'.
]

{ #category : #'initialize-release' }
FilePlugin >> initialiseModule [
	<export: true>
	sCCPfn := interpreterProxy ioLoadFunction: 'secCanCreatePathOfSize' From: 'SecurityPlugin'.
	sCDPfn := interpreterProxy ioLoadFunction: 'secCanDeletePathOfSize' From: 'SecurityPlugin'.
	sCGFTfn := interpreterProxy ioLoadFunction: 'secCanGetFileTypeOfSize' From: 'SecurityPlugin'.
	sCLPfn := interpreterProxy ioLoadFunction: 'secCanListPathOfSize' From: 'SecurityPlugin'.
	sCSFTfn := interpreterProxy ioLoadFunction: 'secCanSetFileTypeOfSize' From: 'SecurityPlugin'.
	sDFAfn := interpreterProxy ioLoadFunction: 'secDisableFileAccess' From: 'SecurityPlugin'.
	sCDFfn := interpreterProxy ioLoadFunction: 'secCanDeleteFileOfSize' From: 'SecurityPlugin'.
	sCOFfn := interpreterProxy ioLoadFunction: 'secCanOpenFileOfSizeWritable' From: 'SecurityPlugin'.
	sCRFfn := interpreterProxy ioLoadFunction: 'secCanRenameFileOfSize' From: 'SecurityPlugin'.
	sHFAfn := interpreterProxy ioLoadFunction: 'secHasFileAccess' From: 'SecurityPlugin'.
	^self cCode: [self sqFileInit] inSmalltalk: [true]
]

{ #category : #'directory primitives' }
FilePlugin >> makeDirEntryName: entryName size: entryNameSize
	createDate: createDate modDate: modifiedDate
	isDir: dirFlag fileSize: fileSize [

	| modDateOop createDateOop nameString results stringPtr fileSizeOop |
	<var: 'entryName' type: 'char *'>
	<var: 'stringPtr' type:'char *'>
	<var: 'fileSize' type:'squeakFileOffsetType '>

	"allocate storage for results, remapping newly allocated
	 oops in case GC happens during allocation"
	interpreterProxy pushRemappableOop:
		(interpreterProxy instantiateClass: (interpreterProxy classArray) indexableSize: 5).
	interpreterProxy pushRemappableOop:
		(interpreterProxy instantiateClass: (interpreterProxy classString) indexableSize: entryNameSize).
	interpreterProxy pushRemappableOop: 
		(interpreterProxy positive32BitIntegerFor: createDate).
	interpreterProxy pushRemappableOop: 
		(interpreterProxy positive32BitIntegerFor: modifiedDate).
	interpreterProxy pushRemappableOop:
		(interpreterProxy positive64BitIntegerFor: fileSize).

	fileSizeOop   := interpreterProxy popRemappableOop.
	modDateOop   := interpreterProxy popRemappableOop.
	createDateOop := interpreterProxy popRemappableOop.
	nameString    := interpreterProxy popRemappableOop.
	results         := interpreterProxy popRemappableOop.

	"copy name into Smalltalk string"
	stringPtr := interpreterProxy firstIndexableField: nameString.
	0 to: entryNameSize - 1 do: [ :i |
		stringPtr at: i put: (entryName at: i).
	].

	interpreterProxy storePointer: 0 ofObject: results withValue: nameString.
	interpreterProxy storePointer: 1 ofObject: results withValue: createDateOop.
	interpreterProxy storePointer: 2 ofObject: results withValue: modDateOop.
	dirFlag
		ifTrue: [ interpreterProxy storePointer: 3 ofObject: results withValue: interpreterProxy trueObject ]
		ifFalse: [ interpreterProxy storePointer: 3 ofObject: results withValue: interpreterProxy falseObject ].
	interpreterProxy storePointer: 4 ofObject: results withValue: fileSizeOop.
	^ results
]

{ #category : #'directory primitives' }
FilePlugin >> makeDirEntryName: entryName size: entryNameSize createDate: createDate modDate: modifiedDate isDir: dirFlag fileSize: fileSize posixPermissions: posixPermissions isSymlink: symlinkFlag [
	<var: 'entryName' type: 'char *'>
	<var: 'fileSize' type: 'squeakFileOffsetType '>
	<option: #PharoVM>

	| modDateOop createDateOop nameString results stringPtr posixPermissionsOop fileSizeOop |
	<var: 'stringPtr' type: 'char *'>

	"allocate storage for results, remapping newly allocated
	 oops in case GC happens during allocation"
	interpreterProxy pushRemappableOop:
		(interpreterProxy instantiateClass: (interpreterProxy classArray) indexableSize: 7).
	interpreterProxy pushRemappableOop:
		(interpreterProxy instantiateClass: (interpreterProxy classString) indexableSize: entryNameSize).
	interpreterProxy pushRemappableOop: 
		(interpreterProxy positive32BitIntegerFor: createDate).
	interpreterProxy pushRemappableOop: 
		(interpreterProxy positive32BitIntegerFor: modifiedDate).
	interpreterProxy pushRemappableOop:
		(interpreterProxy positive64BitIntegerFor: fileSize).
	interpreterProxy pushRemappableOop: 
		(interpreterProxy positive32BitIntegerFor: posixPermissions).

	posixPermissionsOop := interpreterProxy popRemappableOop.
	fileSizeOop := interpreterProxy popRemappableOop.
	modDateOop := interpreterProxy popRemappableOop.
	createDateOop := interpreterProxy popRemappableOop.
	nameString  := interpreterProxy popRemappableOop.
	results := interpreterProxy popRemappableOop.

	"copy name into Smalltalk string"
	stringPtr := interpreterProxy firstIndexableField: nameString.
	0 to: entryNameSize - 1 do: [ :i |
		stringPtr at: i put: (entryName at: i).
	].

	interpreterProxy storePointer: 0 ofObject: results withValue: nameString.
	interpreterProxy storePointer: 1 ofObject: results withValue: createDateOop.
	interpreterProxy storePointer: 2 ofObject: results withValue: modDateOop.
	dirFlag
		ifTrue: [ interpreterProxy storePointer: 3 ofObject: results withValue: interpreterProxy trueObject ]
		ifFalse: [ interpreterProxy storePointer: 3 ofObject: results withValue: interpreterProxy falseObject ].
	interpreterProxy storePointer: 4 ofObject: results withValue: fileSizeOop.
	interpreterProxy storePointer: 5 ofObject: results withValue: posixPermissionsOop.
	symlinkFlag
		ifTrue: [ interpreterProxy storePointer:  6 ofObject: results withValue: interpreterProxy trueObject ]
		ifFalse: [ interpreterProxy storePointer: 6 ofObject: results withValue: interpreterProxy falseObject ].
	^ results
]

{ #category : #'initialize-release' }
FilePlugin >> moduleUnloaded: aModuleName [
	"The module with the given name was just unloaded.
	Make sure we have no dangling references."
	<export: true>
	<var: #aModuleName type: 'char *'>
	(aModuleName strcmp: 'SecurityPlugin') = 0 ifTrue:[
		"The security plugin just shut down. How odd."
		sCCPfn := sCDPfn := sCGFTfn := sCLPfn := sCSFTfn := sDFAfn := sCDFfn := sCOFfn := sCRFfn := sHFAfn := 0.
	].
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectoryCreate [

	| dirName dirNameIndex dirNameSize okToCreate |
	<var: #dirNameIndex type: 'char *'>
	<export: true>

	dirName := interpreterProxy stackValue: 0.
	(interpreterProxy isBytes: dirName) ifFalse:
		[^interpreterProxy primitiveFail].
	dirNameIndex := interpreterProxy firstIndexableField: dirName.
	dirNameSize := interpreterProxy byteSizeOf: dirName.
	"If the security plugin can be loaded, use it to check for permission.
	If not, assume it's ok"
	sCCPfn ~= 0 ifTrue:
		[okToCreate := self cCode: ' ((sqInt (*)(char *, sqInt))sCCPfn)(dirNameIndex, dirNameSize)'
							inSmalltalk: [true].
		 okToCreate ifFalse:
			[^interpreterProxy primitiveFail]].
	(self
		cCode: 'dir_Create(dirNameIndex, dirNameSize)'
		inSmalltalk: [self createDirectory: (interpreterProxy asString: dirNameIndex)]) ifFalse:
		[^interpreterProxy primitiveFail].
	interpreterProxy pop: 1
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectoryDelete [

	| dirName dirNameIndex dirNameSize okToDelete |
	<var: #dirNameIndex type: 'char *'>
	<export: true>

	dirName := interpreterProxy stackValue: 0.
	(interpreterProxy isBytes: dirName)
		ifFalse: [^interpreterProxy primitiveFail].
	dirNameIndex := interpreterProxy firstIndexableField: dirName.
	dirNameSize := interpreterProxy byteSizeOf: dirName.
	"If the security plugin can be loaded, use it to check for permission.
	If not, assume it's ok"
	sCDPfn ~= 0
		ifTrue: [okToDelete := self cCode: ' ((sqInt (*)(char *, sqInt))sCDPfn)(dirNameIndex, dirNameSize)' inSmalltalk: [false].
			okToDelete
				ifFalse: [^interpreterProxy primitiveFail]].
	(self
			cCode: 'dir_Delete(dirNameIndex, dirNameSize)'
			inSmalltalk: [false])
		ifFalse: [^interpreterProxy primitiveFail].
	interpreterProxy pop: 1
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectoryDelimitor [
	| ascii |
	<export: true>
	ascii := self asciiDirectoryDelimiter.
	interpreterProxy minorVersion >= 13
		ifTrue:
			[interpreterProxy
				pop: 1
				thenPush: (interpreterProxy characterObjectOf: ascii)]
		ifFalse:
			[(ascii >= 0 and: [ascii <= 255])
				ifTrue:
					[interpreterProxy
						pop: 1
						thenPush: (interpreterProxy
										fetchPointer: ascii
										ofObject: interpreterProxy characterTable)]
				ifFalse:
					[interpreterProxy primitiveFail]]
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectoryEntry [

	"Two arguments - directory path, and simple file name;
 	 returns an array (see primitiveDirectoryLookup) describing the file or directory,
 	 or nil if it does not exist.  
	 Primitive fails if the outer path does not identify a readable directory.
	 (This is a lookup-by-name variant of primitiveDirectoryLookup.)"

	| requestedName pathName pathNameIndex pathNameSize status entryName entryNameSize createDate modifiedDate dirFlag posixPermissions symlinkFlag fileSize okToList reqNameIndex reqNameSize |
	
	<var: 'entryName' declareC: 'char entryName[256]'>
	<var: 'pathNameIndex' type: 'char *'>
	<var: 'reqNameIndex' type: 'char *'>
	<var: 'fileSize' type: 'squeakFileOffsetType'>
	<export: true>

	requestedName := interpreterProxy stackValue: 0.
	pathName := interpreterProxy stackValue: 1.
	(interpreterProxy isBytes: pathName)
		ifFalse: [^interpreterProxy primitiveFail].

	"Outbound string parameters"
	pathNameIndex := interpreterProxy firstIndexableField: pathName.
	pathNameSize := interpreterProxy byteSizeOf: pathName.

	reqNameIndex := interpreterProxy firstIndexableField: requestedName.
	reqNameSize := interpreterProxy byteSizeOf: requestedName.

	"If the security plugin can be loaded, use it to check for permission. 
	If not, assume it's ok"
	sCLPfn ~= 0
		ifTrue: [okToList := self cCode: '((sqInt (*)(char *, sqInt))sCLPfn)(pathNameIndex, pathNameSize)']
		ifFalse: [okToList := true].
	okToList
		ifTrue: [
			self 
				cppIf: PharoVM 
				ifTrue: [ 
					status := self cCode: 'dir_EntryLookup(pathNameIndex, pathNameSize, reqNameIndex, reqNameSize,										  
														entryName, &entryNameSize, &createDate,
														&modifiedDate, &dirFlag, &fileSize, 
														&posixPermissions, &symlinkFlag)' ]
				ifFalse: [ 
					status := self cCode: 'dir_EntryLookup(pathNameIndex, pathNameSize, reqNameIndex, reqNameSize,
													  entryName, &entryNameSize, &createDate,
													  &modifiedDate, &dirFlag, &fileSize)'] ]
		ifFalse: [status := DirNoMoreEntries].

	interpreterProxy failed
		ifTrue: [^nil].
	status = DirNoMoreEntries
		ifTrue: ["no entry; return nil"
			interpreterProxy pop: 3 "pop pathName, index, rcvr"
				thenPush: interpreterProxy nilObject.
			^nil].
	status = DirBadPath
		ifTrue: [^interpreterProxy primitiveFail]."bad path"

	self 
		cppIf: PharoVM
		ifTrue: [ 
			interpreterProxy 
				pop: 3	"pop pathName, index, rcvr" 
				thenPush: (self
					makeDirEntryName: entryName
					size: entryNameSize
					createDate: createDate
					modDate: modifiedDate
					isDir: dirFlag
					fileSize: fileSize
					posixPermissions: posixPermissions
					isSymlink: symlinkFlag) ]
		ifFalse: [ 
			interpreterProxy 
				pop: 3	"pop pathName, fName, rcvr" 
				thenPush: (self
					makeDirEntryName: entryName
					size: entryNameSize
					createDate: createDate
					modDate: modifiedDate
					isDir: dirFlag
					fileSize: fileSize) ]
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectoryGetMacTypeAndCreator [

	| creatorString typeString fileName creatorStringIndex typeStringIndex fileNameIndex fileNameSize okToGet |
	<var: 'creatorStringIndex' type: 'char *'>
	<var: 'typeStringIndex' type: 'char *'>
	<var: 'fileNameIndex' type: 'char *'>
	<export: true>

	creatorString := interpreterProxy stackValue: 0.
	typeString := interpreterProxy stackValue: 1.
	fileName := interpreterProxy stackValue: 2.
	((interpreterProxy isBytes: creatorString)
			and: [(interpreterProxy byteSizeOf: creatorString) = 4])
		ifFalse: [^interpreterProxy primitiveFail].
	((interpreterProxy isBytes: typeString)
			and: [(interpreterProxy byteSizeOf: typeString) = 4])
		ifFalse: [^interpreterProxy primitiveFail].
	(interpreterProxy isBytes: fileName)
		ifFalse: [^interpreterProxy primitiveFail].
	creatorStringIndex := interpreterProxy firstIndexableField: creatorString.
	typeStringIndex := interpreterProxy firstIndexableField: typeString.
	fileNameIndex := interpreterProxy firstIndexableField: fileName.
	fileNameSize := interpreterProxy byteSizeOf: fileName.
	"If the security plugin can be loaded, use it to check for permission.
	If not, assume it's ok"
	sCGFTfn ~= 0
		ifTrue: [okToGet := self cCode: ' ((sqInt (*)(char *, sqInt))sCGFTfn)(fileNameIndex, fileNameSize)'.
			okToGet
				ifFalse: [^interpreterProxy primitiveFail]].
	(self
			cCode: 'dir_GetMacFileTypeAndCreator(fileNameIndex, fileNameSize, typeStringIndex, creatorStringIndex)'
			inSmalltalk: [true])
		ifFalse: [^interpreterProxy primitiveFail].
	interpreterProxy pop: 3
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectoryLookup [

	| index pathName pathNameIndex pathNameSize status entryName entryNameSize createDate modifiedDate dirFlag symlinkFlag posixPermissions fileSize okToList |
	
	<var: 'entryName' declareC: 'char entryName[256]'>
	<var: 'pathNameIndex' type: 'char *'>
	<var: 'fileSize' type: 'squeakFileOffsetType'>
	<export: true>

	index := interpreterProxy stackIntegerValue: 0.
	pathName := interpreterProxy stackValue: 1.
	(interpreterProxy isBytes: pathName)
		ifFalse: [^interpreterProxy primitiveFail].
	pathNameIndex := interpreterProxy firstIndexableField: pathName.
	pathNameSize := interpreterProxy byteSizeOf: pathName.
	"If the security plugin can be loaded, use it to check for permission. 
	If not, assume it's ok"
	sCLPfn ~= 0
		ifTrue: [okToList := self cCode: '((sqInt (*)(char *, sqInt))sCLPfn)(pathNameIndex, pathNameSize)']
		ifFalse: [okToList := true].
	okToList
		ifTrue: [
			self 
				cppIf: PharoVM 
				ifTrue: [ 
					status := self cCode: 'dir_Lookup(pathNameIndex, pathNameSize, index,
												entryName, &entryNameSize, &createDate,
												&modifiedDate, &dirFlag, &fileSize, 
												&posixPermissions, &symlinkFlag)' ]
				ifFalse: [ 
					status := self cCode: 'dir_Lookup(pathNameIndex, pathNameSize, index,
												entryName, &entryNameSize, &createDate,
												&modifiedDate, &dirFlag, &fileSize)' ] ]
		ifFalse: [status := DirNoMoreEntries].
	interpreterProxy failed
		ifTrue: [^nil].
	status = DirNoMoreEntries
		ifTrue: ["no more entries; return nil"
			interpreterProxy pop: 3 "pop pathName, index, rcvr"
				thenPush: interpreterProxy nilObject.
			^nil].
	status = DirBadPath
		ifTrue: [^interpreterProxy primitiveFail]."bad path"

	self 
		cppIf: PharoVM 
		ifTrue: [ 
			interpreterProxy 
				pop: 3	"pop pathName, index, rcvr" 
				thenPush: (self
					makeDirEntryName: entryName
					size: entryNameSize
					createDate: createDate
					modDate: modifiedDate
					isDir: dirFlag
					fileSize: fileSize
					posixPermissions: posixPermissions
					isSymlink: symlinkFlag) ]
		ifFalse: [ 
			interpreterProxy 
				pop: 3	"pop pathName, index, rcvr" 
				thenPush: (self
						makeDirEntryName: entryName
						size: entryNameSize
						createDate: createDate
						modDate: modifiedDate
						isDir: dirFlag
						fileSize: fileSize) ]
]

{ #category : #'directory primitives' }
FilePlugin >> primitiveDirectorySetMacTypeAndCreator [

	| creatorString typeString fileName creatorStringIndex typeStringIndex fileNameIndex fileNameSize okToSet |
	<var: 'creatorStringIndex' type: 'char *'>
	<var: 'typeStringIndex' type: 'char *'>
	<var: 'fileNameIndex' type: 'char *'>
	<export: true>

	creatorString := interpreterProxy stackValue: 0.
	typeString := interpreterProxy stackValue: 1.
	fileName := interpreterProxy stackValue: 2.
	((interpreterProxy isBytes: creatorString)
	 and: [(interpreterProxy isBytes: typeString)
	 and: [(interpreterProxy isBytes: fileName)
	 and: [(interpreterProxy byteSizeOf: creatorString) = 4
	 and: [(interpreterProxy byteSizeOf: typeString) = 4]]]]) ifFalse:
		[^interpreterProxy primitiveFail].
	creatorStringIndex := interpreterProxy firstIndexableField: creatorString.
	typeStringIndex := interpreterProxy firstIndexableField: typeString.
	fileNameIndex := interpreterProxy firstIndexableField: fileName.
	fileNameSize := interpreterProxy byteSizeOf: fileName.
	"If the security plugin can be loaded, use it to check for permission.
	If not, assume it's ok"
	sCSFTfn ~= 0 ifTrue:
		[okToSet := self
						cCode: '((sqInt (*)(char *, sqInt))sCSFTfn)(fileNameIndex, fileNameSize)'
						inSmalltalk: [true].
		 okToSet ifFalse:
			[^interpreterProxy primitiveFail]].
	(self
		cCode: 'dir_SetMacFileTypeAndCreator(fileNameIndex, fileNameSize, typeStringIndex, creatorStringIndex)'
		inSmalltalk: [true]) ifFalse:
			[^interpreterProxy primitiveFail].
	interpreterProxy pop: 3
]

{ #category : #'security primitives' }
FilePlugin >> primitiveDisableFileAccess [
	<export: true>
	"If the security plugin can be loaded, use it to turn off file access
	 If not, assume it's ok"
	sDFAfn ~= 0 ifTrue:
		[self cCode: '((sqInt (*)(void))sDFAfn)()']
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileAtEnd [
	| file atEnd |
	<export: true>
	<var: 'file' type: 'SQFile *'>
	file := self fileValueOf: (interpreterProxy stackValue: 0).
	interpreterProxy failed
		ifFalse: [atEnd := self sqFileAtEnd: file].
	interpreterProxy failed
		ifFalse: [interpreterProxy pop: 2. "rcvr, file"
			interpreterProxy pushBool: atEnd]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileClose [

	| file |
	<export: true>
	<var: 'file' type: 'SQFile *'>
	file := self fileValueOf: (interpreterProxy stackValue: 0).
	interpreterProxy failed ifFalse: [ self sqFileClose: file ].
	interpreterProxy failed ifFalse: [ interpreterProxy pop: 1  "pop file; leave rcvr on stack" ].
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileDelete [

	| namePointer nameIndex nameSize  okToDelete |
	<var: 'nameIndex' type: 'char *'>
	<export: true>

	namePointer := interpreterProxy stackValue: 0.
	(interpreterProxy isBytes: namePointer)
		ifFalse: [^ interpreterProxy primitiveFail].
	nameIndex := interpreterProxy firstIndexableField: namePointer.
	nameSize := interpreterProxy byteSizeOf: namePointer.
	"If the security plugin can be loaded, use it to check for permission.
	If not, assume it's ok"
	sCDFfn ~= 0
		ifTrue: [okToDelete := self cCode: ' ((sqInt (*)(char *, sqInt))sCDFfn)(nameIndex, nameSize)' inSmalltalk: [true].
			okToDelete
				ifFalse: [^ interpreterProxy primitiveFail]].
	self
		sqFileDeleteName: nameIndex
		Size: nameSize.
	interpreterProxy failed
		ifFalse: [interpreterProxy pop: 1]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileFlush [
	| file |
	<var: 'file' type: 'SQFile *'>
	<export: true>
	file := self fileValueOf: (interpreterProxy stackValue: 0).
	interpreterProxy failed ifFalse:[self sqFileFlush: file].
	interpreterProxy failed ifFalse: [interpreterProxy pop: 1].
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileGetPosition [
	| file position |
	<var: 'file' type: 'SQFile *'>
	<var: 'position' type: 'squeakFileOffsetType'>
	<export: true>
	file := self fileValueOf: (interpreterProxy stackValue: 0).
	interpreterProxy failed ifFalse: [position := self sqFileGetPosition: file].
	interpreterProxy failed ifFalse: [
		interpreterProxy pop: 2 thenPush: (interpreterProxy positive64BitIntegerFor: position)].
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileOpen [
	| writeFlag namePointer filePointer nameIndex nameSize |
	<var: 'nameIndex' type: 'char *'>
	<export: true>
	writeFlag := interpreterProxy
				booleanValueOf: (interpreterProxy stackValue: 0).
	namePointer := interpreterProxy stackValue: 1.
	(interpreterProxy isBytes: namePointer)
		ifFalse: [^ interpreterProxy primitiveFail].
	nameIndex := interpreterProxy firstIndexableField: namePointer.
	nameSize := interpreterProxy byteSizeOf: namePointer.
	filePointer := self fileOpenName: nameIndex size: nameSize write: writeFlag secure: true.
	interpreterProxy failed
		ifFalse: [interpreterProxy pop: 3 "rcvr, name, writeFlag"
			thenPush: filePointer]

]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileRead [
	<export: true>
	self cppIf: SPURVM
		ifTrue: [self primitiveFileReadWithPinning]
		ifFalse: [self primitiveFileReadWithoutPinning]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileReadWithPinning [
	"This version of primitiveFileRead is for garbage collectors that support pinning."
	| count startIndex array file elementSize bytesRead |
	<inline: true>
	<var: 'file' type: #'SQFile *'>
	<var: 'count' type: #'size_t'>
	<var: 'startIndex' type: #'size_t'>
	<var: 'elementSize' type: #'size_t'>
	count		:= interpreterProxy positive32BitValueOf: (interpreterProxy stackValue: 0).
	startIndex	:= interpreterProxy positive32BitValueOf: (interpreterProxy stackValue: 1).
 	array		:= interpreterProxy stackValue: 2.
	file			:= self fileValueOf: (interpreterProxy stackValue: 3).

	(interpreterProxy failed
	"buffer can be any indexable words or bytes object except CompiledMethod"
	 or: [(interpreterProxy isWordsOrBytes: array) not]) ifTrue:
		[^interpreterProxy primitiveFailFor: PrimErrBadArgument].

	elementSize := (interpreterProxy isWords: array) ifTrue: [4] ifFalse: [1].
	(startIndex >= 1
	 and: [(startIndex + count - 1) <= (interpreterProxy slotSizeOf: array)]) ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadIndex].

	"Note: adjust startIndex for zero-origin indexing"
	bytesRead := self
					sqFile: file
					Read: count * elementSize
					Into: (interpreterProxy cCoerce: (interpreterProxy firstIndexableField: array) to: #'char *')
					At: (startIndex - 1) * elementSize.
	interpreterProxy failed ifFalse:
		[interpreterProxy
			pop: 5 "pop rcvr, file, array, startIndex, count"
			thenPush:(interpreterProxy integerObjectOf: bytesRead // elementSize)  "push # of elements read"]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileReadWithoutPinning [
	"This version of primitiveFileRead is for garbage collectors without support for pinning."
	| retryCount count startIndex array file elementSize bytesRead |
	<inline: true>
	<var: 'file' type: #'SQFile *'>
	<var: 'count' type: #'size_t'>
	<var: 'startIndex' type: #'size_t'>
	<var: 'elementSize' type: #'size_t'>
	retryCount	:= 0.
	count		:= interpreterProxy positive32BitValueOf: (interpreterProxy stackValue: 0).
	startIndex	:= interpreterProxy positive32BitValueOf: (interpreterProxy stackValue: 1).
 
	[array		:= interpreterProxy stackValue: 2.
	 file			:= self fileValueOf: (interpreterProxy stackValue: 3).

	 (interpreterProxy failed
	 "buffer can be any indexable words or bytes object except CompiledMethod"
	 or: [(interpreterProxy isWordsOrBytes: array) not]) ifTrue:
		[^interpreterProxy primitiveFailFor: PrimErrBadArgument].

	 elementSize := (interpreterProxy isWords: array) ifTrue: [4] ifFalse: [1].
	 (startIndex >= 1
	  and: [(startIndex + count - 1) <= (interpreterProxy slotSizeOf: array)]) ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadIndex].

	 "Note: adjust startIndex for zero-origin indexing"
	 bytesRead := self
					sqFile: file
					Read: count * elementSize
					Into: (interpreterProxy cCoerce: (interpreterProxy firstIndexableField: array) to: #'char *')
					At: (startIndex - 1) * elementSize.
	 interpreterProxy primitiveFailureCode = PrimErrObjectMayMove
	 and: [(retryCount := retryCount + 1) <= 2] "Two objects, the file and the array can move"] whileTrue:
		[interpreterProxy
			tenuringIncrementalGC;
			primitiveFailFor: PrimNoErr].
	interpreterProxy failed ifFalse:
		[interpreterProxy
			pop: 5 "pop rcvr, file, array, startIndex, count"
			thenPush:(interpreterProxy integerObjectOf: bytesRead // elementSize)  "push # of elements read"]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileRename [

	| oldNamePointer newNamePointer oldNameIndex oldNameSize newNameIndex newNameSize  okToRename |
	<var: 'oldNameIndex' type: 'char *'>
	<var: 'newNameIndex' type: 'char *'>
	<export: true>

	newNamePointer := interpreterProxy stackValue: 0.
	oldNamePointer := interpreterProxy stackValue: 1.
	((interpreterProxy isBytes: newNamePointer)
			and: [interpreterProxy isBytes: oldNamePointer])
		ifFalse: [^interpreterProxy primitiveFail].
	newNameIndex := interpreterProxy firstIndexableField: newNamePointer.
	newNameSize := interpreterProxy byteSizeOf: newNamePointer.
	oldNameIndex := interpreterProxy firstIndexableField: oldNamePointer.
	oldNameSize := interpreterProxy byteSizeOf: oldNamePointer.
	"If the security plugin can be loaded, use it to check for rename permission.
	If not, assume it's ok"
	sCRFfn ~= 0
		ifTrue: [okToRename := self cCode: ' ((sqInt (*)(char *, sqInt))sCRFfn)(oldNameIndex, oldNameSize)'.
			okToRename
				ifFalse: [^interpreterProxy primitiveFail]].
	self
		sqFileRenameOld: oldNameIndex Size: oldNameSize
		New: newNameIndex Size: newNameSize.
	interpreterProxy failed
		ifFalse: [interpreterProxy pop: 2]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileSetPosition [
	| newPosition file |
	<var: 'file' type: 'SQFile *'>
	<var: 'newPosition' type: 'squeakFileOffsetType'>
	<export: true>
	(interpreterProxy byteSizeOf: (interpreterProxy stackValue: 0)) > (self sizeof: #squeakFileOffsetType) ifTrue:
		[^interpreterProxy primitiveFail].
	newPosition := interpreterProxy positive64BitValueOf: (interpreterProxy stackValue: 0).
	file := self fileValueOf: (interpreterProxy stackValue: 1).
	interpreterProxy failed ifFalse:
		[self sqFile: file SetPosition: newPosition ].
	interpreterProxy failed ifFalse:
		[interpreterProxy pop: 2] "pop position, file; leave rcvr on stack"
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileSize [
	| file size |
	<var: 'file' type: 'SQFile *'>
	<var: 'size' type: 'squeakFileOffsetType'>
	<export: true>
	file := self fileValueOf: (interpreterProxy stackValue: 0).
	interpreterProxy failed ifFalse:[size := self sqFileSize: file].
	interpreterProxy failed ifFalse: [
		interpreterProxy pop: 2 thenPush: (interpreterProxy positive64BitIntegerFor: size)].
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileStdioHandles [
	"Answer an Array of file handles for standard in, standard out and standard error,
	 with nil in entries that are unvailable, e.g. because the platform does not provide
	 standard error, etc.  Fail if there are no standard i/o facilities on the platform or
	 if the security plugin denies access or if memory runs out."
	| fileRecords result validMask |
	<export: true>
	<var: 'fileRecords' declareC: 'SQFile fileRecords[3]'>
	sHFAfn ~= 0 ifTrue:
		[(self cCode: ' ((sqInt (*)(void))sHFAfn)()' inSmalltalk: [true]) ifFalse:
			[^interpreterProxy primitiveFailFor: PrimErrUnsupported]].
	self cCode: '' inSmalltalk: [fileRecords := Array new: 3].
	validMask := self sqFileStdioHandlesInto: fileRecords.
	validMask = 0 ifTrue:
		[^interpreterProxy primitiveFailFor: PrimErrUnsupported].
	result := interpreterProxy instantiateClass: interpreterProxy classArray indexableSize: 3.
	result = nil ifTrue:
		[^interpreterProxy primitiveFailFor: PrimErrNoMemory].
	interpreterProxy pushRemappableOop: result.
	0 to: 2 do:
		[:index|
		(validMask bitAnd: (1 << index)) ~= 0 ifTrue:
			[result := interpreterProxy instantiateClass: interpreterProxy classByteArray indexableSize: self fileRecordSize.
			 result = nil ifTrue:
				[interpreterProxy popRemappableOop.
				^interpreterProxy primitiveFailFor: PrimErrNoMemory].
			 interpreterProxy storePointer: index ofObject: interpreterProxy topRemappableOop withValue: result.
			 self
				cCode:
					[self mem: (interpreterProxy firstIndexableField: result)
						cp: (self addressOf: (fileRecords at: index))
						y: self fileRecordSize]
				inSmalltalk:
					[(interpreterProxy firstIndexableField: result)
						unitSize: interpreterProxy wordSize;
						at: 0 put: (fileRecords at: index + 1)]]].
	 "In the non-Spur threaded VM ensure the handles are old, so that sqFileReadIntoAt is unaffected
	  by incremental GCs.  See platforms/Cross/plugins/FilePlugin/sqFilePluginBasicPrims.c.  The Spur
	  VM uses pinning, so it doesn't need the GC."
	self cppIf: COGMTVM
		ifTrue: [self cppIf: SPURVM
					ifTrue: []
					ifFalse: [interpreterProxy fullGC]].
	result := interpreterProxy popRemappableOop.
	interpreterProxy pop: 1 thenPush: result
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileSync [
	| file |
	<var: 'file' type: 'SQFile *'>
	<export: true>
	file := self fileValueOf: (interpreterProxy stackValue: 0).
	interpreterProxy failed ifFalse:[self sqFileSync: file].
	interpreterProxy failed ifFalse: [interpreterProxy pop: 1].
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileTruncate [
"ftruncate is not an ansi function so we have a macro to point to a suitable platform implementation" 
	| truncatePosition file |
	<var: 'file' type: #'SQFile *'>
	<var: 'truncatePosition' type: #squeakFileOffsetType>
	<export: true>
	(interpreterProxy isIntegerObject: (interpreterProxy stackValue: 0)) ifFalse:
		[(interpreterProxy byteSizeOf: (interpreterProxy stackValue: 0)) > (self sizeof: #squeakFileOffsetType) ifTrue:
			[^interpreterProxy primitiveFail]].
	truncatePosition := interpreterProxy positive64BitValueOf: (interpreterProxy stackValue: 0).
	file := self fileValueOf: (interpreterProxy stackValue: 1).
	interpreterProxy failed ifFalse:
		[self sqFile: file Truncate: truncatePosition].
		 interpreterProxy failed ifFalse:
			[interpreterProxy pop: 2 "pop position, file; leave rcvr on stack"]
]

{ #category : #'file primitives' }
FilePlugin >> primitiveFileWrite [
	| count startIndex array file elementSize bytesWritten |
	<var: 'file' type: 'SQFile *'>
	<var: 'count' type: 'size_t'>
	<var: 'startIndex' type: 'size_t'>
	<var: 'elementSize' type: 'size_t'>
	<export: true>
	count := interpreterProxy positive32BitValueOf: (interpreterProxy stackValue: 0).
	startIndex := interpreterProxy positive32BitValueOf: (interpreterProxy stackValue: 1).
	array := interpreterProxy stackValue: 2.
	file := self fileValueOf: (interpreterProxy stackValue: 3).

	 (interpreterProxy failed
	 "buffer can be any indexable words or bytes object except CompiledMethod"
	 or: [(interpreterProxy isWordsOrBytes: array) not]) ifTrue:
		[^interpreterProxy primitiveFailFor: PrimErrBadArgument].

	 elementSize := (interpreterProxy isWords: array) ifTrue: [4] ifFalse: [1].
	 (startIndex >= 1
	  and: [(startIndex + count - 1) <= (interpreterProxy slotSizeOf: array)]) ifFalse:
		[^interpreterProxy primitiveFailFor: PrimErrBadIndex].

	"Note: adjust startIndex for zero-origin indexing"
	bytesWritten := self
						sqFile: file
						Write: count * elementSize
						From: (interpreterProxy cCoerce: (interpreterProxy firstIndexableField: array) to: #'char *')
						At: startIndex - 1 * elementSize.
	interpreterProxy failed ifFalse:
		[interpreterProxy pop: 5 thenPush: (interpreterProxy integerObjectOf: bytesWritten // elementSize)]
]

{ #category : #'security primitives' }
FilePlugin >> primitiveHasFileAccess [
	|  hasAccess |
	<export: true>
	"If the security plugin can be loaded, use it to check . 
	If not, assume it's ok"
	sHFAfn ~= 0
		ifTrue: [hasAccess := self cCode: ' ((sqInt (*)(void))sHFAfn)()' inSmalltalk: [true]]
		ifFalse: [hasAccess := true].
	interpreterProxy pop: 1.
	interpreterProxy pushBool: hasAccess
]

{ #category : #'file primitives' }
FilePlugin >> setMacFile: fileName Type: typeString AndCreator: creatorString [
	"Exported entry point for the VM. Needed for image saving only and no-op on anything but Macs."
	<export: true>
	<var: #fileName type: 'char *'>
	<var: #typeString type: 'char *'>
	<var: #creatorString type: 'char *'>
	^self cCode: 'dir_SetMacFileTypeAndCreator(fileName, strlen(fileName), typeString, creatorString)'.
]

{ #category : #'initialize-release' }
FilePlugin >> shutdownModule [
	<export: true>
	^self cCode: 'sqFileShutdown()' inSmalltalk:[true]
]