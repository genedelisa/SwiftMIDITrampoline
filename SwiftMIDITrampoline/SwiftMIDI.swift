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
    
    typealias MIDIReader = (ts:MIDITimeStamp, data: UnsafePointer<UInt8>, length: UInt16) -> ()
    typealias MIDINotifier = (message:UnsafePointer<MIDINotification>) -> ()
    
    var midiReader: MIDIReader?
    var midiNotifier: MIDINotifier?
    
    func initMIDI(midiNotifier: MIDINotifier? = nil, reader: MIDIReader? = nil) {

        if midiNotifier != nil {
            self.midiNotifier = midiNotifier
        } else {
            self.midiNotifier = myNotifyCallback
        }
        
        if reader != nil {
            self.midiReader = reader
        } else {
            self.midiReader = myPacketReadCallback
        }
        
        enableNetwork()
        
        var status = OSStatus(noErr)
        var s:CFString = "MyClient"
        status = MIDIClientCreate_withBlock(s, &midiClientRef, midiNotifier)
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
            self.midiReader)
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
        
        var notification = message.memory
        println("MIDI Notify, messageId= \(notification.messageID)")
        
        switch (notification.messageID) {
        case MIDINotificationMessageID(kMIDIMsgSetupChanged):
            NSLog("MIDI setup changed")
            break
            
        case MIDINotificationMessageID(kMIDIMsgObjectAdded):
            NSLog("added")
            
            var m:MIDIObjectAddRemoveNotification =
            unsafeBitCast(notification, MIDIObjectAddRemoveNotification.self)
            
            println("id \(m.messageID)")
            println("size \(m.messageSize)")
            println("child \(m.child)")
            println("child type \(m.childType)")
            println("parent \(m.parent)")
            println("parentType \(m.parentType)")
            
            break
            
        case MIDINotificationMessageID(kMIDIMsgObjectRemoved):
            NSLog("kMIDIMsgObjectRemoved")
            break
            
        case MIDINotificationMessageID(kMIDIMsgPropertyChanged):
            NSLog("kMIDIMsgPropertyChanged")
            break
            
        case MIDINotificationMessageID(kMIDIMsgThruConnectionsChanged):
            NSLog("MIDI thru connections changed.")
            break
            
        case MIDINotificationMessageID(kMIDIMsgSerialPortOwnerChanged):
            NSLog("MIDI serial port owner changed.")
            break
            
        case MIDINotificationMessageID(kMIDIMsgIOError):
            NSLog("MIDI I/O error.")
            break
            
        default:
            println("huh?")
            break
        }

    }
    
    
    func myPacketReadCallback(ts:MIDITimeStamp, data:UnsafePointer<UInt8>, len:UInt16) {
        println("got a packet! ts:\(ts) status: \(data[0]) len \(len)")

        let status = data[0]
        let rawStatus = data[0] & 0xF0 // without channel
        var channel = status & 0x0F
        
        switch rawStatus {

        case 0x80:
            println("Note off. Channel \(channel) note \(data[1]) velocity \(data[2])")

        case 0x90:
            println("Note on. Channel \(channel) note \(data[1]) velocity \(data[2])")

        case 0xA0:
            println("Polyphonic Key Pressure (Aftertouch). Channel \(channel) note \(data[1]) pressure \(data[2])")
            
        case 0xB0:
            println("Control Change. Channel \(channel) controller \(data[1]) value \(data[2])")
            
        case 0xC0:
            println("Program Change. Channel \(channel) program \(data[1])")
            
        case 0xD0:
            println("Channel Pressure (Aftertouch). Channel \(channel) pressure \(data[1])")
            
        case 0xE0:
            println("Pitch Bend Change. Channel \(channel) lsb \(data[1]) msb \(data[2])")
            
        case 0xFE:
            println("active sensing")
            
        default: println("unhandled message \(status)")
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