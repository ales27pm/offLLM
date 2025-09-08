#!/usr/bin/env bash
set -euo pipefail

# ---------- Global logging (always captured) ----------
mkdir -p build
# Capture EVERYTHING (stdout+stderr) into build/bootstrap.log while also printing to console
exec > >(tee -a "build/bootstrap.log") 2>&1
set -x

# ---------- Env & defaults ----------
SCHEME="${SCHEME:-monGARS}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-build}"

echo "SCHEME=$SCHEME"
echo "CONFIGURATION=$CONFIGURATION"
echo "BUILD_DIR=$BUILD_DIR"

mkdir -p "scripts/ci" "ios" "$BUILD_DIR"

# ---------- Seed XcodeGen if missing ----------
if [ ! -f ios/project.yml ]; then
  echo "Seeding ios/project.yml"
  cat > ios/project.yml <<'YML'
name: monGARS
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    iOS: "18.0"
targets:
  monGARS:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes:
          - ios/**/*
          - android/**/*
          - node_modules/**/*
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.example.monGARS
      INFOPLIST_FILE: ios/Info.plist
YML
fi

if [ ! -f ios/Info.plist ]; then
  echo "Seeding ios/Info.plist"
  cat > ios/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>monGARS</string>
  <key>CFBundleIdentifier</key><string>com.example.monGARS</string>
  <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>UILaunchStoryboardName</key><string></string>
  <key>UIMainStoryboardFile</key><string></string>
  <key>UISupportedInterfaceOrientations</key>
  <array><string>UIInterfaceOrientationPortrait</string></array>
  <key>LSRequiresIPhoneOS</key><true/>
</dict>
</plist>
PLIST
fi

# ---------- Generate Xcode project ----------
if [ -f ios/project.yml ]; then
  (cd ios && xcodegen generate)
fi

# ---------- Write hardened Podfile (RN + Hermes + bridging headers) ----------
cat > ios/Podfile <<'RUBY'
platform :ios, '18.0'
ENV['RCT_NEW_ARCH_ENABLED'] = '1' # Fabric/Turbo

require_relative '../node_modules/react-native/scripts/react_native_pods'

install! 'cocoapods',
  generate_multiple_pod_projects: true,
  disable_input_output_paths: true,
  warn_for_multiple_pod_sources: true

# Discover project (works for XcodeGen output too)
project_candidates = Dir['*.xcodeproj'] + Dir['**/*.xcodeproj']
project_path = project_candidates.first or raise "No .xcodeproj found near Podfile (#{__dir__})"
puts "Using Xcode project at: #{project_path}"
project project_path, 'Debug' => :debug, 'Release' => :release

app_target = File.basename(project_path, '.xcodeproj')
USE_FLIPPER = ENV['USE_FLIPPER'] == '1'
NEW_ARCH_ENABLED = ENV['RCT_NEW_ARCH_ENABLED'] == '1'

target app_target do
  use_frameworks! linkage: :static

  config = (use_native_modules! rescue nil) || {}
  react_native_path = config[:reactNativePath] || File.expand_path('../node_modules/react-native', __dir__)

  use_react_native!(
    path: react_native_path,
    hermes_enabled: true,
    new_arch_enabled: true,
    fabric_enabled: NEW_ARCH_ENABLED,
    app_path: "#{Pod::Config.instance.installation_root}/.."
  )

  # Ensure <react/bridging/*.h> resolves
  pod 'ReactCommon/turbomodule/bridging', path: "#{react_native_path}/ReactCommon"

  use_flipper!({ 'Flipper' => '0.203.0' }) if USE_FLIPPER
end

FORBIDDEN_HERMES_MARKERS = ['replace hermes','replace hermes for the right configuration','[hermes]'].freeze

