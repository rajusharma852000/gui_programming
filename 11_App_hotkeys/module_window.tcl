package require Tk


set current_folder [lindex $argv 0]  ;# Get current folder from command-line arguments
set module_folder [lindex $argv 1]   ;# Get the module/question name

# Define config directory and file path
set config_dir "~/.config/my_app";
set last_theme_file "$config_dir/last_theme.txt";
set theme "dark";
set switchTOTheme "Light";
set last_call_time 0;

# Create config directory if it doesn't exists
if { ![file exists $config_dir]} {
    file mkdir $config_dir;
}

# Load last theme rom file (if it exists)
if { [file exists $last_theme_file]} {
    set fp [open $last_theme_file r]
    gets $fp theme;
    close $fp
    
    if {$theme eq "dark" } {
        set switchToTheme "Light";
    } else {
        set switchToTheme "Dark";
    }
} 

if { $theme ne "dark" && $theme ne "light" } {
    set theme "dark";
    set switchToTheme "Light";
}

# Set up the current directory
set curr_dir [file join $current_folder $module_folder];
set main_file "$curr_dir/main.tex";
set selected_position "T";
set ::comment_timer_id "";
set ::marks_timer_id "";
set has_unsaved_changes "false";
set error_message "";
set current_file ""

#**************
#Radio button
set choice "roll";
set tex_list { };
set current_index 0;
#**************

#**************
#pane
set selected_pane 1;
set max_panes 1;
set pane_values {1};
set mainFileContent "";
set pane1FileContent "";
set pane2FileContent "";

#***************

#***************
# Last 10 Comments
set user_latest_comment "";
set user_commentDropdownVisible false;
#***************


# Create tex_list from TexFileSequence.csv file
proc sort_tex_list {} {
    global originalOptions;
    global tex_list choice curr_dir

    # Read the data from the CSV file
    set filename "$curr_dir/.TexFileSequence.csv"
    set data {}

    if {[file exists $filename]} {
        set fp [open $filename r]
        while {[gets $fp line] >= 0} {
            
            # Remove spaces and split by comma
            regsub -all " " $line "" line
            if {[string index $line 0] eq "\""} {
		set line [string range $line 1 end]
 	    }
	    if {[string index $line end] eq "\""} {
		set line [string range $line 0 end-1]
	    }
            set parts [split $line ","]
            
            set roll [lindex $parts 0]
            set size 10 ;# Default size

            if {[llength $parts] == 2 && [string length [lindex $parts 1]] > 0} {
                set size [lindex $parts 1]
            }
            

            # Accept roll as string, size as float or int
            lappend data [list $roll $size];
            
        }
        close $fp
    } else {
        show_popup "fail" "File not found: $filename";
        return;
    }
    
    

    # Sort the data
    if { $choice eq "roll" } {
        # sort by roll number
        set sorted_data [lsort -index 0 $data];
        
    } elseif { $choice eq "size" } {
        # sort by size 
        set sorted_data [lsort -index 1 $data];
    } 

    # Extract roll numbers from sorted data
    set tex_list {}
    foreach item $sorted_data {
        lappend tex_list [lindex $item 0]
    }
    
    set originalOptions $tex_list;
}


#***************
#ID
sort_tex_list
set originalOptions $tex_list
set filteredOptions $originalOptions
set searchQuery [lindex $filteredOptions 0]
set lastQuery [lindex $filteredOptions 0]
set dropdownVisible false

#***************

#****************
# time spent 
set start_time [clock seconds];
set total_time_spent 0;
set elapsed_time 0;
set sheets_checked 0;
set update_label_timer_id "";


#*****************


proc create_time_spent_file { } {
    global curr_dir tex_list;
    
    # Create build directory if doesn't exist already
    if {![file isdirectory "$curr_dir/build"]} {
        file mkdir build
    } 
    
    set filepath "$curr_dir/build/TimeSpent.csv";
    
    # Only create the file if it doesn't already exist
    if { ![file exists $filepath] } {
        set fp [open $filepath "w"]
        puts $fp "RollNumber,TimeSpent"  ;# Header row

        foreach roll $tex_list {
            puts $fp "$roll,0"
        }

        close $fp
    }
}


proc update_ui {} {
    
    #create variable: function call
    convert_tex_to_pdf	;
}

proc update_widget {tex_list current_index} {
	#Access global variables
        global searchQuery lastQuery
        
        set file_name [lindex $tex_list $current_index] 	;#get filename from list
        set searchQuery $file_name 
        set lastQuery $file_name				
	create_main
	update_pane          
        update_comment                                  	;# function call
        update_marks                                    	;# function call
         
	# Check if 'Previous' should be disabled (if at index 0)
	if {$current_index == 0} {
	    .nav.prev configure -state disabled
	} else {
	    .nav.prev configure -state normal
	}
	
	# Check if 'Next' should be disabled (if at last index)
	if {$current_index == [expr {[llength $tex_list] - 1}]} {
	    .nav.next configure -state disabled
	} else {
	    .nav.next configure -state normal
	}
}

proc is_error { } {
    global error_message;
    if { $error_message ne "" } {
         show_popup "fail" "Please fix all errors before proceding";
         #tk_messageBox -message "Please fix all errors before proceding" \
         #-icon error -title "Error";
         return "true";
    }
    return "false";
}

proc compare_files {file1 file2} {
    if {[catch {exec diff $file1 $file2} result]} {
        return "Yes"  ;# Files are different
    } else {
        return "No"   ;# Files are identical
    }
}

proc previous_tex {} {  
    # Declaring global variables
    global tex_list current_index has_unsaved_changes
    
    # if any error, do not allow moving backward
    if { [is_error] eq "true" } return;
    
    #save_changes => copy main.tex to curr_file.tex
    save_changes ;#function call
    
    # Make sure index is within the range
    if {$current_index > 0 } {
        #save time spent by user
        add_time_spent;
    
        # decrement index by 1
        incr current_index -1			

        #update widget
        show_popup "success" "Moved to previous file";
        update_widget $tex_list $current_index
        update_commentLogFile
        
        #update the time spent by user
        update_time_spent;
        
        # udpate ui
        after 1 update_ui	;# function call
            
    }
    
    #update the value 
    set has_unsaved_changes "false"
}

proc next_tex {} {
    # Declaring global variables
    global tex_list current_index  has_unsaved_changes curr_dir
    
    # if any error, do not allow moving backward
    if { [is_error] eq "true" } return;
    
    #save_changes => copy main.tex to curr_file.tex
    save_changes ;#function call
    
    # Make sure index is within the range
    if {$current_index < [expr {[llength $tex_list] - 1}] } {
        #save time spent by user
        add_time_spent;
        update_time_spent
    
        # increment index by +1
        incr current_index 1;
        
        #update widget
        show_popup "success" "Moved to next file";
        update_widget $tex_list $current_index
        update_commentLogFile
        
        #update the time spent by user
        update_time_spent;
        
        # udpate ui
        after 1 update_ui	;# function call
    }
    
    #update the value 
    set has_unsaved_changes "false"
}


proc add_time_spent { } {
    global start_time curr_dir lastQuery;
    
    set end_time [clock seconds];
    set time_spent [expr {$end_time - $start_time}];
    set start_time $end_time;
    
    set filepath "$curr_dir/build/TimeSpent.csv";
   
    
    # Read existing file lines
    set fp [open $filepath "r"]
    set lines [split [read $fp] "\n"]
    close $fp

    # Prepare updated list
    set updated_lines {}
    foreach line $lines {
        if {$line eq ""} continue ;# skip empty lines
        lassign [split $line ","] roll stored_time

        if {$roll eq "RollNumber"} {
            lappend updated_lines $line ;# keep header
        } elseif {$roll eq $lastQuery} {
            set new_time [expr {$stored_time + $time_spent}]
            lappend updated_lines "$roll,$new_time"
        } else {
            lappend updated_lines "$roll,$stored_time"
        }
    }

    # Write back the updated content
    set fp [open $filepath "w"]
    foreach line $updated_lines {
        puts $fp $line
    }
    close $fp
    
}

proc update_time_spent { } {
    global curr_dir start_time lastQuery total_time_spent elapsed_time sheets_checked;
    
    set filepath "$curr_dir/build/TimeSpent.csv";
    set sheets_checked 0;
    set total_time_spent 0;
    
    # Read existing file lines
    set fp [open $filepath "r"]
    set lines [split [read $fp] "\n"]
    close $fp

    # Prepare updated list  
    foreach line $lines {
        if {$line eq ""} continue ;# skip empty lines
        lassign [split $line ","] roll stored_time
        
	#fine elapsed time
	if {$roll eq "RollNumber"} {
            continue;
        }
        
        #find total time
        set total_time_spent [expr {int($total_time_spent) + int($stored_time)}];
	
        if {$roll eq $lastQuery} {
            puts "lastQuery: $lastQuery"
            puts "elapsed_t: $stored_time";
            set elapsed_time $stored_time;
        }
        
        # find sheets checked
        if {$stored_time > 10 } {
            set sheets_checked [expr {int($sheets_checked) + 1}];
        }
    }
    puts "sh_checked: $sheets_checked";
    
    #function call
    update_label_timer_every_min;
    
}

