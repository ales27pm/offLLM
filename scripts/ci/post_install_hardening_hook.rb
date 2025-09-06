#!/usr/bin/env ruby
# MonGARS CI hardening for iOS
# - Use libc++ + C++17 (what RN/Folly expect)
# - Disable Folly SIMD (-DFOLLY_DISABLE_SIMD=1) to avoid SimdAnyOf/SimdForEach failures
# - Remove old C++20/headers hacks; idempotent

require 'xcodeproj'

IOS_DIR        = File.expand_path(File.join(__dir__, '..', '..', 'ios'))
PODS_PROJ_PATH = File.join(IOS_DIR, 'Pods', 'Pods.xcodeproj')
APP_PROJ_PATH  = File.join(IOS_DIR, 'monGARS.xcodeproj')

CXX_STD = 'gnu++17'
LIBCXX  = 'libc++'
FOLLY_SIMD_OFF = '-DFOLLY_DISABLE_SIMD=1'

def normalize_cxx_std(current)
  return CXX_STD unless current.is_a?(String)
  if current =~ /(?:c\+\+|gnu\+\+)(\d{2})/
    ver = Regexp.last_match(1).to_i
    ver >= 20 ? CXX_STD : current
  else
    CXX_STD
  end
end

def ensure_flags(list_or_string, *flags)
  arr = case list_or_string
        when nil then []
        when String then list_or_string.split(/\s+/)
        when Array then list_or_string
        else []
        end
  arr << '$(inherited)' unless arr.include?('$(inherited)')
  flags.each { |f| arr << f unless arr.include?(f) }
  arr.join(' ').strip
end

def strip_flags(list_or_string, &block)
  arr = case list_or_string
        when nil then []
        when String then list_or_string.split(/\s+/)
        when Array then list_or_string
        else []
        end
  arr.reject! { |f| block.call(f) }
  arr = ['$(inherited)'] if arr.empty?
  arr.join(' ').strip
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

      # libc++ + C++17
      bs['CLANG_CXX_LIBRARY']           = LIBCXX
      bs['CLANG_CXX_LANGUAGE_STANDARD'] = normalize_cxx_std(bs['CLANG_CXX_LANGUAGE_STANDARD'])
      bs['GCC_C_LANGUAGE_STANDARD']   ||= 'gnu11'

      # Remove previous hacks (C++20 typedefs, custom -isystem, forced SIMD on)
      %w[OTHER_CPLUSPLUSFLAGS OTHER_CFLAGS].each do |k|
        bs[k] = strip_flags(bs[k]) { |f|
          f == '-isystem' ||
          f == '$(SDKROOT)/usr/include/c++/v1' ||
          f.include?('_LIBCPP_ENABLE_CXX20_REMOVED_TYPEDEF_MACROS') ||
          f.include?('FOLLY_USE_SIMD=1')
        }
      end

      # Disable Folly SIMD globally
      bs['OTHER_CPLUSPLUSFLAGS'] = ensure_flags(bs['OTHER_CPLUSPLUSFLAGS'], FOLLY_SIMD_OFF)
      bs['OTHER_CFLAGS']         = ensure_flags(bs['OTHER_CFLAGS'],         FOLLY_SIMD_OFF)
    end
  end

  proj.save
  puts "✅ Patched #{proj_path}"
end

patch_project(PODS_PROJ_PATH)                          # Pods incl. RCT-Folly, DoubleConversion, etc.
patch_project(APP_PROJ_PATH, target_name: 'monGARS')   # App target