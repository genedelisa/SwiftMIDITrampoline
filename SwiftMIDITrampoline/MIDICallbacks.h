//
//  MIDICallbacks.h
//  SwiftMIDITrampoline
//
//  Created by Gene De Lisa on 6/3/15.
//  Copyright (c) 2015 Gene De Lisa. All rights reserved.
//


@import CoreMIDI;

#ifndef SwiftMIDITrampoline_MIDICallbacks_h
#define SwiftMIDITrampoline_MIDICallbacks_h


OSStatus MIDIClientCreate_withBlock(CFStringRef name, MIDIClientRef *outClient, void (^notifyRefCon)(const MIDINotification *message));

OSStatus MIDIInputPortCreate_withBlock(CFStringRef name, MIDIClientRef midiClient, MIDIPortRef* outport, void (^readRefCon)(const MIDITimeStamp ts, const UInt8 *datum, const UInt16 len));
//
//OSStatus MIDIInputPortCreate_withBlock(CFStringRef name, MIDIClientRef midiClient, MIDIPortRef* outport, void (^notifyRefCon)(const MIDIPacketList *packetList, const void *srcConnRefCon));



//@interface MIDICallbacks : NSObject
//@end

#endif
