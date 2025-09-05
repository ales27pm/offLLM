## Build Diagnosis (Condensed)

- Errors: 40, Warnings: 51
- Signals: No singular dominant failure; inspect errors & warnings.

### Next actions (high-level)
- Remove '[Hermes] Replace Hermes' script phases (Pods + user projects).
- Ensure ENABLE_USER_SCRIPT_SANDBOXING=NO and disable IO paths for [CP] scripts if using static pods.
- Force IPHONEOS_DEPLOYMENT_TARGET >= 12.0 in post_install for old pods.
- Clean SPM caches & re-resolve packages if you see 'Internal inconsistency error'.