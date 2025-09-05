#!/usr/bin/env ruby
# Patch Pods + app project to compile cleanly with iOS 18 libc++:
# - Force C++20
# - Re-enable removed typedef macros (e.g., ::FILE) for Folly/RCT-Folly

require 'xcodeproj'

IOS_DIR = File.expand_path(File.join(__dir__, '..', '..', 'ios'))
PODS_PROJ_PATH = File.join(IOS_DIR, 'Pods', 'Pods.xcodeproj')
APP_PROJ_PATH  = File.join(IOS_DIR, 'monGARS.xcodeproj')

CPP_MACRO = '-D_LIBCPP_ENABLE_CXX20_REMOVED_TYPEDEF_MACROS'
CXX_STD   = 'gnu++20'

def normalize_cxx_std(current)
  return CXX_STD unless current.is_a?(String)
  if current =~ /(?:c\+\+|gnu\+\+)(\d{2})/
    ver = Regexp.last_match(1).to_i
    ver >= 20 ? current : CXX_STD
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

      flags = bs['OTHER_CPLUSPLUSFLAGS']
      flags = flags.nil? || flags.empty? ? '$(inherited)' : (flags.is_a?(Array) ? flags.join(' ') : flags)
      flags = "#{flags} #{CPP_MACRO}" unless flags.include?(CPP_MACRO)
      bs['OTHER_CPLUSPLUSFLAGS'] = flags.strip

      bs['CLANG_CXX_LANGUAGE_STANDARD'] = normalize_cxx_std(bs['CLANG_CXX_LANGUAGE_STANDARD'])

      bs['GCC_C_LANGUAGE_STANDARD'] = (bs['GCC_C_LANGUAGE_STANDARD'] || 'gnu11')
    end
  end
  proj.save
  puts "✅ Patched #{proj_path}"
end

patch_project(PODS_PROJ_PATH)                     # all Pods (covers RCT-Folly)
patch_project(APP_PROJ_PATH, target_name: 'monGARS')
