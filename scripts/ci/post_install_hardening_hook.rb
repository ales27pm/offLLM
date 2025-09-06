#!/usr/bin/env ruby
# Make Pods + app target build cleanly on iOS:
# - Standardize on libc++ + C++17 (stable for RN/Folly)
# - Disable Folly SIMD (avoid SimdAnyOf/SimdForEach failures): -DFOLLY_DISABLE_SIMD=1
# - Do NOT inject custom -isystem or C++20 typedef macros (these can perturb header precedence)

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
  flags.each do |f|
    arr << '$(inherited)' unless arr.include?('$(inherited)')
    arr << f unless arr.include?(f)
  end
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

      # Remove any previous tweaks we might have added in earlier attempts
      %w[OTHER_CPLUSPLUSFLAGS OTHER_CFLAGS].each do |k|
        bs[k] = strip_flags(bs[k]) { |f|
          f == '-isystem' ||
          f == '$(SDKROOT)/usr/include/c++/v1' ||
          f.include?('_LIBCPP_ENABLE_CXX20_REMOVED_TYPEDEF_MACROS') ||
          f.include?('FOLLY_USE_SIMD=1')
        }
      end

      # Disable Folly SIMD everywhere (Pods + app)
      bs['OTHER_CPLUSPLUSFLAGS'] = ensure_flags(bs['OTHER_CPLUSPLUSFLAGS'], FOLLY_SIMD_OFF)
      bs['OTHER_CFLAGS']         = ensure_flags(bs['OTHER_CFLAGS'],         FOLLY_SIMD_OFF)
    end
  end

  proj.save
  puts "✅ Patched #{proj_path}"
end

# 1) Patch Pods (covers RCT-Folly, DoubleConversion, etc.)
patch_project(PODS_PROJ_PATH)

# 2) Patch app target
patch_project(APP_PROJ_PATH, target_name: 'monGARS')
