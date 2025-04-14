package require Tk


set current_folder [lindex $argv 0]  ;# Get current folder from command-line arguments
set module_folder [lindex $argv 1]   ;# Get the module/question name


# Set up the current directory
set curr_dir [file join $current_folder $module_folder];
set main_file "$curr_dir/main.tex";
set tex_file_sequence "$curr_dir/.TexFileSequence.csv" ;#Absolute path
set selected_position "T";
set ::comment_timer_id "";
set ::marks_timer_id "";
set has_unsaved_changes "false";
set error_message "";
set configFile "$current_folder/.Settings.config"

#**************
#pane
set selected_pane 1
set max_panes 1
set pane_values {1}
set mainFileContent "";
set pane1FileContent "";
set pane2FileContent "";

#***************



# Create tex_list from TexFileSequence.csv file
proc load_tex_files {file_path} {
    if {![file exists $file_path]} {
        tk_messageBox -message "Error: .TexFileSequence.csv not found!" -icon error  -title "Error";
        return;
    }

    set fp [open $file_path r];
    set tex_files [split [read $fp] "\n"];
    close $fp;

    set tex_list [list];
    foreach file $tex_files {
        set trimmed_file [string trim $file];
        if {$trimmed_file ne ""} {
            lappend tex_list $trimmed_file;
        }
    }
    return $tex_list;
}


# tex_list => list of entries of TexFileSequence.csv file
set tex_list [load_tex_files $tex_file_sequence];
if { [llength $tex_list] > 0 } {
    set current_index 0
} else {
   tk_messageBox -message "Present directory doesn't contain any .tex file" -icon error;
   exit 1;
}



proc update_ui {} {
    global curr_dir;
    
    #create variable 
    convert_tex_to_pdf	;#function call
}

proc update_widget {tex_list current_index} {
        set file_name [lindex $tex_list $current_index] 	;#get the name of the file from the list
        .top.id_combo set $file_name 				;#update the value of ID field
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
         tk_messageBox -message "Please fix all errors before proceding" -icon error -title "Error";
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
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Make sure index is within the range
    if {$current_index > 0 } {
        # decrement index by 1
        incr current_index -1			

        #update widget
        update_widget $tex_list $current_index
        
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
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Make sure index is within the range
    if {$current_index < [expr {[llength $tex_list] - 1}] } {
        # increment index by +1
        incr current_index 1;
        
        #update widget
        update_widget $tex_list $current_index
        
        # udpate ui
        after 1 update_ui	;# function call
    }
    
    #update the value 
    set has_unsaved_changes "false"
}







   
proc run_pdflatex { main_tex } {
    global curr_dir error_message;
    
    # reset the error_message
    set error_message "";
    
    # Store the path to pwd
    set present_dir [pwd]
    
    # Change directory to curr_dir and compile.tex file asynchronously
    cd $curr_dir
    
    
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
        puts "No match found for: $searchString";
        return -1;
    }
    return $start_index;
}



# Define the add_comment function
proc add_comment { new_comment} {
    # Access global variables
    global selected_position main_file has_unsaved_changes;
    global selected_pane pane1FileContent pane2FileContent mainFileContent;
    
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
    puts "Comment updated successfully."

    # Compile the tex file into PDF
    update_ui ;# Function call: update_ui 
}





#Modified till here
#*******************************************************************************************
#Need to be modified






proc add_marks { args } {
    global main_file has_unsaved_changes num_checkboxes  ;# Access global variables
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
    puts "Marks updated successfully."
    
    # Compile the tex file into PDF
    update_ui ;# Function call: update_ui 
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

    # Check if new_marks is a valid floating point number
    if { ![string is double -strict $new_marks] } {
        puts "Invalid entry: $new_marks is not a number"
        return;
    } 

    
    after cancel $::marks_timer_id  ; # Cancel any existing timer
    set ::marks_timer_id [after 750 [list add_marks $new_marks]]  ; # Set a new timer for 0.750 seconds
}