proc format_time {seconds} {
    set hrs [format "%02d" [expr {$seconds / 3600}]]
    set mins [format "%02d" [expr {($seconds % 3600) / 60}]]
    return "$hrs:$mins"
}

proc update_label_timer_every_min {} {
    global total_time_spent elapsed_time sheets_checked start_time update_label_timer_id

    # Cancel previous timer if it exists
    if {[info exists update_label_timer_id] && $update_label_timer_id ne ""} {
        after cancel $update_label_timer_id
    }

    # Calculate time difference
    set current_time [clock seconds]
    set time_spent [expr {$current_time - $start_time}]

    # Update sheets checked if condition met
    set val0 [expr {$elapsed_time + $time_spent}]

    # Update time spent on current sheet
    set val2 [format_time $val0]

    # Update total time spent
    set val3 [expr {$total_time_spent + $time_spent}]
    set val3 [format_time $val3]

    # Update label values
    .sub_right_comment.label4 configure -text $sheets_checked
    .sub_right_comment.label5 configure -text $val2
    .sub_right_comment.label6 configure -text $val3

    # Reschedule function after 1 minute
    set update_label_timer_id [after 60000 update_label_timer_every_min]
}

   
proc run_pdflatex { main_tex } {
    global curr_dir error_message;
    
    # reset the error_message
    set error_message "";
    
    # Store the path to pwd
    set present_dir [pwd]
    
    # Change directory to curr_dir and compile.tex file asynchronously
    cd $curr_dir
    
    # Create build directory if doesn't exist already
    if {![file isdirectory "build"]} {
        file mkdir build
    } 
    
     # Use catch to handle errors safely
    if { [catch {exec pdflatex -file-line-error -interaction=nonstopmode -output-directory=build $main_tex > /dev/null &} result] } {
        set error_message $result;
        cd $present_dir
        return;
    } 
    
    # check for errors in log file
    after 500 check_For_Error_In_Log_File
    
    #change directory back to present_dir
    cd $present_dir
}

proc check_For_Error_In_Log_File { } {
    global curr_dir error_message

    # Store the path to pwd
    set present_dir [pwd]
    
    # Change directory to curr_dir and compile .tex file asynchronously
    cd $curr_dir
    
    # Return if file doesn't exist
    if {![file exist "build/main.log"]} {
        return;
    }
    
    # Open the log file
    set fileID [open "build/main.log" r]
    set logContent [read $fileID]
    close $fileID
    
    # Initialize variables
    set error_message ""
    set first_occurrence true
    
    # Process each line
    foreach line [split $logContent "\n"] {
        # Check for occurrences of "./main.tex" or lines starting with "!"
        if {[string match "*./main.tex*" $line]} {
            if {$first_occurrence} {
                # Ignore the first occurrence of "./main.tex"
                set first_occurrence false
            } else {
                # Collect subsequent occurrences of "./main.tex"
                append error_message "$line\n"
            }
        } elseif {[string match "!*" $line]} {
            # Collect all lines starting with "!"
            append error_message "$line\n"
        }
    }
    
    # Update UI and handle errors
    if {$error_message != ""} {
        enable_SeeErros_Button ;# function call
        cd $present_dir
        return
    } else {
       disable_SeeErrors_Button ;# function call
    }
    
    # Change directory back to present_dir
    cd $present_dir
}

    
    
  

# converts .tex into .pdf
proc convert_tex_to_pdf { } {
    global curr_dir
    
    # string main.tex
    set main_tex "main.tex"
    
    # Construct full path to the .tex file
    set tex_file "$curr_dir/$main_tex"
    
    # Make sure main.tex exist	
    if {![file exists $tex_file]} {
        tk_messageBox -message "Error: File not found!\n$tex_file" -icon error  -title "Error"
        return
    }
    
    # function call: Compile the tex into pdf
    run_pdflatex $main_tex
}


# read content from file
proc read_from_file { filename } {
    set fp [open $filename "r"];
    set fileContent [read $fp];
    close $fp;
    
    return $fileContent;
}


# write content to file
proc write_to_file { filename modifiedContent} {
    set fp [open $filename "w"]
    puts -nonewline $fp $modifiedContent
    close $fp;
}

# find index of first occurence of "searchString" in "fileContent"
proc find_first_match_index { fileContent  searchString } {
    set start_index [string first $searchString $fileContent]
    if { $start_index == -1 } {
        #puts "No match found for: $searchString";
        show_popup "fail" "No match found for: $searchString";
        return -1;
    }
    return $start_index;
}



# Define the add_comment function
proc add_comment { new_comment} {
    # Access global variables
    global selected_position main_file has_unsaved_changes;
    global selected_pane pane1FileContent pane2FileContent mainFileContent;
    global user_latest_comment;
    
    #update the variable: user_latest_comment;
    set user_latest_comment $new_comment;
    
    #update the variable
    set has_unsaved_changes "true";
    
    # read file content
    set fileContent $mainFileContent;
    
     # getting matched pane content from read_pane function
    if { $selected_pane == 1 } {
        set paneContent $pane1FileContent;
    } else {
        set paneContent $pane2FileContent;
    }
    
    if { $paneContent eq "" }  return;
    
    
    # Locate the first occurrence of \putcomment[T, B, M, C]
    set start_index [find_first_match_index $paneContent "\\putcomment$selected_position"]
    if {$start_index == -1} return;

    # Extract the substring from that position
    set sub_input [string range $paneContent $start_index end]

    # Find the first occurrence of \nextcommandmarker after \putcomment
    set end_index [find_first_match_index $sub_input "\\nextcommandmarker"]
    if {$end_index == -1} return;

    # Extract only up to the first \nextcommandmarker
    set match_part [string range $sub_input 0 [expr {$end_index - 1}]]
    
    # Replace old_comment with new_comment i.e.
    # old_comment = \putcommentT{ Hello World}
    # new_comment = \putCommentT{ Hi autog}
    set modifiedContent [string replace $paneContent $start_index [expr {$start_index + $end_index}] "\\putcomment$selected_position\{$new_comment\}\\"]
    
    if { $selected_pane == 1 } {
        set pane1FileContent $modifiedContent;
    } else {
        set pane2FileContent $modifiedContent;
    }
    
    # Replace the matched pane content with the modified one in the entire file
    set modifiedFileContent [string map [list $paneContent $modifiedContent] $fileContent] 
    set mainFileContent $modifiedFileContent;
    
    # Open the file in write mode and write the modified content back
    write_to_file $main_file $modifiedFileContent;

    # Compile the tex file into PDF
    update_ui ;# Function call: update_ui 
    show_popup "success" "Comment updated";
}





#Modified till here
#*******************************************************************************************
#Need to be modified






proc add_marks { args } {
    # Access global variables
    global main_file has_unsaved_changes num_checkboxes;
    global selected_pane pane1FileContent pane2FileContent mainFileContent paneContent;
    
    set has_unsaved_changes "true" ;# update the variable
    set new_marks ""
    set sum 0
    
    
    #calculate the new value of putMarks and total marks of the student
    for {set i 0} {$i < $num_checkboxes} {incr i} {
	 set varName "cbVar$i"   ;# Create the variable name dynamically
	 global $varName         ;# Declare it as a global variable
	 
	 #Arguments are passed only if someone adds marks using marks entryField
	 if { [llength $args] > 0 } {
	     set new_marks  [lindex $args 0];
	     set $varName 0 ;#Unmark all the checkboxes
	 } else {
	     append new_marks "[set $varName]+" ;# Get the actual value
	     set sum [expr {$sum + [set $varName]}] ;# Get and add the actual value
	 }
    }
    
    #remove the trailing "+" only if checkboxes are used to enter marks
    if { ([llength $args] == 0) } {
        set new_marks [string range $new_marks 0 end-1]
	#Update the entry field
        .marks.entry delete 0 end;
        .marks.entry insert 0 $sum;
    }
    
    # Open the file in read mode and read its content
   set fileContent $mainFileContent;
   
   # getting matched pane content from read_pane function
    if { $selected_pane == 1 } {
        set paneContent $pane1FileContent;
    } else {
        set paneContent $pane2FileContent;
    }
    
     if { $paneContent eq "" } return;
   
   # determine putmarks position in main.tex (start_index & end_index )
    set start_index [find_first_match_index $paneContent "\\putmarks"];
    if { $start_index == -1 } return;
    set sub_input [string range $paneContent $start_index end]
    set end_index [find_first_match_index $sub_input "\}"];
    if { $end_index == -1 } return ;
    
    # Replace old_marks with new_marks i.e.
    # old_marks = \putmarks{2+4+0+0}
    # new_marks = \putmarks{2+0+4+4}
    set modifiedContent [string replace $paneContent $start_index [expr {$start_index + $end_index}] "\\putmarks\{$new_marks\}"]
    
    if { $selected_pane == 1 } {
        set pane1FileContent $modifiedContent;
    } else {
        set pane2FileContent $modifiedContent;
    }
    
     # Replace the "$paneContent" with the "$modifiedContent" in the entire file "$fileContent"
    set modifiedFileContent [string map [list $paneContent $modifiedContent] $fileContent] 
    
    # Update the content of "$mainFileContent" with the "$modifiedFileContent"
    set mainFileContent $modifiedFileContent; 
    
    # write the modified content back to the main.tex
    write_to_file $main_file $modifiedFileContent;
    
    # Compile the tex file into PDF
    update_ui ;# Function call: update_ui 
    show_popup "success" "Marks updated";
}



