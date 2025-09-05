#!/usr/bin/env ruby
# Make Pods + app target compile cleanly on iOS 18 toolchains.
# - Force libc++ and C++20
# - Re-enable removed typedef macros (e.g. ::FILE)
# - Ensure SDK libc++ headers are seen first via -isystem $(SDKROOT)/usr/include/c++/v1

require 'xcodeproj'

IOS_DIR        = File.expand_path(File.join(__dir__, '..', '..', 'ios'))
PODS_PROJ_PATH = File.join(IOS_DIR, 'Pods', 'Pods.xcodeproj')
APP_PROJ_PATH  = File.join(IOS_DIR, 'monGARS.xcodeproj')

CPP_MACRO = '-D_LIBCPP_ENABLE_CXX20_REMOVED_TYPEDEF_MACROS'
CXX_STD   = 'gnu++20'
LIBCXX    = 'libc++'
LIBCXX_ISYSTEM = '-isystem $(SDKROOT)/usr/include/c++/v1'

def normalize_cxx_std(current)
  return CXX_STD unless current.is_a?(String)
  if current =~ /(?:c\+\+|gnu\+\+)(\d{2})/
    ver = Regexp.last_match(1).to_i
    ver >= 20 ? current : CXX_STD
  else
    CXX_STD
  end
end

def ensure_flag(flags, newflag)
  arr = case flags
        when nil then []
        when String then flags.split(/\s+/)
        when Array then flags
        else []
        end
  unless arr.any? { |f| f == newflag }
    arr << newflag
  end
  arr
end

def patch_project(proj_path, target_name: nil)
  unless File.exist?(proj_path)
    puts "⚠️  Skip missing: #{proj_path}"
    return
  end

  proj = Xcodeproj::Project.open(proj_path)
  proj.targets.each do |t|
    next if target_name && t.name != target_name

    t.build_configurations.each do |cfg|
      bs = cfg.build_settings

      # Force libc++ and C++20
      bs['CLANG_CXX_LIBRARY']          = LIBCXX
      bs['CLANG_CXX_LANGUAGE_STANDARD'] = normalize_cxx_std(bs['CLANG_CXX_LANGUAGE_STANDARD'])

      # Re-enable removed typedef macros + force SDK libc++ headers first
      cppflags = bs['OTHER_CPLUSPLUSFLAGS']
      cppflags = ensure_flag(cppflags, '$(inherited)')
      cppflags = ensure_flag(cppflags, CPP_MACRO)
      cppflags = ensure_flag(cppflags, LIBCXX_ISYSTEM)
      bs['OTHER_CPLUSPLUSFLAGS'] = cppflags.is_a?(Array) ? cppflags.join(' ') : cppflags

      # Reasonable C language standard
      bs['GCC_C_LANGUAGE_STANDARD'] = (bs['GCC_C_LANGUAGE_STANDARD'] || 'gnu11')
    end
  end

  proj.save
  puts "✅ Patched #{proj_path}"
end

# 1) Patch Pods project (applies to RCT-Folly and friends)
patch_project(PODS_PROJ_PATH)

# 2) Patch app project (target: monGARS)
patch_project(APP_PROJ_PATH, target_name: 'monGARS')