proc create_main {} {
    global curr_dir main_file mainFileContent pane1FileContent pane2FileContent;
    
    set tex_file_name [.top.id_combo get];
    set tex_file_path "$curr_dir/$tex_file_name.tex"
    
    # Check if file exists
    if { ![file exist $tex_file_path] } {
        puts "file $tex_file_name.tex doesn't exist";
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
        puts "No match found for: \\putcomment$selected_position."
        return
    }

    # Extract substring from that position
    set sub_input [string range $paneContent $start_index end]

    # Find the first occurrence of \nextcommandmarker after \putcomment
    set end_index [string first "\\nextcommandmarker" $sub_input]
    if {$end_index == -1} {
        .right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
        puts "No match found for: \\nextcommandmarker."
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
        puts "No valid comment found."
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
        .marks.entry configure -state disabled        ;# disable the button
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
        checkbutton .marks.cb$i -text "$marks_val" -variable $varName -onvalue $marks_val -offvalue 0 -font myFont -command add_marks
        grid .marks.cb$i -row 0 -column [expr {$i + 2}] -padx 3
    }
    
    .marks.entry delete 0 end ;#delete everything 
    .marks.entry insert 0 $sum ;#set the sum as marks
    
}


#*********************** update_marks modified  *******************************************





# Open tex
proc open_tex { } {
    global curr_dir
    
    set tex_file_name [.top.id_combo get]
    set tex_file_path "$curr_dir/$tex_file_name.tex"
    
    if {[file exists $tex_file_path]} {
        exec xdg-open $tex_file_path &  ;# For Linux
    } else {
        tk_messageBox -message "File not found: $tex_file_path" -icon error -title "Error"
    }
}


# Preview button functionality
proc preview_tex {} {
    # Declaring global variables
    global curr_dir 
    
    # IF preview is already availabe, return
    if {![catch {exec pgrep -a evince} result]} {
        if {[string match "*main.pdf*" $result]} {
            puts "Preview is already available";
            return
        }
    } 
	
    # Function call: Compile main.tex into main.pdf
    convert_tex_to_pdf

    # Get generated PDF file
    set pdf_file "$curr_dir/build/main.pdf"
    after 500 [list check_pdf_generation $pdf_file];
}




proc enable_SeeErros_Button { } {
    # Configure the button
    .left_comment.myButton1 configure -fg red -activeforeground red -state normal
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
    global has_unsaved_changes curr_dir
    
    #update the original file, if we have unsaved changes
    if { $has_unsaved_changes eq "true" } {
         set present_dir [pwd]
         cd $curr_dir
         set file1 [.top.id_combo get].tex
         set result [compare_files $file1 main.tex]
         if { $result eq "Yes" } {
             exec cp main.tex $file1
         } 
         cd $present_dir
    }
}




proc showError { } {
    global error_message;
    if { $error_message eq "" } return ;
    set filename [.top.id_combo get].tex
    
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
	puts "Pane $default_pane not found! Check the LaTeX file structure."
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
    global current_index tex_list;
    
    # if any error, do not allow moving from current page
    if { [is_error] eq "true" } return;

    # Get selected value from the combobox
    set selected_id [.top.id_combo get]

    # Save current page changes
    save_changes;

    # Find the index of the selected item
    set index [lsearch -exact $tex_list $selected_id]
    
    if {$index != -1} {
	set current_index $index
	go_to_page $selected_id  ;# Navigate to the selected page
    }
    
}



# Function to navigate to the selected page
proc go_to_page {page_id} {
   global current_index tex_list;  
     
     
   if {$current_index < [expr {[llength $tex_list] - 1}] && $current_index > 0} {
	# update widget
	update_widget $tex_list $current_index;

	#updating UI
	update_ui					;# function call: update_ui
    }
	    

    #update the value 
    set has_unsaved_changes "false"
}



