# frozen_string_literal: true

# Full post-install hook helpers: Clean duplicates, enforce single blueprint per spec
module PostInstallHardeningHook
  module_function

  def apply(installer)
    installer.pods_project.targets.each do |target|
      fix_codegen_duplicates(target)
      enforce_mon_gars_definitions(target)
    end
  end

  def fix_codegen_duplicates(target)
    pod_name = target.name
    return unless pod_name == 'React-Codegen' || pod_name == 'ReactCommon' || pod_name.include?('hermes-engine')

    generated_dir = File.join(generated_root, pod_name)
    return unless Dir.exist?(generated_dir)

    Dir.glob(File.join(generated_dir, '**', '*JSI-generated.*')).each do |generated_file|
      manual_stub = generated_file.sub('-generated', '')
      next unless File.exist?(manual_stub)

      File.delete(generated_file)
      log "Cleaned duplicate: #{generated_file}"
    end
  end

  def enforce_mon_gars_definitions(target)
    return unless target.name == 'monGARS'

    target.build_configurations.each do |config|
      definitions = Array(config.build_settings['GCC_PREPROCESSOR_DEFINITIONS']).dup
      definitions = ['$(inherited)'] if definitions.empty?

      ensure_definition(definitions, 'RCT_NEW_ARCH_ENABLED=1')
      ensure_definition(definitions, 'DISABLE_INPUT_OUTPUT_PATHS=YES')

      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = definitions
    end
  end

  def ensure_definition(definitions, value)
    definitions << value unless definitions.include?(value)
  end

  def generated_root
    @generated_root ||= File.expand_path(File.join('build', 'generated', 'ios'), Pod::Config.instance.installation_root)
  end

  def log(message)
    if defined?(Pod::UI)
      Pod::UI.puts(message)
    else
      puts(message)
    end
  end
end
