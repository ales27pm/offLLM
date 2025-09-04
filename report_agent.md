## Build Diagnosis (Condensed)

- Errors: 1, Warnings: 41
- Signals: Hermes replacement script still found. PhaseScriptExecution failures present. Pods with too-low IPHONEOS_DEPLOYMENT_TARGET (e.g., 9.0).

### Next actions (high-level)
- Remove '[Hermes] Replace Hermes' script phases (Pods + user projects).
- Ensure ENABLE_USER_SCRIPT_SANDBOXING=NO and disable IO paths for [CP] scripts if using static pods.
- Force IPHONEOS_DEPLOYMENT_TARGET >= 12.0 in post_install for old pods.
- Clean SPM caches & re-resolve packages if you see 'Internal inconsistency error'.