//
//  MIDICallbacks.m
//  SwiftMIDITrampoline
//
//  Created by Gene De Lisa on 6/3/15.
//  Copyright (c) 2015 Gene De Lisa. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MIDICallbacks.h"



// in coremidi
//typedef void (*MIDINotifyProc)(const MIDINotification *message, void *refCon);

/*
 This is the trampoline to your notification function.
 */
static void midiNotify_BlockTrampoline(const MIDINotification *message, void *refCon) {
    void (^block)(const MIDINotification*) = (__bridge typeof(block))refCon;
    if (!block) return;
    block(message);
}

/*
 This is the trampoline to your input function.
 Suggestion: Do not block the CoreMIDI realtime thread. This passes off to a block.
 Do not call blocking functions like printf(), NSLog(), malloc() or Objective C method calls from any CoreMIDI I/O context such as the input callback.
 */
static void midiReadPacket_BlockTrampoline(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon) {

    void (^block)(MIDITimeStamp, UInt8 *, UInt16) = (__bridge typeof(block))readProcRefCon;
    if (!block) return;
    
    const MIDIPacket *packet = &pktlist->packet[0];
    for (int i = 0;i < pktlist->numPackets; ++i) {
        UInt8 *data = (UInt8 *)packet->data;
        MIDITimeStamp ts = packet->timeStamp;
        block(ts, data, packet->length);
        packet = MIDIPacketNext(packet);
    }
}


/*!
	@function		MIDIClientCreate_withBlock
 
	@abstract 		Creates MIDI client.
 
	@param			outClient
                    The client to own the newly-created client
	@param			name
                    The name of the client.
    @param          readRefCon
                    Your Swift notification function that will be called.
	@result			An OSStatus result code.
 
	@discussion
 This will create a MIDI client and cause your Swift function to be called when MIDI inputs/output change.
 
 The Swift notification function should have this signature:
 
 func myNotifyCallback(message:UnsafePointer<MIDINotification>) -> Void

 */

OSStatus MIDIClientCreate_withBlock(MIDIClientRef *outClient, CFStringRef name, void (^notifyRefCon)(const MIDINotification *message))
{
    // Copy the block and store it in the refCon passed to MIDIClientCreate.
    // The midiNotify_BlockTrampoline function converts the provided refCon
    // back into a block and invokes it.
    void *refCon = (__bridge_retained void*)notifyRefCon;
    
    return MIDIClientCreate(name, &midiNotify_BlockTrampoline, refCon, outClient);
}


/*!
	@function		MIDIInputPortCreate_withBlock
 
	@abstract 		Creates MIDI input port.
 
	@param			midiClient
                    The client to own the newly-created port
	@param			name
                    The name of the port.
	@param			port
                    On successful return, points to the newly-created port.
    @param          readRefCon
                    Your Swift function that will be called.
	@result			An OSStatus result code.
 
	@discussion
 This will create an input port and cause your Swift function to be called when input data appears on the port.

 The Swift function should have this signature:
 
 func myReadCallback(ts:MIDITimeStamp, data:UnsafePointer<UInt8>, len:UInt16)

 */

OSStatus MIDIInputPortCreate_withBlock(MIDIClientRef midiClient, CFStringRef name, MIDIPortRef* port, void (^readRefCon)(const MIDITimeStamp ts, const UInt8 *data, const UInt16 len)) {
    
    // Copy the block and store it in the refCon passed to MIDIInputPortCreate.
    // The midiReadPacket_BlockTrampoline function converts the provided refCon
    // back into a block and invokes it.
    void *refCon = (__bridge_retained void*)readRefCon;
    
    return MIDIInputPortCreate(midiClient,
                               name,
                               &midiReadPacket_BlockTrampoline,
                               refCon,
                               port);
}


/*!
	@function		MIDIDestinationCreate_withBlock
 
	@abstract 		Creates MIDI virtual destination.
 
	@param			midiClient
                    The client to own the newly-created port
	@param			name
                    The name of the endpoint.
	@param			virtualDestination
                    On successful return, points to the newly-created endpoint.
    @param          readRefCon
                    Your Swift function that will be called.
	@result			An OSStatus result code.
 
	@discussion
 This will cause your Swift function to be called when input data appears on the endpoint.
 
 Apps need to have the audio key in their UIBackgroundModes in order to use CoreMIDI’s MIDISourceCreate and MIDIDestinationCreate functions.
 
 In your Info.plist add the key "Required background modes", then set the value of item 0 to audio.
 */

OSStatus MIDIDestinationCreate_withBlock(MIDIClientRef midiClient, CFStringRef name, MIDIEndpointRef* virtualDestination, void (^readRefCon)(const MIDITimeStamp ts, const UInt8 *data, const UInt16 len)) {

    void *refCon = (__bridge_retained void*)readRefCon;

    return MIDIDestinationCreate(midiClient,
                                 name,
                                 &midiReadPacket_BlockTrampoline,
                                 refCon,
                                 virtualDestination);
}









