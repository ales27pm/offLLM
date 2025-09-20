#pragma once

// Attempts to import the generated LLM spec header from a variety of known
// React Native codegen output locations. Sets LLM_SPEC_AUTOGEN_AVAILABLE to 1
// when a matching header is imported so callers can guard usage of the
// generated C++ bridge types.

#ifdef LLM_SPEC_AUTOGEN_HEADER
#undef LLM_SPEC_AUTOGEN_HEADER
#endif

#ifndef LLM_SPEC_AUTOGEN_AVAILABLE
#define LLM_SPEC_AUTOGEN_AVAILABLE 0
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include("AppSpec/LLMSpec.h")
  #import "AppSpec/LLMSpec.h"
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "AppSpec/LLMSpec.h"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include("AppSpecs/LLMSpec.h")
  #import "AppSpecs/LLMSpec.h"
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "AppSpecs/LLMSpec.h"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include("LLMSpec.h")
  #import "LLMSpec.h"
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "LLMSpec.h"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include(<FBReactNativeSpec/FBReactNativeSpec.h>)
  #import <FBReactNativeSpec/FBReactNativeSpec.h>
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "<FBReactNativeSpec/FBReactNativeSpec.h>"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include(<React-Codegen/FBReactNativeSpec/FBReactNativeSpec.h>)
  #import <React-Codegen/FBReactNativeSpec/FBReactNativeSpec.h>
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "<React-Codegen/FBReactNativeSpec/FBReactNativeSpec.h>"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include("FBReactNativeSpec/FBReactNativeSpec.h")
  #import "FBReactNativeSpec/FBReactNativeSpec.h"
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "FBReactNativeSpec/FBReactNativeSpec.h"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include("FBReactNativeSpec/AppSpec.h")
  #import "FBReactNativeSpec/AppSpec.h"
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "FBReactNativeSpec/AppSpec.h"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include(<FBReactNativeSpec/AppSpec.h>)
  #import <FBReactNativeSpec/AppSpec.h>
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "<FBReactNativeSpec/AppSpec.h>"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE && __has_include("AppSpec.h")
  #import "AppSpec.h"
  #undef LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_AVAILABLE 1
  #define LLM_SPEC_AUTOGEN_HEADER "AppSpec.h"
#endif

#if !LLM_SPEC_AUTOGEN_AVAILABLE
  #define LLM_SPEC_AUTOGEN_HEADER "<missing>"
  #warning "LLMSpecAutoloader: No Codegen spec header found. Ensure RN codegen ran and Pods installed."
#endif
