#!/usr/bin/env wish

# Procedure to select a folder
proc select_folder {} {
    set folder [tk_chooseDirectory]

    # ne: not equal to
    if {$folder ne ""} {
        # Proceed with the rest of your code here
        return $folder
    } else {
        # Exit the program if no folder is selected
        exit
    }
}

# Procedure to read the .csv file and get options
proc read_csv {folder} {
    set csvfile [glob -nocomplain -directory $folder *.csv]
    if {[llength $csvfile] == 0} {
        return [list "No CSV file found"]
    }

    set file [open [lindex $csvfile 0] r]
    set options [list]
    while {[gets $file line] >= 0} {
        lappend options $line
    }
    close $file
    return $options
}

# Procedure to create the GUI helper function
proc helper {options} {
    ttk::frame .main
    pack .main -fill both -expand 1

#1. Create a frame for the combobox and button
    ttk::frame .main.subframe1
    pack .main.subframe1 -side top -anchor center -padx 10 -pady 10

    # Set default value
    set selected_option "Select/Search"

    # Create combobox with default value
    ttk::combobox .main.subframe1.combobox -textvariable selected_option -values $options -state readonly
    .main.subframe1.combobox set "Select/Search"
    pack .main.subframe1.combobox -side left -padx 5

    ttk::button .main.subframe1.button -text "Search" -command {
        # command here
    }
    pack .main.subframe1.button -side left -padx 5



#2. Create a text widget for multiline input
    ttk::frame .main.subframe2
    pack .main.subframe2 -side top -anchor e -padx 20 -pady 10
    text .main.subframe2.input -width 35 -height 8
    pack .main.subframe2.input;

    button .main.subframe2.getInput -text "Compile" -command {
        set userInput [.main.subframe2.input get 1.0 end]

        # Write the input to a .tex file
        set texFile "user_input.tex"
        set file [open $texFile w]
        puts $file "\\documentclass{article}"
        puts $file "\\begin{document}"
        puts $file $userInput
        puts $file "\\end{document}"
        close $file

        # Compile the .tex file to a PDF using a LaTeX compiler
        set pdflatex_cmd "pdflatex $texFile"
        exec cmd /c $pdflatex_cmd

        puts "LaTeX file created and compiled to PDF."
    }

    pack .main.subframe2.getInput;

    


#3. Create a new frame for the buttons
    ttk::frame .main.subframe3
    pack .main.subframe3 -side bottom -anchor s -padx 10 -pady 10

    # Button1
    ttk::button .main.subframe3.button1 -text "Previous" -command {
        # command here
    }
    pack .main.subframe3.button1 -side left -padx 5

    # Button2
    ttk::button .main.subframe3.button2 -text "Open.tex" -command {
        # command here
    }
    pack .main.subframe3.button2 -side left -padx 5

    # Button3
    ttk::button .main.subframe3.button3 -text "Preview" -command {
        # command here
    }
    pack .main.subframe3.button3 -side left -padx 5

    # Button4
    ttk::button .main.subframe3.button4 -text "Next" -command {
        # command here
    }
    pack .main.subframe3.button4 -side left -padx 5
}

# Main procedure to run the script
proc main {} {
    # Set window size
    wm geometry . 400x250

    # 1. Select folder
    set folder [select_folder]

    # 2. Read options from the .csv file
    set options [read_csv $folder]

    # 3. Call helper function with options
    helper $options
}

# Call main
main

# Start the event loop
vwait forever
