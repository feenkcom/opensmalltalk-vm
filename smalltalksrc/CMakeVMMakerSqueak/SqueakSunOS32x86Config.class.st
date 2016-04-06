"
A Linux64x86w32BitConfig is an Abstract base class that provides common information for my subclasses.
I am not meant to be built.

I configure a VM according to my name's form: [Operating System] [WordSize] [Processor Language][VM MemoryManager][BuildType]Conf

SqueakLinux64x86w32CompatBuilder 
	configureABuildFor: #ONE OF MY SUBCLASSES NAME HERE withBuildType: #build;
	enableMessageTracking: true;
	generateByTemplate.



HelpBrowser openOn: CMakeVMMakerSqueakDeveloperHelp



"
Class {
	#name : #SqueakSunOS32x86Config,
	#superclass : #SqueakUnixConfig,
	#category : #'CMakeVMMakerSqueak-SunOS32x86'
}

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> addVMPluginsBuild: aMaker [
	|temp o|
	self flag:'tty'. "I am writing sub-directory CMakeLists.txt here. Should I also write the config.cmake files?"
	enabledebugmessages
		ifTrue: [templates  "this message will go to the top level CMakeLists.txt file"
				addLast: (CMakeMessage new message: self class name , 'addVMPluginsBuild: aMaker')].
	vmplugins do:[ :vmp |                    
		o := String new writeStream.   "each VMPlugin gets its own CMakeLists.txt file in its own directory"
		temp := OrderedCollection new.	
		temp
			addAllLast:((CMakePluginVm new)    "this is the CMakeCompositTemplate"
					config: self 
					definitions: (vmp compilerdefinitions)
					module: (vmp module)
					sources: (vmp sources)
					includedirectories: (vmp includedirectories)).
		temp do: [:each |  o nextPutAll: (each content); cr].
	((self buildDir) directoryExists: (vmp module))
		ifFalse:[	(self buildDir) createDirectory: (vmp module)].
		self write: (o contents) toFile: vmp module , FileDirectory slash , aMaker outputFileName.
		templates   "this will go to the top level CMakeLists.txt file"
			addLast: ((CMakeAddSubDirectory new) sourcedir: (vmp module)) 
	].










]

{ #category : #cmake }
SqueakSunOS32x86Config >> availableBuildTypes [
 	 ^SqueakCMakeVMMakerAbstractBuilder  default  noBuildTypes
"

subclasses should use

  ^super allBuildTypes copyWithoutAll: #( #assertWithHeartbeatTimer #debugWithHeartbeatTimer debugMultiThreadedFFI.....etc))   "
	

]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> coreSourcesBuild [
	"files to include from src/vm dir"
	^ #(
		'cogit.c'
		'gcc3x-cointerp.c'
		)
]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> coreSourcesBuildMultiThreaded [
	"files to include from src/vm dir"
	^ #(
		'cogit.c'
		'cointerpmt.c'
		)
]