# Function to reset the timer
proc update_comment_timer {} {
    global has_unsaved_changes   ;# Access global variables
    set has_unsaved_changes "true" ;# update the variable
    
    set new_comment [.right_comment.text get 1.0 end-1c]
    
    after cancel $::comment_timer_id  ; # Cancel any existing timer
    set ::comment_timer_id [after 750 [list add_comment $new_comment]]  ; # Set a new timer for 0.750 seconds
}

# Function to reset the timer
proc update_marks_timer {} {
    global has_unsaved_changes   ;# Access global variables
    set has_unsaved_changes "true" ;# update the variable
    
    set new_marks [.marks.entry get ]
    if {$new_marks eq ""} {
        set new_marks "0";
    }
    
    # Check if new_marks is a valid floating point number
    if { ![string is double -strict $new_marks] } {
        #puts "Invalid entry: $new_marks is not a number";
        show_popup "fail" "Invalid entry: $new_marks is not a number";
        return;
    } 

    
    after cancel $::marks_timer_id  ; # Cancel any existing timer
    set ::marks_timer_id [after 750 [list add_marks $new_marks]]  ; # Set a new timer for 0.750 seconds
}

proc save_current_status {} {
    # Declaring global variables
    global  has_unsaved_changes curr_dir current_file;
    
    if { $has_unsaved_changes eq "true" } {
	set present_dir [pwd]
	cd $curr_dir
	set file1 "$current_file.tex"
	set result [compare_files $file1 main.tex]
	if { $result eq "Yes" } {
	    exec cp main.tex $file1
	}
	cd $present_dir
    }
    
}


proc create_main {} {
    global curr_dir main_file mainFileContent pane1FileContent pane2FileContent searchQuery;
    global current_file;
    set tex_file_name $searchQuery;
    set tex_file_path "$curr_dir/$tex_file_name.tex"
    set current_file $tex_file_name
    
    # Check if file exists
    if { ![file exist $tex_file_path] } {
        #puts "file $tex_file_name.tex doesn't exist";
        show_popup "fail" "File $tex_file_name.tex doesn't exist";
        return ;
    }
    exec cp $tex_file_path $main_file;
    set mainFileContent [read_from_file $main_file];
    set noOfPanes [count_panes];
    set pane1FileContent [read_pane 1]

    if { $noOfPanes == 2 } {
        set pane2FileContent [read_pane 2]
    }
    
}


# function to update comment
proc update_comment {args} {
    global selected_position selected_pane pane1FileContent pane2FileContent;# Access global variables
    
    
     # getting paneContent from read_pane function
    if { $selected_pane == 1 } {
        set paneContent $pane1FileContent;
    } else {
        set paneContent $pane2FileContent;
    }
    
    if { $paneContent eq "" } return;
    
    
    
    # Locate the first occurrence of \putcommentT or \putcommentB
    set start_index [find_first_match_index $paneContent "\\putcomment$selected_position"]
    if {$start_index == -1} {
        .right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
        #puts "No match found for: \\putcomment$selected_position."
        show_popup "fail" "No match found for: \\putcomment$selected_position";
        return
    }

    # Extract substring from that position
    set sub_input [string range $paneContent $start_index end]

    # Find the first occurrence of \nextcommandmarker after \putcomment
    set end_index [string first "\\nextcommandmarker" $sub_input]
    if {$end_index == -1} {
        .right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
        #puts "No match found for: \\nextcommandmarker."
        show_popup "fail" "No match found for: \\nextcommandmarker.";
        return
    }

    # Extract only up to the first \nextcommandmarker
    set match_part [string range $sub_input 0 [expr {$end_index - 1}]]
    
   
    # Initialize comment variables with default values
    set comment ""
    
    # Extract the comment part within { }
    if {[regexp "\\\\putcomment${selected_position}(.*)" $match_part -> comment]} {
        # Trim whitespaces
        set comment [string trim $comment]
        
        #remove the first "{" and last "}" characters
        set comment [string range $comment 1 end-1]

        # Update the text box with the extracted comment
        .right_comment.text delete 1.0 end  ; # Clear the existing content in the text box
        .right_comment.text insert end $comment  ; # Insert the new comment value
    } else {
        .right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
        #puts "No valid comment found."
        show_popup "fail" "No valid comment found.";
    }
    
    #highlight the syntax: function call
    highlight_latex_syntax;

}


#To determine the marks update source i.e. entryField or checkboxes
proc is_manual_marks_entry { markingScheme putmarks } {
    #If markingScheme and putMarks differ in length,
    #then marks were updated using marks entryField
    if { [llength $markingScheme] != [llength $putmarks] } {
        return "yes";
    } else {
        # Split markingScheme and putmarks by '+'
        set putmarks_list [split $putmarks "+"];
        set marks_list [split $markingScheme "+"];
        
        # Get the size of the marks list (both lists should have the same size here)
        set size [llength $marks_list]
        
        # Compare each element
        for {set i 0 } { $i < $size } { incr i } {
            if { ([lindex $putmarks_list $i] != [lindex $marks_list $i]) && ([lindex $putmarks_list $i] != 0) } {
                return "yes"  ;# Marks were updated manually
            }
        }
        
        # If all values match, return "no"	
        return "no";
    }
}


#*********************** update_marks modified  *******************************************

