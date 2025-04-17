set filename "/home/raju.sharma/Downloads/GUI_Programming/2024f-ma411m-end/graders1/kvs/Q-01/build/activity.log"

# Open and read the entire content
set fileContent [read [open $filename r]]

# Open file for appending and write the content again with a newline
set fileId [open $filename a]
puts $fileId "\n$fileContent"
close $fileId

