//
//  SwiftMIDI.swift
//  SwiftMIDITrampoline
//
//  Created by Gene De Lisa on 6/3/15.
//  Copyright (c) 2015 Gene De Lisa. All rights reserved.
//

import Foundation

import CoreMIDI

class SwiftMIDI {
    
    var midiClientRef = MIDIClientRef()

    var midiInputPortref = MIDIPortRef()
    
    func initMIDI() {

        enableNetwork()
        
        var status = OSStatus(noErr)
        var s:CFString = "MyClient"
        status = MIDIClientCreate_withBlock(s, &midiClientRef, myNotifyCallback)
        if status != noErr {
            println("error creating client: \(status)")
            return
        } else {
            println("midi client created \(midiClientRef)")
        }
        
        var portString:CFString = "MyClient In"
        status = MIDIInputPortCreate_withBlock(portString,
            midiClientRef,
            &midiInputPortref,
            myPacketReadCallback)
        if status != noErr {
            println("error creating input port: \(status)")
            return
        } else {
            println("midi input port created \(midiInputPortref)")
        }
        
        connect()
    }
    
    func myNotifyCallback(message:UnsafePointer<MIDINotification>) -> Void {
        println("got a MIDINotification!")
    }
    
    func myPacketReadCallback(ts:MIDITimeStamp, data:UnsafePointer<UInt8>, len:UInt16) {
        println("got a packet! ts:\(ts) status: \(data[0]) len \(len)")
        

        let status = data[0]
        // without channel
        let rawStatus = data[0] & 0xF0
        
        switch rawStatus {
        case 0x80:
            var channel = status & 0x0F
            println("note off. channel \(channel) note \(data[1]) velocity \(data[2])")
        case 0x90:
            var channel = status & 0x0F
            println("note on. channel \(channel) note \(data[1]) velocity \(data[2])")

        default: break
        }
        
        
    }
    
    
    
    func enableNetwork() {
        var session = MIDINetworkSession.defaultSession()
        session.enabled = true
        session.connectionPolicy = MIDINetworkConnectionPolicy_Anyone
        println("net session enabled \(MIDINetworkSession.defaultSession().enabled)")
    }
    
    func connect() {
        var status = OSStatus(noErr)
        var sourceCount = MIDIGetNumberOfSources()
        println("source count \(sourceCount)")
        
        for srcIndex in 0 ..< sourceCount {
            let mep = MIDIGetSource(srcIndex)
            
            let midiEndPoint = MIDIGetSource(srcIndex)
            status = MIDIPortConnectSource(self.midiInputPortref,
                midiEndPoint,
                nil)
            if status == OSStatus(noErr) {
                println("yay! connected endpoint to midiInputPortref")
            } else {
                println("oh crap!")
            }
            
        }
    }


}