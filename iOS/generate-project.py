from pathlib import Path
import hashlib
root=Path(__file__).parent
objects={}
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(name,text):
 i=uid(name);objects[i]=text;return i
def quote(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
sources=['../Sources/Models.swift','../Sources/Security.swift','../Sources/ImportExport.swift','../Sources/Playlist.swift','../Sources/Player.swift','../Sources/Store.swift','../Sources/About.swift','../Sources/Artwork.swift','../Sources/NetworkPolicy.swift','../Sources/GenreManager.swift','../Sources/SleepTimer.swift','../Sources/LanguagePicker.swift','../Sources/Dash.swift','../Sources/CountryPicker.swift','../Sources/StationLanguagePicker.swift','../Sources/CatalogLanguage.swift','AppIOS.swift','NetworkIOS.swift']
refs=[];builds=[]
for path in sources:
 r=add(path,f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(path)}; sourceTree = "<group>"; }}');refs.append(r)
 builds.append(add('build:'+path,f'{{isa = PBXBuildFile; fileRef = {r}; }}'))
for path in ['Info.plist','../Sources/VLC.h','Podfile']:
 refs.append(add(path,f'{{isa = PBXFileReference; path = {quote(path)}; sourceTree = "<group>"; }}'))
resources=[]
asset=add('assets','{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }')
refs.append(asset)
resources.append(add('resource:assets',f'{{isa = PBXBuildFile; fileRef = {asset}; }}'))
localizations=[]
for folder in sorted((root.parent/'Resources/Localization').glob('*.lproj')):
 path='../Resources/Localization/'+folder.name+'/Localizable.strings'
 localizations.append(add(path,f'{{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {quote(folder.stem)}; path = {quote(path)}; sourceTree = "<group>"; }}'))
variant=add('localized-strings','{isa = PBXVariantGroup; children = ('+','.join(localizations)+',); name = Localizable.strings; sourceTree = "<group>"; }')
refs.append(variant)
resources.append(add('resource:localized-strings',f'{{isa = PBXBuildFile; fileRef = {variant}; }}'))
for path in ['../LICENSE','../NOTICE']:
 r=add(path,f'{{isa = PBXFileReference; lastKnownFileType = text; path = {quote(path)}; sourceTree = "<group>"; }}');refs.append(r);resources.append(add('resource:'+path,f'{{isa = PBXBuildFile; fileRef = {r}; }}'))
product=add('product','{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DeutsiaRadio.app; sourceTree = BUILT_PRODUCTS_DIR; }')
products=add('products',f'{{isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>"; }}')
group=add('main',f'{{isa = PBXGroup; children = ({",".join(refs)},{products},); sourceTree = "<group>"; }}')
sourcephase=add('sources',f'{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0; }}')
frameworkphase=add('frameworks','{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }')
resourcephase=add('resources',f'{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resources)},); runOnlyForDeploymentPostprocessing = 0; }}')
configs=[];projectconfigs=[]
for mode in ['Debug','Release']:
 settings={'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.billsonhe.deutsiaradio','INFOPLIST_FILE':'Info.plist','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','SWIFT_OBJC_BRIDGING_HEADER':'../Sources/VLC.h','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1,2','SDKROOT':'iphoneos','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','OTHER_LDFLAGS':'$(inherited) -ObjC','ENABLE_BITCODE':'NO','CLANG_ENABLE_MODULES':'YES'}
 configs.append(add('target:'+mode,'{isa = XCBuildConfiguration; buildSettings = {'+''.join(f'{k} = {quote(v)};' for k,v in settings.items())+f'}}; name = {mode}; }}'))
 projectconfigs.append(add('project:'+mode,f'{{isa = XCBuildConfiguration; buildSettings = {{CLANG_ENABLE_MODULES = YES; }}; name = {mode}; }}'))
cl=add('targetconfig','{isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }')
pcl=add('projectconfig','{isa = XCConfigurationList; buildConfigurations = ('+','.join(projectconfigs)+',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }')
target=add('target',f'{{isa = PBXNativeTarget; buildConfigurationList = {cl}; buildPhases = ({sourcephase},{frameworkphase},{resourcephase},); buildRules = (); dependencies = (); name = DeutsiaRadio; productName = DeutsiaRadio; productReference = {product}; productType = "com.apple.product-type.application"; }}')
project=add('project',f'{{isa = PBXProject; attributes = {{LastUpgradeCheck = 1600; TargetAttributes = {{{target} = {{ProvisioningStyle = Automatic; }}; }}; }}; buildConfigurationList = {pcl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (zh_CN,en,Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},); }}')
objects[group] = '{isa = PBXGroup; children = ('+','.join(refs)+','+products+',); sourceTree = "<group>"; }'
p=root/'DeutsiaRadio.xcodeproj' ;p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(f'{i} = {s};\n' for i,s in objects.items())+'}; rootObject = '+project+'; }\n')
scheme=p/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
(scheme/'DeutsiaRadio.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="DeutsiaRadio.app" BlueprintName="DeutsiaRadio" ReferencedContainer="container:DeutsiaRadio.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="DeutsiaRadio.app" BlueprintName="DeutsiaRadio" ReferencedContainer="container:DeutsiaRadio.xcodeproj"/></BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(p)
