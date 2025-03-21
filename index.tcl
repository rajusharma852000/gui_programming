package require Tk
source /usr/share/tcltk/tk8.6/ttk/ttk.tcl



set current_dir ""
#set attached_file "module_window.tcl";
#set attached_file "Ankur_module_window.tcl";
#set attached_file "Ankur_module_window_2.tcl";
set attached_file "Raju_module_window.tcl";


# Function to select a folder
proc select_folder {} {
    global current_dir  ;
    
    # Define config directory adn file path
    set config_dir "~/.config/my_app";
    set last_dir_file "$config_dir/last_dir.txt";
    
    # Create config directory if it doesn't exists
    if { ![file exists $config_dir]} {
        file mkdir $config_dir;
    }
    
    # Load last directory rom file (if it exists)
    if { [file exists $last_dir_file]} {
        set fp [open $last_dir_file r]
        gets $fp last_selected_dir
        close $fp
    } else {
        set last_selected_dir [pwd] ;# Default to current directory
    }
    
    # Open directory chooser starting from last remembered locatiohn
    #set selected_dir [tk_chooseDirectory -title "Select Project Folder" -initialdir $last_selected_dir]
    if {[catch {exec zenity --file-selection --directory --title "Select Project Folder" --filename "$last_selected_dir/" --width=800 --height=600} selected_dir]} {
        set selected_dir ""
    }

    if { $selected_dir ne "" } {
        set current_dir $selected_dir
        
        #Save selected directory to file
        set fp [open $last_dir_file w]
        puts $fp $selected_dir
        close $fp
        
        
        if { [load_modules $current_dir] == 1 } {
            .top.loc_entry delete 0 end
            .top.loc_entry insert 0 $current_dir
            .top.loc_entry xview moveto 1 
        }
    }
}

# Function to read folder names from .SubModuleList.csv and update dropdown
proc load_modules {folder} {
    set file_path "$folder/.SubModuleList.csv"
    if {![file exists $file_path]} {
        tk_messageBox -message "Error: .SubModuleList.csv not found!" -icon error
        return 0;
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
    .bottom.module_label configure -state normal
    .bottom.module_combo configure -values $module_list -state normal
    .bottom.module_combo set [lindex $module_list 0]  ;# Set first value as default
    .bottom.start_button configure -state normal
    
    return 1;
}

# Function to launch the module window
proc open_module_window {} {
    # Close the main index window
    global current_dir  attached_file;
    set module_folder "[.bottom.module_combo get]"
    destroy .
    exec wish $attached_file "$current_dir/$module_folder" &
}



# GUI Elements
#wm geometry . 400x227

# Main Frame (Holds Everything)
frame .main -padx 0 -pady 0
grid .main -row 0 -column 0 -sticky nsew

# Ensure ".main" expands within the root window
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1


# Custom font
font create myFont -family "Helvetica" -size 12 -weight normal

# Top frame
frame .top -padx 2 -pady 10 
label .top.loc_label -text "Project Location" -font myFont
entry .top.loc_entry -width 30 -font largeFont
button .top.select_project -text "Select Project" -command select_folder -font myFont
grid .top.loc_label -row 0 -column 0 -sticky w -padx {3 5}
grid .top.loc_entry -row 0 -column 1 -sticky ew -padx {1 5}
grid .top.select_project -row 0 -column 2 -sticky e -padx {25 15}

# Ensure entryBox Expand in Width
grid columnconfigure .top 1 -weight 1


# Bottom frame
frame .bottom -padx 2 -pady 10
label .bottom.module_label -text "Select Module" -font myFont -state disabled
ttk::combobox .bottom.module_combo -width 25 -state readonly -state disabled -font largeFont
button .bottom.start_button -text "Start/Resume" -state disabled -command open_module_window -font myFont

grid .bottom.module_label -row 0 -column 0 -sticky w -padx {3 20}
grid .bottom.module_combo -row 0 -column 1 -sticky ew -padx {1 25}
grid .bottom.start_button -row 0 -column 2 -sticky e -padx {2 15}

# Ensure entryBox Expand in Width
grid columnconfigure .bottom 1 -weight 1

# Attach Top Frame to Main Layout
grid .top -in .main -row 0 -column 0 -sticky new
grid .bottom -in .main -row 1 -column 0 -sticky new
grid rowconfigure .main 0 -weight 0
grid columnconfigure .main 0 -weight 1



# Run GUI event loop
if {[info exists tk_version]} {
    vwait forever
}

