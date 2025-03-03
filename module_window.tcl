package require Tk
package require ttk

set module_folder [lindex $argv 0]  ;# Get module folder from command-line arguments
set tex_file_sequence "$module_folder/.TexFileSequence.csv"

# Function to clear all widgets inside the main window
proc clear_window {} {
    foreach widget [winfo children .] {
        destroy $widget
    }
}

proc load_tex_files {file_path} {
    if {![file exists $file_path]} {
        tk_messageBox -message "Error: .TexFileSequence.csv not found! => $file_path" -icon error
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

proc preview_tex {} {
    global module_folder

    # Ensure the combobox exists
    if {![winfo exists .top.id_combo]} {
        tk_messageBox -message "Error: ID selection dropdown not found!" -icon error
        return
    }

    set selected_tex [.top.id_combo get]

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

    # Change directory to module_folder and compile .tex file asynchronously
    set current_dir [pwd]
    cd $module_folder

    if {[catch {exec pdflatex -interaction=nonstopmode [file tail $tex_file] &} result]} {
        tk_messageBox -message "PDF generation failed!\nError: $result" -icon error
        cd $current_dir
        return
    }

    cd $current_dir

    # Get generated PDF file
    set pdf_file "$module_folder/[file rootname $selected_tex].pdf"
    tk_messageBox -message "pdf file: $pdf_file" -icon error

    after 5000 [list check_pdf_generation $pdf_file]
}

proc check_pdf_generation {pdf_file} {
    if {![file exists $pdf_file]} {
        tk_messageBox -message "PDF generation failed! Check LaTeX log." -icon error
        return
    }

    # Open the generated PDF
    if {$::tcl_platform(os) eq "Windows"} {
        exec cmd.exe /c start "" "$pdf_file"
    } elseif {$::tcl_platform(os) eq "Darwin"} {
        exec open "$pdf_file" &
    } else {
        exec xdg-open "$pdf_file" &
    }
}

set tex_ids [load_tex_files $tex_file_sequence]
if {[llength $tex_ids] > 0} {
    set default_id [lindex $tex_ids 0]  ;# First element as default
} else {
    set default_id ""
}

clear_window

wm title . "Q-01"

frame .main -padx 10 -pady 10
pack .main -fill both -expand 1

frame .top -padx 5 -pady 5
label .top.id_label -text "ID"
ttk::combobox .top.id_combo -values $tex_ids
.top.id_combo set $default_id  
label .top.panel_label -text "Pane"
ttk::combobox .top.panel_combo -values {1 2 3 4 5}
grid .top.id_label -row 0 -column 0 -sticky w -padx 5
grid .top.id_combo -row 0 -column 1 -sticky ew -padx 5
grid .top.panel_label -row 0 -column 2 -sticky w -padx 5
grid .top.panel_combo -row 0 -column 3 -sticky ew -padx 5
grid columnconfigure .top {1 3} -weight 1
pack .top -in .main -fill x

frame .marks -padx 5 -pady 5
label .marks.label -text "Marks"
entry .marks.entry
grid .marks.label -row 0 -column 0 -sticky w -padx 5
grid .marks.entry -row 0 -column 1 -sticky ew -padx 5
grid columnconfigure .marks 1 -weight 1
pack .marks -in .main -fill x

frame .comment -padx 5 -pady 5 -relief flat
label .comment.label -text "Comment"
text .comment.text -wrap word
grid .comment.label -row 0 -column 0 -sticky nw -padx 5 -pady 2
grid .comment.text -row 0 -column 1 -sticky nsew -padx 5 -pady 2
grid columnconfigure .comment 1 -weight 1
grid rowconfigure .comment 0 -weight 1
pack .comment -in .main -fill both -expand 1

frame .comment_placement -padx 5 -pady 2
ttk::combobox .comment_placement.dropdown -values {T M B} -width 5
.comment_placement.dropdown set "T"  
grid .comment_placement.dropdown -row 0 -column 0 -sticky w -padx 5
pack .comment_placement -in .main -anchor w

frame .nav -padx 5 -pady 5
button .nav.prev -text "Previous"
button .nav.open_tex -text "Open .tex"
button .nav.preview -text "Preview" -command preview_tex  
button .nav.next -text "Next"
grid .nav.prev -row 0 -column 0 -sticky ew -padx 2
grid .nav.open_tex -row 0 -column 1 -sticky ew -padx 2
grid .nav.preview -row 0 -column 2 -sticky ew -padx 2
grid .nav.next -row 0 -column 3 -sticky ew -padx 2
grid columnconfigure .nav {0 1 2 3} -weight 1
pack .nav -in .main -fill x

if {[info exists tk_version]} {
    vwait forever
}
