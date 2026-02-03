#!/usr/bin/env ruby

require 'xcodeproj'

project_path = File.expand_path('../Nami.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

# Remove existing test target if it exists
existing_target = project.targets.find { |t| t.name == 'NamiTests' }
if existing_target
  existing_target.remove_from_project
  puts "Removed existing NamiTests target"
end

# Remove existing test group if it exists
existing_group = project.main_group.groups.find { |g| g.name == 'NamiTests' }
if existing_group
  existing_group.remove_from_project
  puts "Removed existing NamiTests group"
end

# Get the main target
main_target = project.targets.find { |t| t.name == 'Nami' }
unless main_target
  puts "Error: Could not find Nami target"
  exit 1
end

# Create test target with explicit product name
test_target = project.new_target(:unit_test_bundle, 'NamiTests', :osx, '14.0')
test_target.product_name = 'NamiTests'

# Add dependency on main target
test_target.add_dependency(main_target)

# Create test group
test_group = project.main_group.new_group('NamiTests', 'NamiTests')

# Add test files
test_files_path = File.expand_path('../NamiTests', __dir__)
Dir.glob("#{test_files_path}/*.swift").each do |file|
  file_ref = test_group.new_file(file)
  test_target.source_build_phase.add_file_reference(file_ref)
end

# Configure build settings
test_target.build_configurations.each do |config|
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Nami.app/Contents/MacOS/Nami'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nami.NamiTests'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['INFOPLIST_FILE'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'
end

# Add NamiTests to scheme
scheme_path = "#{project_path}/xcshareddata/xcschemes/Nami.xcscheme"
if File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new(scheme_path)

  # Clear existing testables
  scheme.test_action.testables.clear

  # Add test target to test action
  test_ref = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  scheme.test_action.add_testable(test_ref)

  # Enable code coverage
  scheme.test_action.code_coverage_enabled = true

  scheme.save!
  puts "Updated Nami.xcscheme with test target and code coverage"
end

project.save
puts "Successfully added NamiTests target"