proc update_marks { } {
    global selected_pane pane1FileContent pane2FileContent;

   # getting matched pane content from read_pane function
    if { $selected_pane == 1 } {
        set paneContent $pane1FileContent;
    } else {
        set paneContent $pane2FileContent;
    }
    
    if { $paneContent eq "" } return;
    
    # find index of "\showmarkingscheme" in file
    set start_index [find_first_match_index $paneContent "\\showmarkingscheme"]
    if { $start_index == -1 } return;
    
    # sub_file ,containg data of $paneContent, start_index onward
    set sub_input [string range $paneContent $start_index end]
    set end_index [find_first_match_index $sub_input "\}"];    
    if { $end_index == -1 } return;
    set match_part [string range $sub_input 0 $end_index]
    
    #extract content between curly braces { }
    regexp "\\\\showmarkingscheme(.*)" $match_part -> markingScheme
    
    # Trim whitespaces
    set markingScheme [string trim $markingScheme]
    
    #remove the first "{" and last "}" brace
    set markingScheme [string range $markingScheme 1 end-1]
    
    # remove whitespaces between marks
    set markingScheme [regsub -all {\s+} $markingScheme ""];
    
    
    #if markingscheme is not present, disable the mark field
    if { $markingScheme eq "" } {
        .marks.entry delete 0 end;                    ;# delete the value
        .marks.entry configure -state disabled       ;# disable the button

        .marks.label configure -state disabled    ;# Change label color
    } else {
        .marks.entry configure -state normal          ;# make the state normal
        .marks.label configure -state normal     ;# Restore original color
    }


    # Extract putmarks values for checkbox selection
    set start_index [find_first_match_index $paneContent "\\putmarks"];
    if { $start_index == -1 } return;
    
    set sub_input [string range $paneContent $start_index end]
    set end_index [find_first_match_index $sub_input "\}"];
    if { $end_index == -1 } return ;
    set match_part [string range $sub_input 0 $end_index]
    
    regexp "\\\\putmarks(.*)" $match_part -> putmarks
    # Trim whitespaces
    set putmarks [string trim $putmarks]
    
    #remove the first "{" and last "}" brace
    set putmarks [string range $putmarks 1 end-1]
    
    # remove whitespaces between marks
    set putmarks [regsub -all {\s+} $putmarks ""];

    # Count number of checkboxes to be created
    global num_checkboxes 0; 
    set num_checkboxes [llength [split $markingScheme "+"]]  ;# number of checkboxes

    # Parse putmarks and marks strings into a lists
    set putmarks_list [split $putmarks +];
    set marks_list [split $markingScheme +];

    # Remove existing checkboxes
    foreach w [winfo children .marks] {
        if {[string match ".marks.cb*" $w]} {
            destroy $w
        }
    }
    
    set sum 0;
    # Create checkboxes dynamically
    for {set i 0} {$i < $num_checkboxes} {incr i} {
        set varName "cbVar$i"
	global $varName
	set $varName 0   ;# Default value is 0 (unchecked)

	# Get the value from marks_list
	set marks_val [lindex $marks_list $i] ; 
	
	#To determine the marks update source i.e. entryField or checkboxes
	if { [is_manual_marks_entry $markingScheme $putmarks] eq "yes" } {
	    # Code for when marks were updated via the entry field
	    set $varName 0 ;#Unmark the checkboxes
	    set sum [lindex $putmarks_list 0]
	} else {
	    # Code for when marks were updated via checkboxes
	    set putmark_val [lindex $putmarks_list $i] ; # Get the value from putmarks_list
            if { $putmark_val != "0" } {
	        set $varName $putmark_val  ;# Assign the actual value, 0 = unmarked, 0 < marked
	        set sum [expr {$sum + $putmark_val}] ;#update the sum
	    }
	}
	
	
        # Use variable reference (global scope)
        global theme
        if {$theme eq "dark" } {
            checkbutton .marks.cb$i -text "$marks_val" -variable $varName -onvalue $marks_val \
            -offvalue 0 -font myFont -command add_marks -background "#1A1A1A" \
            -foreground white -activebackground gray30 -activeforeground white \
            -highlightthickness 0 -selectcolor "#2A2A2A"
        } else {
            checkbutton .marks.cb$i -text "$marks_val" -variable $varName -onvalue $marks_val \
            -offvalue 0 -font myFont -command add_marks -background lightgray \
            -foreground black -activebackground gray30 -activeforeground white \
            -highlightthickness 1 -selectcolor white
        }
        grid .marks.cb$i -row 0 -column [expr {$i + 2}] -padx 3
    }
    
    .marks.entry delete 0 end ;#delete everything 
    .marks.entry insert 0 $sum ;#set the sum as marks
    
}


#*********************** update_marks modified  *******************************************





# Open tex
proc open_tex { } {
    global curr_dir searchQuery;
    
    set tex_file_name $searchQuery
    set tex_file_path "$curr_dir/$tex_file_name.tex"
    
    if {[file exists $tex_file_path]} {
        exec xdg-open $tex_file_path &  ;# For Linux
    } else {
        tk_messageBox -message "File not found: $tex_file_path" -icon error -title "Error"
    }
    
    show_popup "success" "Opened $searchQuery.tex";
}


# Preview button functionality
proc preview_tex {} {
    # Declaring global variables
    global curr_dir 
    
    # IF preview is already availabe, return
    if {![catch {exec pgrep -a evince} result]} {
        if {[string match "*main.pdf*" $result]} {
            show_popup "warning" "Preview is already available";
            return
        }
    } 
	
    # Function call: Compile main.tex into main.pdf
    convert_tex_to_pdf
    show_popup "success" "Preview generated";

    # Get generated PDF file
    set pdf_file "$curr_dir/build/main.pdf"
    after 500 [list check_pdf_generation $pdf_file];
}




proc enable_SeeErros_Button { } {
    # Configure the button
    .left_comment.myButton1 configure -fg "#ff2828" -activeforeground "#ff2828" -state normal
}

proc disable_SeeErrors_Button { } {
    # Configure the button
    .left_comment.myButton1 configure -fg black -activeforeground black -state disabled
}




# Check if the pdf was generated 
proc check_pdf_generation {pdf_file} {
    if {![file exists $pdf_file]} {
        return;
    }
    
    # Open the new PDF file with Evince
    exec evince $pdf_file &
}




proc kill_main_pdf {} {
    catch {
        set pid [exec pgrep -f "evince.*main.pdf"]
        if {[string is digit $pid]} {
            exec kill $pid
        }
    } result
}


# This is on_close funtion
# It asks the user whether he wants to save the changes he has made in the program
# Or want to close wihtout saving them
proc on_close {} {
    global has_unsaved_changes ;
    
    #save time spent by user
    add_time_spent;
    
    
    # IF no changes has been made, close the progam wihout taking re-confirmation 
    if { $has_unsaved_changes eq "false" } {
        kill_main_pdf;
        exit 0
    }

    set response [tk_messageBox -type yesnocancel -icon question -title "Exit" \
        -message "Do you want to save the changes before exiting?"]

    if {$response == "yes"} {
        save_changes  ;# Call your save function here
        kill_main_pdf;
        exit 0
    } elseif {$response == "no"} {
        kill_main_pdf
        exit 0
    } else {
        return  ;# Do nothing, user canceled exit
    }
}

proc save_changes {} {
    # Declaring global variables
    global has_unsaved_changes curr_dir searchQuery mainFileContent; 
    #update the original file, if we have unsaved changes
    if { $has_unsaved_changes eq "true" } {
         set present_dir [pwd]
         cd $curr_dir
         set file1 $searchQuery.tex
         set result [compare_files $file1 main.tex]
         if { $result eq "Yes" } {
             exec cp main.tex $file1
         } 
         cd $present_dir
    }
}




proc showError { } {
    global error_message searchQuery;
    if { $error_message eq "" } return ;
    set filename $searchQuery;
    
    set message "Compile command: \npdflatex -file-line-error -interaction=nonstopmode -output-directory=build $filename \n\n Errors: \n $error_message"
    tk_messageBox -message "$message" -icon error -title "Errors";

}



#*****************************************************************
# pane




#2. it count the panes it has
proc count_panes {} {
    global mainFileContent;
    set content $mainFileContent;

    # Count occurrences of \setpanenumber{n}
    set count 0
    foreach line [split $content "\n"] {
	if {[regexp {\\setpanenumber\{(\d+)\}} $line -> pane]} {
	    if {$pane > $count} {
	        set count $pane
	    }
	}
    }
    return $count
}
	
#2.	
proc generate_pane_list {max_panes} {
    set pane_list {}
    for {set i 1} {$i <= $max_panes} {incr i} {
	lappend pane_list $i
    }
    return $pane_list
}

#3. 
# function to read a particular pane
proc read_pane {pane_no} {
    global  mainFileContent;
    
     # Read file content
    set content $mainFileContent
    
     
     ## Improved regex to match the specific pane section
    set pane_regex "\\\\setpanenumber\\{$pane_no\\}\\s*(.*?)(?=\\\\setpanenumber\\{|\\\\end\\    {document\\}}|\\\\newpage)"
    
     #   Try to match the selected pane
    set match_list [regexp -inline -expanded $pane_regex $content]
    
    
    # If a match is found, extract the pane content
    if {[llength $match_list] > 0} {
	set paneContent [lindex $match_list 0]
    } else {
	#puts "Pane $default_pane not found! Check the LaTeX file structure."
	show_popup "fail" "Pane $default_pane not found! Check the LaTeX file structure.";
	return ""
    }
    
    return $paneContent
}


proc on_selected_tab_change {args } {
    # upate comment and marks as per the selected pane
    update_comment;
    update_marks;
}


# function to update pane
proc update_pane {} {
    global main_file selected_pane max_panes pane_values;
    # Get the max pane number
    set max_panes [count_panes]
    

    # Generate pane numbers from 1 to max_panes
    set pane_values [generate_pane_list $max_panes]
    .top.panel_combo configure -values $pane_values
    
    # if only one pane is present, update selected_pane value
    if { [llength $pane_values] == 1} {
	set selected_pane [lindex $pane_values 0];
    }
}



# Function to handle selection change
proc on_combobox_select {} {
    global current_index tex_list searchQuery;
    
    # if any error, do not allow moving from current page
    if { [is_error] eq "true" } return;

    # Get selected value from the combobox
    set selected_id $searchQuery

    # Save current page changes
    save_current_status;

    # save the time spent by user
    add_time_spent;
        
    # Find the index of the selected item
    set index [lsearch -exact $tex_list $selected_id]
    
    if {$index != -1} {
	set current_index $index
	go_to_page $selected_id  ;# Navigate to the selected page
    }
    
}



