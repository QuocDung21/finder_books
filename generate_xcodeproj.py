import os
import uuid

def generate_id(seed):
    # Deterministic 24-character hex string for PBX objects
    import hashlib
    return hashlib.md5(seed.encode('utf-8')).hexdigest()[:24].upper()

sources = sorted([f for f in os.listdir('Sources') if f.endswith('.swift')])

# IDs
proj_id = generate_id("PROJECT")
main_group_id = generate_id("MAIN_GROUP")
sources_group_id = generate_id("SOURCES_GROUP")
products_group_id = generate_id("PRODUCTS_GROUP")
target_id = generate_id("TARGET_FINDERBOOKS")
app_product_id = generate_id("PRODUCT_FINDERBOOKS")
sources_phase_id = generate_id("PHASE_SOURCES")
frameworks_phase_id = generate_id("PHASE_FRAMEWORKS")
resources_phase_id = generate_id("PHASE_RESOURCES")
native_config_list_id = generate_id("NATIVE_CONFIG_LIST")
proj_config_list_id = generate_id("PROJ_CONFIG_LIST")
proj_debug_config_id = generate_id("PROJ_DEBUG_CONFIG")
proj_release_config_id = generate_id("PROJ_RELEASE_CONFIG")
target_debug_config_id = generate_id("TARGET_DEBUG_CONFIG")
target_release_config_id = generate_id("TARGET_RELEASE_CONFIG")

file_refs = []
build_files = []

for s in sources:
    f_ref_id = generate_id(f"FILE_REF_{s}")
    b_file_id = generate_id(f"BUILD_FILE_{s}")
    file_refs.append((f_ref_id, s))
    build_files.append((b_file_id, f_ref_id, s))

pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
"""

for b_id, f_id, s in build_files:
    pbxproj += f"\t\t{b_id} /* {s} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {s} */; }};\n"

pbxproj += f"""/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t{app_product_id} /* FinderBooks.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FinderBooks.app; sourceTree = BUILT_PRODUCTS_DIR; }};
"""

for f_id, s in file_refs:
    pbxproj += f"\t\t{f_id} /* {s} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {s}; sourceTree = \"<group>\"; }};\n"

pbxproj += f"""/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase_id} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{main_group_id} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{sources_group_id} /* Sources */,
\t\t\t\t{products_group_id} /* Products */,
\t\t\t);
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{sources_group_id} /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
"""

for f_id, s in file_refs:
    pbxproj += f"\t\t\t\t{f_id} /* {s} */,\n"

pbxproj += f"""\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{products_group_id} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_product_id} /* FinderBooks.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = \"<group>\";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* FinderBooks */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {native_config_list_id} /* Build configuration list for PBXNativeTarget "FinderBooks" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase_id} /* Sources */,
\t\t\t\t{frameworks_phase_id} /* Frameworks */,
\t\t\t\t{resources_phase_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = FinderBooks;
\t\t\tproductName = FinderBooks;
\t\t\tproductReference = {app_product_id} /* FinderBooks.app */;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{proj_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t\tDevelopmentTeam = E867MSW4D4;
\t\t\t\t\t\tProvisioningStyle = Automatic;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_config_list_id} /* Build configuration list for PBXProject "FinderBooks" */;
\t\t\tcompatibilityVersion = \"Xcode 14.0\";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {products_group_id} /* Products */;
\t\t\tprojectDirPath = \"\";
\t\t\tprojectRoot = \"\";
\t\t\ttargets = (
\t\t\t\t{target_id} /* FinderBooks */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""

for b_id, f_id, s in build_files:
    pbxproj += f"\t\t\t\t{b_id} /* {s} in Sources */,\n"

pbxproj += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{proj_debug_config_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t\"DEBUG=1\",
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t);
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = auto;
\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{proj_release_config_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = auto;
\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";
\t\t\t\tSWIFT_COMPILATION_MODE = \"wholemodule\";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{target_debug_config_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = E867MSW4D4;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Finder Books\";
\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;
\t\t\t\tINFOPLIST_KEY_NSBonjourServices = \"_finderbooks-pen._tcp _finderbooks-pen._udp\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"Ứng dụng cần sử dụng mạng cục bộ để đồng bộ sách và nét vẽ Apple Pencil với máy Mac.\";
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.quocdung.finderbooks;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES;
\t\t\t\tSUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{target_release_config_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = E867MSW4D4;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Finder Books\";
\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;
\t\t\t\tINFOPLIST_KEY_NSBonjourServices = \"_finderbooks-pen._tcp _finderbooks-pen._udp\";
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = \"Ứng dụng cần sử dụng mạng cục bộ để đồng bộ sách và nét vẽ Apple Pencil với máy Mac.\";
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.quocdung.finderbooks;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES;
\t\t\t\tSUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{proj_config_list_id} /* Build configuration list for PBXProject "FinderBooks" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_debug_config_id} /* Debug */,
\t\t\t\t{proj_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{native_config_list_id} /* Build configuration list for PBXNativeTarget "FinderBooks" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{target_debug_config_id} /* Debug */,
\t\t\t\t{target_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

	}};
	rootObject = {proj_id} /* Project object */;
}}
"""

os.makedirs("FinderBooks.xcodeproj", exist_ok=True)
with open("FinderBooks.xcodeproj/project.pbxproj", "w") as f:
    f.write(pbxproj)

print("🎉 Successfully generated FinderBooks.xcodeproj with Team E867MSW4D4 and Automatic Code Signing!")