def strip_hermes_replacement_scripts!(project)
  project.targets.each do |t|
    t.build_phases.select { |p|
      p.isa == 'PBXShellScriptBuildPhase' &&
      FORBIDDEN_HERMES_MARKERS.any? { |m|
        (p.name || '').downcase.include?(m) || (p.shell_script || '').downcase.include?(m)
      }
    }.each do |p|
      t.build_phases.delete(p)
      p.remove_from_project
    end
  end
  project.save
end

def pods_projects_for(installer)
  pods = [installer.pods_project]
  pods.concat(Array(installer.generated_projects)) if installer.respond_to?(:generated_projects)
  pods.compact
end

def user_projects_for(installer)
  installer.aggregate_targets.map(&:user_project).compact.uniq { |p| p.path.to_s }
end

def scrub_cp_filelists_from_target(target)
  target.build_phases.each do |phase|
    next unless phase.respond_to?(:name)
    next unless phase.name&.include?('[CP]')
    begin
      phase.input_paths = [] if phase.respond_to?(:input_paths=)
      phase.output_paths = [] if phase.respond_to?(:output_paths=)
      phase.input_file_list_paths = [] if phase.respond_to?(:input_file_list_paths=)
      phase.output_file_list_paths = [] if phase.respond_to?(:output_file_list_paths=)
    rescue => e
      puts "WARN: Skipping scrub for phase #{phase.name}: #{e}"
    end
  end
end

