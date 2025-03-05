package require Tk
source /usr/share/tcltk/tk8.6/ttk/ttk.tcl



set module_folder [lindex $argv 0]  ;# Get module folder from command-line arguments
set tex_file_sequence "$module_folder/.TexFileSequence.csv" ;#Absolute path
set last_compile_time 0

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
    # Declare global variables
    global tex_ids current_index module_folder
    
    
    
    if { $current_index >= 0 } {
        if {![catch {exec pgrep evince} result]} { 	;#If evince is already running, update the ui
            set selected_tex [.top.id_combo get] 	;#create variable 
            convert_tex_to_pdf $selected_tex		;#function call
            # Get generated PDF file
	    set pdf_file "$module_folder/build/$selected_tex.pdf" ;#get the full path
	    after 500 [list check_pdf_generation $pdf_file] ;#generate a preview
        }
    }
}


proc previous_tex {} {
    # Declaring global variables
    global tex_ids current_index last_compile_time
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Make sure index is within the range
    if {$current_index > 0 } {
        incr current_index -1	
        puts "decr value: $current_index";		;# increase by -1
        set file_name [lindex $tex_ids $current_index] 	;#get the name of the file from the list
        .top.id_combo set $file_name 			;#update the value of ID field
        
        # Enforce a 2-second cooldown
        if {$current_time - $last_compile_time < 2} {
            puts "Compilation request ignored: Please wait for 2 seconds."
            return
        } else {
            update_ui					;# function call: update_ui
            set last_compile_time $current_time		;# Update the last compile time
        }
    }
}


proc next_tex {} {
    # Declaring global variables
    global tex_ids current_index last_compile_time
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Make sure index is within the range
    if {$current_index < [expr {[llength $tex_ids] - 1}] } {
        incr current_index 1	
        puts "incr value: $current_index";			;# increase by +1
        set file_name [lindex $tex_ids $current_index] 	;#get the name of the file from the list
        .top.id_combo set $file_name 			;#update the value of ID field
        
        # Enforce a 2-second cooldown
        if {$current_time - $last_compile_time < 2} {
            puts "Compilation request ignored: Please wait for 2 seconds."
            return
        } else {
            update_ui					;# function call: update_ui
            set last_compile_time $current_time		;# Update the last compile time
        }
    }
}



   
    
    
    
  

# Function to convert .tex to .pdf
proc convert_tex_to_pdf { selected_tex } {
    global module_folder

     if {$selected_tex eq ""} {
        tk_messageBox -message "No .tex file selected!" -icon error
        return
    }

    # Ensure .tex extension
    if {[file extension $selected_tex] eq ""} {
        set selected_tex "$selected_tex.tex"
    }

    # Construct full path to the .tex file
    set tex_file "$module_folder/$selected_tex"

    if {![file exists $tex_file]} {
        tk_messageBox -message "Error: File not found!\n$tex_file" -icon error
        return
    }
    
    # Store the path to pwd
    set current_dir [pwd]
    
    # Change directory to module_folder and compile.tex file asynchronously
    cd $module_folder
   
    
    # Use catch to handle errors safely
    if {[catch {exec pdflatex -interaction=nonstopmode -output-directory=build $selected_tex} result]} {
        tk_messageBox -message "PDF generation failed!\nError: $result" -icon error
        cd $current_dir
        return
    }
	
    #change directory back to current_dir
    cd $current_dir

}






# Preview button functionality
proc preview_tex {} {
    # Declaring global variables
    global module_folder last_compile_time
    
    # Get the current time in seconds
    set current_time [clock seconds]
    
    # Enforce a 2-second cooldown
    if {$current_time - $last_compile_time < 2} {
        puts "Compilation request ignored: Please wait for 2 seconds."
        return
    }
    
    # Update the last compile time
    set last_compile_time $current_time
    
    
    # Ensure the combobox exists
    if {![winfo exists .top.id_combo]} {
        tk_messageBox -message "Error: ID selection dropdown not found!" -icon error
        return
    }

    set selected_tex [.top.id_combo get]
	
    # Function call: Compile .tex into .pdf
    convert_tex_to_pdf $selected_tex

    # Get generated PDF file
    set pdf_file "$module_folder/build/$selected_tex.pdf"
    after 500 [list check_pdf_generation $pdf_file]
}









# Check if the pdf was generated 
proc check_pdf_generation {pdf_file} {
    if {![file exists $pdf_file]} {
        tk_messageBox -message "PDF generation failed! Check LaTeX log." -icon error
        return
    }
    
    
    #catch {exec evince $pdf_file &}
    exec evince --preview $pdf_file &
}











#function call
clear_window

# title
wm title . "Q-01"
wm geometry . 350x250

frame .main -padx 5 -pady 2
pack .main -fill both -expand 1

frame .top -padx 5 -pady 2
label .top.id_label -text "ID"
ttk::combobox .top.id_combo -values $tex_ids
if {$current_index >= 0} {
    .top.id_combo set [lindex $tex_ids $current_index]
}
label .top.panel_label -text "Pane"
ttk::combobox .top.panel_combo -values {1 2 3 4 5}
grid .top.id_label -row 0 -column 0 -sticky w -padx 5
grid .top.id_combo -row 0 -column 1 -sticky ew -padx 5
grid .top.panel_label -row 0 -column 2 -sticky w -padx 5
grid .top.panel_combo -row 0 -column 3 -sticky ew -padx 5
grid columnconfigure .top {1 3} -weight 1
pack .top -in .main -fill x

frame .marks -padx 5 -pady 2
label .marks.label -text "Marks"
entry .marks.entry
grid .marks.label -row 0 -column 0 -sticky w -padx 5
grid .marks.entry -row 0 -column 1 -sticky ew -padx 5
grid columnconfigure .marks 1 -weight 1
pack .marks -in .main -fill x

frame .comment -padx 5 -pady 2 -relief flat
label .comment.label -text "Comment"
text .comment.text -wrap word -height 5  ;
grid .comment.label -row 0 -column 0 -sticky nw -padx 5 -pady 2
grid .comment.text -row 0 -column 1 -sticky nsew -padx 5 -pady 2
grid columnconfigure .comment 1 -weight 1 ;#expand row 0, col 1 => grow text box in height
grid rowconfigure .comment 0 -weight 1  ;#expand row 0 => grow text box in width
pack .comment -in .main -fill both -expand 1 ;#grow comment frame both in height and width
grid rowconfigure .main 0 -weight 1  ;
frame .comment_placement -padx 5 -pady 2
ttk::combobox .comment_placement.dropdown -values {T M B} -width 5
.comment_placement.dropdown set "T"
grid .comment_placement.dropdown -row 0 -column 0 -sticky w -padx 5
pack .comment_placement -in .main -anchor w

frame .nav -padx 5 -pady 2
button .nav.prev -text "Previous" -command previous_tex
button .nav.open_tex -text "Open .tex"
button .nav.preview -text "Preview" -command preview_tex  
button .nav.next -text "Next" -command next_tex
grid .nav.prev -row 0 -column 0 -sticky ew -padx 2
grid .nav.open_tex -row 0 -column 1 -sticky ew -padx 2
grid .nav.preview -row 0 -column 2 -sticky ew -padx 2
grid .nav.next -row 0 -column 3 -sticky ew -padx 2
grid columnconfigure .nav {0 1 2 3} -weight 1
pack .nav -in .main -fill x -side bottom  ;# Keep navigation at bottom



if {[info exists tk_version]} {
    vwait forever
}
