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


static void midiNotify_BlockTrampoline(const MIDINotification *message, void *refCon) {
    void (^block)(const MIDINotification*) = (__bridge typeof(block))refCon;
    if (!block) return;
    block(message);
}

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


OSStatus MIDIClientCreate_withBlock(MIDIClientRef *outClient, CFStringRef name, void (^notifyRefCon)(const MIDINotification *message))
{
    // Copy the block and store it in the refCon passed to MIDIClientCreate.
    // The midiNotify_BlockTrampoline function converts the provided refCon
    // back into a block and invokes it.
    void *refCon = (__bridge_retained void*)notifyRefCon;
    
    return MIDIClientCreate(name, &midiNotify_BlockTrampoline, refCon, outClient);
}

OSStatus MIDIInputPortCreate_withBlock(MIDIClientRef midiClient, CFStringRef name, MIDIPortRef* outport, void (^readRefCon)(const MIDITimeStamp ts, const UInt8 *data, const UInt16 len)) {
    
    // Copy the block and store it in the refCon passed to MIDIInputPortCreate.
    // The midiReadPacket_BlockTrampoline function converts the provided refCon
    // back into a block and invokes it.
    void *refCon = (__bridge_retained void*)readRefCon;
    
    return MIDIInputPortCreate(midiClient,
                               name,
                               &midiReadPacket_BlockTrampoline,
                               refCon,
                               outport);

}

/*
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