proc filter_combobox {event} {
    global tex_list

    set input [.top.id_combo get]  ;# Get the current text from combobox
    set filtered_list [list]
    if {$event eq "click"} {
	# If clicked, show the full list
	set filtered_list $tex_list
    } else {
	# If typing, filter the list based on input
	foreach item $tex_list {
	    if {[string match "*$input*" $item]} {
	        lappend filtered_list $item
	    }
	}
    }

    # Update combobox values dynamically
    .top.id_combo configure -values $filtered_list

    # Manually open the dropdown
    after 100 { event generate .top.id_combo <Down> }
    

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


proc load_shortcuts {filename} {
    set shortcuts [dict create]
    if {[file exists $filename]} {
        set fileId [open $filename r]
        while {[gets $fileId line] >= 0} {
            set line [string trim $line]

            # Skip comments and empty lines
            if {$line eq "" || [string match "#*" $line]} {
                continue
            }

            # Only accept lines like "copy=Control-c", not "key:value"
            if {[regexp {^([^:=\s]+)=([^\s]+)} $line -> key value]} {
                dict set shortcuts $key $value
            }
        }
        close $fileId
    }
    return $shortcuts
}
















#****************************************************************



# ****************************
# Main Window Setup
# ****************************

# Title and Geometry
wm title . "$module_folder"
wm geometry . 430x227

# Bind the close event: function call to "on_close" function
wm protocol . WM_DELETE_WINDOW on_close

# Main Frame (Holds Everything)
frame .main -padx 2 -pady 2
grid .main -row 0 -column 0 -sticky nsew

# Ensure ".main" expands within the root window
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1

# Font Creation
font create myFont -family "Helvetica" -size 12 -weight normal
# Create a custom style for the combobox
ttk::style configure Custom.TCombobox -padding {5 5 1 1}



# ****************************
# Top Frame (ID & Panel)
# ****************************

frame .top -padx 2 -pady 2

# Labels & Comboboxes for ID and Panel
#***************************
#1. ID
label .top.id_label -text "ID" -font myFont
ttk::combobox .top.id_combo -values $tex_list -font myFont -width 35  -style Custom.TCombobox
.top.id_combo set [lindex $tex_list 0] ;# Set first file name as default value
# Bind combobox selection change to event
bind .top.id_combo <<ComboboxSelected>> {on_combobox_select}
# Bind Enter key to trigger filtering while typing
bind .top.id_combo <KeyRelease> {filter_combobox "type"}
# Manually trigger dropdown when clicking on the arrow button
bind .top.id_combo <ButtonPress-1> {
    if {[winfo pointerx .] > [expr {[winfo rootx .top.id_combo] + [winfo width .top.id_combo] - 20}]} {
        event generate .top.id_combo <Down>
        filter_combobox "click" ;#function call
    }
}
#end ID
#***************************

#***************************
#2. PANE
label .top.panel_label -text "Pane" -font myFont 
ttk::combobox .top.panel_combo -values $pane_values -textvariable selected_pane -font myFont -style Custom.TCombobox
# Add a trace on selected_pane
trace add variable selected_pane write on_selected_tab_change;
.top.panel_combo insert 0 1 ;#set default vaule for Panel Combo (default: 1)
#end PANE
#****************************

# Positioning Components
grid .top.id_label -row 0 -column 0 -sticky w -padx {3 80}
grid .top.id_combo -row 0 -column 1 -sticky ew -padx 3
grid .top.panel_label -row 0 -column 2 -sticky w -padx 3
grid .top.panel_combo -row 0 -column 3 -sticky ew -padx 3

# Ensure Combo Boxes Expand in Width
grid columnconfigure .top 1 -weight 1
grid columnconfigure .top 3 -weight 1

# Attach Top Frame to Main Layout
grid .top -in .main -row 0 -column 0 -sticky new
grid rowconfigure .main 0 -weight 0
grid columnconfigure .main 0 -weight 1





# ****************************
# Marks Frame (Marks Entry)
# ****************************

frame .marks -padx 2 -pady 2

# Marks Label & Entry
label .marks.label -text "Marks" -font myFont -state disabled
entry .marks.entry -font myFont

# Set Default Value for Marks Entry
.marks.entry insert 0 0  

# Bind the KeyRelease event to call update_comment_timer when the user types
bind .marks.entry <KeyRelease> {update_marks_timer} ;

# Positioning Components
grid .marks.label -row 0 -column 0 -sticky w -padx {4 52}
grid .marks.entry -row 0 -column 1 -sticky ew -padx 3

# Ensure Entry Expands in Width
grid columnconfigure .marks 1 -weight 1

# Attach Marks Frame to Main Layout
grid .marks -in .main -row 1 -column 0 -sticky new
grid columnconfigure .main 0 -weight 1






# ****************************
# Comment Section
# ****************************

# Comment Frame (Holds Left & Right Comments)
frame .comment -padx 2 -pady 2 

# Left Comment Frame (Fixed Width, Expands in Height)
frame .left_comment -padx 2 -pady 2 -relief solid
grid .left_comment -in .comment -row 0 -column 0 -sticky ns

# Ensure Left Comment Grows in Height Only
grid rowconfigure .comment 0 -weight 1
grid columnconfigure .comment 0 -weight 0

# Left Comment Contents
label .left_comment.label -text "Comment" -font myFont 
grid .left_comment.label -row 1 -column 0 -sticky w -padx 3 -pady 2

ttk::combobox .left_comment.dropdown -values {T M B C} -width 5 -textvariable selected_position -font myFont  -style Custom.TCombobox
trace add variable selected_position write update_comment ;# Trace the variable to call update_comment when it changes
grid .left_comment.dropdown -row 3 -column 0 -sticky w -padx 3 -pady 2

button .left_comment.myButton1 -text "See Errors" -font myFont -width 7 -height 1 -command showError -state disabled
grid .left_comment.myButton1 -row 4 -column 0 -sticky w -padx 3 -pady 2

# Ensure Space Above & Below the Label Expands
grid rowconfigure .left_comment {0 2} -weight 1
grid rowconfigure .left_comment {1 3 4} -weight 0
grid columnconfigure .left_comment 0 -weight 0


# Right Comment Frame (Expands in Both Width & Height)
frame .right_comment -padx 5 -pady 5 
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

# Ensure Textbox Expands Fully
grid rowconfigure .right_comment 0 -weight 1
grid columnconfigure .right_comment 0 -weight 1

# Attach Comment Frame to Main Layout
grid .comment -in .main -row 2 -column 0 -sticky nsew
grid columnconfigure .main 0 -weight 1
grid rowconfigure .main 2 -weight 1


# Apply bindings from the config
set keymap [load_shortcuts $configFile]
foreach {action keyseq} $keymap {
    switch -- $action {
        undo {
            bind .right_comment.text <$keyseq> {
                event generate .right_comment.text <<Undo>>
            }
        }
        redo {
            bind .right_comment.text <$keyseq> {
                event generate .right_comment.text <<Redo>>
                break;
                
            }
        }
        selectall {
            bind .right_comment.text <$keyseq> {
       		.right_comment.text tag add sel 1.0 end-1c
                break
            }
        }
       
    }
}





# ****************************
# Navigation Section
# ****************************

frame .nav -padx 5 -pady 2 

# Navigation Buttons
button .nav.prev -text "\u2190 Previous" -command previous_tex -font myFont
button .nav.open_tex -text "Open_tex" -command open_tex -font myFont 
button .nav.preview -text "Preview" -command preview_tex -font myFont
button .nav.next -text "Next \u2192" -command next_tex -font myFont

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




# main function
proc main { } {
    # Accessing global variables
    global current_index tex_list
    
    # Preprocessing : function calls
    create_main
    update_pane 
    update_comment 
    update_marks
    run_pdflatex "main"
    
    
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

# Function call: main
main