post_install do |installer|
  react_native_post_install(installer) if defined?(react_native_post_install)

  pods_projects = pods_projects_for(installer)
  user_projects = user_projects_for(installer)
  all_projects  = (pods_projects + user_projects).uniq { |p| p.path.to_s }

  min_target = Gem::Version.new('18.0')

  all_projects.each do |proj|
    strip_hermes_replacement_scripts!(proj)

    proj.targets.each do |t|
      scrub_cp_filelists_from_target(t)

      t.build_configurations.each do |cfg|
        bs = cfg.build_settings

        # Robust header resolution for RN new-arch + libc++
        bs['USE_HEADERMAP'] = 'YES'
        bs['HEADER_SEARCH_PATHS'] = [
          '$(inherited)',
          '$(PODS_ROOT)/Headers/Public/**',
          '$(PODS_ROOT)/Headers/Private/**',
          '$(PODS_CONFIGURATION_BUILD_DIR)/**',
          '$(PODS_ROOT)/Headers/Public/ReactCommon/react',
          '$(SDKROOT)/usr/include/c++/v1'
        ]
        bs['SYSTEM_HEADER_SEARCH_PATHS'] = '$(SDKROOT)/usr/include'

        # Allow non-modular includes in framework modules (RN pods)
        bs['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'

        # Allow Pods scripts to create header symlinks
        bs['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'

        # Swift previews off only for Debug, Release optimized
        if cfg.name.include?('Debug')
          bs['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
          bs['SWIFT_COMPILATION_MODE']   = 'singlefile'
        else
          bs['SWIFT_OPTIMIZATION_LEVEL'] ||= '-O'
        end

        # Non-fatal warnings; Folly safe path
        bs['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
        bs['OTHER_CFLAGS'] = [bs['OTHER_CFLAGS'], '$(inherited)', '-Wno-everything', '-DFOLLY_DISABLE_SIMD=1'].compact.join(' ').squeeze(' ')
        bs['OTHER_CPLUSPLUSFLAGS'] = [bs['OTHER_CPLUSPLUSFLAGS'], '$(inherited)', '-DFOLLY_DISABLE_SIMD=1'].compact.join(' ').squeeze(' ')

        # C/C++ toolchain stability
        bs['CLANG_CXX_LANGUAGE_STANDARD'] ||= 'gnu++17'
        bs['CLANG_CXX_LIBRARY']          ||= 'libc++'
        bs['GCC_C_LANGUAGE_STANDARD']    ||= 'gnu11'

        # Unify deployment target
        current = Gem::Version.new(bs['IPHONEOS_DEPLOYMENT_TARGET'] || '0')
        bs['IPHONEOS_DEPLOYMENT_TARGET'] = min_target.to_s if current < min_target

        bs['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
      end

      # Silence “[CP] … will run every build” warnings
      t.build_phases
        .select { |p| p.isa == 'PBXShellScriptBuildPhase' && p.name&.start_with?('[CP]') }
        .each do |run|
          if (run.input_paths || []).empty? && (run.output_paths || []).empty?
            run.always_out_of_date = '1' if run.respond_to?(:always_out_of_date=)
          end
        end
    end

    proj.save
  end

  # CI guard
  if ENV['CI']
    offending = []
    all_projects.each do |proj|
      proj.targets.each do |t|
        t.build_phases.select { |p| p.isa == 'PBXShellScriptBuildPhase' }.each do |phase|
          name = (phase.name || '').downcase
          body = (phase.shell_script || '').downcase
          if ['replace hermes','replace hermes for the right configuration','[hermes]'].any? { |m| name.include?(m) || body.include?(m) }
            offending << "#{proj.path.basename} :: #{t.name} :: #{phase.name}"
          end
        end
      end
    end
    raise "Forbidden Hermes script phase(s) found:\n  #{offending.join("\n  ")}" unless offending.empty?
  end
end

post_integrate do |installer|
  (pods_projects_for(installer) + user_projects_for(installer)).each do |proj|
    strip_hermes_replacement_scripts!(proj)
    proj.targets.each do |t|
      t.build_phases
        .select { |p| p.isa == 'PBXShellScriptBuildPhase' && p.name&.start_with?('[CP]') }
        .each do |run|
          if (run.input_paths || []).empty? && (run.output_paths || []).empty? && run.respond_to?(:always_out_of_date=)
            run.always_out_of_date = '1'
          end
        end
    end
    proj.save
  end
end
RUBY

# ---------- Clean caches & install pods ----------
rm -rf "$HOME/Library/Developer/Xcode/DerivedData" || true
(
  cd ios
  if [ -f Gemfile ]; then
    bundle install
    bundle exec pod cache clean --all || true
    bundle exec pod install --repo-update
  else
    pod cache clean --all || true
    pod install --repo-update
  fi
)

# ---------- Build ----------
SDK_PATH="$(xcrun --show-sdk-path --sdk iphoneos)"
xcodebuild \
  -workspace "ios/${SCHEME}.xcworkspace" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  -resultBundlePath "${BUILD_DIR}/${SCHEME}.xcresult" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO \
  OTHER_CFLAGS="-Wno-everything" \
  OTHER_CPLUSPLUSFLAGS="-nostdinc++ -isystem${SDK_PATH}/usr/include/c++/v1 -DFOLLY_DISABLE_SIMD=1" \
  OTHER_LDFLAGS="-lc++" \
  | tee "${BUILD_DIR}/xcodebuild.log"

# ---------- Export xcresult JSON (best-effort) ----------
if [ -d "${BUILD_DIR}/${SCHEME}.xcresult" ]; then
  xcrun xcresulttool get --path "${BUILD_DIR}/${SCHEME}.xcresult" --format json --legacy > "${BUILD_DIR}/${SCHEME}.xcresult.json" || true
fi

# ---------- Package unsigned IPA ----------
APP_DIR="${BUILD_DIR}/DerivedData/Build/Products/${CONFIGURATION}-iphoneos"
APP_PATH="${APP_DIR}/${SCHEME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ Not found: $APP_PATH"
  ls -la "$APP_DIR" || true
  exit 1
fi

rm -rf "${BUILD_DIR}/Payload"
mkdir -p "${BUILD_DIR}/Payload"
cp -R "$APP_PATH" "${BUILD_DIR}/Payload/"
( cd "${BUILD_DIR}" && /usr/bin/zip -qry monGARS-unsigned.ipa Payload )
( cd "$APP_DIR" && /usr/bin/zip -qry "$PWD/../../${SCHEME}.app.zip" "${SCHEME}.app" )

echo "✅ Done. IPA at ${BUILD_DIR}/monGARS-unsigned.ipa"
