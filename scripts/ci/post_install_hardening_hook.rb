#!/usr/bin/env ruby
# Harden Xcode projects post `pod install` without editing Podfile:
# - Raise too-low IPHONEOS_DEPLOYMENT_TARGET (<12.0) in Pods targets
# - Disable ENABLE_USER_SCRIPT_SANDBOXING for CI stability
# - Clear CocoaPods [CP] script IO file lists (safer with static pods)
# - Remove stray Hermes "Replace Hermes" phases in Pods + App projects

require 'pathname'
require 'xcodeproj'

# Resolve repository root relative to this script
ROOT = Pathname.new(__dir__).parent.parent
IOS_DIR = ROOT + 'ios'
PODS_XCODEPROJ = IOS_DIR + 'Pods/Pods.xcodeproj'
APP_XCODEPROJ  = IOS_DIR + 'MyOfflineLLMApp.xcodeproj'

def info(msg)  $stdout.puts "[post_install_hardening] #{msg}" end
def warn(msg)  $stderr.puts "[post_install_hardening][WARN] #{msg}" end

def raise_deployment_target_and_disable_sandboxing(proj)
  proj.targets.each do |t|
    t.build_configurations.each do |cfg|
      # Lift ancient pod settings (9.0/10.x/11.x) to at least 12.0
      cur = (cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '0').to_s
      if cur.empty? || cur < '12.0'
        cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
      # Disable user script sandboxing for CI ([CP] phases + static pods)
      cfg.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end

def clear_cp_io_file_lists_and_remove_hermes(phases_container)
  phases_container.targets.each do |t|
    t.build_phases.each do |phase|
      next unless phase.isa == 'PBXShellScriptBuildPhase'
      name = (phase.name || '').to_s
      script = (phase.shell_script || '').to_s
      # Clear CP IO file lists
      if phase.respond_to?(:input_file_list_paths)
        phase.input_file_list_paths = []
      end
      if phase.respond_to?(:output_file_list_paths)
        phase.output_file_list_paths = []
      end
      # Remove stray Hermes "Replace Hermes" phases if present
      if name.include?('Replace Hermes') || name.include?('[Hermes]') || script.include?('Replace Hermes')
        t.build_phases.delete(phase)
        info "Removed Hermes replacement phase from target #{t.name}"
      end
    end
  end
end

projects = []
if File.exist?(PODS_XCODEPROJ.to_s)
  projects << Xcodeproj::Project.open(PODS_XCODEPROJ.to_s)
else
  warn "Pods project not found at #{PODS_XCODEPROJ}"
end
if File.exist?(APP_XCODEPROJ.to_s)
  projects << Xcodeproj::Project.open(APP_XCODEPROJ.to_s)
else
  warn "App project not found at #{APP_XCODEPROJ}"
end

projects.each do |proj|
  info "Hardening #{proj.path}"
  raise_deployment_target_and_disable_sandboxing(proj)
  clear_cp_io_file_lists_and_remove_hermes(proj)
  proj.save
end

info "Done."

