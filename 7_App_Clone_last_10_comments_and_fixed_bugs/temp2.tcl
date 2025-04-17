# Create a Tk interface with a text widget
package require Tk
wm title . "Select All Example"

# Create a text widget
text .text -width 30 -height 5
pack .text

# Insert some example text
.text insert end "Try selecting all text using Ctrl+A."

# Bind the "Control+A" keyboard shortcut to select all text in the text widget
bind .text <Control-a> {
    focus .text
    .text tag add sel 1.0 end
    break
}

# Start the Tk event loop