# Function to navigate to the selected page
proc go_to_page {page_id} {
   global current_index tex_list searchQuery;  
     
     
   if {$current_index < [llength $tex_list] && $current_index >= 0} {
        #update the time spent by user
        update_time_spent
   
	# update widget
	show_popup "success" "Switched to $searchQuery.tex";
	update_widget $tex_list $current_index;

	#updating UI
	update_ui					;# function call: update_ui
    }
	    

    #update the value 
    set has_unsaved_changes "false"
}









# Procedure to highlight LaTeX syntax
proc highlight_latex_syntax {} {
    set text_widget .right_comment.text

    # Remove old tags
    $text_widget tag remove latexCommand 1.0 end
    $text_widget tag remove mathMode 1.0 end

    # Get all content
    set content [$text_widget get 1.0 end]

    # Match LaTeX commands like \frac, \begin, \alpha
    set command_regex {\\[a-zA-Z]+}
    foreach match [regexp -all -inline -indices $command_regex $content] {
        foreach {start end} $match {
            set startIdx [$text_widget index "1.0 + $start chars"]
            set endIdx   [$text_widget index "1.0 + [expr {$end + 1}] chars"]
            $text_widget tag add latexCommand $startIdx $endIdx
        }
    }

    # Match math mode regions like $...$
    set math_regex {\$[^$]+\$}
    foreach match [regexp -all -inline -indices $math_regex $content] {
        foreach {start end} $match {
            set startIdx [$text_widget index "1.0 + $start chars"]
            set endIdx   [$text_widget index "1.0 + [expr {$end + 1}] chars"]
            $text_widget tag add mathMode $startIdx $endIdx
        }
    }
}





#***************************************************************
#ID Search Box

# Function to update the dropdown options based on search input
proc updateDropdown {} {
    global searchQuery originalOptions filteredOptions dropdownVisible

    set keyword [string tolower $searchQuery]

    set filteredOptions [list]
    foreach option $originalOptions {
        if {[string match "*$keyword*" [string tolower $option]] || $keyword eq ""} {
            lappend filteredOptions $option
        }
    }

    if {[llength $filteredOptions] == 0} {
        lappend filteredOptions "No result found"
    }

    .dropdownFrame.dropdown delete 0 end
    foreach option $filteredOptions {
        .dropdownFrame.dropdown insert end $option
    }

    # Adjust height between 1 and 5
    set numResults [llength $filteredOptions]
    if {$numResults < 10} {
        .dropdownFrame.dropdown configure -height $numResults
    } else {
        .dropdownFrame.dropdown configure -height 10
    }
     
     # Get position and size of .top1.search relative to root window
     set x [expr {[winfo x .top] + [winfo x .top1] + [winfo x .top1.search]}]
     set y [expr {[winfo y .top] + [winfo y .top1] + [winfo y .top1.search] + [winfo height .top1.search]}]
     set w [expr {[winfo width .top1.search] + 19 }]
    
     # Adjust height of listbox
    if {$keyword ne "" && ![winfo ismapped .dropdownFrame]} {
        place .dropdownFrame -x $x -y $y -width $w
        .top1.toggleButton configure -text "\u25B2" ;#up arrow
        set dropdownVisible true
    }
}

proc resetDropdown {} {
    global filteredOptions originalOptions

    # Reset search and filtered list
    set filteredOptions $originalOptions

    # Clear and repopulate the dropdown
    .dropdownFrame.dropdown delete 0 end
    foreach option $filteredOptions {
        .dropdownFrame.dropdown insert end $option
    }
}

# Function to toggle the visibility of the listbox
proc toggleDropdown {} {
    global dropdownVisible

    if {$dropdownVisible} {
        place forget .dropdownFrame
        .top1.toggleButton configure -text "\u25BC" ;# down arrow
        set dropdownVisible false
    } else {
        # Reset filtered list
        resetDropdown
	
	# Get position and size of .top1.search relative to root window
        set x [expr {[winfo x .top] + [winfo x .top1] + [winfo x .top1.search]}]
        set y [expr {[winfo y .top] + [winfo y .top1] + [winfo y .top1.search] + [winfo height .top1.search]}]
        set w [expr {[winfo width .top1.search] + 19 }]
        
	 # Adjust height of listbox
        set numResults [llength $::filteredOptions]
        if {$numResults < 10} {
            .dropdownFrame.dropdown configure -height $numResults
        } else {
            .dropdownFrame.dropdown configure -height 10
        }
        
        

        # Place the dropdown just below the search box
        place .dropdownFrame -x $x -y $y -width $w
        # Show the dropdown
        .top1.toggleButton configure -text "\u25B2" ;#up arrow
        set dropdownVisible true
    }
}

# Function to handle selection from the dropdown
proc handleSelection {} {
    global searchQuery dropdownVisible lastQuery current_index tex_list

    set selectedIndices [.dropdownFrame.dropdown curselection]
    if {[llength $selectedIndices] > 0} {
        set selectedValue [.dropdownFrame.dropdown get [lindex $selectedIndices 0]]
        
        #close the dropdown
        place forget .dropdownFrame
        .top1.toggleButton configure -text "\u25BC" ;# down arrow
        set dropdownVisible false
        
        # return, if no result found
        if {$selectedValue eq "No result found"} {
            return
        }
        
        # update search query (entry box)
        set searchQuery $selectedValue
        set lastQuery $selectedValue
        
        # Call on_combobox_select
        on_combobox_select
        update_commentLogFile
    }
}

proc closeDropdownIfNeeded {widget} {
    global dropdownVisible filteredOptions searchQuery lastQuery
    
    # List of widgets that should update the entry field
    set allowlist1 [list .top1.search .dropdownFrame .dropdownFrame.dropdown .dropdownFrame.scroll]
    if {[winfo exists $widget] && [lsearch -exact $allowlist1 $widget] == -1} {
	set searchQuery $lastQuery;
    }
    
    # List of widgets that should NOT close the dropdown
   set allowlist2 [list .top1.toggleButton .top1.search .dropdownFrame .dropdownFrame.dropdown .dropdownFrame.scroll]

    # Check if the widget is NOT in the allowlist
    if {[winfo exists $widget] && [lsearch -exact $allowlist2 $widget] == -1} {
        if {[winfo ismapped .dropdownFrame]} {
            # Hide dropdown
            place forget .dropdownFrame
            .top1.toggleButton configure -text "\u25BC" ;# down arrow
            set dropdownVisible false
        }
    }
}


#**************************************************************
# display_upto_last_10_comments
 
proc update_commentLogFile { } {
    # Access global variables
    global user_latest_comment curr_dir;
    
    # if empty, return
    if { $user_latest_comment eq "" } return;
    
    # Add comment in comment.log file
    set user_comment_file "$curr_dir/build/comment.log";
    set fp [open $user_comment_file a];
    puts $fp $user_latest_comment;
    close $fp;
    
    set user_latest_comment "";
}


proc closeCommentDropdown { widget } {
    # Access global variables
    global user_commentDropdownVisible;
    
    # Create allow list
    set allowlist [list .right_comment.btn1 .dropdownFrame2 .dropdownFrame2.dropdown]

    # Check if the widget is NOT in the allowlist
    if {[winfo exists $widget] && [lsearch -exact $allowlist $widget] == -1} {
        if {[winfo ismapped .dropdownFrame2]} {
            # Hide dropdown
            place forget .dropdownFrame2
            .right_comment.btn1 configure -text "\u25BC" ;# down arrow
            set user_commentDropdownVisible false
        }
    }
}

# Function to toggle the visibility of the listbox
proc toggleCommentDropdown {} {
    global user_commentDropdownVisible;

    if {$user_commentDropdownVisible} {
        place forget .dropdownFrame2
        .right_comment.btn1 configure -text "\u25BC" ;# down arrow
        set user_commentDropdownVisible false
    } else {
	#udpate commentDropdown
	set numResults [update_commentDropdown];
	
	# Get position and size of .top1.search relative to root window
        set x [expr {[winfo x .comment] + [winfo x .right_comment]}]
        set y [expr {[winfo y .comment] + [winfo height .right_comment.text]/2 - 20}]
        set w [expr {[winfo width .right_comment.text]}]
        
	# Adjust height of listbox
        if {$numResults < 10} {
            .dropdownFrame2.dropdown configure -height $numResults
        } else {
            .dropdownFrame2.dropdown configure -height 10
        }
        
        

        # Place the dropdown just below the search box
        place .dropdownFrame2 -x $x -y $y -width $w
        # Show the dropdown
        .right_comment.btn1 configure -text "\u25B2" ;#up arrow
        set user_commentDropdownVisible true;
    }
}

