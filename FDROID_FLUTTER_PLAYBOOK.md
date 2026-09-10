# 🚀 F-Droid Flutter Release & Compliance Playbook

This document serves as the authoritative blueprint and knowledge base for launching Flutter applications on F-Droid with 100% compliance on the first attempt.

---

## 📋 The First-Go Compliance Checklist

### 1. Pinned Flutter Version & CI Alignment
- [ ] **`.github/workflows/release.yml`**: Must specify an explicit Flutter SDK version string instead of channel tags like `stable`.
  ```yaml
        - name: Set up Flutter
          uses: subosito/flutter-action@v2
          with:
            flutter-version: '3.41.4' # Pinned version string
            cache: true
  ```
- [ ] **F-Droid Build Recipe (`prebuild`)**: Extract the version dynamically from `.github/workflows/release.yml`:
  ```yaml
      prebuild:
        - flutterVersion=$(sed -n -E "s/.*flutter-version:\ '(.*)'/\1/p" .github/workflows/release.yml)
        - '[[ $flutterVersion ]]'
        - git -C $$flutter$$ checkout -f $flutterVersion
        - export PUB_CACHE=$(pwd)/.pub-cache
        - $$flutter$$/bin/flutter config --no-analytics
        - $$flutter$$/bin/flutter pub get --enforce-lockfile
      scandelete:
        - .pub-cache
      build:
        - export PUB_CACHE=$(pwd)/.pub-cache
        - $$flutter$$/bin/flutter build apk --release
  ```

---

### 2. AGP 8+ Legacy Plugin Namespace Fallback
- [ ] **`android/build.gradle.kts`**: Older pub.dev packages miss the `namespace` field in their `build.gradle`, causing AGP 8+ builds on F-Droid to fail with `Namespace not specified`.
- [ ] **Root Build Gradle Fix**: Add this subprojects fallback block to `android/build.gradle.kts`:
  ```kotlin
  fun configureNamespace(p: Project) {
      if (p.plugins.hasPlugin("com.android.library")) {
          val androidExt = p.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
          if (androidExt != null && androidExt.namespace == null) {
              androidExt.namespace = "com." + rootProject.name + ".plugin." + p.name.replace("-", "_")
          }
      }
  }

  subprojects {
      if (state.executed) {
          configureNamespace(this)
      } else {
          afterEvaluate { configureNamespace(this) }
      }
  }
  ```

---

### 3. F-Droid YAML Syntax & Formatting Rules (`fdroid rewritemeta`)
- [ ] **No Quotes on Semantic Versions**: `versionName` and `CurrentVersion` MUST NOT be wrapped in quotes.
  - ❌ `versionName: '1.0.0'`
  - ✅ `versionName: 1.0.0`
- [ ] **Full 40-Character Commit Hash**: The `commit:` field MUST use the exact full Git commit SHA, NOT tags or branch names.
  - ❌ `commit: v1.0.0`
  - ✅ `commit: 004f84e3a0b5f137eb13c32e098fe11b8b64e0ee`
- [ ] **No Duplicate Summary/Description**: Do NOT write `Summary` or `Description` fields inside the `.yml` recipe file if using Fastlane.

---

### 4. Fastlane Metadata Structure
- [ ] **Folder Hierarchy**: Store all metadata under `fastlane/metadata/android/en-US/`:
  - `title.txt`
  - `short_description.txt`
  - `full_description.txt`
  - `changelogs/<versionCode>.txt` (e.g. `1.txt`, `2.txt`)
  - `images/phoneScreenshots/`

---

## 🎯 Skill Creation Roadmap
Upon official merge and publishing on F-Droid, this playbook will be packaged into a custom reusable Skill under:
`~/.gemini/config/skills/fdroid-flutter-release/SKILL.md`

This will allow Antigravity to run an automated pre-flight audit tool across any new Flutter repository and make it F-Droid compliant in one click!
