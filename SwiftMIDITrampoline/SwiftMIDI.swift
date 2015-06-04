//
//  SwiftMIDI.swift
//  SwiftMIDITrampoline
//
//  Created by Gene De Lisa on 6/3/15.
//  Copyright (c) 2015 Gene De Lisa. All rights reserved.
//

import Foundation

import CoreMIDI

import AudioToolbox
import CoreAudio


class SwiftMIDI {
    
    var midiClientRef = MIDIClientRef()
    
    var destEndpointRef = MIDIEndpointRef()
    
    var midiInputPortref = MIDIPortRef()
    
    typealias MIDIReader = (ts:MIDITimeStamp, data: UnsafePointer<UInt8>, length: UInt16) -> ()
    typealias MIDINotifier = (message:UnsafePointer<MIDINotification>) -> ()
    var midiReader: MIDIReader?
    var midiNotifier: MIDINotifier?
    
    var musicPlayer:MusicPlayer?
    
    var processingGraph = AUGraph()
    
    var samplerUnit = AudioUnit()
    
    init() {
        augraphSetup()
        graphStart()
        // after the graph starts
        loadSF2Preset(0)
        
        self.midiNotifier = myNotifyCallback
        self.midiReader = myPacketReadCallback
        
        CAShow(UnsafeMutablePointer<MusicSequence>(self.processingGraph))
        
    }
    
    
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
        status = MIDIClientCreate_withBlock(&midiClientRef, s, midiNotifier)
        if status != noErr {
            println("error creating client: \(status)")
            return
        } else {
            println("midi client created \(midiClientRef)")
        }
        
        var portString:CFString = "MyClient In"
        status = MIDIInputPortCreate_withBlock(midiClientRef,
            portString,
            &midiInputPortref,
            self.midiReader)
        if status != noErr {
            println("error creating input port: \(status)")
            return
        } else {
            println("midi input port created \(midiInputPortref)")
        }
        
        var destString:CFString = "Virtual Dest"
        status = MIDIDestinationCreate_withBlock(midiClientRef,
            destString,
            &destEndpointRef,
            myPacketReadCallback)
        if status != noErr {
            println("error creating virtual destination: \(status)")
        } else {
            println("midi virtual destination created \(destEndpointRef)")
        }
        
        
        connect()
        
        playWithMusicPlayer()
        
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
    
    /*
    Since we have a virtual destination, we need to forard the events to the sampler.
    */
    //TODO: implement the other forarding functions besides noteOn and noteOff.
    
    func myPacketReadCallback(ts:MIDITimeStamp, data:UnsafePointer<UInt8>, len:UInt16) {
        
        print("ts:\(ts) ")
        
        let status = data[0]
        let rawStatus = data[0] & 0xF0 // without channel
        var channel = status & 0x0F
        
        switch rawStatus {
            
        case 0x80:
            println("Note off. Channel \(channel) note \(data[1]) velocity \(data[2])")
            // forward to sampler
            // Yes, bad API design. The read proc gives you the data as UInt8s, yet you need a UInt32 to play it with MusicDeviceMIDIEvent
            playNoteOff(UInt32(channel), noteNum: UInt32(data[1]))
            
        case 0x90:
            println("Note on. Channel \(channel) note \(data[1]) velocity \(data[2])")
            // forward to sampler
            playNoteOn(UInt32(channel), noteNum:UInt32(data[1]), velocity: UInt32(data[2]))
            
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
            
        default: println("Unhandled message \(status)")
        }
        
    }
    
    func enableNetwork() {
        var session = MIDINetworkSession.defaultSession()
        session.enabled = true
        session.connectionPolicy = MIDINetworkConnectionPolicy_Anyone
        println("net session enabled \(MIDINetworkSession.defaultSession().enabled)")
    }
    
