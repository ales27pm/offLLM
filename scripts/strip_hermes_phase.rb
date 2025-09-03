#!/usr/bin/env ruby
require 'xcodeproj'

MARKERS = ['replace hermes'].freeze

def scrub_project(path)
  project = Xcodeproj::Project.open(path)
  changed = false
  project.targets.each do |t|
    t.build_phases.select do |p|
      p.isa == 'PBXShellScriptBuildPhase' &&
        MARKERS.any? { |m| ((p.name || '') + (p.shell_script || '')).downcase.include?(m) }
    end.each do |p|
      t.build_phases.delete(p)
      changed = true
    end
  end
  project.save if changed
  puts "[strip_hermes_phase] #{File.basename(path)}: #{changed ? 'removed phases' : 'nothing to remove'}"
end

ARGV.each do |proj|
  if File.exist?(proj)
    scrub_project(proj)
  else
    warn "[strip_hermes_phase] not found: #{proj}"
  end
end
