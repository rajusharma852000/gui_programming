package require Tk
source /usr/share/tcltk/tk8.6/ttk/ttk.tcl



set current_folder [lindex $argv 0]  ;# Get current folder from command-line arguments
set module_folder [lindex $argv 1]   ;# Get the module/question name

# Check if arguments are provided to prevent errors
if {![info exists current_folder] || ![info exists module_folder]} {
    puts "Error: Missing arguments. Usage: wish script.tcl <current_folder> <module_folder>"
    exit 1
}

# Set up the current directory
set curr_dir [file join $current_folder $module_folder]
set main_file "$curr_dir/main.tex"

set tex_file_sequence "$curr_dir/.TexFileSequence.csv" ;#Absolute path
set last_compile_time 0
set selected_position "T"
set ::comment_timer_id ""
set ::marks_timer_id ""
set has_unsaved_changes "false";






# Function to clear all widgets inside the main window
proc clear_window {} {
    foreach widget [winfo children .] {
        destroy $widget
    }
}




# To get the list of entries of TexFileSequence.csv file
proc load_tex_files {file_path} {
    if {![file exists $file_path]} {
        tk_messageBox -message "Error: .TexFileSequence.csv not found!" -icon error
        return {}
    }

    set fp [open $file_path r]
    set tex_files [split [read $fp] "\n"]
    close $fp

    set tex_list [list]
    foreach file $tex_files {
        set trimmed_file [string trim $file]
        if {$trimmed_file ne ""} {
            lappend tex_list $trimmed_file
        }
    }
    return $tex_list
}









# tex_ids => list of entries of TexFileSequence.csv file
set tex_ids [load_tex_files $tex_file_sequence];
if { [llength $tex_ids] > 0 } {
    set current_index 0
} else {
    set tex_ids {}
    set current_index -1
}









proc update_ui {} {
    global curr_dir;
    
        if {![catch {exec pgrep evince} result]} { 	;#If evince is already running, update the ui
            #create variable 
            convert_tex_to_pdf "main"	;#function call
            # Get generated PDF file
	    set pdf_file "$curr_dir/build/main.pdf" ;#get the full path
	    check_pdf_generation $pdf_file 		;#functin call: generate preview
        }
}



proc previous_tex {} {
    # Declaring global variables
    global tex_ids current_index  curr_dir has_unsaved_changes
    
    save_changes ;# Function call => save_changes => copy main.tex to curr_file.tex
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Make sure index is within the range
    if {$current_index > 0 } {
        incr current_index -1			;# increase by -1
        set file_name [lindex $tex_ids $current_index] 	;#get the name of the file from the list
        .top.id_combo set $file_name 			;#update the value of ID field
         update_comment                                  ;# function call
         update_marks                                    ;# function call
        
         
         
	# Check if 'Previous' should be disabled (if at index 0)
	if {$current_index == 0} {
	    .nav.prev configure -state disabled
	} else {
	    .nav.prev configure -state normal
	}
	# Check if 'Next' should be disabled (if at last index)
	if {$current_index == [expr {[llength $tex_ids] - 1}]} {
	    .nav.next configure -state disabled
	} else {
	    .nav.next configure -state normal
	}

        #updating UI
        update_ui					;# function call: update_ui
            
    }
    
    #update the value 
    set has_unsaved_changes "false"
}


proc compare_files {file1 file2} {
    if {[catch {exec diff $file1 $file2} result]} {
        return "Yes"  ;# Files are different
    } else {
        return "No"   ;# Files are identical
    }
}

proc next_tex {} {
    # Declaring global variables
    global tex_ids current_index  has_unsaved_changes curr_dir
    
    save_changes ;# Function call => save_changes => copy main.tex to curr_file.tex
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Make sure index is within the range
    if {$current_index < [expr {[llength $tex_ids] - 1}] } {
        incr current_index 1				;# increase by +1
        set file_name [lindex $tex_ids $current_index] 	;#get the name of the file from the list
        .top.id_combo set $file_name 			;#update the value of ID field
        update_comment                                  ;# function call
        update_marks                                    ;# function call
        
        
        # Check if 'Previous' should be disabled (if at index 0)
	if {$current_index == 0} {
	    .nav.prev configure -state disabled
	} else {
	    .nav.prev configure -state normal
	}
	# Check if 'Next' should be disabled (if at last index)
	if {$current_index == [expr {[llength $tex_ids] - 1}]} {
	    .nav.next configure -state disabled
	} else {
	    .nav.next configure -state normal
	}
        
        #updating UI
        update_ui					;# function call: update_ui
            
    }
    
    
    #update the value 
    set has_unsaved_changes "false"
}



   
    
    
    
  

