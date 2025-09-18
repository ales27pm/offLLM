# frozen_string_literal: true

# Full post-install hook: Clean duplicates, enforce single blueprint per spec
def fix_codegen_duplicates(pod_name, target)
  if pod_name == 'React-Codegen' || pod_name.include?('hermes-engine') || pod_name == 'ReactCommon'
    # Remove duplicate JSI specs
    generated_dir = File.join(target.name, 'build', 'generated', 'ios')
    Dir.glob(File.join(generated_dir, '**', '*JSI-generated.*')).each do |file|
      manual_stub = file.sub('-generated', '')
      next unless File.exist?(manual_stub)

      File.delete(file)
      puts "Cleaned duplicate: #{file}"
    end
  end

  # Enforce single AppSpec provider
  if target.name == 'monGARS'
    xcconfig_path =
      if target.respond_to?(:resolved_build_setting_path)
        target.resolved_build_setting_path('GCC_PREPROCESSOR_DEFINITIONS')
      end

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      definitions = Array(config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'])
      definitions << 'RCT_NEW_ARCH_ENABLED=1' unless definitions.include?('RCT_NEW_ARCH_ENABLED=1')
      unless definitions.include?('DISABLE_INPUT_OUTPUT_PATHS=YES')
        definitions << 'DISABLE_INPUT_OUTPUT_PATHS=YES' # Your existing file-list fix
      end
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = definitions
    end
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    fix_codegen_duplicates(target.name, target)
  end
end
