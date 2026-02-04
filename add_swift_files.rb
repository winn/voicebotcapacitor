#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/vwinnv/github/voicebotcapacitor/ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the App group (where other Swift files are)
app_group = project.main_group['App'] || project.main_group.new_group('App')

# Files to add
files_to_add = [
  '/Users/vwinnv/github/voicebotcapacitor/ios/App/App/NativeContainerViewController.swift',
  '/Users/vwinnv/github/voicebotcapacitor/ios/App/App/SpeechRecognitionManager.swift',
  '/Users/vwinnv/github/voicebotcapacitor/ios/App/App/TextToSpeechManager.swift',
  '/Users/vwinnv/github/voicebotcapacitor/ios/App/App/SettingsViewController.swift'
]

files_to_add.each do |file_path|
  file_name = File.basename(file_path)

  # Check if file already exists in project
  existing_file = app_group.files.find { |f| f.path == file_name }

  if existing_file
    puts "#{file_name} already exists in project"
  else
    # Add file reference to the group
    file_ref = app_group.new_file(file_path)

    # Add file to the target's compile sources phase
    target.add_file_references([file_ref])

    puts "Added #{file_name} to project"
  end
end

# Save the project
project.save

puts "Project updated successfully!"
