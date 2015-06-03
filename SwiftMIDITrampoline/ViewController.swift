//
//  ViewController.swift
//  SwiftMIDITrampoline
//
//  Created by Gene De Lisa on 6/3/15.
//  Copyright (c) 2015 Gene De Lisa. All rights reserved.
//

import UIKit


class ViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var midi = SwiftMIDI()
        // call this without the param and it will print to stdout
        midi.initMIDI(reader: myPacketReadCallback)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    var previousTimeStamp = MIDITimeStamp(0)
    
    func myPacketReadCallback(ts:MIDITimeStamp, data:UnsafePointer<UInt8>, len:UInt16) {
        let status = data[0]
        let rawStatus = data[0] & 0xF0 // without channel
        var channel = status & 0x0F
        var delta = MIDITimeStamp(0)
        
        if self.previousTimeStamp != 0 {
            delta = ts - self.previousTimeStamp
        }
        
        
        switch rawStatus {
            
        case 0x80:

            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Note off. Channel \(channel) note \(data[1]) velocity \(data[2])\n")
            })
            
        case 0x90:

            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Note on. Channel \(channel) note \(data[1]) velocity \(data[2])\n")
            })
            
        case 0xA0:
            println("Polyphonic Key Pressure (Aftertouch). Channel \(channel) note \(data[1]) pressure \(data[2])")
            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Note on. Channel \(channel) note \(data[1]) velocity \(data[2])\n")
            })
        case 0xB0:

            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Control Change. Channel \(channel) controller \(data[1]) value \(data[2])\n")
            })
            
        case 0xC0:
            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Program Change. Channel \(channel) program \(data[1])\n")
            })
        case 0xD0:

            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Channel Pressure (Aftertouch). Channel \(channel) pressure \(data[1])\n")

            })
        case 0xE0:

            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("Pitch Bend Change. Channel \(channel) lsb \(data[1]) msb \(data[2])\n")

            })
        case 0xFE:
            println("active sensing")
            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = self.textView.text.stringByAppendingString("\n")
            })
            
        default: println("unhandled message \(status)")
        }

        // make the textview scroll to bottom
        dispatch_async(dispatch_get_main_queue(), {
            let len = count(self.textView.text)
            if len > 0 {
                let bottom = NSMakeRange(len - 1, 1)
                self.textView.scrollRangeToVisible(bottom)
            }
        })
        
        
        self.previousTimeStamp = ts

    }
    
   

}