proc update_commentDropdown {} {
    global curr_dir;

    # Retrieve upto last 10 comments
    set user_comment_file "$curr_dir/build/comment.log";
    set comments [getLastNLines $user_comment_file 150];
    set comments [lreverse $comments]  ;# Reverse the list
    
    #no result found
    if {[llength $comments] == 0} {
        lappend comments "No result found"
    }
    
    # Extract top 10 unique comments
    set seen {}
    set unique_comments {}

    foreach c $comments {
	if {[lsearch -exact $seen $c] == -1} {
	    lappend seen $c
	    lappend unique_comments $c
	}
	    if {[llength $unique_comments] == 10} {
	    break
	}
    }
    
    
    # Clear and repopulate the dropdown
    .dropdownFrame2.dropdown delete 0 end
    foreach option $unique_comments {
        .dropdownFrame2.dropdown insert end $option
    }
    
    return [llength $unique_comments];
}

proc handleCommentSelection { } {
    global user_commentDropdownVisible has_unsaved_changes;

    set selectedIndices [.dropdownFrame2.dropdown curselection]
    if {[llength $selectedIndices] > 0} {
        set selectedValue [.dropdownFrame2.dropdown get [lindex $selectedIndices 0]]
       
        place forget .dropdownFrame2
        .right_comment.btn1 configure -text "\u25BC" ;# down arrow
        set user_commentDropdownVisible false
        
        if {$selectedValue eq "No result found"} {
            return;
        }
        
        # update the variable
        set has_unsaved_changes "true" ;
        set new_comment $selectedValue
        .right_comment.text delete 1.0 end
	.right_comment.text insert end $new_comment;
        after 10 [list add_comment $new_comment];
    }
}




#****************************************************************





proc getLastNLines {filename n} {
    if {![file exists $filename]} {
        return;
    }
    set f [open $filename "r"]
    fconfigure $f -translation binary

    # Seek to near the end of the file
    set fileSize [file size $filename]
    set chunkSize 4096  ;# Read last 4 KB
    set offset [expr {$fileSize > $chunkSize ? $fileSize - $chunkSize : 0}]
    seek $f $offset

    set data [read $f]
    close $f

    # Split into lines and remove any empty ones
    set lines [filterNonEmpty [split $data "\n"]]

    # If file doesn't end in a newline, the last line may be incomplete. Adjust as needed.
    set lastN [lrange $lines end-[expr {$n-1}] end]
    return $lastN
}



# Helper to filter empty lines
proc filterNonEmpty {lst} {
    set result {}
    foreach item $lst {
        if {[string trim $item] ne ""} {
            lappend result $item
        }
    }
    return $result
}


proc show_popup { status new_message } {
    global popup_message hide_popup_id;
  
    if { $status eq "success" } {
        .msg configure -background green -foreground white
        set popup_message "✅️ $new_message";
    } elseif { $status eq "fail" } {
        .msg configure -background red -foreground white
        set popup_message "❌️ $new_message";
    } else {
        .msg configure -background "#999909" -foreground white
        set popup_message "⚠️ $new_message";
    }
    
    .msg configure -text $popup_message
    
    # Update layout to calculate required size
    update idletasks

    # Get label's natural size
    set w1 [expr {[winfo reqwidth .msg] + 20}]
    set w2 [expr {[winfo width .right_comment.text]}];
    set w [expr {$w1 > $w2 ? $w1 : $w2}]
    set h [expr {[winfo reqheight .msg]}]
    set x [expr {[winfo x .comment] + [winfo x .right_comment]}]
    set y [expr {[winfo y .comment] + [winfo height .right_comment.text] - $h - 15}]
    set h [expr {$h + 20}];
    

    # Position the label accordingly
    place .msg -x $x -y $y -width $w -height $h

    # Cancel any previous after event
    if {[info exists hide_popup_id]} {
        after cancel $hide_popup_id
    }

    # Schedule new hide after 1200ms
    set hide_popup_id [after 1500 { place forget .msg }]
}



#*************************************
# Dark and Light mode

# ---------------------------
# Dark Mode Function
# ---------------------------
proc dark_mode {} {
    # Change the background and foreground for the main window
    . configure -background black

    # Set dark theme for all widgets
    foreach widget [winfo children .] {
        apply_dark_theme_recursive $widget
    }
}

# ---------------------------
# Light Mode Function
# ---------------------------
proc light_mode {} {
    # Revert the background and foreground to default
    . configure -background {}

    # Reset theme for all widgets
    foreach widget [winfo children .] {
        apply_light_theme_recursive $widget
    }
}

# ---------------------------
# Recursively Apply Dark Theme
# ---------------------------
proc apply_dark_theme_recursive {widget} {
    set class [winfo class $widget]

    switch -- $class {
        Label {
            $widget configure -background "#333333" -foreground white
        }
        Entry {
            $widget configure -background "#1A1A1A" -foreground white -insertbackground white \
                              -highlightthickness 0 -relief flat -disabledbackground gray30 \
                              -disabledforeground white
        }
        Text {
            $widget configure -background "#1A1A1A" -foreground white -insertbackground white \
                              -highlightthickness 0 -relief flat
        }
        Button {
            $widget configure -background "#2B2B2B" -foreground white \
                              -activebackground gray30 -activeforeground white \
                              -highlightthickness 0 -relief flat -borderwidth 1 \
                              -disabledforeground gray30
        }
        Radiobutton {
            $widget configure -background "#1A1A1A" -foreground white -activebackground gray30 \
                              -activeforeground white -highlightthickness 0 \
                              -selectcolor "#2A2A2A" -relief flat
        }
        Checkbutton {
            $widget configure -background "#1A1A1A" -foreground white \
                              -activebackground gray30 -activeforeground white \
                              -highlightthickness 0 -selectcolor "#2A2A2A"
        }
        Listbox {
            $widget configure -background "#1A1A1A" -foreground white -selectbackground "#2A2A2A" \
                              -selectforeground white -highlightthickness 0
        }
        Scrollbar {
            $widget configure -background "#1A1A1A" -activebackground gray50 -relief flat \
                              -troughcolor "#333333"
        }
        Frame {
            $widget configure -background "#333333"
        }
        default {}
    }
    
    ttk::style configure Custom.TCombobox -fieldbackground "#1A1A1A" -foreground white \
    -background gray20 -bordercolor black -arrowcolor white -insertcolor white

    foreach child [winfo children $widget] {
        apply_dark_theme_recursive $child
    }
    
    .left_comment.myButton1 configure -fg "#ff2828" -disabledforeground gray30
    .right_comment.text tag configure latexCommand -foreground orange
    .right_comment.text tag configure mathMode -foreground yellow
    
    .msg configure -background green -foreground white
}




# ---------------------------
# Recursively Revert to Light Theme
# ---------------------------
proc apply_light_theme_recursive {widget} {
    set class [winfo class $widget]

    switch -- $class {
        Label {
            $widget configure -background lightgray -foreground black
        }
        Entry {
            $widget configure -background white -foreground black -insertbackground black \
                              -highlightthickness 1 -relief sunken \
                              -disabledbackground lightgray -disabledforeground black
        }
        Text {
            $widget configure -background white -foreground black -insertbackground black \
                              -highlightthickness 1 -relief sunken
        }
        Button {
            $widget configure -background lightgray -foreground black \
                              -activebackground gray90 -activeforeground black \
                              -highlightthickness 1 -relief raised -borderwidth 1 \
                              -disabledforeground "#a3a3a3"
        }
        Radiobutton {
            $widget configure -background lightgray -foreground black -activebackground gray90 \
                              -activeforeground black -highlightthickness 0 \
                              -selectcolor white -relief flat
        }
        Checkbutton {
            $widget configure -background lightgray -foreground black \
                              -activebackground gray90 -activeforeground black \
                              -highlightthickness 1 -selectcolor white
        }
        Listbox {
            $widget configure -background "#FFFFFF" -foreground black -selectbackground gray90 \
                              -selectforeground black -highlightthickness 0
        }
        Scrollbar {
            $widget configure -background "#E0E0E0" -activebackground "#F0F0F0" -relief flat \
                              -troughcolor gray80
        }
        Frame {
            $widget configure -background lightgray
        }
        default {}
    }

    foreach child [winfo children $widget] {
        apply_light_theme_recursive $child
    }
    
    ttk::style configure Custom.TCombobox -padding {5 5 1 1}  -fieldbackground white \
    -background lightgray -foreground black -arrowcolor black -insertcolor black
    
    .left_comment.myButton1 configure -fg "#ff2828" -disabledforeground "#a3a3a3"
    .right_comment.text tag configure latexCommand -foreground blue
    .right_comment.text tag configure mathMode -foreground green
    
    .msg configure -background green -foreground white
}




proc update_theme { } {
    global theme;
    
    if { $theme eq "dark" } {
        dark_mode;
    } else {
        light_mode;
    }
}

