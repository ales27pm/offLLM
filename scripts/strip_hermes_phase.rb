#!/usr/bin/env ruby
# Usage: ruby scripts/strip_hermes_phase.rb ios/Pods/Pods.xcodeproj ios/MyOfflineLLMApp.xcodeproj

require 'xcodeproj'

markers = [
  'Replace Hermes for the right configuration, if needed',
  'Replace Hermes'
]

def scrub_project(path, markers)
  project = Xcodeproj::Project.open(path)
  changed = false

  project.targets.each do |t|
    phases_to_delete = t.build_phases.select do |p|
      p.respond_to?(:name) && markers.any? { |m| p.name.to_s.include?(m) }
    end
    phases_to_delete.each do |p|
      t.build_phases.delete(p)
      changed = true
    end
  end

  project.save if changed
  changed
end

ARGV.each do |proj_path|
  if File.exist?(proj_path)
    changed = scrub_project(proj_path, markers)
    puts "[strip_hermes_phase] #{proj_path}: #{changed ? 'removed phases' : 'nothing to remove'}"
  else
    warn "[strip_hermes_phase] not found: #{proj_path}"
  end
end