# Function to convert .tex to .pdf
proc convert_tex_to_pdf { main } {
    global curr_dir

     if {$main eq ""} {
        tk_messageBox -message "No .tex file selected!" -icon error
        return
    }

    # Ensure .tex extension
    if {[file extension $main] eq ""} {
        set main_tex "$main.tex"
    } else {
        set main_tex "$main"
    }


    # Construct full path to the .tex file
    set tex_file "$curr_dir/$main_tex"

    if {![file exists $tex_file]} {
        tk_messageBox -message "Error: File not found!\n$tex_file" -icon error
        return
    }
    
    # Store the path to pwd
    set current_dir [pwd]
    
    # Change directory to curr_dir and compile.tex file asynchronously
    cd $curr_dir

    
    # Use catch to handle errors safely
    if { [catch {exec pdflatex -interaction=nonstopmode -output-directory=build $main_tex > /dev/null } result] } {
        tk_messageBox -message "PDF generation failed!\nError: $result" -icon error    
        cd $current_dir
        return
    }

	
    #change directory back to current_dir
    cd $current_dir

}




# Define the add_comment function
proc add_comment { new_comment} {
    global selected_position main_file has_unsaved_changes   ;# Access global variables
    set has_unsaved_changes "true" ;# update the variable
    
    # Open the file in read mode and read its content
    set fileId [open $main_file "r"]
    set fileContent [read $fileId]
    close $fileId
    
    # Modify the content by updating the comment inside \putcomment_{...}
    set comment_regex "\\\\putcomment$selected_position\\{(.*?)\\}"
    if {[regexp $comment_regex $fileContent match]} {
        set modifiedContent [regsub $comment_regex $fileContent "\\putcomment$selected_position\{$new_comment\}"]
    } else {
        puts "No matching \\putcomment$selected_position\{(.*?)\} found."
        return
    }
     
    # Open the file in write mode and write the modified content back to the file
    set fileId [open $main_file "w"]
    puts -nonewline $fileId $modifiedContent
    close $fileId
    
    puts "Comment updated successfully."
    
    # Compile the tex file into pdf
    update_ui 			      ;#function call: update_ui
    
}





proc add_marks { args } {
    global main_file has_unsaved_changes num_checkboxes  ;# Access global variables
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
    
    #remove the trailing "+" only if checkbox to enter marks
    if { ([llength $args] == 0) } {
        set new_marks [string range $new_marks 0 end-1]
	#Update the entry field
        .marks.entry delete 0 end;
        .marks.entry insert 0 $sum;
    }
    
    
    
    # Open the file in read mode and read its content
    set fileId [open $main_file "r"]
    set fileContent [read $fileId]
    close $fileId
    
    set marks_regex "\\\\putmarks\\{(.*?)\\}"
    if {[regexp $marks_regex $fileContent match]} {
        set modifiedContent [regsub $marks_regex $fileContent "\\putmarks\{$new_marks\}"]
    } else {
        puts "No matching \\putmarks\{(.*?)\} found."
        return
    }
     
    # Open the file in write mode and write the modified content back to the file
    set fileId [open $main_file "w"]
    puts -nonewline $fileId $modifiedContent
    close $fileId
    
    puts "Marks updated successfully."
    
    # Compile the tex file into pdf
    update_ui 			      ;#function call: update_ui;#function call: update_ui
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

    # Check if new_marks is a valid non-negative integer
    if { ![string is integer -strict $new_marks] || $new_marks < 0 } {
        puts "Invalid entry: $new_marks"
        return;
    } 

    
    after cancel $::marks_timer_id  ; # Cancel any existing timer
    set ::marks_timer_id [after 750 [list add_marks $new_marks]]  ; # Set a new timer for 0.750 seconds
}




