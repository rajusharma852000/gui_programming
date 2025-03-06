package require Tk
source /usr/share/tcltk/tk8.6/ttk/ttk.tcl



set current_dir ""
# Function to select a folder
proc select_folder {} {
    global current_dir  ;
    set current_dir [tk_chooseDirectory -title "Select project Folder"]
    
    if {$current_dir ne ""} {
        .top.loc_entry delete 0 end
        .top.loc_entry insert 0 $current_dir
        load_modules $current_dir
    }
}

# Function to read folder names from .SubModuleList.csv and update dropdown
proc load_modules {folder} {
    set file_path "$folder/.SubModuleList.csv"
    if {![file exists $file_path]} {
        tk_messageBox -message "Error: .SubModuleList.csv not found!" -icon error
        return
    }

    set fp [open $file_path r]
    set modules [split [read $fp] "\n"]
    close $fp

    # Remove empty entries and update dropdown
    set module_list [list]
    foreach module $modules {
        if {[string trim $module] ne ""} {
            lappend module_list $module
        }
    }

    # Update the dropdown menu and set the first value as default
    .bottom.module_combo configure -values $module_list -state normal
    .bottom.module_combo set [lindex $module_list 0]  ;# Set first value as default
    .bottom.start_button configure -state normal
}

# Function to launch the module window
proc open_module_window {} {
    # Close the main index window
    global current_dir  ;
    set module_folder "[.bottom.module_combo get]"
    destroy .
    exec wish module_window.tcl "$current_dir/$module_folder" &
}

# GUI Elements
#font create myFont -family Arial -size 12 -weight bold
font create myFont -family "TkHeadingFont" -size 12 -weight normal
frame .top -padx 10 -pady 10
label .top.loc_label -text "Project Location" -font myFont
entry .top.loc_entry -width 40 -font largeFont
button .top.select_project -text "Select Project" -command select_folder -font myFont
pack .top.loc_label .top.loc_entry .top.select_project -side left -padx 5

frame .bottom -padx 10 -pady 5
label .bottom.module_label -text "Select Module" -font myFont
ttk::combobox .bottom.module_combo -width 30 -state disabled -font largeFont
button .bottom.start_button -text "Start/Resume" -state disabled -command open_module_window -font myFont
pack .bottom.module_label .bottom.module_combo .bottom.start_button -side left -padx 5

# Pack main frames after defining all elements
pack .top .bottom -side top -fill x

# Run GUI event loop
if {[info exists tk_version]} {
    vwait forever
}