proc toggle_theme { } {
     global theme last_theme_file last_call_time switchToTheme;
     
    
     if {$theme eq "dark" } {
         set theme "light";
         set switchToTheme "Dark";
         after 10 light_mode;
         
         # pop up
         show_popup "success" "Light Mode Applied";
     } else {
         set theme "dark";
         set switchToTheme "Light";
         after 10 dark_mode;
         
         # pop up
         show_popup "success" "Dark Mode Applied";
     }
     
    
    
     
     # Get current time in milliseconds
    set now [clock milliseconds]
    
    # Check if 3 seconds (3000 ms) have passed since last call
    if { ($now - $last_call_time) > 1000 } {
        set fp [open $last_theme_file w]
        puts $fp $theme
        close $fp
    }
     
    # Update the last_call_time
    set last_call_time $now
}


proc fix_orientation { } {

    update idletasks  ;# Forces layout calculations to finish
    set dist1 [expr {[winfo x .comment] + [winfo x .right_comment] + [winfo x .right_comment.text]}];
    
    #set width of ID's entry field
    set dist2 [expr {[winfo x .top] + [winfo x .top.id_label] + [winfo width .top.id_label]}];
    set dist [expr {$dist1 - $dist2}];
    grid configure .top1 -padx "$dist 0"
    
    #set width of Mark's entry field
    set dist3 [expr {[winfo x .marks] + [winfo x .marks.label] + [winfo width .marks.label]}];
    set dist [expr {$dist1 - $dist3}];
    grid configure .marks.entry -padx "$dist 0";
    
}


# ****************************



# ****************************
# Main Window Setup
# ****************************

# Title and Geometry
wm title . "$module_folder"
wm geometry . 450x310

# Bind the close event: function call to "on_close" function
wm protocol . WM_DELETE_WINDOW on_close

# Main Frame (Holds Everything)
frame .main -padx 0 -pady 2
grid .main -row 0 -column 0 -sticky nsew

# Ensure ".main" expands within the root window
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1

# Font Creation
font create myFont -family "Helvetica" -size 12 -weight normal
# Create a custom style for the combobox
ttk::style configure Custom.TCombobox -padding {5 5 1 1} 


# Add options for Combobox's Listbox
option add *TCombobox*Listbox.background "#1A1A1A"
option add *TCombobox*Listbox.foreground white
option add *TCombobox*Listbox.selectBackground gray
option add *TCombobox*Listbox.selectForeground white



# ****************************
# Top Frame (ID & Panel)
# ****************************

frame .top -padx 0 -pady 2

# Labels & Comboboxes for ID and Panel
#***************************
#1. ID

#lable
label .top.id_label -text "ID" -font myFont -underline 0

frame .top1 -padx 0 -pady 0;
# Create the search input
entry .top1.search -textvariable searchQuery -width 35
grid .top1.search -row 0 -column 0 -sticky ew -padx 0 -pady 0

# Create the toggle button
button .top1.toggleButton -text "\u25BC" -width 1 -height 1 -padx 1 -pady 0 -command {toggleDropdown}
grid .top1.toggleButton -row 0 -column 1 -padx {0 1} -pady 0 -sticky ew


#end ID
#***************************

#**************************
#Radio button
radiobutton .top.rb1 -text "R" -variable choice -value "roll" -font myFont \
-relief raised -command {
		sort_tex_list
		# pop up
		show_popup "success" "Sorted by roll number";
	}  
radiobutton .top.rb2 -text "S" -variable choice -value "size" -font myFont \
-relief raised -command {
		sort_tex_list
		# pop up
		show_popup "success" "Sorted by size";
	}    

#**************************




#***************************
#2. PANE
label .top.panel_label -text "Pane" -font myFont  -underline 1
ttk::combobox .top.panel_combo -values $pane_values -textvariable selected_pane -font myFont -style Custom.TCombobox
# Add a trace on selected_pane
#Syntax : trace add variable varName write callback
# Meaning: Run callback every time varName is written to
trace add variable selected_pane write on_selected_tab_change;
#end PANE
#****************************

# Positioning Components
grid .top.id_label -row 0 -column 0 -sticky w -padx {1 0}
grid .top1 -in .top -row 0 -column 1 -sticky ew
grid .top.rb1 -row 0 -column 2 -sticky w -padx 0
grid .top.rb2 -row 0 -column 3 -sticky w -padx 0
grid .top.panel_label -row 0 -column 4 -sticky w -padx {3 1}
grid .top.panel_combo -row 0 -column 5 -sticky ew -padx {1 2}

# Ensure Combo Boxes Expand in Width
grid columnconfigure .top 1 -weight 1
grid columnconfigure .top 5 -weight 1
grid columnconfigure .top1 0 -weight 1

# Attach Top Frame to Main Layout
grid .top -in .main -row 0 -column 0 -sticky new
grid rowconfigure .main 0 -weight 0
grid columnconfigure .main 0 -weight 1





# ****************************
# Marks Frame (Marks Entry)
# ****************************

frame .marks -padx 0 -pady 2

# Marks Label & Entry
label .marks.label -text "Marks" -font myFont -state disabled  -underline 0
entry .marks.entry -font myFont

# Set Default Value for Marks Entry
.marks.entry insert 0 0  

# Bind the KeyRelease event to call update_comment_timer when the user types
bind .marks.entry <KeyRelease> {update_marks_timer} ;

# Positioning Components
grid .marks.label -row 0 -column 0 -sticky w -padx {1 0}
grid .marks.entry -row 0 -column 1 -sticky ew -padx {1 2}

# Ensure Entry Expands in Width
grid columnconfigure .marks 1 -weight 1

# Attach Marks Frame to Main Layout
grid .marks -in .main -row 1 -column 0 -sticky new
grid columnconfigure .main 0 -weight 1






# ****************************
# Comment Section
# ****************************

# Comment Frame (Holds Left & Right Comments)
frame .comment -padx 0 -pady 2 

# Left Comment Frame (Fixed Width, Expands in Height)
frame .left_comment -padx 1 -pady 2 -relief solid
grid .left_comment -in .comment -row 0 -column 0 -sticky ns

# Ensure Left Comment Grows in Height Only
grid rowconfigure .comment 0 -weight 1
grid columnconfigure .comment 0 -weight 0

                                                                                               
# Left Comment Contents
button .left_comment.theme_btn -textvariable switchToTheme -font myFont -command {toggle_theme} -underline 0
grid .left_comment.theme_btn -row 0 -column 0 -sticky w -padx 1 -pady 2
label .left_comment.label -text "Comment" -font myFont -underline 0
grid .left_comment.label -row 2 -column 0 -sticky w -padx 1 -pady 2

ttk::combobox .left_comment.dropdown -values {T M B C} -width 5 -textvariable selected_position -font myFont  -style Custom.TCombobox
trace add variable selected_position write update_comment ;# Trace the variable to call update_comment when it changes
grid .left_comment.dropdown -row 4 -column 0 -sticky w -padx 1 -pady 2

button .left_comment.myButton1 -text "See Errors" -font myFont -width 7 -height 1 -command {showError} -state disabled -underline 4
grid .left_comment.myButton1 -row 5 -column 0 -sticky w -padx 1 -pady 2

# Ensure Space Above & Below the Label Expands
grid rowconfigure .left_comment {1 3} -weight 1
grid rowconfigure .left_comment {0 2 4 5} -weight 0
grid columnconfigure .left_comment 0 -weight 0


# Right Comment Frame (Expands in Both Width & Height)
frame .right_comment -padx 0 -pady 5 
grid .right_comment -in .comment -row 0 -column 1 -sticky nsew

# Ensure Right Comment Grows Fully
grid columnconfigure .comment 1 -weight 1
grid rowconfigure .comment 0 -weight 1

# Textbox Inside Right Comment (Captures 100% Space)
text .right_comment.text -wrap word -height 5 -width 40 -font myFont -undo 1
grid .right_comment.text -row 0 -column 0 -sticky nsew

# Define tag styles
.right_comment.text tag configure latexCommand -foreground blue
.right_comment.text tag configure mathMode -foreground green

# Bind a key release event to trigger highlighting and update_comment
bind .right_comment.text <KeyRelease> {highlight_latex_syntax; update_comment_timer;}

# Show upto last 10 comments
button .right_comment.btn1 -text "\u25BC" -font myFont -width 1 \
-command {toggleCommentDropdown} -padx 2 -pady 0
grid .right_comment.btn1 -row 0 -column 1 -sticky ns -padx 1 -pady 0


#****************************************************
# timer and pop up
frame .sub_right_comment -padx 0 -pady 1
grid .sub_right_comment -in .right_comment -row 1 -column 0 -sticky ew