proc create_main {curr_file} {
    global main_file;
    exec cp $curr_file $main_file;
}


# function to update comment
proc update_comment {args} {
    global selected_position  curr_dir main_file;# Access global variables
    
    set tex_file_name [.top.id_combo get];
    set tex_file_path "$curr_dir/$tex_file_name.tex"
    create_main $tex_file_path;
    set fp [open $main_file r];
    set content [read $fp]
    close $fp

    # Define regular expressions to extract comments
    set comment_regex "\\\\putcomment$selected_position\\{(.*?)\\}"
    
   
    # Initialize comment variables with default values
    set comment ""
    
    # Extract comments if they exist  
    if {[regexp $comment_regex $content -> match]} {
        set comment $match
        .right_comment.text delete 1.0 end  ; # Clear the existing content in the text box
        .right_comment.text insert end $comment  ; # Insert the new comment value
    }

}


#To determine the marks update source i.e. entryField or checkboxes
proc is_manual_marks_entry { marks putmarks } {
    #If markingScheme and putMarks differ in length,
    #then marks were updated using marks entryField
    if { [llength $marks] != [llength $putmarks] } {
        return "yes";
    } else {
        # Split marks and putmarks by '+'
        set putmarks_list [split $putmarks "+"];
        set marks_list [split $marks "+"];
        
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



proc update_marks { } {
    global curr_dir main_file

    # Read file content
    set fp [open $main_file r]
    set content [read $fp]
    close $fp

    # Define regex patterns
    set marks_regex "\\\\showmarkingscheme\\{(.*?)\\}"
    set putmarks_regex "\\\\putmarks\\{(.*?)\\}"

    # Extract marks for checkboxes count
    set marks ""
    if {[regexp $marks_regex $content -> match]} {
        set marks $match; #1+1+1+1
        set marks [regsub -all {\s+} $marks ""]  ;# Remove all the whitespace
    }
    
    
    #if marking is scheme is not present, disable the mark field
    if { $marks eq "" } {
        .marks.entry delete 0 end;                    ;# delete the value
        .marks.entry configure -state disabled        ;# disable the button
        .marks.label configure -foreground gray50     ;# Change label color
    } else {
        .marks.entry configure -state normal          ;# make the state normal
        .marks.label configure -foreground black      ;# Restore original color
    }

    # Extract putmarks values for checkbox selection
    set putmarks ""
    if {[regexp $putmarks_regex $content -> put_match]} {
        set putmarks $put_match ;#1+0+1+1
        set putmarks [regsub -all {\s+} $putmarks ""]  ;# Remove all the whitespace
    }

    # Count number of checkboxes to be created
    global num_checkboxes 0; 
    set num_checkboxes [llength [split $marks "+"]]  ;# number of checkboxes

    # Parse putmarks and marks strings into a lists
    set putmarks_list [split $putmarks +];
    set marks_list [split $marks +];

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
	if { [is_manual_marks_entry $marks $putmarks] eq "yes" } {
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





# Generate pdf from tex file as soon as the program starts
proc create_pdf { } {
    global curr_dir
    set selected_tex [.top.id_combo get];
    convert_tex_to_pdf $selected_tex

}



# Open tex
proc open_tex { } {
    global curr_dir
    
    set tex_file_name [.top.id_combo get]
    set tex_file_path "$curr_dir/$tex_file_name.tex"
    
    if {[file exists $tex_file_path]} {
        exec xdg-open $tex_file_path &  ;# For Linux
    } else {
        tk_messageBox -message "File not found: $tex_file_path" -icon error
    }
}


# Preview button functionality
proc preview_tex {} {
    # Declaring global variables
    global curr_dir last_compile_time
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Enforce a 2-second cooldown
    if {$current_time - $last_compile_time < 2} {
        puts "Compilation request ignored: Please wait for 2 seconds."
        return
    }
    
    # Update the last compile time
    set last_compile_time $current_time
    

    # Check if evince is displaying main.pdf
    if {![catch {exec pgrep -a evince} result]} {
        if {[string match "*main.pdf*" $result]} {
            puts "Preview is already available";
            return
        }
    }
	
    # Function call: Compile .tex into .pdf
    convert_tex_to_pdf "main"

    # Get generated PDF file
    set pdf_file "$curr_dir/build/main.pdf"
    check_pdf_generation $pdf_file;
}









# Check if the pdf was generated 
proc check_pdf_generation {pdf_file} {
    if {![file exists $pdf_file]} {
        tk_messageBox -message "PDF generation failed! Check LaTeX log." -icon error
        return
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

# Function call: clear everthing before the program starts
clear_window  

# Bind the close event: function call to "on_close" function
wm protocol . WM_DELETE_WINDOW on_close



# ****************************
# Main Window Setup
# ****************************

# Title and Geometry
wm title . "$module_folder"
wm geometry . 400x227

# Main Frame (Holds Everything)
frame .main -padx 2 -pady 2
grid .main -row 0 -column 0 -sticky nsew

# Ensure ".main" expands within the root window
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1

# Font Creation
font create myFont -family "Helvetica" -size 12 -weight normal



# ****************************
# Top Frame (ID & Panel)
# ****************************

frame .top -padx 2 -pady 2

# Labels & Comboboxes for ID and Panel
label .top.id_label -text "ID" -font myFont
ttk::combobox .top.id_combo -values $tex_ids -font myFont
.top.id_combo set [lindex $tex_ids 0] ;# Set first file name as default value
label .top.panel_label -text "Pane" -font myFont
ttk::combobox .top.panel_combo -values {1 2} -font myFont
.top.panel_combo insert 0 1 ;#set default vaule for Panel Combo (default: 1)

# Positioning Components
grid .top.id_label -row 0 -column 0 -sticky w -padx {3 48}
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
label .marks.label -text "Marks" -font myFont
entry .marks.entry -font myFont

# Set Default Value for Marks Entry
.marks.entry insert 0 0  

# Bind the KeyRelease event to call update_comment_timer when the user types
bind .marks.entry <KeyRelease> {update_marks_timer} ;

# Positioning Components
grid .marks.label -row 0 -column 0 -sticky w -padx {4 23}
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

ttk::combobox .left_comment.dropdown -values {T M B C} -width 5 -textvariable selected_position -font myFont
trace add variable selected_position write update_comment ;# Trace the variable to call update_comment when it changes
grid .left_comment.dropdown -row 3 -column 0 -sticky w -padx 3 -pady 2

button .left_comment.myButton1 -text "See Errors" -font myFont -width 8 -height 1
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
text .right_comment.text -wrap word -height 5 -width 40 -font myFont
grid .right_comment.text -row 0 -column 0 -sticky nsew
bind .right_comment.text <KeyRelease> {update_comment_timer} 

# Ensure Textbox Expands Fully
grid rowconfigure .right_comment 0 -weight 1
grid columnconfigure .right_comment 0 -weight 1

# Attach Comment Frame to Main Layout
grid .comment -in .main -row 2 -column 0 -sticky nsew
grid columnconfigure .main 0 -weight 1
grid rowconfigure .main 2 -weight 1









# ****************************
# Navigation Section
# ****************************

frame .nav -padx 5 -pady 2 

# Navigation Buttons
button .nav.prev -text "Previous" -command previous_tex -font myFont
button .nav.open_tex -text "Open_tex" -command open_tex -font myFont 
button .nav.preview -text "Preview" -command preview_tex -font myFont
button .nav.next -text "Next" -command next_tex -font myFont

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
    update_comment 
    update_marks
    #create_pdf
    
    global current_index tex_ids
        # Check if 'Previous' should be disabled (if at index 0)
	if {$current_index == 0} {
	    .nav.prev configure -state disabled
	} else {
	    .nav.prev configure -state normal
	}

	# Check if 'Next' should be disabled (if at last index)
	if {$current_index == [expr {[llength $tex_ids] - 1}]} {
	    .nav.next configure -state disabled
	} else {
	    .nav.next configure -state normal
	}

    
}

# Function call: main
main


if {[info exists tk_version]} {
    vwait forever
}











