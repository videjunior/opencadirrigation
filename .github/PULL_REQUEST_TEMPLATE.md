**What this changes and why**

**How it was checked**
- [ ] `dart analyze lib test tool bin` reports no issue and the changed files are formatted (`dart format`)
- [ ] `flutter test` passes; a fixed defect has a test that fails without the fix
- [ ] Generated files rebuilt when their sources changed (`tool/build_worker.sh`, `dart run tool/gen_site.dart`, …)
- [ ] Visible texts go through the string table, with Portuguese, English and Spanish
- [ ] A new command, tool, menu item or dialog has its route for the AI assistant (`lib/app/ai/ai_coverage.dart`)
- [ ] No competing product is named (see the editorial rule in CONTRIBUTING.md)

Contributions are accepted under the MIT licence of the project.
