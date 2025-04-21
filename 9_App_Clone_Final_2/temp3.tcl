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
        next {
             bind . <$keyseq> {
                next_tex
            }
        }
        previous {
              bind . <$keyseq> {
                previous_tex
            }
        }
        
       
    }
}