    /**
    Connect our input port to all midi sources.
    */
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
                println("yay! connected source endpoint \(midiEndPoint) to midiInputPortref")
            } else {
                println("oh crap!")
            }
        }
    }
    
    // Testing virtual destination
    
    func playWithMusicPlayer() {
        var sequence = createMusicSequence()
        self.musicPlayer = createMusicPlayer(sequence)
        playMusicPlayer()
    }
    
    func createMusicPlayer(musicSequence:MusicSequence) -> MusicPlayer {
        var musicPlayer = MusicPlayer()
        var status = OSStatus(noErr)
        
        status = NewMusicPlayer(&musicPlayer)
        if status != OSStatus(noErr) {
            println("bad status \(status) creating player")
        }
        
        status = MusicPlayerSetSequence(musicPlayer, musicSequence)
        if status != OSStatus(noErr) {
            println("setting sequence \(status)")
        }
        
        status = MusicPlayerPreroll(musicPlayer)
        if status != OSStatus(noErr) {
            println("prerolling player \(status)")
        }
        
        status = MusicSequenceSetMIDIEndpoint(musicSequence, self.destEndpointRef)
        if status != OSStatus(noErr) {
            println("error setting sequence endpoint \(status)")
        }
        
        return musicPlayer
    }
    
    func playMusicPlayer() {
        var status = OSStatus(noErr)
        var playing = Boolean(0)
        
        if let player = self.musicPlayer {
            status = MusicPlayerIsPlaying(player, &playing)
            if playing != 0 {
                println("music player is playing. stopping")
                status = MusicPlayerStop(player)
                if status != OSStatus(noErr) {
                    println("Error stopping \(status)")
                    return
                }
            } else {
                println("music player is not playing.")
            }
            
            status = MusicPlayerSetTime(player, 0)
            if status != OSStatus(noErr) {
                println("setting time \(status)")
                return
            }
            
            status = MusicPlayerStart(player)
            if status != OSStatus(noErr) {
                println("Error starting \(status)")
                return
            }
        }
    }
    
    
    func createMusicSequence() -> MusicSequence {
        
        var musicSequence = MusicSequence()
        var status = NewMusicSequence(&musicSequence)
        if status != OSStatus(noErr) {
            println("\(__LINE__) bad status \(status) creating sequence")
        }
        
        // just for fun, add a tempo track.
        var tempoTrack = MusicTrack()
        if MusicSequenceGetTempoTrack(musicSequence, &tempoTrack) != noErr {
            assert(tempoTrack != nil, "Cannot get tempo track")
        }
        //MusicTrackClear(tempoTrack, 0, 1)
        if MusicTrackNewExtendedTempoEvent(tempoTrack, 0.0, 128.0) != noErr {
            println("could not set tempo")
        }
        if MusicTrackNewExtendedTempoEvent(tempoTrack, 4.0, 256.0) != noErr {
            println("could not set tempo")
        }
        
        
        // add a track
        var track = MusicTrack()
        status = MusicSequenceNewTrack(musicSequence, &track)
        if status != OSStatus(noErr) {
            println("error creating track \(status)")
        }
        
        // bank select msb
        var chanmess = MIDIChannelMessage(status: 0xB0, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            println("creating bank select event \(status)")
        }
        // bank select lsb
        chanmess = MIDIChannelMessage(status: 0xB0, data1: 32, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            println("creating bank select event \(status)")
        }
        
        // program change. first data byte is the patch, the second data byte is unused for program change messages.
        chanmess = MIDIChannelMessage(status: 0xC0, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            println("creating program change event \(status)")
        }
        
        // now make some notes and put them on the track
        var beat = MusicTimeStamp(0.0)
        for i:UInt8 in 60...72 {
            var mess = MIDINoteMessage(channel: 0,
                note: i,
                velocity: 64,
                releaseVelocity: 0,
                duration: 1.0 )
            status = MusicTrackNewMIDINoteEvent(track, beat, &mess)
            if status != OSStatus(noErr) {
                println("creating new midi note event \(status)")
            }
            beat++
        }
        
        // associate the AUGraph with the sequence.
        MusicSequenceSetAUGraph(musicSequence, self.processingGraph)
        
        // Let's see it
        CAShow(UnsafeMutablePointer<MusicSequence>(musicSequence))
        
        return musicSequence
    }
    
    func augraphSetup() {
        var status = OSStatus(noErr)
        status = NewAUGraph(&self.processingGraph)
        CheckError(status)
        
        // create the sampler
        
        //https://developer.apple.com/library/prerelease/ios/documentation/AudioUnit/Reference/AudioComponentServicesReference/index.html#//apple_ref/swift/struct/AudioComponentDescription
        
        var samplerNode = AUNode()
        var cd = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_MusicDevice),
            componentSubType: OSType(kAudioUnitSubType_Sampler),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph, &cd, &samplerNode)
        CheckError(status)
        
        // create the ionode
        var ioNode = AUNode()
        var ioUnitDescription = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph, &ioUnitDescription, &ioNode)
        CheckError(status)
        
        // now do the wiring. The graph needs to be open before you call AUGraphNodeInfo
        status = AUGraphOpen(self.processingGraph)
        CheckError(status)
        
        status = AUGraphNodeInfo(self.processingGraph, samplerNode, nil, &self.samplerUnit)
        CheckError(status)
        
        var ioUnit  = AudioUnit()
        status = AUGraphNodeInfo(self.processingGraph, ioNode, nil, &ioUnit)
        CheckError(status)
        
        var ioUnitOutputElement = AudioUnitElement(0)
        var samplerOutputElement = AudioUnitElement(0)
        status = AUGraphConnectNodeInput(self.processingGraph,
            samplerNode, samplerOutputElement, // srcnode, inSourceOutputNumber
            ioNode, ioUnitOutputElement) // destnode, inDestInputNumber
        CheckError(status)
    }
    
    
    func graphStart() {
        //https://developer.apple.com/library/prerelease/ios/documentation/AudioToolbox/Reference/AUGraphServicesReference/index.html#//apple_ref/c/func/AUGraphIsInitialized
        
        var status = OSStatus(noErr)
        var outIsInitialized:Boolean = 0
        status = AUGraphIsInitialized(self.processingGraph, &outIsInitialized)
        println("isinit status is \(status)")
        println("bool is \(outIsInitialized)")
        if outIsInitialized == 0 {
            status = AUGraphInitialize(self.processingGraph)
            CheckError(status)
        }
        
        var isRunning = Boolean(0)
        AUGraphIsRunning(self.processingGraph, &isRunning)
        println("running bool is \(isRunning)")
        if isRunning == 0 {
            status = AUGraphStart(self.processingGraph)
            CheckError(status)
        }
        
    }
    
    func playNoteOn(channel:UInt32, noteNum:UInt32, velocity:UInt32)    {
        var noteCommand = UInt32(0x90 | channel)
        var status  = OSStatus(noErr)
        status = MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, velocity, 0)
        CheckError(status)
    }
    
    func playNoteOff(channel:UInt32, noteNum:UInt32)    {
        var noteCommand = UInt32(0x80 | channel)
        var status : OSStatus = OSStatus(noErr)
        status = MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, 0, 0)
        CheckError(status)
    }
    
    
    /// loads preset into self.samplerUnit
    func loadSF2Preset(preset:UInt8)  {
        
        // This is the MuseCore soundfont. Change it to the one you have.
        if let bankURL = NSBundle.mainBundle().URLForResource("GeneralUser GS MuseScore v1.442", withExtension: "sf2") {
            var instdata = AUSamplerInstrumentData(fileURL: Unmanaged.passUnretained(bankURL),
                instrumentType: UInt8(kInstrumentType_DLSPreset),
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB),
                presetID: preset)
            
            
            var status = AudioUnitSetProperty(
                self.samplerUnit,
                AudioUnitPropertyID(kAUSamplerProperty_LoadInstrument),
                AudioUnitScope(kAudioUnitScope_Global),
                0,
                &instdata,
                UInt32(sizeof(AUSamplerInstrumentData)))
            CheckError(status)
        }
    }
    
    
    
    /**
    Not as detailed as Adamson's CheckError, but adequate.
    For other projects you can uncomment the Core MIDI constants.
    */
    func CheckError(error:OSStatus) {
        if error == 0 {return}
        
        switch(Int(error)) {
            // AudioToolbox
        case kAUGraphErr_NodeNotFound:
            println("Error:kAUGraphErr_NodeNotFound \n")
            
        case kAUGraphErr_OutputNodeErr:
            println( "Error:kAUGraphErr_OutputNodeErr \n")
            
        case kAUGraphErr_InvalidConnection:
            println("Error:kAUGraphErr_InvalidConnection \n")
            
        case kAUGraphErr_CannotDoInCurrentContext:
            println( "Error:kAUGraphErr_CannotDoInCurrentContext \n")
            
        case kAUGraphErr_InvalidAudioUnit:
            println( "Error:kAUGraphErr_InvalidAudioUnit \n")
            
        case kMIDIInvalidClient :
            println( "kMIDIInvalidClient ")
            
        case kMIDIInvalidPort :
            println( "kMIDIInvalidPort ")
            
        case kMIDIWrongEndpointType :
            println( "kMIDIWrongEndpointType")
            
        case kMIDINoConnection :
            println( "kMIDINoConnection ")
            
        case kMIDIUnknownEndpoint :
            println( "kMIDIUnknownEndpoint ")
            
        case kMIDIUnknownProperty :
            println( "kMIDIUnknownProperty ")
            
        case kMIDIWrongPropertyType :
            println( "kMIDIWrongPropertyType ")
            
        case kMIDINoCurrentSetup :
            println( "kMIDINoCurrentSetup ")
            
        case kMIDIMessageSendErr :
            println( "kMIDIMessageSendErr ")
            
        case kMIDIServerStartErr :
            println( "kMIDIServerStartErr ")
            
        case kMIDISetupFormatErr :
            println( "kMIDISetupFormatErr ")
            
        case kMIDIWrongThread :
            println( "kMIDIWrongThread ")
            
        case kMIDIObjectNotFound :
            println( "kMIDIObjectNotFound ")
            
        case kMIDIIDNotUnique :
            println( "kMIDIIDNotUnique ")
            
        case kAudioToolboxErr_InvalidSequenceType :
            println( " kAudioToolboxErr_InvalidSequenceType ")
            
        case kAudioToolboxErr_TrackIndexError :
            println( " kAudioToolboxErr_TrackIndexError ")
            
        case kAudioToolboxErr_TrackNotFound :
            println( " kAudioToolboxErr_TrackNotFound ")
            
        case kAudioToolboxErr_EndOfTrack :
            println( " kAudioToolboxErr_EndOfTrack ")
            
        case kAudioToolboxErr_StartOfTrack :
            println( " kAudioToolboxErr_StartOfTrack ")
            
        case kAudioToolboxErr_IllegalTrackDestination :
            println( " kAudioToolboxErr_IllegalTrackDestination")
            
        case kAudioToolboxErr_NoSequence :
            println( " kAudioToolboxErr_NoSequence ")
            
        case kAudioToolboxErr_InvalidEventType :
            println( " kAudioToolboxErr_InvalidEventType")
            
        case kAudioToolboxErr_InvalidPlayerState :
            println( " kAudioToolboxErr_InvalidPlayerState")
            
        case kAudioUnitErr_InvalidProperty :
            println( " kAudioUnitErr_InvalidProperty")
            
        case kAudioUnitErr_InvalidParameter :
            println( " kAudioUnitErr_InvalidParameter")
            
        case kAudioUnitErr_InvalidElement :
            println( " kAudioUnitErr_InvalidElement")
            
        case kAudioUnitErr_NoConnection :
            println( " kAudioUnitErr_NoConnection")
            
        case kAudioUnitErr_FailedInitialization :
            println( " kAudioUnitErr_FailedInitialization")
            
        case kAudioUnitErr_TooManyFramesToProcess :
            println( " kAudioUnitErr_TooManyFramesToProcess")
            
        case kAudioUnitErr_InvalidFile :
            println( " kAudioUnitErr_InvalidFile")
            
        case kAudioUnitErr_FormatNotSupported :
            println( " kAudioUnitErr_FormatNotSupported")
            
        case kAudioUnitErr_Uninitialized :
            println( " kAudioUnitErr_Uninitialized")
            
        case kAudioUnitErr_InvalidScope :
            println( " kAudioUnitErr_InvalidScope")
            
        case kAudioUnitErr_PropertyNotWritable :
            println( " kAudioUnitErr_PropertyNotWritable")
            
        case kAudioUnitErr_InvalidPropertyValue :
            println( " kAudioUnitErr_InvalidPropertyValue")
            
        case kAudioUnitErr_PropertyNotInUse :
            println( " kAudioUnitErr_PropertyNotInUse")
            
        case kAudioUnitErr_Initialized :
            println( " kAudioUnitErr_Initialized")
            
        case kAudioUnitErr_InvalidOfflineRender :
            println( " kAudioUnitErr_InvalidOfflineRender")
            
        case kAudioUnitErr_Unauthorized :
            println( " kAudioUnitErr_Unauthorized")
            
        default:
            println("huh?")
        }
    }
    
    
}