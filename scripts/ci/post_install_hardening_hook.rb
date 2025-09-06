#!/usr/bin/env ruby
# Make Pods + app target build cleanly by:
# - Standardizing on C++17 (expected by Folly/RN)
# - Using libc++
# - NOT injecting extra include paths or C++20 typedef macros

require 'xcodeproj'

IOS_DIR        = File.expand_path(File.join(__dir__, '..', '..', 'ios'))
PODS_PROJ_PATH = File.join(IOS_DIR, 'Pods', 'Pods.xcodeproj')
APP_PROJ_PATH  = File.join(IOS_DIR, 'monGARS.xcodeproj')

CXX_STD = 'gnu++17'
LIBCXX  = 'libc++'

def normalize_cxx_std(current)
  return CXX_STD unless current.is_a?(String)
  # If a project sets c++2a/20, bring it down to gnu++17 for consistency.
  if current =~ /(?:c\+\+|gnu\+\+)(\d{2})/
    ver = Regexp.last_match(1).to_i
    ver >= 20 ? CXX_STD : current
  else
    CXX_STD
  end
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

      # Use libc++ and C++17 across the board
      bs['CLANG_CXX_LIBRARY']            = LIBCXX
      bs['CLANG_CXX_LANGUAGE_STANDARD']  = normalize_cxx_std(bs['CLANG_CXX_LANGUAGE_STANDARD'])
      bs['GCC_C_LANGUAGE_STANDARD']    ||= 'gnu11'

      # Strip any previously injected flags that modified header precedence
      # and C++20 removed typedef macros.
      %w[OTHER_CPLUSPLUSFLAGS OTHER_CFLAGS].each do |k|
        v = bs[k]
        next if v.nil?

        arr = v.is_a?(Array) ? v : v.to_s.split(/\s+/)
        arr.reject! { |f|
          f == '-isystem' || f == '$(SDKROOT)/usr/include/c++/v1' ||
          f.include?('_LIBCPP_ENABLE_CXX20_REMOVED_TYPEDEF_MACROS')
        }
        bs[k] = arr.empty? ? '$(inherited)' : arr.join(' ')
      end
    end
  end

  proj.save
  puts "✅ Patched #{proj_path}"
end

# 1) Patch Pods project (covers RCT-Folly, DoubleConversion, etc.)
patch_project(PODS_PROJ_PATH)

# 2) Patch app project target (monGARS)
patch_project(APP_PROJ_PATH, target_name: 'monGARS')