label .sub_right_comment.label1 -text "Checked" -font myFont 
grid .sub_right_comment.label1 -row 0 -column 0 -sticky ew -padx 2 -pady 2

label .sub_right_comment.label2  -text "Elapsed Time" -font myFont 
grid .sub_right_comment.label2  -row 0 -column 1 -sticky ew -padx 2 -pady 2

label .sub_right_comment.label3  -text "Total Time" -font myFont 
grid .sub_right_comment.label3  -row 0 -column 2 -sticky ew -padx 2 -pady 2

label .sub_right_comment.label4  -text "0" -font myFont 
grid .sub_right_comment.label4  -row 1 -column 0 -sticky ew -padx 2 -pady 2

label .sub_right_comment.label5  -text "0" -font myFont 
grid .sub_right_comment.label5  -row 1 -column 1 -sticky ew -padx 2 -pady 2

label .sub_right_comment.label6  -text "0" -font myFont 
grid .sub_right_comment.label6  -row 1 -column 2 -sticky ew -padx 2 -pady 2

grid columnconfigure .sub_right_comment 0 -weight 1
grid columnconfigure .sub_right_comment 1 -weight 1
grid columnconfigure .sub_right_comment 2 -weight 1

#****************************************************


# Ensure Textbox Expands Fully
grid rowconfigure .right_comment 0 -weight 1 
grid columnconfigure .right_comment 0 -weight 1
grid columnconfigure .right_comment 1 -weight 0

# Attach Comment Frame to Main Layout
grid .comment -in .main -row 2 -column 0 -sticky nsew
grid columnconfigure .main 0 -weight 1
grid rowconfigure .main 2 -weight 1




# ****************************
# popup lable, Position: Absolute
# ****************************
label .msg -height 1 -background green -foreground white;
place forget .msg;


# ****************************



# ****************************
# Navigation Section
# ****************************

frame .nav -padx 1 -pady 2 

# Navigation Buttons
button .nav.prev -text "Previous" -command previous_tex -font myFont -underline 0
button .nav.open_tex -text "Open Tex" -command open_tex -font myFont  -underline 5
button .nav.preview -text "Preview" -command preview_tex -font myFont -underline 6
button .nav.next -text "Next" -command next_tex -font myFont -underline 0

# Position Buttons (Grow in Width, Fixed Height)
grid .nav.prev -row 0 -column 0 -sticky ew -padx 2
grid .nav.open_tex -row 0 -column 1 -sticky ew -padx 2
grid .nav.preview -row 0 -column 2 -sticky ew -padx 2
grid .nav.next -row 0 -column 3 -sticky ew -padx 2

# Ensure All Buttons Expand Equally
grid columnconfigure .nav {0 1 2 3} -weight 1

# Attach Navigation Frame at the Bottom
grid .nav -in .main -row 3 -column 0 -sticky ew 

# Ensure Nav Row Does NOT Expand in Height
grid rowconfigure .main 3 -weight 0
grid columnconfigure .main 0 -weight 1













#*******************************************
# Dropdown for search box (ID Field)
# Create a standalone dropdown frame (not inside .top1)
frame .dropdownFrame -relief raised -bd 1

# Listbox creation (unchanged)
listbox .dropdownFrame.dropdown -width 35 -height 5 -yscrollcommand {.dropdownFrame.scroll set} -exportselection 0
grid .dropdownFrame.dropdown -row 0 -column 0 -sticky nsew

#****************  HOVER   *********************
# Track mouse movement over the listbox
bind .dropdownFrame.dropdown <Motion> {
    set idx [%W nearest %y]
    %W selection clear 0 end
    %W selection set $idx
    %W activate $idx
}

# Clear selection when mouse leaves
bind .dropdownFrame.dropdown <Leave> {
    %W selection clear 0 end
}
#****************  HOVER   *********************
scrollbar .dropdownFrame.scroll -width 16 -orient vertical -command {.dropdownFrame.dropdown yview}
grid .dropdownFrame.scroll -row 0 -column 1 -sticky ns

# Bind events
bind .top1.search <KeyRelease> {updateDropdown}
bind .dropdownFrame.dropdown <<ListboxSelect>> {handleSelection}
#bind . <ButtonPress> {closeDropdownIfNeeded %W}

# Initialize dropdown content
place forget .dropdownFrame
grid columnconfigure .dropdownFrame 0 -weight 1;
#*******************************************














#**********************************************
# Dropdown to display upto last 10 comments
frame .dropdownFrame2 -relief raised -bd 1;

# Listbox creation (unchanged)
listbox .dropdownFrame2.dropdown -width 35 -height 2 -exportselection 0
grid .dropdownFrame2.dropdown -row 0 -column 0 -sticky nsew

#****************  HOVER   *********************
# Track mouse movement over the listbox
bind .dropdownFrame2.dropdown <Motion> {
    set idx [%W nearest %y]
    %W selection clear 0 end
    %W selection set $idx
    %W activate $idx
}

# Clear selection when mouse leaves
bind .dropdownFrame2.dropdown <Leave> {
    %W selection clear 0 end
}

#****************  HOVER   *********************

# Bind events
bind .dropdownFrame2.dropdown <<ListboxSelect>> {handleCommentSelection}
#bind . <ButtonPress> {closeCommentDropdown %W}
bind . <ButtonPress> {
    closeDropdownIfNeeded %W
    closeCommentDropdown %W
}


# Initialize dropdown content
place forget .dropdownFrame2
grid columnconfigure .dropdownFrame2 0 -weight 1;

#**********************************************






# shortcuts
# Bind Undo: Ctrl+z / Ctrl+Z (case-insensitive)
bind .right_comment.text <Control-z> {
    event generate .right_comment.text <<Undo>>
}
bind .right_comment.text <Control-Z> {
    event generate .right_comment.text <<Undo>>
}

# Bind Redo: Ctrl+Shift+z / Ctrl+Shift+Z
bind .right_comment.text <Control-Shift-z> {
    event generate .right_comment.text <<Redo>>
}
bind .right_comment.text <Control-Shift-Z> {
    event generate .right_comment.text <<Redo>>
}

# Bind Select All: Ctrl+a / Ctrl+A
bind .right_comment.text <Control-a> {
    .right_comment.text tag add sel 1.0 end-1c
    break
}
bind .right_comment.text <Control-A> {
    .right_comment.text tag add sel 1.0 end-1c
    break
}

# Bind Next: Alt+n / Alt+N (global)
bind . <Alt-n> {
    next_tex
}
bind . <Alt-N> {
    next_tex
}

# Bind Previous: Alt+p / Alt+P (global)
bind . <Alt-p> {
    previous_tex
}
bind . <Alt-P> {
    previous_tex
}

# Bind Alt+i and Alt+I to focus the combobox
bind . <Alt-i> {
    focus .top1.search
}
bind . <Alt-I> {
    focus .top1.search
}



# Bind Alt+a and Alt+A to focus the combobox
bind . <Alt-a> {
    focus .top.panel_combo
}
bind . <Alt-A> {
    focus .top.panel_combo
}


# Bind Alt+m and Alt+M to focus the combobox
bind . <Alt-m> {
    focus .marks.entry
}
bind . <Alt-M> {
    focus .marks.entry
}


# Bind Alt+c and Alt+C to focus the combobox
bind . <Alt-c> {
    focus .left_comment.dropdown
}
bind . <Alt-C> {
    focus .left_comment.dropdown
}

# Bind showError: Alt+e / Alt+E (global)
bind . <Alt-e> {
    showError
}
bind . <Alt-E> {
    showError
}

# Bind preview_tex: Alt+w / Alt+W (global)
bind . <Alt-w> {
    preview_tex
}
bind . <Alt-W> {
    preview_tex
}


# Bind open_tex: Alt+t / Alt+T (global)
bind . <Alt-t> {
    open_tex
}
bind . <Alt-T> {
    open_tex
}


# Bind Dark_MOde: Alt+l / Alt+L (global)
bind . <Alt-l> {
    toggle_theme
}
bind . <Alt-L> {
    toggle_theme
}














# main function
proc main { } {
    # Accessing global variables
    global current_index tex_list
    
    # Preprocessing : function calls
    create_main
    create_time_spent_file;
    update_pane 
    update_comment 
    update_marks
    run_pdflatex "main"
    update_theme
    update_time_spent
    
    # Check if 'Previous' should be disabled (if at index 0)
    if {$current_index == 0} {
        .nav.prev configure -state disabled
    } else {
        .nav.prev configure -state normal
    }

    # Check if 'Next' should be disabled (if at last index)
    if {$current_index == [expr {[llength $tex_list] - 1}]} {
        .nav.next configure -state disabled
    } else {
        .nav.next configure -state normal
    }
    
    
    fix_orientation;
}

# Function call: main
main














