#!/usr/bin/env ruby
# Purpose: Patch Pods + app project with safe C++ flags for libc++ C++23 removals
# - Fix Folly / RCT-Folly includes that still use ::FILE by re-enabling old typedef macros
# - Ensure C++20 across all native targets so RN / Folly compile cleanly

require 'xcodeproj'

IOS_DIR = File.expand_path(File.join(__dir__, '..', '..', 'ios'))
PODS_PROJ_PATH = File.join(IOS_DIR, 'Pods', 'Pods.xcodeproj')
APP_PROJ_PATH  = File.join(IOS_DIR, 'monGARS.xcodeproj')

CPP_MACRO = '-D_LIBCPP_ENABLE_CXX20_REMOVED_TYPEDEF_MACROS'
CXX_STD   = 'gnu++20'

def patch_project(proj_path, targets_filter: nil)
  unless File.exist?(proj_path)
    puts "⚠️  Skipping missing project: #{proj_path}"
    return
  end

  proj = Xcodeproj::Project.open(proj_path)
  proj.targets.each do |t|
    next if targets_filter && !targets_filter.call(t)

    t.build_configurations.each do |cfg|
      bs = cfg.build_settings

      # OTHER_CPLUSPLUSFLAGS
      flags = bs['OTHER_CPLUSPLUSFLAGS']
      if flags.nil? || flags.empty?
        flags = '$(inherited)'
      elsif flags.is_a?(Array)
        flags = flags.join(' ')
      end
      unless flags.include?(CPP_MACRO)
        flags = "#{flags} #{CPP_MACRO}"
      end
      bs['OTHER_CPLUSPLUSFLAGS'] = flags.strip

      # CLANG_CXX_LANGUAGE_STANDARD
      bs['CLANG_CXX_LANGUAGE_STANDARD'] = CxxStdNormalize(bs['CLANG_CXX_LANGUAGE_STANDARD'] || CXX_STD)

      # Also help some pods that set C++17 explicitly
      if (bs['GCC_C_LANGUAGE_STANDARD'] || '').empty?
        bs['GCC_C_LANGUAGE_STANDARD'] = 'gnu11'
      end
    end
  end

  proj.save
  puts "✅ Patched #{proj_path}"
end

# normalize helper
def CxxStdNormalize(current)
  # Always promote to gnu++20 unless already >= gnu++20
  return 'gnu++20' if current !~ /(?:c\+\+|gnu\+\+)(\d{2})/
  ver = current[/(\d{2})/, 1].to_i
  ver >= 20 ? current : 'gnu++20'
end

# 1) Patch Pods project (all targets incl. Folly/RCT-Folly)
patch_project(PODS_PROJ_PATH)

# 2) Patch app project target (monGARS) as well
patch_project(APP_PROJ_PATH, targets_filter: ->(t) { t.name == 'monGARS' })
