package require Tk
package require ttk

set module_folder [lindex $argv 0]
set tex_file_sequence "$module_folder/.TexFileSequence.csv"

# Reset UI Before Loading New Content
proc clear_window {} {
    foreach widget [winfo children .] {
        destroy $widget
    }
}

# read .TexFileSequence.csv file
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


set tex_ids [load_tex_files $tex_file_sequence]
if {[llength $tex_ids] > 0} {
    set current_index 0
} else {
    set tex_ids {}
    set current_index -1
}

proc update_ui {} {
    global tex_ids current_index
    if {$current_index >= 0} {
        set file_name [lindex $tex_ids $current_index]
        .top.id_combo set $file_name
        if {[winfo exists .preview]} {
            .preview.text configure -text "$file_name is currently open"
        }
    }
}

proc preview_tex {} {
    global tex_ids current_index
    if {$current_index >= 0} {
        set file_name [lindex $tex_ids $current_index]
        if {[winfo exists .preview]} {
            .preview.text configure -text "$file_name is currently open"
        } else {
            toplevel .preview
            wm title .preview "Preview"
            wm geometry .preview "300x100"
            label .preview.text -text "$file_name is currently open" -padx 30 -pady 5
            pack .preview.text -fill both -expand 1
        }
    }
}

proc previous_tex {} {
    global tex_ids current_index
    if {$current_index > 0} {
        incr current_index -1
        update_ui
    }
}

proc next_tex {} {
    global tex_ids current_index
    if {$current_index < [expr {[llength $tex_ids] - 1}]} {
        incr current_index
        update_ui
    }
}

clear_window
wm title . "Q-01"
wm geometry . 350x250

frame .main -padx 10 -pady 10
pack .main -fill both -expand 1

frame .top -padx 5 -pady 5
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

frame .marks -padx 5 -pady 5
label .marks.label -text "Marks"
entry .marks.entry
grid .marks.label -row 0 -column 0 -sticky w -padx 5
grid .marks.entry -row 0 -column 1 -sticky ew -padx 5
grid columnconfigure .marks 1 -weight 1
pack .marks -in .main -fill x

frame .comment -padx 5 -pady 5 -relief flat
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

frame .nav -padx 5 -pady 5
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