
    grid [frame .gender ]
    grid [label .label1  -text "Male" -textvariable myLabel1 ] 
    grid [radiobutton .gender.maleBtn -text "Male"   -variable gender -value "Male"
    -command "set  myLabel1 Male"] -row 1 -column 2
    grid [radiobutton .gender.femaleBtn -text "Female" -variable gender -value "Female"
    -command "set  myLabel1 Female"] -row 1 -column 3
    .gender.maleBtn select
    grid [label .myLabel2  -text "Range 1 not selected" -textvariable myLabelValue2 ] 
    grid [checkbutton .chk1 -text "Range 1" -variable occupied1 -command {if {$occupied1 } {
    set myLabelValue2 {Range 1 selected}
    } else {
    set myLabelValue2 {Range 1 not selected}
    } }]
    proc setLabel {text} {
    .label configure -text $text 
    }