{ #category : #plugins }
SqueakSunOS32x86Config >> customizeCMakeVMDisplayNull [
	|module|
	module := vmplugins detect: [:vmd | #CMakeVMDisplayNull = ((vmd class name) asSymbol)] ifNone:[nil].  "error handling?"
	module 
		sources: #('${targetPlatform}/vm-display-null/sqUnixDisplayNull') ;
		compilerdefinitions:(OrderedCollection with: '-fPIC' with: '-DPIC');
		compilerflags: (self compilerFlags);
		externallibraries: #();
		linkerflags: (self linkerFlags);
		includedirectories:(OrderedCollection 
										with:'${crossDir}/plugins/FilePlugin' 
										with: '${targetPlatform}/plugins/B3DAcceleratorPlugin'  
 									     with: '${crossDir}/plugins/B3DAcceleratorPlugin').
	self flag:'tty'. "I don't think includedirectories is correct. revisit"







]

{ #category : #plugins }
SqueakSunOS32x86Config >> customizeCMakeVMDisplayX11 [
	|module|
	module := vmplugins detect: [:vmd | #CMakeVMDisplayX11 = ((vmd class name) asSymbol)] ifNone:[nil].  "error handling?"
	module 
		sources: #( '${targetPlatform}/vm-display-X11/sqUnixX11' '${targetPlatform}/vm-display-X11/sqUnixMozilla' );
		compilerdefinitions:(OrderedCollection with: '-fPIC' with: '-DPIC');
		compilerflags: (self compilerFlags);
		externallibraries: (self externalLibraries);
		linkerflags: (self linkerFlags);
		includedirectories:(OrderedCollection 
										with:'${crossDir}/plugins/FilePlugin' 
										with: '${targetPlatform}/plugins/B3DAcceleratorPlugin'  
 									     with: '${crossDir}/plugins/B3DAcceleratorPlugin').

]

{ #category : #plugins }
SqueakSunOS32x86Config >> customizeCMakeVMSoundALSA [
	|module|
	module := vmplugins detect: [:vmd | #CMakeVMSoundALSA = ((vmd class name) asSymbol)] ifNone:[nil].  "error handling?"
	module 
		sources: #( '${targetPlatform}/vm-sound-ALSA/sqUnixSoundALSA' );
		compilerdefinitions:(OrderedCollection with: '-fPIC' with: '-DPIC');
		compilerflags: (self compilerFlags);
		externallibraries: (self externalLibraries);
		linkerflags: (self linkerFlags);
		includedirectories: #().
	
]

{ #category : #plugins }
SqueakSunOS32x86Config >> customizeCMakeVMSoundNull [
	|module|
	module := vmplugins detect: [:vmd | #CMakeVMSoundNull = ((vmd class name) asSymbol)] ifNone:[nil].  "error handling?"
	module 
		sources: #( '${targetPlatform}/vm-sound-null/sqUnixSoundNull' );
		compilerdefinitions:(OrderedCollection with: '-fPIC' with: '-DPIC');
		compilerflags: (self compilerFlags);
		externallibraries: (self externalLibraries);
		linkerflags: (self linkerFlags);
		includedirectories:#()


]

{ #category : #plugins }
SqueakSunOS32x86Config >> customizeVMPlugins [
	|mysubset iwantonly|
	"trim the vmdrivers ordered collection of CMakeVMDriver subclasses to only those I want. then customize them for use on this OS/platform"
	iwantonly :=	 #(#CMakeVMDisplayNull  #CMakeVMDisplayX11  #CMakeVMSoundALSA  #CMakeVMSoundNull ).
	mysubset := vmplugins select: [:vmd | 0 < (iwantonly occurrencesOf: (vmd class name) asSymbol)]. 
	vmplugins := mysubset.
	self 
		customizeCMakeVMDisplayNull;
		customizeCMakeVMDisplayX11;
		customizeCMakeVMSoundALSA;
		customizeCMakeVMSoundNull.




]

{ #category : #plugins }
SqueakSunOS32x86Config >> defaultExternalPlugins [
	^ #(
		B3DAcceleratorPlugin
		ThreadedIA32FFIPlugin "SqueakFFIPrims"
		"UUIDPlugin"
		"UnixOSProcessPlugin ?? "	
		JPEGReaderPlugin 
		JPEGReadWriter2Plugin 			
		RePlugin
		InternetConfigPlugin
	)

"debug"
]

{ #category : #plugins }
SqueakSunOS32x86Config >> defaultInternalPlugins [
" took from unixbuild/bld/plugins.int"
	^ #(
		ADPCMCodecPlugin 
		AsynchFilePlugin 
		BalloonEnginePlugin "B2DPlugin" 
		BitBltSimulation "BitBltPlugin"
		BMPReadWriterPlugin 
		CroquetPlugin 
		DeflatePlugin  "ZipPlugin"
		DropPlugin 
		DSAPlugin "DSAPrims" 
		FFTPlugin 
		FileCopyPlugin 
		FilePlugin 
		FloatArrayPlugin 
		FloatMathPlugin 
		JoystickTabletPlugin 
		KlattSynthesizerPlugin "Klatt"
		LargeIntegersPlugin "LargeIntegers"
		Matrix2x3Plugin 
		MIDIPlugin 
		MiscPrimitivePlugin 
		Mpeg3Plugin  	
		SecurityPlugin 
		SerialPlugin 
		SocketPlugin 
		SoundCodecPlugin "SoundCodecPrims"
		SoundGenerationPlugin 
		SoundPlugin 
		StarSqueakPlugin 
		SurfacePlugin	
		LocalePlugin
		)
]

{ #category : #cmake }
SqueakSunOS32x86Config >> dirBuildPlatform [
	^self dirSunOS32x86
]

{ #category : #cmake }
SqueakSunOS32x86Config >> excludeFromBuild [
	"over-ride to exclude yourself from a build or not"
	^true
]

{ #category : #cmake }
SqueakSunOS32x86Config >> executableName [
	"AbstractBaseClass configurations are not meant to be executable"
	^ self vmIShouldNotBeHereExecutableName
]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> externalPluginsBuild [
	^ externalPlugins ifNil: [ externalPlugins := self defaultExternalPlugins ]
]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> extraPluginSettingsBuild: aMaker [
	aMaker isExternal 
		ifTrue:[aMaker templates addLast:((CMakeSet new) variable:'LIBRARY_OUTPUT_PATH' value:'${outputDir}')].
	aMaker templates addLast:((CMakeSet new) variable:'linkFlags' quotedValue:'${linkFlags} -m32').


"	maker isExternal ifTrue: [
		maker set: 'LIBRARY_OUTPUT_PATH' to: '${outputDir}' 
	].
	maker set: #linkFlags toString: '${linkFlags} -m32'"
]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> internalPluginsBuild [
	^ internalPlugins ifNil: [ internalPlugins := self defaultInternalPlugins ]
]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> postBuildActionsBuild: aMaker [
	"SystemNavigation default browseMethodsWhoseNamesContain: 'postBuildActionsBuild:'"
	(aMaker config enabledebugmessages)
		ifTrue:[	
	aMaker config templates 
		addLast: ((CMakeMessage new) message: (self class name), ' postBuildActionsBuild' )
	].
	aMaker config templates 
		addLast: ((CMakeMessage new) message: 'postBuildActionsBuild: aMaker' );
		addLast:((CMakeCommand new) command:'include' params:'config.cmake');                                                 "cmake --help-command include "
		addLast:((CMakeCommand new) command:'LIST' params:'REMOVE_DUPLICATES config_vars');                      "cmake --help-command LIST"
		addLast:((CMakeCommand new) command:'FILE' params:'WRITE ${CMAKE_BINARY_DIR}/config.h.in ""');          "cmake --help-command FILE"
		addLast:(CMakeAppendConfigHIn new);
		addLast:((CMakeCommand new) command:'CONFIGURE_FILE' params:'${CMAKE_BINARY_DIR}/config.h.in ${CMAKE_BINARY_DIR}/config.h');
		addLast:((CMakeCommand new) command:'GET_CMAKE_PROPERTY' params:'tmp VARIABLES');
		addLast:((CMakeCommand new) command:'LIST' params:'REMOVE_ITEM tmp tmp');
		addLast:((CMakeCommand new) command:'LIST' params:'SORT tmp');
		addLast:((CMakeCommand new) command:'FILE' params:'WRITE ${CMAKE_BINARY_DIR}/config.h.status ""');
		addLast:(CMakeAppendConfigStatus new).


]

{ #category : #'cmake buildType redirects' }
SqueakSunOS32x86Config >> preferredIncludesBuild [
	(enabledebugmessages)
		ifTrue:[	
	templates 
		addLast: ((CMakeMessage new) message: (self class name), ' preferredIncludesBuild' )
	].
	templates
		addLast: ((CMakeIncludeDirectories new) dirs: (OrderedCollection with: '${targetPlatform}/plugins/B3DAcceleratorPlugin')).

	(enabledebugmessages)
		ifTrue:[	
	templates 
		addLast: ((CMakeMessage new) message: 'CMAKE_INCLUDE_PATH =  ${CMAKE_INCLUDE_PATH}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_SYSTEM_INCLUDE_PATH =  ${CMAKE_SYSTEM_INCLUDE_PATH}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES = ${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES =  ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_FIND_ROOT_PATH_MODE_INCLUDE =  ${CMAKE_FIND_ROOT_PATH_MODE_INCLUDE}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_FIND_ROOT_PATH_MODE_INCLUDE =  ${CMAKE_INCLUDE_CURRENT_DIR}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_INCLUDE_CURRENT_DIR_IN_INTERFACE =  ${CMAKE_INCLUDE_CURRENT_DIR_IN_INTERFACE}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_INCLUDE_DIRECTORIES_BEFORE =  ${CMAKE_INCLUDE_DIRECTORIES_BEFORE}' );
		addLast: ((CMakeMessage new) message: 'CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE =  ${CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE}' )
	].
]